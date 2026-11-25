extends Node
## Versioned atomic save container (ARCHITECTURE.md §17.1), replacing the source's localStorage
## (src/core/settings.ts, src/core/storage.ts).
##
## Every section is validated (CampaignSchema for the campaign v2 object and the legacy-import
## metadata); the Capacitor importer (LegacyImport) converts a legacy five-key payload after its raw
## backup. Real WebView acquisition is M9. All file access goes through `file_ops` (SaveFileOps),
## which tests replace to inject failures.
##
## Versions are exact: a container is format 3 only when `format_version` is a finite number equal
## to 3; anything greater (3.5 included) is a future format, anything smaller is unsupported. A
## present campaign is accepted only at version exactly 2; any other campaign version makes the
## whole container invalid (never silently reset to defaults).
##
## Transactions: every domain write (settings, a record, the campaign, an import) builds a complete
## candidate container, which commit() writes atomically; only after a successful write does the
## candidate replace `data`. A refused or failed write leaves `data` exactly as it was, so memory
## and the committed save never diverge (a fully written, validated temp may still be recovered by
## the next launch: crash recovery).
##
## Write protocol: save_v3.tmp is written and closed, re-read and validated, the previous valid
## save is rotated to save_v3.bak, then the temp file is renamed over save_v3.json.
## Load picks the NEWEST valid file among main, temp (a validated write whose rename never
## happened) and backup. An invalid or unreadable main is never deleted, rotated or replaced before
## its exact bytes are copied (save_v3.corrupt.json, or a hash-suffixed name when an earlier,
## different copy exists) and the copy is read back and verified; when that is impossible (the main
## cannot be read, the copy cannot be written or verified) the main stays untouched, the newest
## valid file (or the defaults) is shown read-only and every write is refused for the session. A
## valid main that is merely older than the temp becomes the backup instead. A newer, unknown
## container format in ANY of main, temp or backup is copied byte-for-byte (save_v3.future.json,
## save_v3.tmp.future.json, save_v3.bak.future.json; a failed copy is reported as
## future_copy_failed:<file>), no save file is touched again and every write is refused for the
## session (load_status, last_error, future_copy_errors, save_failed).

signal save_failed(reason: String)
## A user-visible notice became pending ("recovered_backup", "recovered_temp", "corrupt_reset",
## "future_blocked", "save_unpreserved"); the title shows it once (take_notice()).
signal notice_raised(kind: String)

const FORMAT_VERSION := 3
const FILE_NAME := "save_v3.json"
const TEMP_NAME := "save_v3.tmp"
const BACKUP_NAME := "save_v3.bak"
const CORRUPT_NAME := "save_v3.corrupt.json"
## Byte-for-byte copies of a future-format payload, per location.
const FUTURE_COPY := {FILE_NAME: "save_v3.future.json", TEMP_NAME: "save_v3.tmp.future.json", BACKUP_NAME: "save_v3.bak.future.json"}

const TEXT_SPEEDS := ["slow", "normal", "fast", "instant"]
const GESTURE_BINDINGS := ["off", "action", "bark", "sword", "shield", "switch", "run"]
const LEGACY_IMPORT_STATUSES := ["not_attempted", "imported", "imported_partial", "not_found", "retryable_error", "blocked"]

