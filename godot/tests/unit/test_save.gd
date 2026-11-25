extends TestCase
## SaveService: exact defaults, validation, records semantics, the atomic write with crash
## injection at every stage, newest-valid recovery and future-format preservation. The runner gives
## every case its own empty user:// directory (SaveService.base_dir).

var _svc: Node
var _dir: String


func before_each() -> void:
	_svc = Engine.get_main_loop().root.get_node("SaveService")
	_dir = _svc.base_dir


func _write(name: String, text: String) -> void:
	var f := FileAccess.open(_dir + name, FileAccess.WRITE)
	f.store_string(text)
	f.close()


func _write_bytes(name: String, bytes: PackedByteArray) -> void:
	var f := FileAccess.open(_dir + name, FileAccess.WRITE)
	f.store_buffer(bytes)
	f.close()


func _exists(name: String) -> bool:
	return FileAccess.file_exists(_dir + name)


func _score_in(name: String) -> int:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(_dir + name))
	return int(parsed["records"]["level1"]["score"])


const ARCH_DEFAULT := {
	"format_version": 3, "written_at_unix_ms": 0,
	"settings": {"muted": false, "volume": 0.7, "textSpeed": "normal", "lives": 2,
		"controls": {"swipeUp": "sword", "swipeDown": "shield", "doubleTap": "bark", "run": "hold", "switcher": true, "hand": "right"}},
	"records": {}, "legacy_arcade_coins": {"present": false, "value": 0},
	"campaign": {"version": 2, "completed": [], "meters": {"commozione": 20, "supervillain": 10, "grace": 70, "standing": 50},
		"flags": {}, "book": {"marvels": [], "items": [], "values": [], "remembered": [], "shards": []},
		"abilities": [], "coins": 0, "playTime": 0, "savedAt": null, "notice": null},
	"legacy_import": {"status": "not_attempted", "source": "capacitor_webview", "attempt_count": 0,
		"attempted_at_unix_ms": null, "payload_sha256": null, "keys_present": [], "keys_imported": [], "keys_failed": [], "error_code": null},
}


func test_SAV_001_defaults_match_architecture() -> void:
	assert_eq(_svc.load_status, "new", "fresh directory")
	assert_eq(_svc.data, ARCH_DEFAULT, "default container")


func test_SAV_002_settings_validate_and_clamp() -> void:
	var s: Dictionary = _svc.normalize_settings({"muted": "yes", "volume": 7, "textSpeed": "warp", "lives": 42,
		"controls": {"swipeUp": "rocket", "run": "toggle", "switcher": 1, "hand": "left"}, "bogus": true})
	assert_eq(s["muted"], false, "muted fallback")
	assert_eq(s["volume"], 1.0, "volume clamp")
	assert_eq(s["textSpeed"], "normal", "text speed fallback")
	assert_eq(s["lives"], 9, "lives clamp")
	assert_eq(s["controls"]["swipeUp"], "sword", "unknown binding")
	assert_eq(s["controls"]["run"], "toggle", "run toggle kept")
	assert_eq(s["controls"]["switcher"], true, "non-bool switcher")
	assert_eq(s["controls"]["hand"], "left", "hand kept")
	assert_false(s.has("bogus"), "unknown field dropped")
	assert_eq(_svc.normalize_settings(null), ARCH_DEFAULT["settings"], "null -> defaults")


func test_SAV_003_settings_round_trip_and_signal_only_real_changes() -> void:
	var app: Node = Engine.get_main_loop().root.get_node("AppState")
	var emitted := [0]
	var cb := func(_s: Dictionary) -> void: emitted[0] += 1
	app.settings_changed.connect(cb)
	app.update_settings(app.settings.duplicate(true))
	assert_eq(emitted[0], 0, "no signal for an unchanged value")
	assert_false(_exists("save_v3.json"), "no file for a no-op")
	var s: Dictionary = app.settings.duplicate(true)
	s["lives"] = 5
	app.update_settings(s)
	assert_eq(emitted[0], 1, "one signal for a real change")
	app.settings_changed.disconnect(cb)
	_svc.load_from_disk()
	assert_eq(_svc.load_status, "loaded", "reloaded")
	assert_eq(_svc.get_settings()["lives"], 5, "lives persisted")
	assert_eq(_svc.set_settings(_svc.get_settings()), {"changed": false, "saved": false}, "unchanged result")


func test_SAV_004_records_keep_bests_independently() -> void:
	assert_eq(_svc.save_record("level1", {"score": 1000, "stars": 2.5, "time": 200.0}), {"new_best": true, "saved": true}, "first record")
	assert_eq(_svc.save_record("level1", {"score": 900, "stars": 4.0, "time": 150.0}), {"new_best": false, "saved": true}, "lower score")
	assert_eq(_svc.save_record("level1", {"score": 1200, "stars": 1.0, "time": 300.0}), {"new_best": true, "saved": true}, "higher score")
	assert_eq(_svc.get_record("level1"), {"score": 1200, "stars": 4.0, "time": 150.0}, "independent bests")
	_svc.load_from_disk()
	assert_eq(_svc.get_record("level1"), {"score": 1200, "stars": 4.0, "time": 150.0}, "persisted bests")


