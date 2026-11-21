extends TestCase
## SaveService: exact defaults, validation, records semantics and the atomic write/recovery path.
## Every case runs in its own user:// subdirectory and restores the live service afterwards.

var _svc: Node
var _saved_dir: String
var _saved_data: Dictionary
var _dir: String


func before_each() -> void:
	_svc = Engine.get_main_loop().root.get_node("SaveService")
	_saved_dir = _svc.base_dir
	_saved_data = _svc.data.duplicate(true)
	_dir = "user://tests/save_%d/" % Time.get_ticks_usec()
	_wipe(_dir)
	DirAccess.make_dir_recursive_absolute(_dir)
	_svc.base_dir = _dir
	_svc.load_from_disk()


func after_each() -> void:
	_wipe(_dir)
	_svc.base_dir = _saved_dir
	_svc.data = _saved_data
	_svc.write_blocked = false


func _wipe(dir: String) -> void:
	var d := DirAccess.open(dir)
	if d == null:
		return
	for f in d.get_files():
		d.remove(f)
	DirAccess.remove_absolute(dir)


func _write(name: String, text: String) -> void:
	var f := FileAccess.open(_dir + name, FileAccess.WRITE)
	f.store_string(text)
	f.close()


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


func test_SAV_003_settings_round_trip_only_on_change() -> void:
	var s: Dictionary = _svc.get_settings()
	assert_false(_svc.set_settings(s), "unchanged settings must not write")
	assert_false(FileAccess.file_exists(_dir + "save_v3.json"), "no file for a no-op")
	s["lives"] = 5
	assert_true(_svc.set_settings(s), "changed settings write")
	_svc.data = {}
	_svc.load_from_disk()
	assert_eq(_svc.load_status, "loaded", "reloaded")
	assert_eq(_svc.get_settings()["lives"], 5, "lives persisted")


func test_SAV_004_records_keep_bests_independently() -> void:
	assert_true(_svc.save_record("level1", {"score": 1000, "stars": 2.5, "time": 200.0}), "first record is a best")
	assert_false(_svc.save_record("level1", {"score": 900, "stars": 4.0, "time": 150.0}), "lower score is not a best")
	assert_true(_svc.save_record("level1", {"score": 1200, "stars": 1.0, "time": 300.0}), "higher score is a best")
	assert_eq(_svc.get_record("level1"), {"score": 1200, "stars": 4.0, "time": 150.0}, "independent bests")
	_svc.load_from_disk()
	assert_eq(_svc.get_record("level1"), {"score": 1200, "stars": 4.0, "time": 150.0}, "persisted bests")


func test_SAV_018_round_trip_is_identical() -> void:
	_svc.save_record("level1", {"score": 10, "stars": 0.5, "time": 12.25})
	var before: Dictionary = _svc.data.duplicate(true)
	_svc.load_from_disk()
	before.erase("written_at_unix_ms")
	var after: Dictionary = _svc.data.duplicate(true)
	after.erase("written_at_unix_ms")
	assert_eq(after, before, "semantic round trip")


func test_SAV_019_atomic_write_leaves_no_temp_and_rotates_backup() -> void:
	_svc.save_record("level1", {"score": 1, "stars": 0, "time": 1})
	assert_false(FileAccess.file_exists(_dir + "save_v3.tmp"), "temp removed by rename")
	assert_false(FileAccess.file_exists(_dir + "save_v3.bak"), "no backup before a second write")
	_svc.save_record("level1", {"score": 2, "stars": 0, "time": 1})
	assert_true(FileAccess.file_exists(_dir + "save_v3.bak"), "previous valid save rotated to backup")
	var bak: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(_dir + "save_v3.bak"))
	assert_eq(bak["records"]["level1"]["score"], 1, "backup holds the previous save")


func test_SAV_021_corrupt_save_recovers_from_backup() -> void:
	_svc.save_record("level1", {"score": 7, "stars": 1, "time": 9})
	_svc.save_record("level1", {"score": 8, "stars": 1, "time": 9})
	_write("save_v3.json", "{ this is not json")
	_svc.load_from_disk()
	assert_eq(_svc.load_status, "recovered_from_backup", "status")
	assert_eq(_svc.get_record("level1")["score"], 7, "backup content restored")
	assert_true(FileAccess.file_exists(_dir + "save_v3.corrupt.json"), "corrupt payload preserved")


func test_SAV_020_crash_before_rename_keeps_last_valid() -> void:
	_svc.save_record("level1", {"score": 3, "stars": 1, "time": 9})
	# Simulate a crash after the temp write: a stray (even invalid) temp must never be trusted.
	_write("save_v3.tmp", "{\"format_version\": 3, \"records\": {\"level1\": {\"score\": 999")
	_svc.load_from_disk()
	assert_eq(_svc.load_status, "loaded", "main save still used")
	assert_eq(_svc.get_record("level1")["score"], 3, "last valid save")
	# Simulate a crash between backup rotation and rename: no main file, valid backup.
	_svc.save_record("level1", {"score": 4, "stars": 1, "time": 9})
	DirAccess.remove_absolute(_dir + "save_v3.json")
	_svc.load_from_disk()
	assert_eq(_svc.load_status, "recovered_from_backup", "recovers newest valid file")
	assert_eq(_svc.get_record("level1")["score"], 3, "backup content")


func test_SAV_022_future_version_preserved_never_overwritten() -> void:
	var future := "{\"format_version\": 4, \"something\": \"new\"}"
	_write("save_v3.json", future)
	_svc.load_from_disk()
	assert_eq(_svc.load_status, "future_version", "status")
	assert_true(_svc.write_blocked, "writes blocked")
	assert_false(_svc.save_record("level1", {"score": 1, "stars": 0, "time": 1}) and false, "call returns")
	assert_eq(FileAccess.get_file_as_string(_dir + "save_v3.json"), future, "file untouched")
	assert_true(FileAccess.file_exists(_dir + "save_v3.future.json"), "copy preserved")