## Directory holding the save files (tests point it at an isolated user:// subdirectory).
var base_dir := "user://"
## Last load outcome: "new", "loaded", "recovered_from_temp", "recovered_from_backup",
## "future_version", "corrupt" (an invalid main was preserved and nothing valid was left: defaults)
## or "unpreserved" (an invalid or unreadable main could not be preserved: read-only session).
var load_status := "new"
## Reason of the last failed write ("" after a successful one).
var last_error := ""
## Test hook: simulate a crash during/after a write stage ("temp_partial" = torn temp write,
## "temp_written", "temp_validated", "backup_rotated"); "" in the game.
var fault_after := ""
## True while every write is refused for the session (a newer format found, or an invalid main
## that could not be preserved); see block_reason.
var write_blocked := false
## Why writes are refused: "future_version", "unpreserved" or "" (tests may set write_blocked
## alone, which reads as a future-format block).
var block_reason := ""
## Which of main/temp/backup hold a future format (last load).
var future_files: Array[String] = []
## Failed byte-for-byte copies of those files, "future_copy_failed:<file>" (last load). Writes stay
## blocked and the original stays untouched either way.
var future_copy_errors: Array[String] = []
## Test hook: locations (FILE_NAME/TEMP_NAME/BACKUP_NAME) whose future copy is cut short, to
## exercise the verification of the written copy; empty in the game.
var fault_future_copy: Array[String] = []
## The verified copy of the last invalid main ("" when none was needed).
var corrupt_copy := ""
var data: Dictionary = {}
## File operations (tests inject failures by replacing it).
var file_ops: SaveFileOps = SaveFileOps.new()
## False when the process runs a scripted main loop (the test runner and --script tools): the
## container then lives in memory until load_from_disk() is called for an explicit (isolated)
## directory, so no tool or test ever reads or writes the developer's real save.
var persist_to_disk := true
## The notice the title should show once ("" when none).
var pending_notice := ""

const CATALOG: StoryCatalog = preload("res://data/campaign/story_catalog.tres")


func _ready() -> void:
	if Engine.get_main_loop().get_script() != null:
		persist_to_disk = false
		data = default_container()
		load_status = "new"
		return
	load_from_disk()


## The notice for the title, once.
func take_notice() -> String:
	var n := pending_notice
	pending_notice = ""
	return n


func _raise(kind: String) -> void:
	pending_notice = kind
	notice_raised.emit(kind)


# --- Defaults -----------------------------------------------------------------------------------

static func default_settings() -> Dictionary:
	return {
		"muted": false,
		"volume": GameConfig.Audio.DEFAULT_VOLUME,
		"textSpeed": "normal",
		"lives": GameConfig.Lives.START,
		"controls": {
			"swipeUp": "sword",
			"swipeDown": "shield",
			"doubleTap": "bark",
			"run": "hold",
			"switcher": true,
			"hand": "right",
		},
	}


static func default_campaign() -> Dictionary:
	return CampaignSchema.new_campaign()


static func default_container() -> Dictionary:
	return {
		"format_version": FORMAT_VERSION,
		"written_at_unix_ms": 0,
		"settings": default_settings(),
		"records": {},
		"legacy_arcade_coins": {"present": false, "value": 0},
		"campaign": default_campaign(),
		"legacy_import": CampaignSchema.default_legacy_import(),
	}


# --- Validation (pure) --------------------------------------------------------------------------

static func _is_num(v: Variant) -> bool:
	return (typeof(v) == TYPE_FLOAT or typeof(v) == TYPE_INT) and is_finite(float(v))


## Port of loadSettings/validControls: fills gaps, clamps, drops unknown values.
static func normalize_settings(raw: Variant) -> Dictionary:
	var s: Dictionary = raw if raw is Dictionary else {}
	var d := default_settings()
	var out := {}
	out["muted"] = s["muted"] if s.get("muted") is bool else d["muted"]
	out["volume"] = clampf(float(s["volume"]), 0.0, 1.0) if _is_num(s.get("volume")) else d["volume"]
	out["textSpeed"] = s["textSpeed"] if TEXT_SPEEDS.has(s.get("textSpeed")) else "normal"
	out["lives"] = LivesRules.clamp_lives(float(s["lives"])) if _is_num(s.get("lives")) else GameConfig.Lives.START
	var c: Dictionary = s["controls"] if s.get("controls") is Dictionary else {}
	var dc: Dictionary = d["controls"]
	out["controls"] = {
		"swipeUp": c["swipeUp"] if GESTURE_BINDINGS.has(c.get("swipeUp")) else dc["swipeUp"],
		"swipeDown": c["swipeDown"] if GESTURE_BINDINGS.has(c.get("swipeDown")) else dc["swipeDown"],
		"doubleTap": c["doubleTap"] if GESTURE_BINDINGS.has(c.get("doubleTap")) else dc["doubleTap"],
		"run": "toggle" if c.get("run") == "toggle" else "hold",
		"switcher": c["switcher"] if c.get("switcher") is bool else dc["switcher"],
		"hand": "left" if c.get("hand") == "left" else "right",
	}
	return out