func test_SAV_018_round_trip_is_identical() -> void:
	_svc.save_record("level1", {"score": 10, "stars": 0.5, "time": 12.25})
	var before: Dictionary = _svc.data.duplicate(true)
	_svc.load_from_disk()
	assert_eq(_svc.data, before, "semantic round trip (including written_at)")


func test_SAV_019_temp_is_validated_before_it_replaces_the_save() -> void:
	_svc.save_record("level1", {"score": 1, "stars": 0, "time": 1})
	assert_false(_exists("save_v3.tmp"), "temp renamed into place")
	assert_false(_exists("save_v3.bak"), "no backup before a second write")
	_svc.save_record("level1", {"score": 2, "stars": 0, "time": 1})
	assert_eq(_score_in("save_v3.bak"), 1, "previous valid save rotated to backup")
	assert_eq(_score_in("save_v3.json"), 2, "new save in place")
	# A temp that fails validation never replaces anything.
	_svc.data["format_version"] = 99
	assert_false(_svc.write_to_disk(), "invalid content refused")
	assert_eq(_svc.last_error, "temp_validation_failed", "reason")
	assert_false(_exists("save_v3.tmp"), "invalid temp removed")
	assert_eq(_score_in("save_v3.json"), 2, "main untouched")


func test_SAV_020_crash_at_every_write_stage_recovers_newest_valid() -> void:
	_svc.save_record("level1", {"score": 10, "stars": 0, "time": 1})
	_svc.save_record("level1", {"score": 20, "stars": 0, "time": 1})
	var committed := 20
	var score := 30
	for stage: String in ["temp_partial", "temp_written", "temp_validated", "backup_rotated"]:
		_svc.fault_after = stage
		var r: Dictionary = _svc.save_record("level1", {"score": score, "stars": 0, "time": 1})
		assert_false(r["saved"], stage + ": crash reported as not saved")
		_svc.fault_after = ""
		_svc.load_from_disk()
		if stage == "temp_partial":
			# A torn temp is invalid: the last committed save wins and the temp is discarded.
			assert_eq(_svc.load_status, "loaded", stage + " status")
			assert_eq(_svc.get_record("level1")["score"], committed, stage + " keeps the last committed save")
		else:
			# A complete temp is the newest valid file (before or after the backup rotation).
			assert_eq(_svc.load_status, "recovered_from_temp", stage + " status")
			assert_eq(_svc.get_record("level1")["score"], score, stage + " recovers the newest valid write")
			assert_eq(_score_in("save_v3.json"), score, stage + " recovered data promoted to main")
			committed = score
		assert_false(_exists("save_v3.tmp"), stage + " no stray temp after load")
		score += 10


