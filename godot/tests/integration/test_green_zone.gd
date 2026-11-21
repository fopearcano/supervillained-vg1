extends TestCase
## The Green Zone scene with real node wiring, driven only through InputService (no teleports,
## no rule calls) for the automation case. Logic advances in fixed 1/60 s ticks.

const SCENE := preload("res://scenes/green_zone/green_zone_scene.tscn")
const DT := 1.0 / 60.0

var scene: GreenZoneScene
var _save_dir: String
var _save_prev_dir: String
var _save_prev_data: Dictionary


func before_each() -> void:
	var svc: Node = Engine.get_main_loop().root.get_node("SaveService")
	_save_prev_dir = svc.base_dir
	_save_prev_data = svc.data.duplicate(true)
	_save_dir = "user://tests/gz_%d/" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(_save_dir)
	svc.base_dir = _save_dir
	svc.load_from_disk()


func after_each() -> void:
	if scene and is_instance_valid(scene):
		scene.get_parent().remove_child(scene)
		scene.free()
	var svc: Node = Engine.get_main_loop().root.get_node("SaveService")
	var d := DirAccess.open(_save_dir)
	if d:
		for f in d.get_files():
			d.remove(f)
		DirAccess.remove_absolute(_save_dir)
	svc.base_dir = _save_prev_dir
	svc.data = _save_prev_data
	InputService.clear_injection()


func _spawn(briefing: bool = false) -> GreenZoneScene:
	scene = SCENE.instantiate()
	scene.show_briefing = briefing
	scene.manual_ticks = true
	tree.root.add_child(scene)
	scene.resize(Vector2i(216, 432))
	return scene


func _step(n: int = 1, render_every: int = 4) -> void:
	for k in n:
		InputService.update(DT)
		scene.tick(DT)
		if scene.ticks % render_every == 0:
			scene._process(DT)


func test_ARCH_001_scene_builds_shared_world() -> void:
	_spawn()
	assert_true(scene.world is IsoWorld, "IsoWorld")
	assert_true(scene.world.player is PlayableDog, "PlayableDog")
	assert_eq(scene.rules.treats.size(), 30, "30 treats placed")
	assert_eq(scene._treat_views.size(), 30, "30 treat views")
	assert_true(scene.active, "playing without briefing")
	assert_eq(scene.world.ground_layer.get_used_cells().size(), 96 * 96, "every non-void cell drawn")
	scene._process(DT)
	assert_true(scene.world.visible_count > 5 and scene.world.visible_count < 400, "culling keeps a small visible set (%d)" % scene.world.visible_count)


func test_FLOW_001_briefing_waits_for_confirmation() -> void:
	_spawn(true)
	assert_false(scene.active, "inactive under the briefing")
	var t0: float = scene.rules.stats["time"]
	_step(30)
	assert_eq(scene.rules.stats["time"], t0, "timer frozen under the briefing")
	scene.start_play()
	_step(30)
	assert_near(scene.rules.stats["time"], 0.5, 1e-9, "timer runs after start")