## A record value has exact shape {score: int >= 0, stars: 0..5 in half steps, time: seconds >= 0}.
static func normalize_record(raw: Variant) -> Variant:
	if not raw is Dictionary:
		return null
	var r: Dictionary = raw
	if not (_is_num(r.get("score")) and _is_num(r.get("stars")) and _is_num(r.get("time"))):
		return null
	return {
		"score": maxi(0, int(floor(float(r["score"])))),
		"stars": clampf(floor(float(r["stars"]) * 2.0 + 1e-6) / 2.0, 0.0, 5.0),
		"time": maxf(0.0, float(r["time"])),
	}


static func normalize_records(raw: Variant) -> Dictionary:
	var out := {}
	if raw is Dictionary:
		for key: Variant in raw:
			if not key is String:
				continue
			var rec: Variant = normalize_record(raw[key])
			if rec != null:
				out[key] = rec
	return out


## Validates a parsed container; returns {ok, data, error}. The version decision compares the
## finite numeric value exactly (never an integer cast): 3 is this format, anything greater (3.5
## included) a future format, anything smaller unsupported; none of those is normalized. A present
## campaign whose version is not exactly 2 makes the container invalid.
static func validate_container(raw: Variant) -> Dictionary:
	if not raw is Dictionary:
		return {"ok": false, "error": "not_an_object"}
	var r: Dictionary = raw
	if not _is_num(r.get("format_version")):
		return {"ok": false, "error": "missing_format_version"}
	var version := float(r["format_version"])
	if version > float(FORMAT_VERSION):
		return {"ok": false, "error": "future_format_version", "version": r["format_version"]}
	if version != float(FORMAT_VERSION):
		# No earlier Godot container exists; Capacitor data arrives through the legacy importer.
		return {"ok": false, "error": "unsupported_format_version", "version": r["format_version"]}
	var camp: Variant = r.get("campaign")
	if camp is Dictionary and not CampaignSchema.is_version(camp):
		return {"ok": false, "error": "unsupported_campaign_version", "version": (camp as Dictionary).get("version")}
	var out := default_container()
	out["written_at_unix_ms"] = maxi(0, int(r["written_at_unix_ms"])) if _is_num(r.get("written_at_unix_ms")) else 0
	out["settings"] = normalize_settings(r.get("settings"))
	out["records"] = normalize_records(r.get("records"))
	var lc: Variant = r.get("legacy_arcade_coins")
	if lc is Dictionary and lc.get("present") is bool and _is_num(lc.get("value")):
		out["legacy_arcade_coins"] = {"present": lc["present"], "value": maxi(0, int(floor(float(lc["value"]))))}
	# Campaign v2 and the legacy-import metadata: every field normalized (CampaignSchema).
	out["campaign"] = CampaignSchema.normalize(camp, CATALOG.ids())["data"]
	out["legacy_import"] = CampaignSchema.normalize_legacy_import(r.get("legacy_import"))
	return {"ok": true, "data": out}


# --- File operations ----------------------------------------------------------------------------

func _path(name: String) -> String:
	return base_dir.path_join(name)


static func _sha12(bytes: PackedByteArray) -> String:
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(bytes)
	return ctx.finish().hex_encode().substr(0, 12)


## Reads one save file: {"state": "absent"} | {"state": "unreadable"} (it exists but its bytes
## could not be read) | {"state": "read", "bytes", "parsed"} (parsed is null when the bytes are not
## JSON).
func _read_file(path: String) -> Dictionary:
	if not file_ops.exists(path):
		return {"state": "absent"}
	var read := file_ops.read_bytes(path)
	if not read["ok"]:
		return {"state": "unreadable"}
	var bytes: PackedByteArray = read["bytes"]
	# JSON.new().parse reports a corrupt file through its return code without logging an error.
	var json := JSON.new()
	var parsed: Variant = json.data if json.parse(bytes.get_string_from_utf8()) == OK else null
	return {"state": "read", "bytes": bytes, "parsed": parsed}


