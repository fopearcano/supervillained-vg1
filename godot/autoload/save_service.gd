extends Node
## Versioned atomic save container (ARCHITECTURE.md §17.1), replacing the source's localStorage
## (src/core/settings.ts, src/core/storage.ts).
##
## Milestone scope: settings and Green Zone records are validated and persisted; the campaign,
## legacy-coin and legacy-import sections are created with their exact defaults and preserved
## through round trips. Full campaign v1/v2 validation and Capacitor import land in M4/M9.
##
## Write protocol: save_v3.tmp is written and closed, re-read and validated, the previous valid
## save is rotated to save_v3.bak, then the temp file is renamed over save_v3.json.
## Load picks the NEWEST valid file among main, temp (a validated write whose rename never
## happened) and backup, preserves an INVALID main as save_v3.corrupt.json (a valid main that is
## merely older than the temp becomes the backup instead) and promotes a recovered file back to
## main. A newer, unknown container format in ANY of main, temp or backup is copied byte-for-byte
## (save_v3.future.json, save_v3.tmp.future.json, save_v3.bak.future.json; a failed copy is reported
## as future_copy_failed:<file>), no save file is touched again and every write is refused for the
## session (load_status, last_error, future_copy_errors, save_failed).

signal save_failed(reason: String)

const FORMAT_VERSION := 3
const FILE_NAME := "save_v3.json"
const TEMP_NAME := "save_v3.tmp"
const BACKUP_NAME := "save_v3.bak"
## Byte-for-byte copies of a future-format payload, per location.
const FUTURE_COPY := {FILE_NAME: "save_v3.future.json", TEMP_NAME: "save_v3.tmp.future.json", BACKUP_NAME: "save_v3.bak.future.json"}

const TEXT_SPEEDS := ["slow", "normal", "fast", "instant"]
const GESTURE_BINDINGS := ["off", "action", "bark", "sword", "shield", "switch", "run"]
const LEGACY_IMPORT_STATUSES := ["not_attempted", "imported", "imported_partial", "not_found", "retryable_error", "blocked"]

## Directory holding the save files (tests point it at an isolated user:// subdirectory).
var base_dir := "user://"
## Last load outcome: "new", "loaded", "recovered_from_temp", "recovered_from_backup",
## "future_version" or "corrupt" (main unreadable and nothing valid to recover; defaults used).
var load_status := "new"
## Reason of the last failed write ("" after a successful one).
var last_error := ""
## Test hook: simulate a crash during/after a write stage ("temp_partial" = torn temp write,
## "temp_written", "temp_validated", "backup_rotated"); "" in the game.
var fault_after := ""
## When a newer/unknown format was found it is preserved and never overwritten.
var write_blocked := false
## Which of main/temp/backup hold a future format (last load).
var future_files: Array[String] = []
## Failed byte-for-byte copies of those files, "future_copy_failed:<file>" (last load). Writes stay
## blocked and the original stays untouched either way.
var future_copy_errors: Array[String] = []
## Test hook: locations (FILE_NAME/TEMP_NAME/BACKUP_NAME) whose future copy is cut short, to
## exercise the verification of the written copy; empty in the game.
var fault_future_copy: Array[String] = []
var data: Dictionary = {}


func _ready() -> void:
	load_from_disk()


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
	return {
		"version": 2,
		"completed": [],
		"meters": {"commozione": 20, "supervillain": 10, "grace": 70, "standing": 50},
		"flags": {},
		"book": {"marvels": [], "items": [], "values": [], "remembered": [], "shards": []},
		"abilities": [],
		"coins": 0,
		"playTime": 0,
		"savedAt": null,
		"notice": null,
	}


