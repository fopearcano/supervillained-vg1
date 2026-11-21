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


func test_P_SAV_021_corrupt_save_recovers_from_backup() -> void:
	_svc.save_record("level1", {"score": 7, "stars": 1, "time": 9})
	_svc.save_record("level1", {"score": 8, "stars": 1, "time": 9})
	_write("save_v3.json", "{ this is not json")
	_svc.load_from_disk()
	assert_eq(_svc.load_status, "recovered_from_backup", "status (user-visible notice is M4)")
	assert_eq(_svc.get_record("level1")["score"], 7, "backup content restored")
	assert_eq(FileAccess.get_file_as_string(_dir + "save_v3.corrupt.json"), "{ this is not json", "corrupt payload preserved")
	assert_eq(_score_in("save_v3.json"), 7, "recovered save promoted to main")


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


func test_SAV_022_future_version_preserved_never_overwritten() -> void:
	var future := "{\"format_version\": 4, \"something\": \"new\"}"
	_write("save_v3.json", future)
	_svc.load_from_disk()
	assert_eq(_svc.load_status, "future_version", "status")
	assert_eq(_svc.last_error, "future_format_version", "reported")
	assert_true(_svc.write_blocked, "writes blocked")
	var failures := []
	var cb := func(reason: String) -> void: failures.append(reason)
	_svc.save_failed.connect(cb)
	var r: Dictionary = _svc.save_record("level1", {"score": 1, "stars": 0, "time": 1})
	var s: Dictionary = _svc.get_settings()
	s["lives"] = 3
	var rs: Dictionary = _svc.set_settings(s)
	_svc.save_failed.disconnect(cb)
	assert_eq(r, {"new_best": true, "saved": false}, "record kept for the session but not saved")
	assert_eq(rs, {"changed": true, "saved": false}, "settings not saved")
	assert_eq(failures, ["write_blocked_future_version", "write_blocked_future_version"], "each refused write reported")
	assert_eq(FileAccess.get_file_as_string(_dir + "save_v3.json"), future, "file untouched")
	assert_eq(FileAccess.get_file_as_string(_dir + "save_v3.future.json"), future, "byte copy preserved")
	assert_false(_exists("save_v3.tmp") or _exists("save_v3.bak"), "no temp/backup created")
	_svc.load_from_disk()
	assert_eq(_svc.load_status, "future_version", "still reported on the next launch")