func load_from_disk() -> void:
	persist_to_disk = true
	pending_notice = ""
	write_blocked = false
	block_reason = ""
	last_error = ""
	corrupt_copy = ""
	future_files.clear()
	future_copy_errors.clear()
	file_ops.make_dir(base_dir)
	var files := {}
	var valid := {}
	for name: String in [FILE_NAME, TEMP_NAME, BACKUP_NAME]:
		files[name] = _read_file(_path(name))
		if files[name]["state"] != "read":
			continue
		var v := validate_container(files[name]["parsed"])
		if v["ok"]:
			valid[name] = v["data"]
		elif v.get("error") == "future_format_version":
			future_files.append(name)
	# Newest valid file by write time (main wins ties: it is checked first).
	var best_name := ""
	for name: String in [FILE_NAME, TEMP_NAME, BACKUP_NAME]:
		if valid.has(name) and (best_name == "" or int(valid[name]["written_at_unix_ms"]) > int(valid[best_name]["written_at_unix_ms"])):
			best_name = name
	if not future_files.is_empty():
		# A newer app wrote here: keep every byte, touch no save file, refuse every write. The newest
		# data is in the unknown format, so a future main means defaults; otherwise the valid
		# current-format main/temp/backup is shown read-only.
		for name in future_files:
			var copy_error := _preserve_future(name)
			if copy_error != "":
				future_copy_errors.append(copy_error)
		write_blocked = true
		block_reason = "future_version"
		last_error = future_copy_errors[0] if not future_copy_errors.is_empty() else "future_format_version"
		for reason in future_copy_errors:
			save_failed.emit(reason)
		data = default_container() if future_files.has(FILE_NAME) or best_name == "" else valid[best_name]
		load_status = "future_version"
		_raise("future_blocked")
		return
	var main: Dictionary = files[FILE_NAME]
	if main["state"] != "absent" and not valid.has(FILE_NAME):
		# An invalid or unreadable main: its exact bytes are copied and verified before anything may
		# replace it. When that is impossible it stays untouched and the session is read-only.
		var kept := _preserve_corrupt(main)
		if kept != "":
			write_blocked = true
			block_reason = "unpreserved"
			last_error = kept
			save_failed.emit(kept)
			data = valid[best_name] if best_name != "" else default_container()
			load_status = "unpreserved"
			_raise("save_unpreserved")
			return
	if best_name == "":
		data = default_container()
		load_status = "corrupt" if main["state"] != "absent" else "new"
		if file_ops.exists(_path(TEMP_NAME)):
			file_ops.remove(_path(TEMP_NAME))
		if main["state"] != "absent":
			_raise("corrupt_reset")
		return
	data = valid[best_name]
	if best_name == FILE_NAME:
		load_status = "loaded"
		# A leftover temp is either invalid or older than main: never trusted.
		if file_ops.exists(_path(TEMP_NAME)):
			file_ops.remove(_path(TEMP_NAME))
		return
	load_status = "recovered_from_temp" if best_name == TEMP_NAME else "recovered_from_backup"
	# The player hears about a recovery when the main save was unreadable or missing and the backup
	# or temp was used; a temp newer than a valid main is an interrupted write, recovered silently.
	if best_name == BACKUP_NAME or not valid.has(FILE_NAME):
		_raise("recovered_backup" if best_name == BACKUP_NAME else "recovered_temp")
	write_to_disk()


## Copies a future-format file byte-for-byte next to it and reads the copy back. Returns "" on
## success or "future_copy_failed:<file>". An identical copy is not rewritten; a different earlier
## copy is kept and the new one gets a hash suffix. A short or failed copy is removed (it is our own
## file; the original is never touched).
func _preserve_future(name: String) -> String:
	var failed := "future_copy_failed:" + name
	var read := file_ops.read_bytes(_path(name))
	if not read["ok"]:
		return failed
	var bytes: PackedByteArray = read["bytes"]
	var keep := _path(FUTURE_COPY[name])
	if file_ops.exists(keep):
		if file_ops.read_bytes(keep)["bytes"] == bytes:
			return ""
		keep = _path(FUTURE_COPY[name].get_basename() + "." + _sha12(bytes) + ".json")
		if file_ops.exists(keep) and file_ops.read_bytes(keep)["bytes"] == bytes:
			return ""
	var payload := bytes.slice(0, bytes.size() / 2) if fault_future_copy.has(name) else bytes
	var stored := file_ops.write_bytes(keep, payload)
	if not stored or file_ops.read_bytes(keep)["bytes"] != bytes:
		file_ops.remove(keep)
		return failed
	return ""