## SAV-021 (with test_shell's notice case): a corrupt main with a valid backup is restored with no
## data loss. The invalid main's exact bytes are copied and the copy read back BEFORE the main is
## removed or replaced; an earlier, different copy is never overwritten. When the main cannot be
## read, or its copy cannot be written or verified, the main stays byte-for-byte untouched, the
## backup is shown read-only, every write is refused for the session and a notice is raised; the
## next healthy launch preserves and recovers as usual.
func test_SAV_021_invalid_main_copied_and_verified_before_any_repair() -> void:
	_svc.save_record("level1", {"score": 7, "stars": 1, "time": 9})
	_svc.save_record("level1", {"score": 8, "stars": 1, "time": 9})
	var bad := PackedByteArray([0x7b, 0x20, 0xc3, 0xa9, 0x00, 0x6e, 0x6f, 0x74, 0x0d, 0x0a, 0x20])
	_write_bytes("save_v3.json", bad)
	var ops := FaultyFileOps.new()
	_svc.file_ops = ops
	_svc.load_from_disk()
	_svc.file_ops = SaveFileOps.new()
	assert_eq([_svc.load_status, _svc.take_notice()], ["recovered_from_backup", "recovered_backup"], "restored, with a notice")
	assert_eq(_svc.get_record("level1")["score"], 7, "backup content restored")
	assert_eq(FileAccess.get_file_as_bytes(_dir + "save_v3.corrupt.json"), bad, "the exact bytes kept")
	assert_eq(_score_in("save_v3.json"), 7, "recovered save promoted to main")
	# Order: the copy is written and read back before anything removes or replaces the main.
	var copy_write := ops.calls.find(["write_bytes", _dir + "save_v3.corrupt.json"])
	var copy_read := ops.calls.find(["read_bytes", _dir + "save_v3.corrupt.json"])
	var first_touch := -1
	for k in ops.calls.size():
		var c: Array = ops.calls[k]
		if (c[0] == "remove" and String(c[1]).ends_with("save_v3.json")) or (c[0] == "rename" and (String(c[1]).ends_with("save_v3.json") or String(c[2]).ends_with("save_v3.json"))):
			first_touch = k
			break
	assert_true(copy_write >= 0 and copy_read > copy_write and first_touch > copy_read, "copy %d, read back %d, then the main %d" % [copy_write, copy_read, first_touch])
	# A second, different invalid main: the first copy stays, the new one gets a hash suffix.
	_write("save_v3.json", "{ another torn save")
	_svc.load_from_disk()
	var copies := Array(DirAccess.get_files_at(_dir)).filter(func(f: String) -> bool: return f.begins_with("save_v3.corrupt."))
	assert_eq(copies.size(), 2, "two copies (%s)" % [copies])
	assert_eq(FileAccess.get_file_as_bytes(_dir + "save_v3.corrupt.json"), bad, "the first copy untouched")
	assert_eq(FileAccess.get_file_as_string(_svc.corrupt_copy), "{ another torn save", "the second copy verified")
	# Failures: the main cannot be read; the copy cannot be written; the copy reads back wrong.
	for fault: Dictionary in [{"fail": {"read_bytes": "save_v3.json"}, "why": "main_unreadable"},
			{"fail": {"write_bytes": "corrupt"}, "why": "corrupt_copy_write_failed"},
			{"short": "corrupt", "why": "corrupt_copy_verify_failed"},
			{"fail": {"read_bytes": "corrupt"}, "why": "corrupt_copy_verify_failed"}]:
		_clear()
		_write("save_v3.bak", _valid_save(41, 1000))
		_write("save_v3.json", "{ torn main " + String(fault["why"]))
		var before := _files()
		var f := FaultyFileOps.new()
		f.fail = fault.get("fail", {})
		f.short_read = fault.get("short", "")
		_svc.file_ops = f
		_svc.load_from_disk()
		var what := String(fault["why"])
		assert_eq([_svc.load_status, _svc.write_blocked, _svc.block_reason, _svc.last_error], ["unpreserved", true, "unpreserved", what], what + ": read-only session")
		assert_eq(_svc.take_notice(), "save_unpreserved", what + ": notice")
		assert_eq(_svc.get_record("level1")["score"], 41, what + ": the valid backup shown read-only")
		var shown: Dictionary = _svc.data.duplicate(true)
		var r: Dictionary = _svc.save_record("level1", {"score": 99, "stars": 0, "time": 1})
		var rs: Dictionary = _svc.set_settings({"lives": 7})
		assert_eq([r["saved"], rs["saved"], _svc.last_error], [false, false, "write_blocked_unpreserved_save"], what + ": every write refused")
		assert_eq(_svc.data, shown, what + ": memory unchanged")
		_svc.file_ops = SaveFileOps.new()
		assert_eq(_files(), before, what + ": every file byte-for-byte untouched, no partial copy")
		# The next healthy launch preserves the main and recovers.
		_svc.load_from_disk()
		assert_eq([_svc.load_status, _svc.write_blocked, FileAccess.get_file_as_string(_dir + "save_v3.corrupt.json")], ["recovered_from_backup", false, "{ torn main " + what], what + ": recovered next time")
	# An unreadable main with nothing else: defaults, read-only, the main untouched.
	_clear()
	_write("save_v3.json", "{ only this")
	var f2 := FaultyFileOps.new()
	f2.fail = {"read_bytes": "save_v3.json"}
	_svc.file_ops = f2
	_svc.load_from_disk()
	_svc.file_ops = SaveFileOps.new()
	assert_eq([_svc.load_status, _svc.data, FileAccess.get_file_as_string(_dir + "save_v3.json")], ["unpreserved", ARCH_DEFAULT, "{ only this"], "defaults read-only, main untouched")
	_clear()
	_svc.load_from_disk()


func test_SLICE_corrupt_without_backup_uses_defaults_then_saves() -> void:
	_write("save_v3.json", "[1, 2")
	_svc.load_from_disk()
	assert_eq(_svc.load_status, "corrupt", "status")
	assert_eq(_svc.data, ARCH_DEFAULT, "defaults in memory")
	assert_true(_exists("save_v3.corrupt.json"), "corrupt payload preserved")
	assert_true(_svc.save_record("level1", {"score": 5, "stars": 0, "time": 1})["saved"], "a new save can be written")
	assert_eq(_score_in("save_v3.json"), 5, "main replaced by a valid save")


func test_SLICE_older_format_is_not_mistaken_for_future() -> void:
	_write("save_v3.json", "{\"format_version\": 2, \"records\": {}}")
	_svc.load_from_disk()
	assert_eq(_svc.load_status, "corrupt", "unsupported old container is not loaded")
	assert_false(_svc.write_blocked, "writes allowed (only a NEWER format blocks)")


## CRLF line ends, non-ASCII characters and trailing spaces must all survive unchanged.
const FUTURE_BYTES := "{\"format_version\": 4,\r\n \"something\": \"nuovo \u2013 \u0259\"}\r\n  "
## A fractional future version: greater than 3, so future (never normalized as format 3).
const FUTURE_FRACTION := "{\"format_version\": 3.5, \"settings\": {\"lives\": 9}, \"records\": {}}\r\n"


func _valid_save(score: int, written: int) -> String:
	var c: Dictionary = _svc.default_container()
	c["written_at_unix_ms"] = written
	c["records"] = {"level1": {"score": score, "stars": 0.0, "time": 1.0}}
	return JSON.stringify(c)


func _files() -> Dictionary:
	var out := {}
	for f in DirAccess.get_files_at(_dir):
		out[f] = FileAccess.get_file_as_bytes(_dir + f)
	return out


func _clear() -> void:
	for f in DirAccess.get_files_at(_dir):
		DirAccess.remove_absolute(_dir + f)
	for d in DirAccess.get_directories_at(_dir):
		DirAccess.remove_absolute(_dir + d)


