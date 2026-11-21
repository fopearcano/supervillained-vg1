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


func test_DOG_002_idle_sit_sniff_phases() -> void:
	_replay(_trace("idle_phases"), 30, 720)


func test_DOG_001_scripted_run_costs_no_energy() -> void:
	_replay(_trace("scripted_run"), 10, 150)


func test_DOG_003_action_lock_and_knockback() -> void:
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
	var profile: PlayableCharacterProfile = load("res://data/characters/zampano_profile.tres")
	var frames := profile.normal_frames
	var src: Dictionary = fixture()["animation"]
	for anim: String in src:
		var def: Dictionary = src[anim]["def"]
		for dir in IsoGrid.DIRS8:
			var name := StringName("%s_%s" % [anim, dir.to_lower()])
			if not assert_true(frames.has_animation(name), "missing animation " + name):
				continue
			assert_eq(frames.get_frame_count(name), int(def["frames"]), "%s frame count" % name)
			assert_eq(frames.get_animation_loop(name), bool(def["loop"]), "%s loop flag" % name)
			var total := 0.0
			var holds: Array = def.get("frameDurationsMs", [])
			for f in frames.get_frame_count(name):
				var seconds := frames.get_frame_duration(name, f) / frames.get_animation_speed(name)
				total += seconds
				if not holds.is_empty():
					assert_near(seconds, float(holds[f]) / 1000.0, 1e-6, "%s frame %d hold" % [name, f])
			assert_near(total, src[anim]["duration"], 1e-6, "%s cycle duration" % name)
		assert_near(profile.action_durations[anim], src[anim]["duration"], 1e-9, anim + " profile duration")