func test_MOVE_001_keyboard_and_joystick_paths() -> void:
	_spawn()
	Input.action_press(&"move_up")
	InputService.update(DT)
	assert_near(InputService.move_y, -GameConfig.InputCfg.KEYBOARD_WALK_MAG, 1e-12, "keyboard walk magnitude")
	Input.action_release(&"move_up")
	InputService.update(DT)
	assert_eq(InputService.move_y, 0.0, "released")
	# Floating joystick: appears under the thumb only in the joystick zone; dead zone applies.
	InputService.pointer_down(3, Vector2(40, 300))
	assert_true(InputService.joystick["active"], "joystick claimed in zone")
	InputService.pointer_move(3, Vector2(40, 300 - 3))
	InputService.update(DT)
	assert_eq(InputService.move_y, 0.0, "inside dead zone")
	InputService.pointer_move(3, Vector2(40, 300 - 40))
	InputService.update(DT)
	assert_near(InputService.move_y, -1.0, 1e-9, "full deflection, base follows the thumb")
	assert_false(InputService.run_held, "full deflection never runs")
	# A second finger on RUN while the joystick is held.
	var run_c: Vector2 = InputService.buttons[&"run"]["center"]
	InputService.pointer_down(4, run_c)
	assert_true(InputService.run_held, "RUN held with simultaneous joystick")
	InputService.pointer_up(4, run_c)
	InputService.pointer_up(3, Vector2(40, 260))
	InputService.update(DT)
	assert_false(InputService.joystick["active"], "joystick released")
	# Touches outside the zone (right side) do not grab the joystick.
	InputService.pointer_down(5, Vector2(200, 200))
	assert_false(InputService.joystick["active"], "right side is not the joystick zone")
	InputService.pointer_up(5, Vector2(200, 200))


func test_UI_001_hud_and_buttons_mirror_for_left_hand() -> void:
	_spawn()
	var right: Vector2 = InputService.buttons[&"pee"]["center"]
	InputService.left_handed = true
	scene.controls.layout(Vector2i(216, 432))
	var left: Vector2 = InputService.buttons[&"pee"]["center"]
	assert_eq(left.x, 216 - right.x, "PEE mirrored")
	assert_true(InputService.joystick_zone.position.x > 0, "joystick zone moves right")
	InputService.left_handed = false
	scene.controls.layout(Vector2i(216, 432))
	var st := scene.hud_state()
	assert_eq(st["zone_name"], "Green Zone", "zone name")
	assert_eq(st["stars"], 5.0, "five stars at full health")


func test_FLOW_002_pause_freezes_and_resume_clears_input() -> void:
	_spawn()
	_step(10)
	InputService.trigger(&"menu")
	_step(1)
	assert_true(scene.paused, "MENU opens the pause")
	assert_eq(scene.world.process_mode, Node.PROCESS_MODE_DISABLED, "world frozen")
	InputService.trigger(&"pee")
	scene.resume()
	assert_false(scene.paused, "resumed")
	assert_false(InputService.consume(&"pee"), "queued input cleared on resume")


func test_FLOW_005_game_over_flow_and_no_record() -> void:
	_spawn()
	scene.rules.stats["lives"] = 1
	scene.rules.hunger.value = 0.01
	_step(2)
	assert_eq(scene.rules.state, "gameover", "starved with one life")
	_step(70)
	assert_eq(scene.result.get("state"), "gameover", "game over result after 1.1 s")
	assert_true(scene._overlay is GameOverOverlay, "game over overlay")
	assert_eq(SaveService.get_record("level1"), null, "game over saves no record")


func test_WORLD_005_pollution_layers_follow_the_model() -> void:
	_spawn()
	var w := scene.world
	var m := w.map
	scene._process(DT)
	var g0 := w.ground_layer.notifications
	var p0 := w.pollution_layer.notifications
	scene._process(DT)
	assert_eq(w.ground_layer.notifications, g0, "no notification without model changes")
	m.stamp_dirt(80.5, 80.5, 2.6, 1.0)
	scene._process(DT)
	assert_eq(w.ground_layer.notifications, g0 + 1, "one ground notification per change set")
	assert_eq(w.pollution_layer.notifications, p0 + 1, "one pollution notification per change set")
	var c := Vector2i(80, 80)
	var expected_tint := GroundLayer.tint_for(m.dirt[m.index(80, 80)])
	assert_eq(w.ground_layer.runtime_coords.get(c), expected_tint, "dead-grass tint")
	assert_near(w.pollution_layer.alpha_by_cell[c], 0.3 + 0.65 * m.dirt[m.index(80, 80)], 1e-6, "dirt overlay alpha")
	m.clean(80.5, 80.5, 3.0)
	scene._process(DT)
	assert_false(w.ground_layer.runtime_coords.has(c), "tint removed when clean")
	assert_true(w.ground_layer.reset_pending.has(c), "reset pending until default is applied")
	assert_false(w.pollution_layer.alpha_by_cell.has(c), "dirt overlay cell removed")
	assert_true(w.fresh_layer.alpha_by_cell.has(c), "fresh highlight shown")
	for k in 90:
		m.update(DT)
		scene._process(DT)
	assert_false(w.fresh_layer.alpha_by_cell.has(c), "fresh highlight fades out after 1.2 s")