## SAV-022: a future format (4, and the fractional 3.5) in main, temp or backup is preserved byte for
## byte and blocks every write; the session is genuinely read-only (memory unchanged too).
func test_SAV_022_future_format_in_main_temp_or_backup_is_preserved_and_blocks_writes() -> void:
	for payload: String in [FUTURE_BYTES, FUTURE_FRACTION]:
		_future_case(payload)


func _future_case(payload: String) -> void:
	var copies := {"save_v3.json": "save_v3.future.json", "save_v3.tmp": "save_v3.tmp.future.json", "save_v3.bak": "save_v3.bak.future.json"}
	for loc: String in copies:
		_clear()
		# A valid current-format main (newest) and backup around the future payload.
		if loc != "save_v3.json":
			_write("save_v3.json", _valid_save(5, 2000))
		if loc != "save_v3.bak":
			_write("save_v3.bak", _valid_save(4, 1000))
		_write(loc, payload)
		var before := _files()
		_svc.load_from_disk()
		assert_eq([_svc.load_status, _svc.last_error, _svc.write_blocked], ["future_version", "future_format_version", true], loc + ": reported and blocked")
		assert_eq(_svc.future_files, [loc] as Array[String], loc + ": location reported")
		assert_eq(_svc.future_copy_errors, [] as Array[String], loc + ": copy succeeded")
		if loc == "save_v3.json":
			assert_eq(_svc.data, ARCH_DEFAULT, loc + ": a future main means defaults, never stale data")
		else:
			assert_eq(_svc.get_record("level1")["score"], 5, loc + ": the valid main is shown read-only")
		var failures := []
		var cb := func(reason: String) -> void: failures.append(reason)
		_svc.save_failed.connect(cb)
		var shown: Dictionary = _svc.data.duplicate(true)
		var r: Dictionary = _svc.save_record("level1", {"score": 99, "stars": 0, "time": 1})
		var st: Dictionary = _svc.get_settings()
		st["lives"] = 5
		var rs: Dictionary = _svc.set_settings(st)
		_svc.save_failed.disconnect(cb)
		assert_eq([r["saved"], rs["saved"]], [false, false], loc + ": nothing saved")
		assert_eq(_svc.data, shown, loc + ": read-only in memory too (no record, no setting, same written_at)")
		assert_eq(failures, ["write_blocked_future_version", "write_blocked_future_version"], loc + ": each refused write reported")
		var after := _files()
		for f: String in before:
			assert_eq(after.get(f), before[f], "%s: %s byte-for-byte untouched" % [loc, f])
		assert_eq(after.get(copies[loc]), payload.to_utf8_buffer(), loc + ": byte-for-byte copy " + copies[loc])
		assert_eq(after.keys().size(), before.keys().size() + 1, loc + ": only the copy was added")
		_svc.load_from_disk()
		assert_eq([_svc.load_status, _files()], ["future_version", after], loc + ": next launch still blocked, nothing rewritten")
	_clear()
	_svc.load_from_disk()


func _container(fields: Dictionary) -> String:
	var c: Dictionary = _svc.default_container()
	c["written_at_unix_ms"] = 5000
	c["records"] = {"level1": {"score": 55, "stars": 1.0, "time": 2.0}}
	c.merge(fields, true)
	return JSON.stringify(c)


## Exact versions: the container is format 3 only at exactly 3 (3.0 included); 3.5, 3.0001, 4 are
## future; 2.5, 2.999, 2 are unsupported; a nested campaign is accepted only at exactly 2, and any
## other campaign version makes the container invalid (never normalized, never reset to defaults).
## On disk: a below-3 or bad-campaign main is preserved exactly and the backup recovered; a temp or
## backup with such a version is never used.
func test_SLICE_exact_versions_fractional_and_nested_never_normalized() -> void:
	var base: Dictionary = _svc.default_container()
	var cases := [[3, "ok"], [3.0, "ok"], [3.5, "future_format_version"], [3.0001, "future_format_version"], [4, "future_format_version"],
		[2.5, "unsupported_format_version"], [2.999, "unsupported_format_version"], [2, "unsupported_format_version"], [0, "unsupported_format_version"],
		["3", "missing_format_version"], [true, "missing_format_version"]]
	for pair: Array in cases:
		var c := base.duplicate(true)
		c["format_version"] = pair[0]
		var v := SaveService.validate_container(c)
		assert_eq("ok" if v["ok"] else String(v["error"]), pair[1], "format_version %s (%s)" % [pair[0], type_string(typeof(pair[0]))])
	for cv: Variant in [2.5, 2.1, 1.999, 2.0000001, 3, 1, "2"]:
		var c := base.duplicate(true)
		c["campaign"]["version"] = cv
		var v := SaveService.validate_container(c)
		assert_eq([v["ok"], v.get("error")], [false, "unsupported_campaign_version"], "campaign version %s rejects the container" % [cv])
		assert_false(CampaignSchema.normalize(c["campaign"], SaveService.CATALOG.ids())["ok"], "campaign version %s rejected" % [cv])
	var c2 := base.duplicate(true)
	c2["campaign"]["version"] = 2.0
	assert_true(SaveService.validate_container(c2)["ok"], "campaign 2.0 accepted")
	# On disk: a main below 3 or with a fractional campaign version is kept exactly; the backup wins.
	for main_text: String in [_container({"format_version": 2.5}), _container({"campaign": {"version": 2.5, "completed": ["1.0"], "coins": 77}}),
			_container({"campaign": {"version": 2.1}})]:
		_clear()
		_write("save_v3.bak", _valid_save(4, 1000))
		_write("save_v3.json", main_text)
		_svc.load_from_disk()
		assert_eq([_svc.load_status, _svc.write_blocked, _svc.get_record("level1")["score"]], ["recovered_from_backup", false, 4], "invalid version: backup recovered (%s)" % main_text.substr(0, 40))
		assert_eq(FileAccess.get_file_as_string(_dir + "save_v3.corrupt.json"), main_text, "kept exactly, not normalized")
		assert_eq(_score_in("save_v3.json"), 4, "the backup promoted")
	# A newer temp or a backup with such a version is never used.
	_clear()
	_write("save_v3.json", _valid_save(6, 1000))
	_write("save_v3.tmp", _container({"written_at_unix_ms": 9000, "campaign": {"version": 2.5}}))
	_svc.load_from_disk()
	assert_eq([_svc.load_status, _svc.get_record("level1")["score"], _exists("save_v3.tmp")], ["loaded", 6, false], "a fractional-campaign temp is not recovered")
	_clear()
	_write("save_v3.json", "{ torn")
	_write("save_v3.bak", _container({"format_version": 2.5}))
	_svc.load_from_disk()
	assert_eq([_svc.load_status, _svc.data], ["corrupt", ARCH_DEFAULT], "a below-3 backup is not recovered: defaults")
	_clear()
	_svc.load_from_disk()


