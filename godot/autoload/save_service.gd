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

signal save_failed(reason: String)

const FORMAT_VERSION := 3
const FILE_NAME := "save_v3.json"
const TEMP_NAME := "save_v3.tmp"
const BACKUP_NAME := "save_v3.bak"

const TEXT_SPEEDS := ["slow", "normal", "fast", "instant"]
const GESTURE_BINDINGS := ["off", "action", "bark", "sword", "shield", "switch", "run"]
const LEGACY_IMPORT_STATUSES := ["not_attempted", "imported", "imported_partial", "not_found", "retryable_error", "blocked"]

## Directory holding the save files (tests point it at an isolated user:// subdirectory).
var base_dir := "user://"
## Last load outcome: "new", "loaded", "recovered_from_backup", "future_version", "corrupt".
var load_status := "new"
## When a newer/unknown format was found it is preserved and never overwritten.
var write_blocked := false
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
	if version > FORMAT_VERSION or version < FORMAT_VERSION:
		return {"ok": false, "error": "unknown_format_version", "version": version}
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
	DirAccess.make_dir_recursive_absolute(base_dir)
	var main := _read_json(_path(FILE_NAME))
	if not main["exists"]:
		var bak := _read_json(_path(BACKUP_NAME))
		if bak["exists"]:
			var vb := validate_container(bak["parsed"])
			if vb["ok"]:
				data = vb["data"]
				load_status = "recovered_from_backup"
				return
		data = default_container()
		load_status = "new"
		return
	var v := validate_container(main["parsed"])
	if v["ok"]:
		data = v["data"]
		load_status = "loaded"
		return
	if v.get("error") == "unknown_format_version":
		# Preserve the unknown save: keep a copy and never overwrite it with defaults.
		var keep := _path("save_v3.future.json")
		if not FileAccess.file_exists(keep):
			var f := FileAccess.open(keep, FileAccess.WRITE)
			if f:
				f.store_string(main["text"])
				f.close()
		write_blocked = true
		data = default_container()
		load_status = "future_version"
		return
	var bak2 := _read_json(_path(BACKUP_NAME))
	if bak2["exists"]:
		var vb2 := validate_container(bak2["parsed"])
		if vb2["ok"]:
			data = vb2["data"]
			load_status = "recovered_from_backup"
			_keep_corrupt(main["text"])
			return
	_keep_corrupt(main["text"])
	data = default_container()
	load_status = "corrupt"


func _keep_corrupt(text: String) -> void:
	var f := FileAccess.open(_path("save_v3.corrupt.json"), FileAccess.WRITE)
	if f:
		f.store_string(text)
		f.close()


## Atomic write: temp → validate → rotate backup → rename. Returns true on success.
func write_to_disk() -> bool:
	if write_blocked:
		save_failed.emit("write_blocked_future_version")
		return false
	data["written_at_unix_ms"] = int(Time.get_unix_time_from_system() * 1000.0)
	var text := JSON.stringify(data, "  ", true)
	var tmp := _path(TEMP_NAME)
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		save_failed.emit("open_temp_failed")
		return false
	f.store_string(text)
	f.flush()
	f.close()
	var check := _read_json(tmp)
	if not check["exists"] or not validate_container(check["parsed"])["ok"]:
		DirAccess.remove_absolute(tmp)
		save_failed.emit("temp_validation_failed")
		return false
	var main := _path(FILE_NAME)
	if FileAccess.file_exists(main):
		var current := _read_json(main)
		if validate_container(current["parsed"])["ok"]:
			if FileAccess.file_exists(_path(BACKUP_NAME)):
				DirAccess.remove_absolute(_path(BACKUP_NAME))
			DirAccess.rename_absolute(main, _path(BACKUP_NAME))
		else:
			DirAccess.remove_absolute(main)
	var err := DirAccess.rename_absolute(tmp, main)
	if err != OK:
		save_failed.emit("rename_failed")
		return false
	return true


# --- Domain API ---------------------------------------------------------------------------------

func get_settings() -> Dictionary:
	return (data["settings"] as Dictionary).duplicate(true)


## Settings save on confirmed change only (and only if something actually changed).
func set_settings(s: Dictionary) -> bool:
	var normalized := normalize_settings(s)
	if normalized == data["settings"]:
		return false
	data["settings"] = normalized
	write_to_disk()
	return true


func get_record(level_id: String) -> Variant:
	var r: Dictionary = data["records"]
	return (r[level_id] as Dictionary).duplicate() if r.has(level_id) else null


## Port of saveRecord: keeps best score, best stars and lowest time independently.
## Returns true when the score is a new best. Persists immediately (level completion).
func save_record(level_id: String, rec: Dictionary) -> bool:
	var records: Dictionary = data["records"]
	var old: Variant = records.get(level_id)
	var new_best: bool = old == null or int(rec["score"]) > int(old["score"])
	var merged := {
		"score": maxi(int(old["score"]) if old != null else 0, int(rec["score"])),
		"stars": maxf(float(old["stars"]) if old != null else 0.0, float(rec["stars"])),
		"time": minf(float(old["time"]), float(rec["time"])) if old != null else float(rec["time"]),
	}
	records[level_id] = normalize_record(merged)
	write_to_disk()
	return new_best