func test_DEPTH_004_tree_fades_when_hiding_the_dog() -> void:
	_spawn()
	var w := scene.world
	var tree_prop: IsoProp = null
	for n in w.object_layer.get_children():
		if n is IsoProp and n.kind == "tree" and n.map_prop != null:
			tree_prop = n
			break
	assert_true(tree_prop != null, "a tree exists")
	# Stand just behind (north of) the tree: the tree sorts in front and overlaps the dog.
	var mp := tree_prop.map_prop
	w.player.set_grid_position(mp.x - 0.6, mp.y - 0.6)
	w.snap_camera()
	scene._process(DT)
	assert_near(tree_prop.iso.fade, 1.0 + (0.42 - 1.0) * (10.0 / 60.0), 1e-6, "first-order fade step")
	assert_true(tree_prop.z_index > w.player.z_index, "tree drawn after the dog standing behind it")
	for k in 120:
		scene._process(DT)
	assert_near(tree_prop.iso.fade, 0.42, 0.01, "faded to 0.42")
	w.player.set_grid_position(mp.x + 3.0, mp.y + 3.0)
	w.snap_camera()
	for k in 120:
		scene._process(DT)
	assert_near(tree_prop.iso.fade, 1.0, 0.01, "back to opaque when clear")
	assert_true(w.player.z_index > tree_prop.z_index, "dog sorts in front when south-east of the tree")


## AUTO-001: real-input Green Zone run. The driver only sets InputService movement and presses
## PEE; it follows the BFS distance field toward the exit, detours to nearby treats, and pees on
## its poops. It must eat, poop, pee, clean, reach the exit and save the record.
func test_AUTO_001_real_input_run_reaches_exit() -> void:
	_spawn()
	var dog := scene.world.player
	var cleaned := [0]
	scene.rules.poop_cleaned.connect(func(_x: float, _y: float, _s: int) -> void: cleaned[0] += 1)
	var driver := GreenZoneDriver.new()
	for t in 60 * 150:
		if scene.rules.state != "playing":
			break
		driver.step(scene)
		_step(1, 6)
		if driver.stalled(60 * 8):
			fail("no progress toward the exit for 8 s at %s,%s (distance %d)" % [dog.gx, dog.gy, driver.best_distance])
			return
	InputService.clear_injection()
	_step(80)
	var st := scene.rules.stats
	assert_eq(scene.rules.state, "complete", "reached the exit")
	assert_true(st["treats"] >= 4, "ate treats (%d)" % st["treats"])
	assert_true(st["poops"] >= 1, "pooped (%d)" % st["poops"])
	assert_true(st["pees"] >= 1, "peed (%d)" % st["pees"])
	assert_true(cleaned[0] >= 1, "cleaned a poop with pee")
	assert_eq(scene.result.get("state"), "complete", "level-end result")
	assert_true(scene._overlay is LevelEndOverlay, "level end overlay shown")
	var rec: Variant = SaveService.get_record("level1")
	assert_true(rec != null and int(rec["score"]) == int(scene.result["total"]), "record saved at completion")
	print("       AUTO-001: %.1f s, treats %d, poops %d, pees %d, marks %d, lives %d, health %.4f, stars %.1f, total %d" % [
		st["time"], st["treats"], st["poops"], st["pees"], st["marks"], st["lives"], scene.result["health"], scene.result["stars"], scene.result["total"]])