## Committed bytes: the main, or the backup while an interrupted write left no main.
func _committed() -> PackedByteArray:
	return FileAccess.get_file_as_bytes(_dir + ("save_v3.json" if _exists("save_v3.json") else "save_v3.bak"))


const WRITE_STAGES := [
	{"fail": {"write_bytes": "save_v3.tmp"}, "why": "open_temp_failed"},
	{"torn": "save_v3.tmp", "why": "temp_validation_failed"},
	{"fail": {"read_bytes": "save_v3.tmp"}, "why": "temp_validation_failed"},
	{"fail": {"remove": "save_v3.bak"}, "why": "backup_remove_failed"},
	{"fail": {"rename": "save_v3.bak"}, "why": "backup_rotation_failed"},
	{"fail": {"rename": "save_v3.tmp"}, "why": "rename_failed"},
	{"hook": "temp_partial", "why": "simulated_crash_during_temp_write"},
	{"hook": "temp_written", "why": "simulated_crash_after_temp_written"},
	{"hook": "temp_validated", "why": "simulated_crash_after_temp_validated"},
	{"hook": "backup_rotated", "why": "simulated_crash_after_backup_rotated"},
	{"blocked": true, "why": "write_blocked_future_version"},
]


## Settings, a record and the campaign are each one transaction: at every injected write stage (and
## in a blocked session) the call reports failure, the whole in-memory container (written_at
## included) is exactly what it was and the committed file keeps its exact bytes; the next launch
## loads either the previous state or, only from a complete validated temp, the whole candidate.
## A retry in the same session then succeeds once.
func test_SLICE_domain_writes_are_transactions_at_every_stage() -> void:
	var ops := {
		"settings": func() -> bool:
			var st: Dictionary = _svc.get_settings()
			st["lives"] = 2 + (int(st["lives"]) - 1) % 8
			return _svc.set_settings(st)["saved"],
		"record": func() -> bool:
			var old: Variant = _svc.get_record("level1")
			return _svc.save_record("level1", {"score": (int(old["score"]) if old != null else 0) + 1, "stars": 1.0, "time": 50.0})["saved"],
		"campaign": func() -> bool:
			var camp: Dictionary = _svc.get_campaign()
			camp["coins"] = int(camp["coins"]) + 1
			return _svc.save_campaign(camp, 1800000000000),
	}
	for op: String in ops:
		for stage: Dictionary in WRITE_STAGES:
			var what := "%s/%s" % [op, stage["why"]]
			_clear()
			_svc.load_from_disk()
			_svc.save_record("level1", {"score": 10, "stars": 1.0, "time": 60.0})
			_svc.write_to_disk()
			assert_true(_exists("save_v3.json") and _exists("save_v3.bak"), what + ": main and backup to start from")
			var f := FaultyFileOps.new()
			f.fail = stage.get("fail", {})
			f.torn_write = stage.get("torn", "")
			_svc.file_ops = f
			_svc.fault_after = stage.get("hook", "")
			_svc.write_blocked = stage.get("blocked", false)
			var before: Dictionary = _svc.data.duplicate(true)
			var committed := _committed()
			var saved: bool = (ops[op] as Callable).call()
			var reason: String = _svc.last_error
			_svc.file_ops = SaveFileOps.new()
			_svc.fault_after = ""
			_svc.write_blocked = false
			assert_eq([saved, reason], [false, stage["why"]], what + ": reported")
			assert_eq(_svc.data, before, what + ": the whole container in memory unchanged")
			assert_eq(_committed(), committed, what + ": the committed file's bytes unchanged")
			var parsed: Variant = JSON.parse_string(_committed().get_string_from_utf8())
			assert_eq(SaveService.validate_container(parsed)["data"], before, what + ": memory equals the committed save")
			# Retry in the same session: succeeds once.
			var attempt: Dictionary = _svc.data.duplicate(true)
			assert_true((ops[op] as Callable).call(), what + ": the retry saves")
			var after_retry: Dictionary = _svc.data.duplicate(true)
			_svc.load_from_disk()
			assert_eq(_svc.data, after_retry, what + ": the retry is what loads")
			assert_true(after_retry != attempt, what + ": the retry changed the state once")
	_clear()
	_svc.load_from_disk()


