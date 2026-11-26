extends TestCase
## M4 persistence: the format-3 campaign and import sections, the campaign session (new game, the
## walk handoff, replays), crash windows through injected file operations, the legacy Capacitor
## import (raw backup first, per-key conversion, status rules) and the Couch summary. The runner
## gives every case its own empty save directory; nothing here touches a real save.

const NOW := 1795608000000

var _svc: Node
var _dir: String


func before_each() -> void:
	_svc = SaveService
	_dir = _svc.base_dir
	AppState.clock = func() -> int: return NOW


func after_each() -> void:
	_svc.file_ops = SaveFileOps.new()
	AppState.end_replay()
	AppState.clock = func() -> int: return int(Time.get_unix_time_from_system() * 1000.0)


func _disk() -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(_dir + "save_v3.json"))
	return parsed if parsed is Dictionary else {}


func _bytes(name: String) -> PackedByteArray:
	return FileAccess.get_file_as_bytes(_dir + name)


func _src(name: String) -> Variant:
	return fixture()[name]


func _store(values: Dictionary) -> LegacyImport.FixtureSource:
	return LegacyImport.FixtureSource.new({"status": "ok", "raw": LegacyImport.FixtureSource.payload(values)})


func _write_abs(path: String, bytes: PackedByteArray) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_buffer(bytes)
	f.close()


## Committed bytes: the main, or the backup while an interrupted write left no main.
func _committed() -> PackedByteArray:
	return _bytes("save_v3.json") if FileAccess.file_exists(_dir + "save_v3.json") else _bytes("save_v3.bak")


