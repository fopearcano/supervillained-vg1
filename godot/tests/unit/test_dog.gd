extends TestCase
## PlayableDog movement/animation against traces recorded from the real source Zampano class
## (src/entities/zampano.ts executed under Node, tests/fixtures/source_reference.json).

const DT := 1.0 / 60.0
const DOG := preload("res://entities/playable_dog/playable_dog.tscn")
const SCREEN_DIRS := [[0.0, -1.0], [0.7071, -0.7071], [1.0, 0.0], [0.7071, 0.7071], [0.0, 1.0], [-0.7071, 0.7071], [-1.0, 0.0], [-0.7071, -0.7071]]
const POS_TOL := 1e-9

var _map: WorldMapModel
var _dogs: Array[PlayableDog] = []


func before_each() -> void:
	_map = GreenZoneLevel.load_model(GreenZoneLevel.definition())


func after_each() -> void:
	for d in _dogs:
		d.free()
	_dogs.clear()


func _dog() -> PlayableDog:
	var d: PlayableDog = DOG.instantiate()
	_dogs.append(d)
	d.set_grid_position(_map.start.x, _map.start.y)
	d.face("N")
	return d


func _script_for(name: String) -> Callable:
	if name.begins_with("walk_"):
		var parts := name.split("_")
		var dir: Array = SCREEN_DIRS[int(parts[1])]
		var mag := float(parts[2])
		return func(k: int) -> Array: return [dir[0] * mag, dir[1] * mag, false] if k < 75 else [0.0, 0.0, false]
	if name.begins_with("run_") and name != "run_exhaust":
		var dir: Array = SCREEN_DIRS[int(name.split("_")[1])]
		return func(k: int) -> Array: return [dir[0], dir[1], true] if k < 75 else [0.0, 0.0, false]
	match name:
		"run_exhaust":
			return func(k: int) -> Array: return [0.0, -1.0, true] if k < 400 else [0.0, 0.0, false]
		"idle_phases":
			return func(_k: int) -> Array: return [0.0, 0.0, false]
		"scripted_run":
			return func(k: int) -> Array: return [0.0, -1.0, "scripted"] if k < 120 else [0.0, 0.0, false]
	return func(_k: int) -> Array: return [0.7071 * 0.8, 0.7071 * 0.8, false]


func _check(dog: PlayableDog, e: Dictionary, label: String) -> bool:
	var ok := true
	ok = assert_near(dog.gx, e["gx"], POS_TOL, label + " gx") and ok
	ok = assert_near(dog.gy, e["gy"], POS_TOL, label + " gy") and ok
	ok = assert_near(dog.vx, e["vx"], POS_TOL, label + " vx") and ok
	ok = assert_near(dog.vy, e["vy"], POS_TOL, label + " vy") and ok
	ok = assert_eq(dog.facing, e["facing"], label + " facing") and ok
	ok = assert_eq(dog.anim, e["anim"], label + " anim") and ok
	ok = assert_eq(dog.state, e["state"], label + " state") and ok
	ok = assert_near(dog.anim_speed, e["speed"], 1e-9, label + " anim speed") and ok
	if e.has("running"):
		ok = assert_eq(dog.running, e["running"], label + " running") and ok
		ok = assert_near(dog.energy.value, e["energy"], 1e-9, label + " energy") and ok
		ok = assert_eq(dog.energy.exhausted, e["exhausted"], label + " exhausted") and ok
	return ok


func _replay(trace: Dictionary, every: int, ticks: int) -> void:
	var dog := _dog()
	var name: String = trace["name"]
	if name.begins_with("terrain_"):
		var cell: Array = fixture()["zampano"]["terrain_cells"][{"terrain_tall_grass": "tallGrass", "terrain_water": "water", "terrain_bush": "bush"}[name]]
		dog.set_grid_position(cell[0], cell[1])
	var script := _script_for(name)
	var idx := 0
	var expected: Array = trace["trace"]
	for k in ticks:
		var it: Array = script.call(k)
		dog.set_intent(it[0], it[1], it[2])
		dog.update_movement(DT, _map)
		if k % every == every - 1 and idx < expected.size():
			if not _check(dog, expected[idx], "%s k=%d" % [name, k]):
				return
			idx += 1


