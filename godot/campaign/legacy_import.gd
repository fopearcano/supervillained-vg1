class_name LegacyImport
extends RefCounted
## Import of the Capacitor app's localStorage (ARCHITECTURE.md §17.1–17.2, MIG-005–010).
##
## A source hands over the exported payload exactly as received: the JSON object of the five
## `supervillained:` keys to their stored string values (or null). In order:
##   1. the raw bytes are written to user://legacy/capacitor_local_storage.json, with a metadata file
##      (timestamp, SHA-256, size), and both are read back and verified — before anything is parsed;
##      any failure here parses nothing and claims nothing (retryable_error);
##   2. each key is parsed and converted independently (settings, records, the passive standalone
##      coins, the campaign v1 → v2 → format 3, the v1 backup), so valid keys import even if
##      another fails;
##   3. the deterministic status is recorded: imported, imported_partial, not_found, retryable_error
##      or blocked, with per-key results.
## Retries: retryable_error retries on the next run; blocked waits for user/developer action (a
## future-format save that refuses writes, an unreadable payload, nothing convertible); not_found is
## terminal unless forced (diagnostics); imported and imported_partial are idempotent.
## Real WebView acquisition (the M1 spike's bridge, MIG-001–004) is M9; M4 uses FixtureSource.

const PREFIX := "supervillained:"
const BACKUP_FILE := "capacitor_local_storage.json"
const META_FILE := "capacitor_local_storage.meta.json"
const TERMINAL := ["imported", "imported_partial", "not_found", "blocked"]


## A source for fixtures, tests and the debug path: acquire() returns the prepared result,
## {"status": "ok"|"not_found"|"error", "raw": PackedByteArray, "error_code": String}.
class FixtureSource:
	extends RefCounted

	var result: Dictionary
	var calls := 0

	func _init(p_result: Dictionary) -> void:
		result = p_result

	func acquire() -> Dictionary:
		calls += 1
		return result

	## A store holding these key values (null = key absent), serialized deterministically.
	static func payload(values: Dictionary) -> PackedByteArray:
		var obj := {}
		for k: String in CampaignSchema.LEGACY_KEYS:
			obj[PREFIX + k] = values.get(k, null)
		return JSON.stringify(obj, "", true).to_utf8_buffer()


static func sha256_hex(bytes: PackedByteArray) -> String:
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(bytes)
	return ctx.finish().hex_encode()


## Runs one import attempt against SaveService `svc`. Returns a report:
## {"ran", "status", "parsed", "backup", "keys_present", "keys_imported", "keys_failed", "error_code"}.
static func run(svc: Node, source: Object, now_ms: int, force: bool = false) -> Dictionary:
	var li: Dictionary = svc.data["legacy_import"]
	if TERMINAL.has(li["status"]) and not force:
		return _report(li, false, false, "")
	if svc.write_blocked:
		# A future-format save is preserved read-only: the import would have to write; it waits.
		li["status"] = "blocked"
		li["error_code"] = "save_write_blocked"
		return _report(li, true, false, "")
	li["attempt_count"] = int(li["attempt_count"]) + 1
	li["attempted_at_unix_ms"] = now_ms
	li["keys_present"] = []
	li["keys_imported"] = []
	li["keys_failed"] = []
	li["error_code"] = null
	var got: Dictionary = source.call("acquire")
	match String(got.get("status", "error")):
		"not_found":
			li["status"] = "not_found"
			return _finish(svc, li, false, "")
		"ok":
			pass
		_:
			li["status"] = "retryable_error"
			li["error_code"] = String(got.get("error_code", "acquire_failed"))
			return _finish(svc, li, false, "")
	var raw: PackedByteArray = got.get("raw", PackedByteArray())
	# 1. The raw backup, before any parsing.
	var b := backup_raw(svc, raw, now_ms)
	if not b["ok"]:
		li["status"] = "retryable_error"
		li["error_code"] = b["error"]
		li["payload_sha256"] = null
		return _finish(svc, li, false, "")
	li["payload_sha256"] = b["sha256"]
	# 2. The wrapper, then every key on its own.
	var json := JSON.new()
	if json.parse(raw.get_string_from_utf8()) != OK or not json.data is Dictionary:
		li["status"] = "blocked"
		li["error_code"] = "payload_not_a_json_object"
		return _finish(svc, li, true, b["path"])
	var payload: Dictionary = json.data
	var present: Array = []
	for k: String in CampaignSchema.LEGACY_KEYS:
		if typeof(payload.get(PREFIX + k)) == TYPE_STRING:
			present.append(k)
	li["keys_present"] = present
	if present.is_empty():
		li["status"] = "not_found"
		return _finish(svc, li, true, b["path"])
	var imported: Array = []
	var failed: Array = []
	var first_error := ""
	for k: String in present:
		var err := _import_key(svc, k, String(payload[PREFIX + k]))
		if err == "":
			imported.append(k)
		else:
			failed.append(k)
			if first_error == "":
				first_error = "%s:%s" % [k, err]
	li["keys_imported"] = imported
	li["keys_failed"] = failed
	if failed.is_empty():
		li["status"] = "imported"
	elif imported.is_empty():
		li["status"] = "blocked"
	else:
		li["status"] = "imported_partial"
	li["error_code"] = null if first_error == "" else first_error
	return _finish(svc, li, true, b["path"])