## Every injected write stage (file-operation failures, crash hooks) and a blocked session.
const STAGES := [
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


## Arms one stage: main and backup exist first (so every stage is reachable).
func _arm(stage: Dictionary) -> void:
	_svc.file_ops = SaveFileOps.new()
	_svc.write_to_disk()
	_svc.write_to_disk()
	var f := FaultyFileOps.new()
	f.fail = stage.get("fail", {})
	f.torn_write = stage.get("torn", "")
	_svc.file_ops = f
	_svc.fault_after = stage.get("hook", "")
	_svc.write_blocked = stage.get("blocked", false)


func _disarm() -> void:
	_svc.file_ops = SaveFileOps.new()
	_svc.fault_after = ""
	_svc.write_blocked = false


func test_SAV_005_legacy_standalone_coins_are_passive_preservation() -> void:
	var r: Variant = _svc.run_legacy_import(_store({"coins": "123.7"}), NOW)
	assert_eq(r["status"], "imported", "coins key imported")
	assert_eq(_svc.legacy_coins(), {"present": true, "value": 123}, "present/value, normalized")
	var before: Dictionary = _svc.legacy_coins()
	# Gameplay: the walk handoff, a record, settings — none touches the passive coins.
	AppState.complete_walk(7, 61.5)
	_svc.save_record("level1", {"score": 900, "stars": 3.5, "time": 80.0})
	AppState.set_setting("volume", 0.5)
	assert_eq(_svc.legacy_coins(), before, "never mutated by gameplay")
	assert_eq(int(_svc.get_campaign()["coins"]), 7, "campaign coins are separate")
	assert_eq(_disk()["legacy_arcade_coins"], {"present": true, "value": 123}, "persisted as preservation data")
	# Without the old key: {present: false, value: 0}.
	_svc.data = _svc.default_container()
	assert_eq(_svc.legacy_coins(), {"present": false, "value": 0}, "absent key")
	# The only writer of the field is the importer.
	var writers: PackedStringArray = []
	# (SaveService only normalizes the field on load; LegacyImport is the one writer.)
	for path in ["res://autoload/app_state.gd", "res://scenes/green_zone/green_zone_scene.gd", "res://systems/green_zone_rules.gd", "res://systems/green_zone_threats.gd", "res://main/main.gd"]:
		if FileAccess.get_file_as_string(path).contains("[\"legacy_arcade_coins\"] =") or FileAccess.get_file_as_string(path).contains("legacy_arcade_coins\"] ="):
			writers.append(path)
	assert_eq(writers, PackedStringArray(), "no gameplay or shell code writes legacy_arcade_coins")


func test_SAV_006_new_campaign_exact_default_snapshot() -> void:
	var src: Dictionary = fixture("source_campaign_migration")["new_campaign"]
	assert_eq(CampaignSchema.new_campaign(), src, "the source newCampaign()")
	_svc.data["campaign"]["completed"] = ["1.0"]
	_svc.data["campaign"]["coins"] = 99
	assert_true(AppState.new_game(), "saved")
	var expected := src.duplicate(true)
	expected["savedAt"] = NOW
	assert_eq(_svc.get_campaign(), expected, "NEW GAME: the exact default, saved now (source resetCampaign)")
	assert_eq(_disk()["campaign"], expected, "on disk")


func test_SAV_007_campaign_effects_dedupe_and_clamp_like_source() -> void:
	var fx: Dictionary = fixture()["effects"]
	var st := CampaignSchema.new_campaign()
	for step: Dictionary in fx["steps"]:
		var changes: Array = CampaignRules.apply_effects(st, step["effects"])
		assert_eq(changes, step["changes"], "change labels for %s" % [step["effects"]])
		var want: Dictionary = step["state"]
		assert_eq([st["meters"], st["book"], st["abilities"], st["coins"], st["flags"]], [want["meters"], want["book"], want["abilities"], want["coins"], want["flags"]], "state after %s" % [step["effects"]])
	CampaignRules.mark_complete(st, "1.0")
	CampaignRules.mark_complete(st, "1.0")
	CampaignRules.mark_complete(st, "1.1")
	assert_eq(st["completed"], fx["completed"], "completion added once")
	# The saved form keeps the rule: duplicates and out-of-range meters are normalized away.
	var raw := CampaignSchema.new_campaign()
	raw["meters"] = {"commozione": 140, "supervillain": -3, "grace": 50.5, "standing": "x"}
	raw["book"]["marvels"] = ["A", "B", "A"]
	raw["abilities"] = ["cross", "cross", "knight", "wings"]
	var n: Dictionary = CampaignSchema.normalize(raw, SaveService.CATALOG.ids())["data"]
	assert_eq([n["meters"], n["book"]["marvels"], n["abilities"]], [{"commozione": 100, "supervillain": 0, "grace": 50.5, "standing": 50}, ["A", "B"], ["cross", "knight"]], "normalized on save")


## SAV-009 (partial: the story's per-effect autosaves are M5): the walk's scene completion saves
## the campaign (savedAt = the save time); settings, records and imports write the container
## (written_at_unix_ms) without moving campaign.savedAt.
func test_P_SAV_009_container_writes_never_move_campaign_saved_at() -> void:
	AppState.complete_walk(3, 40.0)
	var saved_at: Variant = _disk()["campaign"]["savedAt"]
	assert_eq(saved_at, NOW, "the scene completion saved the campaign")
	AppState.clock = func() -> int: return NOW + 60000
	var w0 := int(_disk()["written_at_unix_ms"])
	AppState.set_setting("muted", true)
	_svc.save_record("level1", {"score": 10, "stars": 1.0, "time": 99.0})
	_svc.run_legacy_import(_store({"settings": JSON.stringify({"volume": 0.25})}), NOW + 60000)
	var d := _disk()
	assert_true(int(d["written_at_unix_ms"]) > w0, "container written again")
	assert_eq(d["campaign"]["savedAt"], saved_at, "campaign.savedAt unchanged by container writes")


## SAV-010 (partial: story play time is M5): the walk's time counts outside replays only; savedAt
## is Unix milliseconds.
func test_P_SAV_010_play_time_excludes_replays_and_saved_at_is_unix_ms() -> void:
	AppState.complete_walk(0, 30.25)
	assert_eq([_svc.get_campaign()["playTime"], _svc.get_campaign()["savedAt"]], [30.25, NOW], "walk time counted; savedAt in ms")
	AppState.begin_replay("1.0")
	var bytes := _bytes("save_v3.json")
	assert_eq(AppState.complete_walk(5, 90.0), {"saved": false, "replay": true, "applied": false, "error": ""}, "a replay hands nothing over")
	assert_eq(_bytes("save_v3.json"), bytes, "no persistent byte changed")
	assert_eq(_svc.get_campaign()["playTime"], 30.25, "replay time not counted")
	assert_true(int(_svc.get_campaign()["savedAt"]) > 1_000_000_000_000, "milliseconds, not seconds")


func test_SAV_011_replay_state_is_a_deep_independent_copy() -> void:
	var st := CampaignSchema.new_campaign()
	st["completed"] = ["1.0"]
	st["book"]["marvels"] = ["A LION OF STONE"]
	st["flags"] = {"vow": true}
	_svc.save_campaign(st, NOW)
	AppState.begin_replay("1.0")
	var copy: Dictionary = AppState.replay_state
	CampaignRules.apply_effects(copy, {"marvel": "A GOLDEN HORSE", "grace": -20, "flags": {"vow": false}, "coins": 50})
	(copy["completed"] as Array).append("1.1")
	var saved: Variant = _svc.get_campaign()
	assert_eq([saved["book"]["marvels"], saved["meters"]["grace"], saved["flags"], saved["coins"], saved["completed"]], [["A LION OF STONE"], 70, {"vow": true}, 0, ["1.0"]], "the saved campaign is untouched")
	(_svc.data["campaign"]["book"]["marvels"] as Array).append("SOMETHING ELSE")
	assert_eq(AppState.replay_state["book"]["marvels"], ["A LION OF STONE", "A GOLDEN HORSE"], "and the copy is independent the other way")
	assert_eq(AppState.campaign()["coins"], 50, "the session reads the replay copy")


func test_SAV_012_campaign_flag_schema() -> void:
	var flags := {
		"oath": "enforced", "lamp": "lost", "drawing": "city", "tellingTier": 3, "zaraOwe": "pope", "corfu": "syria",
		"letter": "named", "courtesy84": "unanswered", "shortfall": 36000, "pawOffered": true, "longWay": "yes",
		"santinaBall": "kept", "futureScalar": "x", "futureNumber": 2.5, "futureBool": false, "futureArray": [1], "futureObject": {"a": 1},
		"vow": 1,
	}
	var dropped: Array = []
	var out := CampaignSchema.normalize_flags(flags, dropped)
	assert_eq(out, {"oath": "enforced", "drawing": "city", "zaraOwe": "pope", "corfu": "syria", "letter": "named",
		"courtesy84": "unanswered", "shortfall": 36000, "pawOffered": true, "santinaBall": "kept", "futureScalar": "x",
		"futureNumber": 2.5, "futureBool": false}, "valid known values and unknown scalars kept")
	dropped.sort()
	assert_eq(dropped, ["flags.futureArray", "flags.futureObject", "flags.lamp", "flags.longWay", "flags.tellingTier", "flags.vow"], "invalid known values and composites omitted")
	assert_eq(CampaignSchema.normalize_flags({"shortfall": -1, "santinaBall": "performed"}), {"santinaBall": "performed"}, "shortfall nonnegative; the current santinaBall value")
	# Through the importer: the raw payload is backed up before the flags are normalized, and the
	# v1 compatibility value survives the migration.
	var v1 := {"version": 1, "completed": ["1.0", "1.4"], "flags": {"santinaBall": "kept", "junk": [1, 2]}}
	var r: Variant = _svc.run_legacy_import(_store({"story": JSON.stringify(v1)}), NOW)
	assert_eq(r["status"], "imported", "imported")
	var raw := _bytes("legacy/capacitor_local_storage.json").get_string_from_utf8()
	assert_true(raw.contains("junk"), "the raw backup keeps what normalization drops")
	assert_eq(_svc.get_campaign()["flags"], {"santinaBall": "kept"}, "v1 santinaBall kept; the composite is not a kept flag")


func test_SLICE_every_campaign_field_is_normalized() -> void:
	var raw := {
		"version": 2, "completed": ["1.0", "9.9", 7, "1.0", "1.1"], "meters": {"grace": 20.0},
		"flags": "nope", "book": {"items": ["X", "X", 3], "values": "bad"}, "abilities": "cross",
		"coins": -4.5, "playTime": -10, "savedAt": 1795608000000.7, "notice": "dream-rewritten", "extra": {"x": 1},
	}
	var r := CampaignSchema.normalize(raw, SaveService.CATALOG.ids())
	var d: Dictionary = r["data"]
	assert_eq([d["completed"], d["meters"], d["flags"], d["book"]["items"], d["book"]["values"], d["abilities"], d["coins"], d["playTime"], d["savedAt"], d["notice"], d.has("extra")],
		[["1.0", "1.1"], {"commozione": 20, "supervillain": 10, "grace": 20, "standing": 50}, {}, ["X"], [], [], 0, 0, 1795608000000, "dream-rewritten", false], "normalized")
	assert_false(CampaignSchema.normalize({"version": 1}, SaveService.CATALOG.ids())["ok"], "not v2: defaults kept by the caller")
	var li := CampaignSchema.normalize_legacy_import({"status": "imported", "attempt_count": 2.0, "payload_sha256": "ABC", "keys_imported": ["settings", "bogus", "settings"], "error_code": 5})
	assert_eq([li["status"], li["attempt_count"], li["payload_sha256"], li["keys_imported"], li["error_code"], li["source"]], ["imported", 2, null, ["settings"], null, "capacitor_webview"], "import metadata normalized")
	assert_eq(CampaignSchema.normalize_legacy_import({"status": "weird"}), CampaignSchema.default_legacy_import(), "unknown status: defaults")


## Every write stage through injected file operations: the temp write, its validation, the backup
## removal and rotation, the final rename, plus the crash hooks; after each the next load finds the
## newest valid save and never a torn one.
func test_SLICE_crash_windows_with_injected_file_operations() -> void:
	_svc.save_record("level1", {"score": 100, "stars": 1.0, "time": 90.0})
	_svc.save_record("level1", {"score": 200, "stars": 1.0, "time": 90.0})
	var cases := [
		[{"write_bytes": "save_v3.tmp"}, "", "open_temp_failed"],
		[{}, "save_v3.tmp", "temp_validation_failed"],
		[{"remove": "save_v3.bak"}, "", "backup_remove_failed"],
		[{"rename": "save_v3.bak"}, "", "backup_rotation_failed"],
		[{"rename": "save_v3.tmp"}, "", "rename_failed"],
	]
	var score := 200
	for c: Array in cases:
		var ops := FaultyFileOps.new()
		ops.fail = c[0]
		ops.torn_write = c[1]
		_svc.file_ops = ops
		var r: Dictionary = _svc.save_record("level1", {"score": score + 50, "stars": 1.0, "time": 90.0})
		assert_eq([r["saved"], _svc.last_error], [false, c[2]], "failure reported: %s" % c[2])
		_svc.file_ops = SaveFileOps.new()
		_svc.load_from_disk()
		var got := int(_svc.get_record("level1")["score"])
		assert_true(got == score or got == score + 50, "%s: a valid save loads (%d)" % [c[2], got])
		score = got
		assert_true(_svc.load_status in ["loaded", "recovered_from_temp", "recovered_from_backup"], "%s: %s" % [c[2], _svc.load_status])
	for hook in ["temp_partial", "temp_written", "temp_validated", "backup_rotated"]:
		_svc.fault_after = hook
		_svc.save_record("level1", {"score": score + 50, "stars": 1.0, "time": 90.0})
		_svc.fault_after = ""
		_svc.load_from_disk()
		var got := int(_svc.get_record("level1")["score"])
		assert_true(got >= score, "%s: newest valid (%d)" % [hook, got])
		score = got


## MIG-005, M4 fixture/simulated portion (M9 proves it on a real WebView store): the raw five-key
## payload is written byte for byte with its SHA-256 and timestamp before any parsing and read back;
## a backup directory, write, read-back or metadata failure parses nothing and claims nothing.
func test_P_MIG_005_raw_payload_backed_up_before_parsing() -> void:
	var raw := LegacyImport.FixtureSource.payload({"settings": JSON.stringify({"muted": true}), "coins": "42"})
	var ops := FaultyFileOps.new()
	_svc.file_ops = ops
	var r: Variant = _svc.run_legacy_import(LegacyImport.FixtureSource.new({"status": "ok", "raw": raw}), NOW)
	assert_eq(r["status"], "imported", "imported")
	assert_eq(_bytes("legacy/capacitor_local_storage.json"), raw, "the raw payload, byte for byte")
	var meta: Dictionary = JSON.parse_string(_bytes("legacy/capacitor_local_storage.meta.json").get_string_from_utf8())
	assert_eq([meta["sha256"], int(meta["bytes"]), int(meta["written_at_unix_ms"])], [LegacyImport.sha256_hex(raw), raw.size(), NOW], "timestamp and SHA-256 recorded")
	assert_eq(_svc.legacy_import_state()["payload_sha256"], LegacyImport.sha256_hex(raw), "hash in the save")
	var first_write := ops.calls.find(ops.calls.filter(func(c: Array) -> bool: return c[0] == "write_bytes")[0])
	var backup_write := ops.calls.find(["write_bytes", _svc.legacy_dir().path_join("capacitor_local_storage.json")])
	var save_write := ops.calls.find(["write_bytes", _dir + "save_v3.tmp"])
	assert_true(backup_write == first_write and backup_write < save_write, "the backup is the first write, before the converted save")
	assert_true(ops.calls.find(["read_bytes", _svc.legacy_dir().path_join("capacitor_local_storage.json")]) > backup_write, "read back")
	for fault: Dictionary in [{"fail": {"make_dir": "legacy"}}, {"fail": {"write_bytes": "capacitor_local_storage.json"}},
			{"short": "capacitor_local_storage.json"}, {"fail": {"write_bytes": "meta.json"}}]:
		_svc.data = _svc.default_container()
		var f := FaultyFileOps.new()
		f.fail = fault.get("fail", {})
		f.short_read = fault.get("short", "")
		_svc.file_ops = f
		DirAccess.remove_absolute(_svc.legacy_dir().path_join("capacitor_local_storage.json"))
		DirAccess.remove_absolute(_svc.legacy_dir().path_join("capacitor_local_storage.meta.json"))
		DirAccess.remove_absolute(_svc.legacy_dir())
		var rr: Variant = _svc.run_legacy_import(LegacyImport.FixtureSource.new({"status": "ok", "raw": raw}), NOW)
		assert_eq([rr["status"], rr["parsed"], rr["keys_imported"], _svc.get_settings()["muted"], _svc.legacy_coins()["present"]],
			["retryable_error", false, [], false, false], "no parse, no success after %s (%s)" % [fault, rr["error_code"]])
		assert_true(String(rr["error_code"]).begins_with("backup_"), "a backup error code (%s)" % rr["error_code"])


## MIG-006 (fixture portion): settings, records and the passive standalone coins convert like the
## source's own readers (loadSettings, loadRecords, loadCoins); records merge as bests.
func test_P_MIG_006_settings_records_and_passive_coins_convert_exactly() -> void:
	_svc.save_record("level1", {"score": 500, "stars": 2.0, "time": 70.0})
	var settings := {"muted": true, "volume": 1.7, "textSpeed": "fast", "lives": 12, "controls": {"swipeUp": "bark", "run": "toggle", "hand": "left", "switcher": "no"}}
	var records := {"level1": {"score": 400, "stars": 3.5, "time": 95.0}, "level9": {"score": "x"}}
	var r: Variant = _svc.run_legacy_import(_store({"settings": JSON.stringify(settings), "records": JSON.stringify(records), "coins": "17"}), NOW)
	assert_eq(r["status"], "imported", "imported")
	assert_eq(_svc.get_settings(), _svc.normalize_settings(settings), "settings: the loadSettings rules")
	assert_eq(_svc.get_settings()["controls"], {"swipeUp": "bark", "swipeDown": "shield", "doubleTap": "bark", "run": "toggle", "switcher": true, "hand": "left"}, "controls validated")
	assert_eq(_svc.get_record("level1"), {"score": 500, "stars": 3.5, "time": 70.0}, "records merged as independent bests")
	assert_eq(_svc.get_record("level9"), null, "an invalid record dropped")
	assert_eq(_svc.legacy_coins(), {"present": true, "value": 17}, "coins preserved")


## MIG-007 (fixture portion): a v2 campaign converts to format 3 field by field.
func test_P_MIG_007_v2_campaign_converts_exactly() -> void:
	var v2 := {"version": 2, "completed": ["1.0", "1.1"], "meters": {"commozione": 33, "supervillain": 12, "grace": 64, "standing": 55},
		"flags": {"vow": true, "oath": "undecided"}, "book": {"marvels": ["M"], "items": ["I"], "values": ["V"], "remembered": ["R"], "shards": ["S"]},
		"abilities": ["cross"], "coins": 12, "playTime": 321.5, "savedAt": 1700000000000, "notice": null}
	var r: Variant = _svc.run_legacy_import(_store({"story": JSON.stringify(v2)}), NOW)
	assert_eq(r["status"], "imported", "imported")
	assert_eq(_svc.get_campaign(), v2, "identical after normalization")
	assert_eq(_disk()["campaign"], v2, "on disk")


## MIG-008 (fixture portion): a v1 campaign runs the source migrateV1 semantics (the source-executed
## fixtures) before the format-3 conversion.
func test_P_MIG_008_v1_campaign_migrates_before_conversion() -> void:
	var cases: Dictionary = fixture("source_campaign_migration")["migrations"]
	for name: String in cases:
		var c: Dictionary = cases[name]
		if not c.get("raw") is Dictionary:
			continue
		_svc.data = _svc.default_container()
		_svc.data["legacy_import"] = CampaignSchema.default_legacy_import()
		var r: Variant = _svc.run_legacy_import(_store({"story": JSON.stringify(c["raw"])}), NOW)
		assert_eq(r["status"], "imported", "%s imported" % name)
		var want: Dictionary = CampaignSchema.normalize(c["migrated"], SaveService.CATALOG.ids())["data"]
		assert_eq(_svc.get_campaign(), want, "%s: migrateV1 then format 3" % name)


## MIG-009 (fixture portion): the status rules — imported / imported_partial / not_found /
## retryable_error / blocked, per-key results, retries and idempotence.
func test_P_MIG_009_status_transitions_retries_and_idempotence() -> void:
	# retryable_error, then a retry that imports.
	var err := LegacyImport.FixtureSource.new({"status": "error", "error_code": "bridge_timeout"})
	assert_eq(_svc.run_legacy_import(err, NOW)["status"], "retryable_error", "acquisition error is retryable")
	assert_eq([_svc.legacy_import_state()["attempt_count"], _svc.legacy_import_state()["error_code"]], [1, "bridge_timeout"], "attempt counted")
	var ok := _store({"settings": "{}", "story": "not json"})
	var r: Variant = _svc.run_legacy_import(ok, NOW + 1)
	assert_eq([r["status"], r["keys_present"], r["keys_imported"], r["keys_failed"], r["error_code"]], ["imported_partial", ["settings", "story"], ["settings"], ["story"], "story:not_json"], "valid keys import, the bad one fails")
	assert_eq(_svc.legacy_import_state()["attempt_count"], 2, "second attempt")
	# Idempotent: nothing runs again, nothing is written.
	var bytes := _bytes("save_v3.json")
	var again: Variant = _svc.run_legacy_import(ok, NOW + 2)
	assert_eq([again["ran"], ok.calls, _bytes("save_v3.json")], [false, 1, bytes], "imported_partial is terminal and idempotent")
	# not_found is terminal unless forced.
	_svc.data = _svc.default_container()
	assert_eq(_svc.run_legacy_import(LegacyImport.FixtureSource.new({"status": "not_found"}), NOW)["status"], "not_found", "no store")
	var later := _store({"settings": "{}"})
	assert_false(_svc.run_legacy_import(later, NOW)["ran"], "not_found does not retry by itself")
	assert_eq(_svc.run_legacy_import(later, NOW, true)["status"], "imported", "a forced diagnostic retry imports")
	# blocked: an unreadable payload, or nothing convertible, or a write-blocked (future) save.
	_svc.data = _svc.default_container()
	assert_eq(_svc.run_legacy_import(LegacyImport.FixtureSource.new({"status": "ok", "raw": "{broken".to_utf8_buffer()}), NOW)["status"], "blocked", "malformed payload: backed up, not trusted")
	assert_eq(_bytes("legacy/capacitor_local_storage.json"), "{broken".to_utf8_buffer(), "the malformed payload is kept")
	_svc.data = _svc.default_container()
	assert_eq(_svc.run_legacy_import(_store({"records": "[1]", "coins": "\"x\""}), NOW)["status"], "blocked", "nothing convertible")
	_svc.data = _svc.default_container()
	assert_eq(_svc.run_legacy_import(_store({}), NOW)["status"], "not_found", "a store without the keys")
	_svc.data = _svc.default_container()
	_svc.write_blocked = true
	assert_eq(_svc.run_legacy_import(_store({"settings": "{}"}), NOW)["status"], "blocked", "a future-format save waits")
	_svc.write_blocked = false


## MIG-010 (partial: the limitation copy is not owner-approved and the real missing-store case is
## M9): a missing store reports not_found and imports nothing; a failed attempt never reports
## success; the title shows a retry or blocked notice (MessageOverlay text in data/shell).
func test_P_MIG_010_missing_store_never_fabricates_success() -> void:
	var r: Variant = _svc.run_legacy_import(LegacyImport.FixtureSource.new({"status": "not_found"}), NOW)
	assert_eq([r["status"], r["keys_imported"], r["parsed"]], ["not_found", [], false], "nothing imported")
	assert_eq(_svc.get_campaign(), CampaignSchema.new_campaign(), "no campaign fabricated")
	var text: ShellText = load("res://data/shell/shell_text.tres")
	assert_true(text.get_text("legacy_retry") != "" and text.get_text("legacy_blocked") != "", "notice copy present")


## COUCH data (UI-012–014 data side): CampaignSummary equals src/campaign/summary.ts on five
## campaigns (fresh, after the walk, mid-story, both endings) and the formatting samples.
func test_SLICE_couch_summary_matches_source() -> void:
	var cf: Dictionary = fixture()["couch"]
	for c: Dictionary in cf["cases"]:
		var got := CampaignSummary.progress(c["state"], SaveService.CATALOG)
		var want: Dictionary = c["summary"]
		for k: String in want:
			assert_true(values_equal(got[k], want[k]), "%s.%s = %s, source %s" % [c["name"], k, got[k], want[k]])
		assert_eq(CampaignSummary.format_play_time(float(c["state"]["playTime"])), c["playTime"], "%s play time" % c["name"])
		assert_eq(CampaignSummary.format_saved_at(c["state"]["savedAt"], int(cf["now"]), 0), c["savedAt"], "%s saved" % c["name"])
	for p: Array in cf["play_time"]:
		assert_eq(CampaignSummary.format_play_time(float(p[0])), p[1], "play time %s" % p[0])
	for p: Array in cf["saved_at"]:
		assert_eq(CampaignSummary.format_saved_at(p[0], int(cf["now"]), 0), p[1], "saved %s" % p[0])
	for p: Array in cf["next_label"]:
		var st: Dictionary = (cf["cases"] as Array).filter(func(c: Dictionary) -> bool: return c["name"] == p[0])[0]["state"]
		var label := SaveService.CATALOG.continue_label(st["completed"])
		assert_eq(label if label != "" else null, p[1], "%s continue label" % p[0])


## FLOW-006: level 1 is open; a level opens when the previous one is complete; inside a level the
## finished scenes and the first unfinished one are open (source StoryFlow.unlocked and
## StoryChapterScene); nothing else.
func test_FLOW_006_sequential_unlock_matches_source_rules() -> void:
	var cat := SaveService.CATALOG
	var st := CampaignSchema.new_campaign()
	var open := func(s: Dictionary) -> Array: return Array(cat.ids()).filter(func(id: String) -> bool: return CampaignFlow.scene_open(s, cat, id))
	assert_eq(open.call(st), ["1.0"], "a new campaign: only 1.0")
	st["completed"] = ["1.0"]
	assert_eq(open.call(st), ["1.0", "1.1"], "after 1.0: 1.0 (replay) and 1.1")
	assert_false(CampaignFlow.level_unlocked(st, cat, 2), "level 2 closed until level 1 is complete")
	st["completed"] = ["1.0", "1.1", "1.2", "1.3", "1.4", "1.5"]
	assert_true(CampaignFlow.level_unlocked(st, cat, 2), "level 2 opens")
	assert_eq(open.call(st), ["1.0", "1.1", "1.2", "1.3", "1.4", "1.5", "2.1"], "all of level 1 and the first of level 2")
	st["completed"] = ["1.0", "1.2"]
	assert_eq(open.call(st), ["1.0", "1.1", "1.2"], "a gap: the first unfinished is the one open")
	assert_eq(CampaignFlow.continue_target(st, cat)["id"], "1.1", "CONTINUE goes to the first unfinished")
	st["completed"] = Array(cat.ids())
	assert_eq(CampaignFlow.continue_target(st, cat), {}, "finished: CONTINUE opens the level list")


## FLOW-010: a finished scene starts from a deep copy with persistence off; an unfinished one from
## the campaign itself; a locked one not at all.
func test_FLOW_010_replay_starts_from_a_deep_copy() -> void:
	var cat := SaveService.CATALOG
	var st := CampaignSchema.new_campaign()
	st["completed"] = ["1.0"]
	var r := CampaignFlow.start(st, cat, "1.0")
	assert_eq([r["mode"], r["persist"], r["playable"]], ["replay", false, true], "replay of the walk")
	(r["state"]["completed"] as Array).append("X")
	assert_eq(st["completed"], ["1.0"], "deep copy")
	var p := CampaignFlow.start(st, cat, "1.1")
	assert_eq([p["mode"], p["persist"], p["playable"], is_same(p["state"], st)], ["play", true, true, true], "the next scene plays on the campaign (1.1 is playable from M5R)")
	for id: String in cat.ids():
		if not StoryLibrary.has_scene(id) and id != "1.0":
			assert_false(cat.playable_in_build(id), "%s: a scene without Resources is not playable in this build" % id)
	assert_false(cat.playable_in_build("9.9"), "an unknown ID is not playable")
	assert_eq(CampaignFlow.start(st, cat, "1.3")["mode"], "locked", "locked")
	assert_eq(CampaignFlow.finish(st, "1.0", true), {"save": false}, "a replay finish saves nothing")


## FLOW-007/008/009/012 shell portions (the story runner that applies effects, fades Commozione,
## shows the aside and offers SKIP SCENE is M5).
func test_P_FLOW_007_009_policy_shell() -> void:
	var cat := SaveService.CATALOG
	# FLOW-007: the walk's effects (coins, time) and its completion persist together, in ONE atomic
	# campaign save (the source saves twice, addWalk then finishSub; one save cannot half-apply).
	var ops := FaultyFileOps.new()
	_svc.file_ops = ops
	AppState.complete_walk(4, 12.0)
	var saves := ops.calls.filter(func(c: Array) -> bool: return c[0] == "rename" and String(c[2]).ends_with("save_v3.json"))
	assert_eq(saves.size(), 1, "one atomic campaign save")
	assert_eq([_svc.get_campaign()["coins"], _svc.get_campaign()["playTime"], _svc.get_campaign()["completed"]], [4, 12.0, ["1.0"]], "coins, time and 1.0 persisted together")
	# FLOW-009: the snap after the walk (replay or not) and after each level's last scene, never after a story replay.
	assert_true(CampaignFlow.supervillained_after(cat, "1.0", false) and CampaignFlow.supervillained_after(cat, "1.0", true), "after 1.0")
	assert_true(CampaignFlow.supervillained_after(cat, "1.5", false), "after 1.5")
	assert_false(CampaignFlow.supervillained_after(cat, "1.5", true), "not after a replay of 1.5")
	assert_false(CampaignFlow.supervillained_after(cat, "1.2", false), "not mid-level")
	for ch: Dictionary in cat.chapters:
		var last: Dictionary = (ch["sub_levels"] as Array).back()
		assert_true(CampaignFlow.supervillained_after(cat, last["id"], false), "after %s" % last["id"])
	# FLOW-008 (shell): the effect rules never duplicate awards.
	var st := CampaignSchema.new_campaign()
	CampaignRules.apply_effects(st, {"marvel": "A", "unlock": "cross"})
	assert_eq(CampaignRules.apply_effects(st, {"marvel": "A", "unlock": "cross"}), [], "no second award on a restart")


## The walk's handoff is ONE campaign save (coins, time, 1.0 and one savedAt): at every injected write
## stage and in a blocked session none of them is applied (the whole container in memory and the
## committed bytes unchanged); the retry applies them exactly once; a repeated handoff after
## success adds nothing.
func test_SLICE_walk_handoff_is_atomic_and_idempotent() -> void:
	_svc.save_record("level1", {"score": 10, "stars": 1.0, "time": 60.0})
	for stage: Dictionary in STAGES:
		_arm(stage)
		var before: Dictionary = _svc.data.duplicate(true)
		var committed := _committed()
		var r: Dictionary = AppState.complete_walk(4, 12.5)
		_disarm()
		assert_eq([r["saved"], r["applied"], r["error"]], [false, false, stage["why"]], "%s: reported" % stage["why"])
		assert_eq(_svc.data, before, "%s: nothing applied in memory" % stage["why"])
		assert_eq(_committed(), committed, "%s: committed bytes unchanged" % stage["why"])
	AppState.clock = func() -> int: return NOW + 5
	var ok: Dictionary = AppState.complete_walk(4, 12.5)
	assert_eq([ok["saved"], ok["applied"]], [true, true], "the retry saves")
	var camp: Dictionary = _svc.get_campaign()
	assert_eq([camp["coins"], camp["playTime"], camp["completed"], camp["savedAt"]], [4, 12.5, ["1.0"], NOW + 5], "applied once, with one savedAt")
	assert_eq(_disk()["campaign"], camp, "on disk")
	var again: Dictionary = AppState.complete_walk(4, 12.5)
	assert_eq([again["saved"], again["applied"], _svc.get_campaign()], [true, false, camp], "a repeated handoff adds nothing")


## The dream-rewritten notice counts as taken only after its clearing is saved (source showNotice:
## saveCampaign, savedAt = now). At every failed stage, and blocked, it stays in memory and in the
## committed file and the caller learns the save failed.
func test_SLICE_story_notice_taken_only_after_a_saved_clear() -> void:
	var st := CampaignSchema.new_campaign()
	st["notice"] = "dream-rewritten"
	st["completed"] = ["1.0"]
	_svc.save_campaign(st, NOW - 1000)
	for stage: Dictionary in STAGES:
		_arm(stage)
		var before: Dictionary = _svc.data.duplicate(true)
		var committed := _committed()
		var n: Dictionary = AppState.take_story_notice()
		_disarm()
		assert_eq([n["notice"], n["saved"], n["error"]], [false, false, stage["why"]], "%s: not taken, failure reported" % stage["why"])
		assert_eq(_svc.data, before, "%s: notice kept in memory" % stage["why"])
		assert_eq(_committed(), committed, "%s: and in the committed file" % stage["why"])
		var parsed: Dictionary = JSON.parse_string(committed.get_string_from_utf8())
		assert_eq(parsed["campaign"]["notice"], "dream-rewritten", "%s: persisted notice" % stage["why"])
	assert_eq(AppState.take_story_notice(), {"notice": true, "saved": true, "error": ""}, "taken once saved")
	assert_eq([_disk()["campaign"]["notice"], _disk()["campaign"]["savedAt"]], [null, NOW], "cleared and saved (savedAt = now, as the source)")
	assert_eq(AppState.take_story_notice(), {"notice": false, "saved": true, "error": ""}, "only once")


## MIG-009 (fixture portion): the import is one transaction. When its final container write fails (at
## every injected stage) the pre-import settings, records, passive coins, campaign and import record
## stay exactly as they were, in memory and in the committed file, and the attempt reports
## retryable_error with no imported keys (blocked: it waits, nothing changes). A same-session retry
## imports cleanly (no campaign_conflict); a forced re-run never adds the campaign's coins, time or
## progress twice.
func test_P_MIG_009_final_write_failure_leaks_nothing_and_retries() -> void:
	_svc.save_record("level1", {"score": 500, "stars": 2.0, "time": 70.0})
	var v2 := {"version": 2, "completed": ["1.0", "1.1"], "meters": {"commozione": 33, "supervillain": 12, "grace": 64, "standing": 55},
		"flags": {"vow": true}, "book": {"marvels": ["M"], "items": [], "values": [], "remembered": [], "shards": []},
		"abilities": ["cross"], "coins": 12, "playTime": 321.5, "savedAt": 1700000000000, "notice": null}
	var values := {"settings": JSON.stringify({"muted": true, "lives": 6}), "records": JSON.stringify({"level1": {"score": 900, "stars": 4.0, "time": 65.0}}),
		"coins": "17", "story": JSON.stringify(v2)}
	for stage: Dictionary in STAGES:
		_arm(stage)
		var before: Dictionary = _svc.data.duplicate(true)
		var committed := _committed()
		var r: Dictionary = _svc.run_legacy_import(_store(values), NOW)
		_disarm()
		var want := ["blocked", "save_write_blocked"] if stage.get("blocked", false) else ["retryable_error", "container_write_failed"]
		assert_eq([r["status"], r["error_code"], r["keys_imported"], r["committed"]], want + [[], false], "%s: reported, nothing claimed" % stage["why"])
		assert_eq(_svc.data, before, "%s: no partial import in memory" % stage["why"])
		assert_eq(_committed(), committed, "%s: committed bytes unchanged" % stage["why"])
	var ok: Dictionary = _svc.run_legacy_import(_store(values), NOW + 1)
	assert_eq([ok["status"], ok["keys_imported"], ok["committed"]], ["imported", ["settings", "records", "coins", "story"], true], "the same-session retry imports")
	assert_eq(_svc.get_campaign(), v2, "the campaign once (no campaign_conflict): coins 12, time 321.5")
	assert_eq([_svc.get_settings()["muted"], _svc.get_settings()["lives"], _svc.get_record("level1"), _svc.legacy_coins()],
		[true, 6, {"score": 900, "stars": 4.0, "time": 65.0}, {"present": true, "value": 17}], "settings, merged records, passive coins")
	assert_eq(_svc.legacy_import_state()["attempt_count"], 1, "only the committed attempt is on record")
	var bytes := _bytes("save_v3.json")
	assert_eq([_svc.run_legacy_import(_store(values), NOW + 2)["ran"], _bytes("save_v3.json")], [false, bytes], "imported: idempotent")
	var forced: Dictionary = _svc.run_legacy_import(_store(values), NOW + 3, true)
	assert_eq([forced["status"], forced["keys_failed"], forced["error_code"]], ["imported_partial", ["story"], "story:campaign_conflict"], "a forced re-run does not replace the campaign")
	assert_eq([_svc.get_campaign()["coins"], _svc.get_campaign()["playTime"], _svc.get_campaign()["completed"], _svc.legacy_coins()["value"]],
		[12, 321.5, ["1.0", "1.1"], 17], "coins, time, progress and the passive coins never added twice")


## MIG-005 (fixture portion): an existing raw backup is never written over unless it was preserved
## first. A different earlier payload is moved aside and verified there; one that cannot be read,
## whose aside name holds other bytes, or that cannot be moved, stays untouched and the attempt is
## retryable (nothing parsed, nothing claimed).
func test_P_MIG_005_existing_raw_backup_preserved_or_left_alone() -> void:
	var dir: String = _svc.legacy_dir()
	DirAccess.make_dir_recursive_absolute(dir)
	var path := dir.path_join("capacitor_local_storage.json")
	var earlier := "{\"supervillained:coins\": \"5\"}".to_utf8_buffer()
	_write_abs(path, earlier)
	var aside := dir.path_join("capacitor_local_storage.%s.json" % LegacyImport.sha256_hex(earlier).substr(0, 12))
	var raw := LegacyImport.FixtureSource.payload({"coins": "9"})
	var src := LegacyImport.FixtureSource.new({"status": "ok", "raw": raw})
	var f := FaultyFileOps.new()
	for fault: Array in [[{"read_bytes": "capacitor_local_storage.json"}, "", "backup_existing_unreadable"],
			[{"rename": "capacitor_local_storage"}, "", "backup_rotate_failed"], [{}, "other", "backup_aside_conflict"]]:
		f.fail = fault[0]
		if fault[1] != "":
			_write_abs(aside, String(fault[1]).to_utf8_buffer())
		_svc.file_ops = f
		var r: Dictionary = _svc.run_legacy_import(src, NOW)
		_svc.file_ops = SaveFileOps.new()
		assert_eq([r["status"], r["error_code"], r["parsed"], _svc.legacy_coins()["present"]], ["retryable_error", fault[2], false, false], "%s: retryable, nothing parsed" % fault[2])
		assert_eq(FileAccess.get_file_as_bytes(path), earlier, "%s: the earlier raw backup untouched" % fault[2])
		if fault[1] != "":
			assert_eq(FileAccess.get_file_as_string(aside), "other", "%s: the other aside file untouched" % fault[2])
			DirAccess.remove_absolute(aside)
	# The moved copy reads back wrong: stop before writing (the earlier bytes are already aside).
	f.fail = {}
	f.short_read = "capacitor_local_storage.%s" % LegacyImport.sha256_hex(earlier).substr(0, 6)
	_svc.file_ops = f
	var bad: Dictionary = _svc.run_legacy_import(src, NOW)
	_svc.file_ops = SaveFileOps.new()
	assert_eq([bad["status"], bad["error_code"], FileAccess.file_exists(path), FileAccess.get_file_as_bytes(aside)], ["retryable_error", "backup_rotate_verify_failed", false, earlier], "not written over; the earlier bytes kept aside")
	var ok: Dictionary = _svc.run_legacy_import(src, NOW)
	assert_eq([ok["status"], FileAccess.get_file_as_bytes(path), FileAccess.get_file_as_bytes(aside), _svc.legacy_coins()], ["imported", raw, earlier, {"present": true, "value": 9}], "healthy: the new payload, the earlier one aside")
	# A healthy different payload later: the previous one moves aside, verified.
	var raw2 := LegacyImport.FixtureSource.payload({"coins": "11"})
	_svc.run_legacy_import(LegacyImport.FixtureSource.new({"status": "ok", "raw": raw2}), NOW, true)
	var aside2 := dir.path_join("capacitor_local_storage.%s.json" % LegacyImport.sha256_hex(raw).substr(0, 12))
	assert_eq([FileAccess.get_file_as_bytes(path), FileAccess.get_file_as_bytes(aside2), FileAccess.get_file_as_bytes(aside)], [raw2, raw, earlier], "every earlier payload kept")


## MIG-007/008 (fixture portion): only exact story versions convert: 1 (migrated first) and 2, also
## written as 1.0 and 2.0; 2.5, 2.1, 1.5, 2.0000001, 0.999, "2" and 3 are unknown versions and leave
## the campaign exactly as it was.
func test_P_MIG_007_008_story_versions_must_be_exact() -> void:
	for ver: Variant in [2.5, 2.1, 1.5, 2.0000001, 0.999, "2", 3]:
		_svc.data = _svc.default_container()
		var story := {"version": ver, "completed": ["1.0"], "coins": 40, "playTime": 9}
		var r: Dictionary = _svc.run_legacy_import(_store({"story": JSON.stringify(story)}), NOW)
		assert_eq([r["status"], r["keys_failed"], r["error_code"]], ["blocked", ["story"], "story:unknown_version"], "version %s rejected" % [ver])
		assert_eq(_svc.get_campaign(), CampaignSchema.new_campaign(), "version %s: campaign untouched" % [ver])
	for ver: Variant in [1.0, 2.0]:
		_svc.data = _svc.default_container()
		var story := {"version": ver, "completed": ["1.0"], "coins": 40, "playTime": 9}
		var r: Dictionary = _svc.run_legacy_import(_store({"story": JSON.stringify(story)}), NOW)
		assert_eq([r["status"], _svc.get_campaign()["completed"], _svc.get_campaign()["coins"]], ["imported", ["1.0"], 40], "version %s accepted" % [ver])


func test_SLICE_tests_use_isolated_save_directories() -> void:
	assert_true(_svc.base_dir.begins_with("user://test_runs/"), "isolated directory: %s" % _svc.base_dir)
	assert_true(_svc.persist_to_disk, "the runner enables disk writes only for that directory")