## Copies an invalid main's exact bytes (`file` from _read_file) and verifies the copy by reading it
## back. Returns "" when a verified copy exists, otherwise the reason ("main_unreadable",
## "corrupt_copy_write_failed", "corrupt_copy_verify_failed", "corrupt_copy_conflict"); the main is
## never touched here. An identical earlier copy counts; a different one is never overwritten (the new
## copy gets a hash suffix).
func _preserve_corrupt(file: Dictionary) -> String:
	if file["state"] != "read":
		return "main_unreadable"
	var bytes: PackedByteArray = file["bytes"]
	var keep := _path(CORRUPT_NAME)
	if file_ops.exists(keep):
		var old := file_ops.read_bytes(keep)
		if old["ok"] and old["bytes"] == bytes:
			corrupt_copy = keep
			return ""
		keep = _path("save_v3.corrupt.%s.json" % _sha12(bytes))
		if file_ops.exists(keep):
			var same := file_ops.read_bytes(keep)
			if same["ok"] and same["bytes"] == bytes:
				corrupt_copy = keep
				return ""
			return "corrupt_copy_conflict"
	if not file_ops.write_bytes(keep, bytes):
		file_ops.remove(keep)
		return "corrupt_copy_write_failed"
	var back := file_ops.read_bytes(keep)
	if not back["ok"] or back["bytes"] != bytes:
		file_ops.remove(keep)
		return "corrupt_copy_verify_failed"
	corrupt_copy = keep
	return ""


func _fail(reason: String) -> bool:
	last_error = reason
	save_failed.emit(reason)
	return false


## The reason a blocked session gives for a refused write.
func blocked_reason() -> String:
	return "write_blocked_unpreserved_save" if block_reason == "unpreserved" else "write_blocked_future_version"


## The transactional write: `candidate` (a complete container) gets a strictly increasing
## `written_at_unix_ms`, is written atomically and only then becomes `data`. A refused or failed
## write leaves `data` (and its written_at) exactly as it was; nothing of the candidate reaches
## memory. Returns true on success; last_error/save_failed report a failure.
func commit(candidate: Dictionary) -> bool:
	if write_blocked:
		return _fail(blocked_reason())
	var c := candidate.duplicate(true)
	# Strictly increasing so "newest valid file" is well defined even within one millisecond.
	var now := int(Time.get_unix_time_from_system() * 1000.0)
	c["written_at_unix_ms"] = maxi(now, int(data.get("written_at_unix_ms", 0)) + 1)
	if persist_to_disk and not _write_atomic(c):
		return false
	data = c
	last_error = ""
	return true


## Rewrites the current container (a recovered file promoted back to main; tests).
func write_to_disk() -> bool:
	return commit(data)


## Atomic write of `c`: temp → validate → rotate backup → rename. On failure the previous valid file
## stays recoverable; an invalid main is replaced only after its verified copy exists.
func _write_atomic(c: Dictionary) -> bool:
	var text := JSON.stringify(c, "  ", true)
	var tmp := _path(TEMP_NAME)
	if fault_after == "temp_partial":
		file_ops.write_bytes(tmp, text.substr(0, text.length() / 2).to_utf8_buffer())
		return _fail("simulated_crash_during_temp_write")
	if not file_ops.write_bytes(tmp, text.to_utf8_buffer()):
		return _fail("open_temp_failed")
	if fault_after == "temp_written":
		return _fail("simulated_crash_after_temp_written")
	var check := _read_file(tmp)
	if check["state"] != "read" or not validate_container(check["parsed"])["ok"]:
		file_ops.remove(tmp)
		return _fail("temp_validation_failed")
	if fault_after == "temp_validated":
		return _fail("simulated_crash_after_temp_validated")
	var main := _path(FILE_NAME)
	if file_ops.exists(main):
		var current := _read_file(main)
		var cv := validate_container(current["parsed"]) if current["state"] == "read" else {"ok": false}
		if cv["ok"]:
			if file_ops.exists(_path(BACKUP_NAME)) and file_ops.remove(_path(BACKUP_NAME)) != OK:
				return _fail("backup_remove_failed")
			if file_ops.rename(main, _path(BACKUP_NAME)) != OK:
				return _fail("backup_rotation_failed")
		elif cv.get("error") == "future_format_version":
			# A newer app wrote the main meanwhile: keep it, stop writing for the session.
			var copy_error := _preserve_future(FILE_NAME)
			if copy_error != "":
				future_copy_errors.append(copy_error)
			write_blocked = true
			block_reason = "future_version"
			return _fail(blocked_reason())
		else:
			var kept := _preserve_corrupt(current)
			if kept != "":
				return _fail(kept)
			if file_ops.remove(main) != OK:
				return _fail("corrupt_main_remove_failed")
	if fault_after == "backup_rotated":
		return _fail("simulated_crash_after_backup_rotated")
	if file_ops.rename(tmp, main) != OK:
		return _fail("rename_failed")
	return true