func _trace(name: String) -> Dictionary:
	for t: Dictionary in fixture()["zampano"]["traces"]:
		if t["name"] == name:
			return t
	fail("missing trace " + name)
	return {"name": name, "trace": []}


func test_MOVE_003_walk_run_traces_8_directions() -> void:
	for d in 8:
		for mag in ["0.8", "0.4"]:
			_replay(_trace("walk_%d_%s" % [d, mag]), 6, 105)
		_replay(_trace("run_%d" % d), 6, 105)


func test_MOVE_004_terrain_multipliers() -> void:
	for name in ["terrain_tall_grass", "terrain_water", "terrain_bush"]:
		_replay(_trace(name), 3, 30)


func test_MOVE_001_analog_never_runs() -> void:
	var dog := _dog()
	for k in 60:
		dog.set_intent(0.0, -1.0, false)
		dog.update_movement(DT, _map)
		assert_false(dog.running, "full deflection without RUN must not run")
	assert_true(JsMath.hypot(dog.vx, dog.vy) <= GameConfig.Player.WALK_SPEED + 1e-9, "walk speed cap")


func test_DOG_007_exhaustion_and_recovery() -> void:
	_replay(_trace("run_exhaust"), 15, 900)


func test_DOG_002_rest_sequence_and_reset_after_action() -> void:
	_replay(_trace("idle_phases"), 30, 720)
	# A pee at 5 s (while sitting) restarts the rest clock: stand, then sit again 3 s after it ends.
	var dog := _dog()
	var expected: Array = fixture()["zampano"]["idle_after_action"]
	var idx := 0
	for k in 720:
		if k == 300:
			dog.start_action("pee", GameConfig.Bladder.PEE_TIME)
		dog.set_intent(0.0, 0.0, false)
		dog.update_movement(DT, _map)
		if k % 10 == 9:
			var e: Dictionary = expected[idx]
			idx += 1
			if not (assert_eq(dog.anim, e["anim"], "k=%d anim" % k) and assert_eq(dog.state, e["state"], "k=%d state" % k)
					and assert_near(dog.anim_speed, e["speed"], 1e-9, "k=%d speed" % k)):
				return
	var anims: Array = expected.map(func(e: Dictionary) -> String: return e["anim"])
	assert_true(anims.has("sit") and anims.has("pee"), "fixture covers sit then pee")


func test_DOG_001_idle_walk_run_selection_and_facing_kept() -> void:
	# Every walk/run trace stops at tick 75: the anim falls back to idle and the facing is kept.
	for d in 8:
		for name in ["walk_%d_0.8" % d, "run_%d" % d]:
			var t: Array = _trace(name)["trace"]
			var moving: Dictionary = t[10]
			var stopped: Dictionary = t[t.size() - 1]
			assert_eq(moving["anim"], "run" if name.begins_with("run") else "walk", name + " moving anim")
			assert_eq(stopped["anim"], "idle", name + " anim after stopping")
			assert_eq(stopped["facing"], moving["facing"], name + " facing kept on zero input")
	_replay(_trace("walk_3_0.8"), 6, 105)
	_replay(_trace("run_5"), 6, 105)