## Writes the raw payload and its metadata, then reads both back. {"ok", "sha256", "path", "error"}.
static func backup_raw(svc: Node, raw: PackedByteArray, now_ms: int) -> Dictionary:
	var ops: SaveFileOps = svc.file_ops
	var dir: String = svc.legacy_dir()
	if ops.make_dir(dir) != OK and not DirAccess.dir_exists_absolute(dir):
		return {"ok": false, "error": "backup_dir_failed"}
	var path := dir.path_join(BACKUP_FILE)
	var sha := sha256_hex(raw)
	# An earlier, different payload is kept beside it (never overwritten).
	if ops.exists(path):
		var old: Dictionary = ops.read_bytes(path)
		if old["ok"] and old["bytes"] != raw:
			var aside := dir.path_join("capacitor_local_storage.%s.json" % sha256_hex(old["bytes"]).substr(0, 12))
			if not ops.exists(aside) and ops.rename(path, aside) != OK:
				return {"ok": false, "error": "backup_rotate_failed"}
	if not ops.write_bytes(path, raw):
		return {"ok": false, "error": "backup_write_failed"}
	var back: Dictionary = ops.read_bytes(path)
	if not back["ok"] or back["bytes"] != raw or sha256_hex(back["bytes"]) != sha:
		return {"ok": false, "error": "backup_readback_failed"}
	var meta := JSON.stringify({"file": BACKUP_FILE, "sha256": sha, "bytes": raw.size(), "written_at_unix_ms": now_ms, "source": "capacitor_webview"}, "", true).to_utf8_buffer()
	var meta_path := dir.path_join(META_FILE)
	if not ops.write_bytes(meta_path, meta) or ops.read_bytes(meta_path)["bytes"] != meta:
		return {"ok": false, "error": "backup_meta_failed"}
	return {"ok": true, "sha256": sha, "path": path, "error": ""}


## Converts one key into the container; returns "" or an error code.
static func _import_key(svc: Node, key: String, text: String) -> String:
	var json := JSON.new()
	if json.parse(text) != OK:
		if key == "coins":
			svc.data["legacy_arcade_coins"] = {"present": true, "value": 0}
		return "not_json"
	var v: Variant = json.data
	match key:
		"settings":
			if not v is Dictionary:
				return "not_an_object"
			svc.data["settings"] = svc.normalize_settings(v)
		"records":
			if not v is Dictionary:
				return "not_an_object"
			var mine: Dictionary = svc.data["records"]
			for level_id: String in svc.normalize_records(v):
				var rec: Dictionary = svc.normalize_records(v)[level_id]
				var old: Variant = mine.get(level_id)
				mine[level_id] = rec if old == null else svc.normalize_record({
					"score": maxi(int(old["score"]), int(rec["score"])),
					"stars": maxf(float(old["stars"]), float(rec["stars"])),
					"time": minf(float(old["time"]), float(rec["time"]))})
		"coins":
			# Passive preservation only: present/value, never gameplay coins.
			if not CampaignSchema.is_finite_number(v):
				svc.data["legacy_arcade_coins"] = {"present": true, "value": 0}
				return "not_a_number"
			svc.data["legacy_arcade_coins"] = {"present": true, "value": maxi(0, int(floor(float(v))))}
		"story":
			if not v is Dictionary:
				return "not_an_object"
			var version: Variant = (v as Dictionary).get("version")
			var v2: Dictionary
			if CampaignSchema.is_finite_number(version) and float(version) == 1.0:
				v2 = CampaignMigration.migrate_v1(v)
			elif CampaignSchema.is_finite_number(version) and float(version) == 2.0:
				v2 = v
			else:
				return "unknown_version"
			var current: Dictionary = svc.data["campaign"]
			if not (current["completed"] as Array).is_empty() or current["savedAt"] != null:
				return "campaign_conflict"
			svc.data["campaign"] = CampaignSchema.normalize(v2, svc.CATALOG.ids())["data"]
		"story-v1-backup":
			# The untouched v1 save the old app kept aside: preserved in the raw backup file.
			if not v is Dictionary:
				return "not_an_object"
	return ""


static func _finish(svc: Node, li: Dictionary, parsed: bool, path: String) -> Dictionary:
	if not svc.write_to_disk():
		li["status"] = "retryable_error"
		li["error_code"] = "container_write_failed"
	return _report(li, true, parsed, path)


static func _report(li: Dictionary, ran: bool, parsed: bool, path: String) -> Dictionary:
	return {"ran": ran, "status": li["status"], "parsed": parsed, "backup": path,
		"keys_present": (li["keys_present"] as Array).duplicate(), "keys_imported": (li["keys_imported"] as Array).duplicate(),
		"keys_failed": (li["keys_failed"] as Array).duplicate(), "error_code": li["error_code"]}