## Crash recovery stays: a complete, validated temp from a failed call is recovered whole by the
## next launch (never a mix with the previous state).
func test_SLICE_failed_call_leaves_a_recoverable_whole_temp() -> void:
	_svc.save_record("level1", {"score": 10, "stars": 1.0, "time": 60.0})
	_svc.write_to_disk()
	var f := FaultyFileOps.new()
	f.fail = {"rename": "save_v3.tmp"}
	_svc.file_ops = f
	var st: Dictionary = _svc.get_settings()
	st["lives"] = 6
	assert_false(_svc.set_settings(st)["saved"], "reported failed")
	_svc.file_ops = SaveFileOps.new()
	assert_eq(_svc.get_settings()["lives"], 2, "not applied in this session")
	_svc.load_from_disk()
	assert_eq([_svc.load_status, _svc.get_settings()["lives"], _svc.get_record("level1")["score"]], ["recovered_from_temp", 6, 10], "the whole candidate recovered next launch")


func test_SLICE_temp_recovery_keeps_a_valid_older_main_as_backup() -> void:
	_write("save_v3.json", _valid_save(5, 1000))
	_write("save_v3.tmp", _valid_save(6, 2000))
	_svc.load_from_disk()
	assert_eq(_svc.load_status, "recovered_from_temp", "newer temp wins")
	assert_eq(_svc.get_record("level1")["score"], 6, "temp data")
	assert_false(_exists("save_v3.corrupt.json"), "a valid older main is not 'corrupt'")
	assert_eq([_score_in("save_v3.json"), _score_in("save_v3.bak")], [6, 5], "temp promoted; the older main became the backup")
	# An invalid main is still preserved before the temp replaces it.
	_write("save_v3.json", "{ torn")
	_write("save_v3.tmp", _valid_save(7, 9_999_999_999_999))
	_svc.load_from_disk()
	assert_eq(_svc.load_status, "recovered_from_temp", "status")
	assert_eq(FileAccess.get_file_as_string(_dir + "save_v3.corrupt.json"), "{ torn", "invalid main preserved")


## A failed byte-for-byte copy is reported as future_copy_failed:<file>; writes stay blocked and the
## original stays untouched. Two injections per location: the destination cannot be opened (a
## directory occupies its path: a real I/O failure) and a short write caught by the read-back.
func test_SLICE_future_copy_failures_are_reported_and_writes_stay_blocked() -> void:
	var copies := {"save_v3.json": "save_v3.future.json", "save_v3.tmp": "save_v3.tmp.future.json", "save_v3.bak": "save_v3.bak.future.json"}
	for loc: String in copies:
		for injection in ["destination_unwritable", "short_write"]:
			var what := "%s/%s" % [loc, injection]
			_clear()
			if loc != "save_v3.json":
				_write("save_v3.json", _valid_save(5, 2000))
			if loc != "save_v3.bak":
				_write("save_v3.bak", _valid_save(4, 1000))
			_write(loc, FUTURE_BYTES)
			if injection == "destination_unwritable":
				DirAccess.make_dir_absolute(_dir + copies[loc])
			else:
				_svc.fault_future_copy = [loc] as Array[String]
			var before := _files()
			var reasons := []
			var cb := func(reason: String) -> void: reasons.append(reason)
			_svc.save_failed.connect(cb)
			_svc.load_from_disk()
			_svc.fault_future_copy.clear()
			var expected := "future_copy_failed:" + loc
			assert_eq([_svc.load_status, _svc.write_blocked, _svc.last_error], ["future_version", true, expected], what + ": reported, writes blocked")
			assert_eq(_svc.future_copy_errors, [expected] as Array[String], what + ": failure exposed")
			var r: Dictionary = _svc.save_record("level1", {"score": 99, "stars": 0, "time": 1})
			_svc.save_failed.disconnect(cb)
			assert_eq(reasons, [expected, "write_blocked_future_version"], what + ": copy failure signalled, then the refused write")
			assert_false(r["saved"], what + ": nothing saved")
			var after := _files()
			assert_eq(after, before, what + ": every original byte-for-byte untouched, no partial copy left")
			assert_false(FileAccess.file_exists(_dir + copies[loc]), what + ": no copy file")
	# Two future files whose copies both fail are both reported, in main/temp/backup order.
	_clear()
	_write("save_v3.json", FUTURE_BYTES)
	_write("save_v3.bak", FUTURE_BYTES)
	DirAccess.make_dir_absolute(_dir + "save_v3.future.json")
	_svc.fault_future_copy = ["save_v3.bak"] as Array[String]
	_svc.load_from_disk()
	_svc.fault_future_copy.clear()
	assert_eq(_svc.future_copy_errors, ["future_copy_failed:save_v3.json", "future_copy_failed:save_v3.bak"] as Array[String], "both failures exposed")
	assert_true(_svc.write_blocked, "still blocked")
	# Once the destination is free again the next launch copies it.
	_clear()
	_write("save_v3.tmp", FUTURE_BYTES)
	_svc.load_from_disk()
	assert_eq([_svc.future_copy_errors, FileAccess.get_file_as_string(_dir + "save_v3.tmp.future.json")], [[] as Array[String], FUTURE_BYTES], "copy succeeds when it can")
	_clear()
	_svc.load_from_disk()