static func default_container() -> Dictionary:
	return {
		"format_version": FORMAT_VERSION,
		"written_at_unix_ms": 0,
		"settings": default_settings(),
		"records": {},
		"legacy_arcade_coins": {"present": false, "value": 0},
		"campaign": default_campaign(),
		"legacy_import": {
			"status": "not_attempted",
			"source": "capacitor_webview",
			"attempt_count": 0,
			"attempted_at_unix_ms": null,
			"payload_sha256": null,
			"keys_present": [],
			"keys_imported": [],
			"keys_failed": [],
			"error_code": null,
		},
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


## Validates a parsed container; returns {ok, data, error}. Unknown versions are not normalized.
static func validate_container(raw: Variant) -> Dictionary:
	if not raw is Dictionary:
		return {"ok": false, "error": "not_an_object"}
	var r: Dictionary = raw
	if not _is_num(r.get("format_version")):
		return {"ok": false, "error": "missing_format_version"}
	var version := int(r["format_version"])
	if version > FORMAT_VERSION:
		return {"ok": false, "error": "future_format_version", "version": version}
	if version < FORMAT_VERSION:
		# No earlier Godot container exists; Capacitor data arrives through the legacy importer.
		return {"ok": false, "error": "unsupported_format_version", "version": version}
	var out := default_container()
	out["written_at_unix_ms"] = maxi(0, int(r["written_at_unix_ms"])) if _is_num(r.get("written_at_unix_ms")) else 0
	out["settings"] = normalize_settings(r.get("settings"))
	out["records"] = normalize_records(r.get("records"))
	var lc: Variant = r.get("legacy_arcade_coins")
	if lc is Dictionary and lc.get("present") is bool and _is_num(lc.get("value")):
		out["legacy_arcade_coins"] = {"present": lc["present"], "value": maxi(0, int(floor(float(lc["value"]))))}
	# Campaign: preserved when it is a v2 object (full schema validation is milestone M4).
	var camp: Variant = r.get("campaign")
	if camp is Dictionary and int(camp.get("version", 0)) == 2:
		out["campaign"] = camp.duplicate(true)
	var li: Variant = r.get("legacy_import")
	if li is Dictionary and LEGACY_IMPORT_STATUSES.has(li.get("status")):
		var merged: Dictionary = out["legacy_import"]
		for k: String in merged:
			if li.has(k):
				merged[k] = li[k]
	return {"ok": true, "data": out}


# --- File operations ----------------------------------------------------------------------------

func _path(name: String) -> String:
	return base_dir.path_join(name)


func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"exists": false}
	var text := FileAccess.get_file_as_string(path)
	# JSON.new().parse reports a corrupt file through its return code without logging an error.
	var json := JSON.new()
	var parsed: Variant = json.data if json.parse(text) == OK else null
	return {"exists": true, "parsed": parsed, "text": text}


func load_from_disk() -> void:
	write_blocked = false
	last_error = ""
	future_files.clear()
	future_copy_errors.clear()
	DirAccess.make_dir_recursive_absolute(base_dir)
	var files := {}
	var valid := {}
	for name: String in [FILE_NAME, TEMP_NAME, BACKUP_NAME]:
		files[name] = _read_json(_path(name))
		if not files[name]["exists"]:
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
		last_error = future_copy_errors[0] if not future_copy_errors.is_empty() else "future_format_version"
		for reason in future_copy_errors:
			save_failed.emit(reason)
		data = default_container() if future_files.has(FILE_NAME) or best_name == "" else valid[best_name]
		load_status = "future_version"
		return
	var main: Dictionary = files[FILE_NAME]
	if main["exists"] and not valid.has(FILE_NAME):
		_keep_corrupt(main["text"])
	if best_name == "":
		data = default_container()
		load_status = "corrupt" if main["exists"] else "new"
		DirAccess.remove_absolute(_path(TEMP_NAME))
		return
	data = valid[best_name]
	if best_name == FILE_NAME:
		load_status = "loaded"
		# A leftover temp is either invalid or older than main: never trusted.
		DirAccess.remove_absolute(_path(TEMP_NAME))
		return
	load_status = "recovered_from_temp" if best_name == TEMP_NAME else "recovered_from_backup"
	write_to_disk()


## Copies a future-format file byte-for-byte next to it and reads the copy back. Returns "" on
## success or "future_copy_failed:<file>". An identical copy is not rewritten; a different earlier
## copy is kept and the new one gets a hash suffix. A short or failed copy is removed (it is our own
## file; the original is never touched).
func _preserve_future(name: String) -> String:
	var failed := "future_copy_failed:" + name
	var bytes := FileAccess.get_file_as_bytes(_path(name))
	if bytes.is_empty() and FileAccess.get_open_error() != OK:
		return failed
	var keep := _path(FUTURE_COPY[name])
	if FileAccess.file_exists(keep):
		if FileAccess.get_file_as_bytes(keep) == bytes:
			return ""
		var ctx := HashingContext.new()
		ctx.start(HashingContext.HASH_SHA256)
		ctx.update(bytes)
		keep = _path(FUTURE_COPY[name].get_basename() + "." + ctx.finish().hex_encode().substr(0, 12) + ".json")
		if FileAccess.file_exists(keep) and FileAccess.get_file_as_bytes(keep) == bytes:
			return ""
	var f := FileAccess.open(keep, FileAccess.WRITE)
	if f == null:
		return failed
	var payload := bytes.slice(0, bytes.size() / 2) if fault_future_copy.has(name) else bytes
	var stored := f.store_buffer(payload)
	f.close()
	if not stored or FileAccess.get_file_as_bytes(keep) != bytes:
		DirAccess.remove_absolute(keep)
		return failed
	return ""