func test_MOVE_005_external_push_and_knockback_decay() -> void:
	var dog := _dog()
	var expected: Array = fixture()["zampano"]["push_knock"]
	var idx := 0
	for k in 150:
		if k < 90:
			dog.push_x = 1.6
			dog.push_y = -0.4
		if k == 60:
			dog.knockback(-1.0, 0.3, 7.0)
		dog.set_intent(0.3 if k < 120 else 0.0, -0.6 if k < 120 else 0.0, false)
		dog.update_movement(DT, _map)
		if k % 5 == 4:
			var e: Dictionary = expected[idx]
			idx += 1
			var lbl := "k=%d" % k
			if not (assert_near(dog.gx, e["gx"], POS_TOL, lbl + " gx") and assert_near(dog.gy, e["gy"], POS_TOL, lbl + " gy")
					and assert_near(dog.knock_x, e["knockX"], 1e-12, lbl + " knockX") and assert_near(dog.knock_y, e["knockY"], 1e-12, lbl + " knockY")
					and assert_eq(dog.facing, e["facing"], lbl + " facing")):
				return


func test_SLICE_scripted_run_costs_no_energy() -> void:
	_replay(_trace("scripted_run"), 10, 150)


func test_DOG_003_pee_locks_movement_for_rule_duration() -> void:
	var dog := _dog()
	var idx := 0
	var expected: Array = fixture()["zampano"]["action_lock"]
	for k in 120:
		if k == 30:
			dog.start_action("pee", GameConfig.Bladder.PEE_TIME)
		if k == 80:
			dog.knockback(1.0, 0.5, 7.0)
		dog.set_intent(0.0, -0.8, false)
		dog.update_movement(DT, _map)
		if k % 5 == 4:
			var e: Dictionary = expected[idx]
			assert_near(dog.gx, e["gx"], POS_TOL, "k=%d gx" % k)
			assert_near(dog.gy, e["gy"], POS_TOL, "k=%d gy" % k)
			assert_eq(dog.state, e["state"], "k=%d state" % k)
			assert_eq(dog.anim, e["anim"], "k=%d anim" % k)
			assert_eq(dog.controllable, e["controllable"], "k=%d controllable" % k)
			assert_near(dog.anim_speed, e["speed"], 1e-9, "k=%d anim speed" % k)
			idx += 1


func test_AST_005_spriteframes_timing_matches_manifest() -> void:
	# Zampanò against the source animationTiming fixture (frame-time samples), then every playable
	# skin against the source's own cycle durations and loop flags.
	var profile: PlayableCharacterProfile = load("res://data/characters/zampano_profile.tres")
	var src: Dictionary = fixture()["animation"]
	for anim: String in src:
		assert_near(profile.action_durations[anim], src[anim]["duration"], 1e-9, anim + " profile duration")
	var skins: Dictionary = fixture()["animation_skins"]
	assert_eq(skins.size(), 7, "every PLAYABLE_CHARACTER_KEYS skin")
	var aliases: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/characters/playable_profiles.json"))["aliases"]
	for skin: String in skins:
		var frames: SpriteFrames = load("res://data/characters/%s_frames.tres" % aliases.get(skin, skin))
		for anim: String in skins[skin]:
			var def: Dictionary = skins[skin][anim]
			for dir in IsoGrid.DIRS8:
				var name := StringName("%s_%s" % [anim, dir.to_lower()])
				if not assert_true(frames.has_animation(name), "%s missing animation %s" % [skin, name]):
					continue
				assert_eq(frames.get_frame_count(name), int(def["frames"]), "%s %s frame count" % [skin, name])
				assert_eq(frames.get_animation_loop(name), bool(def["loop"]), "%s %s loop flag" % [skin, name])
				var total := 0.0
				var holds: Variant = def["holds"]
				for f in frames.get_frame_count(name):
					var seconds := frames.get_frame_duration(name, f) / frames.get_animation_speed(name)
					total += seconds
					if holds != null:
						assert_near(seconds, float(holds[f]) / 1000.0, 1e-6, "%s %s frame %d hold" % [skin, name, f])
				assert_near(total, float(def["duration"]), 1e-6, "%s %s cycle duration" % [skin, name])
	# Frame-time samples of the source animationFrame() for Zampanò.
	for anim: String in src:
		assert_eq(int(src[anim]["def"]["frames"]), profile.normal_frames.get_frame_count(StringName(anim + "_s")), anim + " frames")