# --- Domain API ---------------------------------------------------------------------------------

## A deep copy of the container to build a transaction on (commit() it).
func candidate() -> Dictionary:
	return data.duplicate(true)


func get_settings() -> Dictionary:
	return (data["settings"] as Dictionary).duplicate(true)


## Settings save on confirmed change only, as one transaction. Returns {"changed": bool, "saved":
## bool}; when the write is refused or fails the previous settings stay in memory and on disk.
func set_settings(s: Dictionary) -> Dictionary:
	var normalized := normalize_settings(s)
	if normalized == data["settings"]:
		return {"changed": false, "saved": false}
	var c := candidate()
	c["settings"] = normalized
	return {"changed": true, "saved": commit(c)}


func get_record(level_id: String) -> Variant:
	var r: Dictionary = data["records"]
	return (r[level_id] as Dictionary).duplicate() if r.has(level_id) else null


## Port of saveRecord: keeps best score, best stars and lowest time independently, and persists
## at once (level completion) as one transaction. Returns {"new_best": bool, "saved": bool}; when
## the write fails or is blocked (future format) the previous record stays, in memory and on disk.
func save_record(level_id: String, rec: Dictionary) -> Dictionary:
	var old: Variant = (data["records"] as Dictionary).get(level_id)
	var new_best: bool = old == null or int(rec["score"]) > int(old["score"])
	var merged := {
		"score": maxi(int(old["score"]) if old != null else 0, int(rec["score"])),
		"stars": maxf(float(old["stars"]) if old != null else 0.0, float(rec["stars"])),
		"time": minf(float(old["time"]), float(rec["time"])) if old != null else float(rec["time"]),
	}
	var c := candidate()
	(c["records"] as Dictionary)[level_id] = normalize_record(merged)
	return {"new_best": new_best, "saved": commit(c)}


# --- Campaign and legacy import -------------------------------------------------------------------

## A deep copy of the saved campaign.
func get_campaign() -> Dictionary:
	return (data["campaign"] as Dictionary).duplicate(true)


## Stores a campaign at a source-equivalent campaign save (source saveCampaign), as one transaction:
## savedAt becomes `now_ms`, the object is normalized and the container written. Returns the write
## result; on failure the previous campaign stays.
func save_campaign(state: Dictionary, now_ms: int) -> bool:
	var st := state.duplicate(true)
	st["savedAt"] = now_ms
	var n := CampaignSchema.normalize(st, CATALOG.ids())
	if not n["ok"]:
		return _fail("campaign_not_version_2")
	var c := candidate()
	c["campaign"] = n["data"]
	return commit(c)


func legacy_coins() -> Dictionary:
	return (data["legacy_arcade_coins"] as Dictionary).duplicate()


func legacy_import_state() -> Dictionary:
	return (data["legacy_import"] as Dictionary).duplicate(true)


## Runs the Capacitor import through `source` (see campaign/legacy_import.gd).
func run_legacy_import(source: Object, now_ms: int, force: bool = false) -> Dictionary:
	return LegacyImport.run(self, source, now_ms, force)


func legacy_dir() -> String:
	return _path("legacy")