func _keep_corrupt(text: String) -> void:
	var f := FileAccess.open(_path("save_v3.corrupt.json"), FileAccess.WRITE)
	if f:
		f.store_string(text)
		f.close()


func _fail(reason: String) -> bool:
	last_error = reason
	save_failed.emit(reason)
	return false


## Atomic write: temp → validate → rotate backup → rename. Returns true on success; on failure the
## previous valid file stays recoverable and last_error/save_failed report the reason.
func write_to_disk() -> bool:
	if write_blocked:
		return _fail("write_blocked_future_version")
	# Strictly increasing so "newest valid file" is well defined even within one millisecond.
	var now := int(Time.get_unix_time_from_system() * 1000.0)
	data["written_at_unix_ms"] = maxi(now, int(data.get("written_at_unix_ms", 0)) + 1)
	var text := JSON.stringify(data, "  ", true)
	var tmp := _path(TEMP_NAME)
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return _fail("open_temp_failed")
	if fault_after == "temp_partial":
		f.store_string(text.substr(0, text.length() / 2))
		f.close()
		return _fail("simulated_crash_during_temp_write")
	f.store_string(text)
	f.flush()
	f.close()
	if fault_after == "temp_written":
		return _fail("simulated_crash_after_temp_written")
	var check := _read_json(tmp)
	if not check["exists"] or not validate_container(check["parsed"])["ok"]:
		DirAccess.remove_absolute(tmp)
		return _fail("temp_validation_failed")
	if fault_after == "temp_validated":
		return _fail("simulated_crash_after_temp_validated")
	var main := _path(FILE_NAME)
	if FileAccess.file_exists(main):
		var current := _read_json(main)
		if validate_container(current["parsed"])["ok"]:
			if FileAccess.file_exists(_path(BACKUP_NAME)) and DirAccess.remove_absolute(_path(BACKUP_NAME)) != OK:
				return _fail("backup_remove_failed")
			if DirAccess.rename_absolute(main, _path(BACKUP_NAME)) != OK:
				return _fail("backup_rotation_failed")
		else:
			_keep_corrupt(current["text"])
			if DirAccess.remove_absolute(main) != OK:
				return _fail("corrupt_main_remove_failed")
	if fault_after == "backup_rotated":
		return _fail("simulated_crash_after_backup_rotated")
	if DirAccess.rename_absolute(tmp, main) != OK:
		return _fail("rename_failed")
	last_error = ""
	return true


# --- Domain API ---------------------------------------------------------------------------------

func get_settings() -> Dictionary:
	return (data["settings"] as Dictionary).duplicate(true)


## Settings save on confirmed change only. Returns {"changed": bool, "saved": bool}.
func set_settings(s: Dictionary) -> Dictionary:
	var normalized := normalize_settings(s)
	if normalized == data["settings"]:
		return {"changed": false, "saved": false}
	data["settings"] = normalized
	return {"changed": true, "saved": write_to_disk()}


func get_record(level_id: String) -> Variant:
	var r: Dictionary = data["records"]
	return (r[level_id] as Dictionary).duplicate() if r.has(level_id) else null


## Port of saveRecord: keeps best score, best stars and lowest time independently, and persists
## at once (level completion). Returns {"new_best": bool, "saved": bool}; when the write fails or
## is blocked (future format) the record still holds for this session but "saved" is false.
func save_record(level_id: String, rec: Dictionary) -> Dictionary:
	var records: Dictionary = data["records"]
	var old: Variant = records.get(level_id)
	var new_best: bool = old == null or int(rec["score"]) > int(old["score"])
	var merged := {
		"score": maxi(int(old["score"]) if old != null else 0, int(rec["score"])),
		"stars": maxf(float(old["stars"]) if old != null else 0.0, float(rec["stars"])),
		"time": minf(float(old["time"]), float(rec["time"])) if old != null else float(rec["time"]),
	}
	records[level_id] = normalize_record(merged)
	return {"new_best": new_best, "saved": write_to_disk()}