static func _sha12(bytes: PackedByteArray) -> String:
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(bytes)
	return ctx.finish().hex_encode().substr(0, 12)


## SAV-022: an earlier preservation copy is never written over. A first copy with other or
## unreadable bytes stays and the new payload goes to its hash-suffixed name; when that name already
## holds other or unreadable bytes it is a conflict (future_copy_conflict:<file>, writes blocked)
## and nothing is written. The original future save and every earlier copy stay byte-identical.
func test_SAV_022_future_copies_never_overwrite_an_earlier_copy() -> void:
	var hashed := "save_v3.future.%s.json" % _sha12(FUTURE_BYTES.to_utf8_buffer())
	var cases := [
		{"what": "hashed copy holds other bytes", "first": "EARLIER COPY A", "hashed": "OTHER BYTES B", "unreadable": "", "error": "future_copy_conflict:save_v3.json"},
		{"what": "hashed copy unreadable", "first": "EARLIER COPY A", "hashed": "UNREADABLE C", "unreadable": hashed, "error": "future_copy_conflict:save_v3.json"},
		{"what": "first copy unreadable, no hashed copy", "first": "EARLIER COPY D", "hashed": "", "unreadable": "save_v3.future.json", "error": ""},
		{"what": "first copy differs, no hashed copy", "first": "EARLIER COPY E", "hashed": "", "unreadable": "", "error": ""},
	]
	for c: Dictionary in cases:
		var what: String = c["what"]
		_clear()
		_write("save_v3.json", FUTURE_BYTES)
		_write("save_v3.future.json", c["first"])
		if c["hashed"] != "":
			_write(hashed, c["hashed"])
		var before := _files()
		var f := FaultyFileOps.new()
		f.fail = {"read_bytes": c["unreadable"]} if c["unreadable"] != "" else {}
		_svc.file_ops = f
		_svc.load_from_disk()
		var r: Dictionary = _svc.save_record("level1", {"score": 9, "stars": 0, "time": 1})
		_svc.file_ops = SaveFileOps.new()
		var errors: Array = Array(_svc.future_copy_errors)
		assert_eq([_svc.load_status, _svc.write_blocked, r["saved"]], ["future_version", true, false], what + ": blocked either way")
		assert_eq(errors, [c["error"]] if c["error"] != "" else [], what + ": reported")
		var after := _files()
		for name: String in before:
			assert_eq(after.get(name), before[name], "%s: %s byte-identical" % [what, name])
		if c["hashed"] == "":
			assert_eq(after.get(hashed), FUTURE_BYTES.to_utf8_buffer(), what + ": the new payload under its hash name")
			assert_eq(after.size(), before.size() + 1, what + ": only that copy was added")
		else:
			assert_eq(after.size(), before.size(), what + ": nothing added")
	_clear()
	_svc.load_from_disk()


# --- Campaign v1 -> v2 (src/campaign/state.ts, fixtures from the executed source) ---------------

func _migration() -> Dictionary:
	return fixture("source_campaign_migration")


## SAV-013: every v1 fixture migrates exactly as the source: only 1.0/1.2/1.3/1.4 and the approved
## fields (their flags, scraps, remembered lines, coins, play time, save time) survive.
func test_SAV_013_v1_keeps_only_unchanged_scenes_and_approved_fields() -> void:
	var fx := _migration()
	assert_eq(CampaignMigration.V1_KEPT_SCENES, fx["v1_kept_scenes"], "kept scenes")
	assert_eq(CampaignMigration.new_campaign(), fx["new_campaign"], "new campaign")
	var cases: Dictionary = fx["migrations"]
	assert_true(cases.size() >= 7, "v1 fixtures")
	for name: String in cases:
		var raw: Dictionary = cases[name]["raw"]
		var before := raw.duplicate(true)
		assert_eq(CampaignMigration.migrate_v1(raw), cases[name]["migrated"], name + " migrated like the source")
		assert_eq(raw, before, name + " input untouched (pure)")
	var full: Dictionary = CampaignMigration.migrate_v1(cases["full"]["raw"])
	assert_eq(full["completed"], ["1.0", "1.2", "1.3", "1.4"], "only the kept scenes")
	assert_eq(full["flags"], {"pawOffered": true, "longWay": false, "santinaBall": "returned"}, "only the kept scenes' flags")
	assert_eq([full["coins"], full["playTime"], full["savedAt"]], [123.5, 456.25, 1700000000000.0], "coins, play time, save time kept")


