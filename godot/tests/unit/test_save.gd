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


## CRLF line ends, non-ASCII characters and trailing spaces must all survive unchanged.
const FUTURE_BYTES := "{\"format_version\": 4,\r\n \"something\": \"nuovo \u2013 \u0259\"}\r\n  "


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


func test_SAV_022_future_format_in_main_temp_or_backup_is_preserved_and_blocks_writes() -> void:
	var copies := {"save_v3.json": "save_v3.future.json", "save_v3.tmp": "save_v3.tmp.future.json", "save_v3.bak": "save_v3.bak.future.json"}
	for loc: String in copies:
		_clear()
		# A valid current-format main (newest) and backup around the future payload.
		if loc != "save_v3.json":
			_write("save_v3.json", _valid_save(5, 2000))
		if loc != "save_v3.bak":
			_write("save_v3.bak", _valid_save(4, 1000))
		_write(loc, FUTURE_BYTES)
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
		var r: Dictionary = _svc.save_record("level1", {"score": 99, "stars": 0, "time": 1})
		var st: Dictionary = _svc.get_settings()
		st["lives"] = 5
		var rs: Dictionary = _svc.set_settings(st)
		_svc.save_failed.disconnect(cb)
		assert_eq([r["saved"], rs["saved"]], [false, false], loc + ": nothing saved")
		assert_eq(failures, ["write_blocked_future_version", "write_blocked_future_version"], loc + ": each refused write reported")
		var after := _files()
		for f: String in before:
			assert_eq(after.get(f), before[f], "%s: %s byte-for-byte untouched" % [loc, f])
		assert_eq(after.get(copies[loc]), FUTURE_BYTES.to_utf8_buffer(), loc + ": byte-for-byte copy " + copies[loc])
		assert_eq(after.keys().size(), before.keys().size() + 1, loc + ": only the copy was added")
		_svc.load_from_disk()
		assert_eq([_svc.load_status, _files()], ["future_version", after], loc + ": next launch still blocked, nothing rewritten")
	_clear()
	_svc.load_from_disk()


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