## SAV-014: a v1 save that reached 1.1 without a recorded 1.0 counts the Green Zone walk as done.
func test_SAV_014_v1_1_1_without_1_0_counts_1_0() -> void:
	var raw: Dictionary = _migration()["migrations"]["walked_1_1_without_1_0"]["raw"]
	assert_false((raw["completed"] as Array).has("1.0"), "fixture lacks 1.0")
	var m := CampaignMigration.migrate_v1(raw)
	assert_eq(m["completed"], ["1.0"], "1.0 complete, 1.1 replayed")
	assert_eq(m["flags"], {"longWay": true}, "its flags kept (a kept scene is complete)")
	assert_eq(m["notice"], "dream-rewritten", "1.1 is played again: notice")


## SAV-015: everything the rewrite changed starts fresh: meters (but the 1.3 paw's -3), book
## marvels/items/values, abilities and the ending flag.
func test_SAV_015_rewritten_scenes_reset_meters_book_abilities_ending() -> void:
	var cases: Dictionary = _migration()["migrations"]
	var full := CampaignMigration.migrate_v1(cases["full"]["raw"])
	assert_eq(full["meters"], {"commozione": 20, "supervillain": 7, "grace": 70, "standing": 50}, "fresh meters, paw offered -3")
	assert_eq([full["book"]["marvels"], full["book"]["items"], full["book"]["values"]], [[], [], []], "dream book reset")
	assert_eq(full["abilities"], [], "costumes/abilities reset")
	assert_false((full["flags"] as Dictionary).has("ending") or (full["flags"] as Dictionary).has("vow"), "ending and dream flags dropped")
	assert_eq(CampaignMigration.migrate_v1(cases["kept_scenes_only"]["raw"])["meters"]["supervillain"], 10, "no paw: supervillain at its start")
	assert_eq(CampaignMigration.migrate_v1(cases["nothing_kept_flags_dropped"]["raw"])["flags"], {}, "no kept scene: no kept flags")


## SAV-016: loading a v1 store keeps the untouched payload aside once and stores the migration;
## a second load is idempotent (same campaign, same backup); an existing backup is never replaced.
func test_SAV_016_v1_payload_backed_up_once_second_load_idempotent() -> void:
	var fx := _migration()
	for name: String in fx["sequences"]:
		var seq: Dictionary = fx["sequences"][name]
		var raw: Dictionary = fx["migrations"][name]["raw"]
		var first := CampaignMigration.load_campaign({"story": raw.duplicate(true)})
		assert_eq(first["campaign"], seq["first"], name + " first load")
		assert_eq(first["store"]["story"], seq["after_first"]["story"], name + " migrated save stored")
		assert_eq(first["store"][CampaignMigration.V1_BACKUP_KEY], seq["after_first"]["backup"], name + " untouched v1 payload backed up")
		assert_eq(first["store"][CampaignMigration.V1_BACKUP_KEY], raw, name + " backup equals the original")
		var second := CampaignMigration.load_campaign(first["store"])
		assert_eq(second["campaign"], seq["second"], name + " second load (v2 normalization)")
		assert_eq(second["campaign"], first["campaign"], name + " idempotent")
		assert_eq(second["store"], first["store"], name + " second load writes nothing new")
	var earlier := {"version": 1, "completed": ["1.0"], "marker": "earlier"}
	var again := CampaignMigration.load_campaign({"story": fx["migrations"]["full"]["raw"], CampaignMigration.V1_BACKUP_KEY: earlier})
	assert_eq(again["store"][CampaignMigration.V1_BACKUP_KEY], fx["existing_backup_kept"], "an existing backup is kept")
	assert_eq(CampaignMigration.load_campaign({})["campaign"], fx["new_campaign"], "no save: new campaign")
	assert_eq(CampaignMigration.load_campaign({"story": {"version": 7}})["campaign"], fx["new_campaign"], "unknown version: new campaign (source)")


## SAV-017: the dream-rewritten notice is set only when a played scene is replayed, shown once
## (consume_notice true, then false) and cleared for good in the saved campaign.
func test_SAV_017_dream_rewritten_notice_set_shown_cleared_once() -> void:
	var fx := _migration()
	var cases: Dictionary = fx["migrations"]
	for name: String in cases:
		var m: Dictionary = CampaignMigration.migrate_v1(cases[name]["raw"])
		assert_eq(m["notice"], cases[name]["migrated"]["notice"], name + " notice set like the source")
	for name: String in fx["sequences"]:
		var seq: Dictionary = fx["sequences"][name]
		var state: Dictionary = CampaignMigration.load_campaign(CampaignMigration.load_campaign({"story": fx["migrations"][name]["raw"]})["store"])["campaign"]
		var shown: Array = []
		for k in 2:
			var s := CampaignMigration.consume_notice(state)
			if s:
				state["savedAt"] = 1800000000000.0
			shown.append(s)
		assert_eq(shown, seq["shown"], name + " shown exactly once")
		assert_eq(state, seq["after_notice"], name + " cleared notice saved")
		var reloaded: Dictionary = CampaignMigration.load_campaign({"story": state})["campaign"]
		assert_eq(reloaded, seq["third"], name + " stays cleared after reload")
		assert_false(CampaignMigration.consume_notice(reloaded), name + " never shown again")
