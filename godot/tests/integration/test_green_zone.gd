extends TestCase
## The Green Zone scene with real node wiring, driven only through InputService (no teleports,
## no rule calls) for the automation case. Logic advances in fixed 1/60 s ticks.

const SCENE := preload("res://scenes/green_zone/green_zone_scene.tscn")
const DT := 1.0 / 60.0

var scene: GreenZoneScene


## Save storage, input, audio and settings are isolated per case by the runner.
func after_each() -> void:
	if scene and is_instance_valid(scene):
		scene.get_parent().remove_child(scene)
		scene.free()
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


func test_P_ARCH_001_green_zone_scene_builds_shared_world() -> void:
	_spawn()
	assert_true(scene.world is IsoWorld, "IsoWorld")
	assert_true(scene.world.player is PlayableDog, "PlayableDog")
	assert_eq(scene.rules.treats.size(), 30, "30 treats placed")
	assert_eq(scene._treat_views.size(), 30, "30 treat views")
	assert_true(scene.active, "playing without briefing")
	assert_eq(scene.world.ground_layer.get_used_cells().size(), 96 * 96, "every non-void cell drawn")
	scene._process(DT)
	assert_true(scene.world.visible_count > 5 and scene.world.visible_count < 400, "culling keeps a small visible set (%d)" % scene.world.visible_count)


func test_FLOW_001_briefing_waits_for_confirmation_and_switches_music() -> void:
	_spawn(true)
	assert_false(scene.active, "inactive under the briefing")
	assert_eq(AudioService.current_track, &"intro", "intro music while reading the briefing")
	var t0: float = scene.rules.stats["time"]
	_step(30)
	assert_eq(scene.rules.stats["time"], t0, "timer frozen under the briefing")
	# The real confirmation path: Space/Enter (InputService "confirm") read by the overlay.
	var briefing: BriefingOverlay = scene._overlay
	assert_true(briefing is BriefingOverlay, "briefing overlay shown")
	InputService.trigger(&"confirm")
	await tree.process_frame
	await tree.process_frame
	assert_false(scene.active, "no start before 0.5 s of reading")
	briefing.time = 0.6
	InputService.trigger(&"confirm")
	await tree.process_frame
	await tree.process_frame
	assert_true(scene.active, "confirm starts the walk")
	assert_eq(AudioService.current_track, &"greenzone", "Green Zone music with the walk")
	assert_true(scene._overlay == null, "briefing closed")
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


func test_P_UI_001_006_hud_and_buttons_mirror_for_left_hand() -> void:
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
	scene.manual_ticks = false
	_step(10)
	InputService.trigger(&"menu")
	_step(1)
	assert_true(scene.paused, "MENU opens the pause")
	assert_eq(scene.world.process_mode, Node.PROCESS_MODE_DISABLED, "world frozen")
	var time0: float = scene.rules.stats["time"]
	var hunger0: float = scene.rules.hunger.value
	var ticks0 := scene.ticks
	for k in 30:
		scene._physics_process(DT)
	assert_eq([scene.rules.stats["time"], scene.rules.hunger.value, scene.ticks], [time0, hunger0, ticks0], "timers and rules frozen while paused")
	InputService.trigger(&"pee")
	scene.resume()
	assert_false(scene.paused, "resumed")
	assert_false(InputService.consume(&"pee"), "queued input cleared on resume")
	scene._physics_process(DT)
	assert_eq(scene.ticks, ticks0 + 1, "ticks again after resume")
	scene.manual_ticks = true


func test_P_FLOW_005_game_over_flow_and_no_record() -> void:
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
	await tree.process_frame
	var g0 := w.ground_layer.notifications
	var p0 := w.pollution_layer.notifications
	var f0 := w.fresh_layer.notifications
	var calls0 := w.ground_layer.callback_calls
	scene._process(DT)
	await tree.process_frame
	assert_eq([w.ground_layer.notifications, w.pollution_layer.notifications, w.fresh_layer.notifications], [g0, p0, f0], "empty change set: no notification")
	assert_eq(w.ground_layer.callback_calls, calls0, "no engine callbacks without a notification")
	m.stamp_dirt(80.5, 80.5, 2.6, 1.0)
	scene._process(DT)
	assert_eq(w.ground_layer.notifications, g0 + 1, "one ground notification per change set")
	assert_eq(w.pollution_layer.notifications, p0 + 1, "one pollution notification per change set")
	assert_eq(w.fresh_layer.notifications, f0, "fresh layer untouched by a stamp")
	await tree.process_frame
	var c := Vector2i(80, 80)
	var dirt := m.dirt[m.index(80, 80)]
	# The ENGINE's runtime TileData received the source colours (lerpColor tint, overlay alpha).
	assert_eq(w.ground_layer.applied.get(c), GroundLayer.tint_for(dirt), "engine TileData: dead-grass tint")
	assert_near((w.pollution_layer.applied.get(c, Color.WHITE) as Color).a, 0.3 + 0.65 * dirt, 1e-6, "engine TileData: dirt overlay alpha")
	assert_false(w.ground_layer.applied.has(Vector2i(10, 10)), "cells without pollution never opted in")
	var active := w.ground_layer.runtime_coords.size()
	assert_true(active > 5, "several tinted cells (%d)" % active)
	# A second change elsewhere reapplies every still-active cell (layer-wide refresh).
	w.ground_layer.applied.clear()
	m.stamp_dirt(70.5, 70.5, 1.0, 0.5)
	scene._process(DT)
	await tree.process_frame
	assert_true(w.ground_layer.applied.has(c), "still-active cell reapplied on a later refresh")
	m.clean(80.5, 80.5, 3.0)
	scene._process(DT)
	assert_false(w.ground_layer.runtime_coords.has(c), "tint removed when clean")
	assert_true(w.ground_layer.reset_pending.has(c), "reset pending until default is applied")
	await tree.process_frame
	assert_eq(w.ground_layer.applied.get(c), Color.WHITE, "engine TileData: default modulation applied to the reset cell")
	assert_false(w.pollution_layer.alpha_by_cell.has(c), "dirt overlay cell removed")
	assert_eq(w.pollution_layer.get_cell_source_id(c), -1, "dirt overlay erased from the layer")
	assert_true(w.fresh_layer.alpha_by_cell.has(c), "fresh highlight shown")
	await tree.process_frame
	assert_false(w.ground_layer.reset_pending.has(c), "reset cell dropped on the next process tick")
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
func test_SLICE_real_input_run_reaches_exit() -> void:
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


func test_DOG_006_presentation_never_changes_rule_state() -> void:
	# The same scripted run twice: once with the presentation live (in the tree: animation, squash,
	# invulnerability blink applied every tick), once with the dog outside the tree.
	var runs: Array = []
	for live in [true, false]:
		var def := GreenZoneLevel.definition()
		var map := GreenZoneLevel.load_model(def)
		var dog: PlayableDog = preload("res://entities/playable_dog/playable_dog.tscn").instantiate()
		if live:
			tree.root.add_child(dog)
		dog.set_grid_position(map.start.x, map.start.y)
		var rules := GreenZoneRules.new(map, dog, def, 3)
		var input := InputStub.new()
		var trace: Array = []
		var blinked := false
		for t in 420:
			input.move_y = -0.8 if t < 200 else 0.0
			if t == 100:
				rules.hunger.value = 0.001
			if t == 150:
				dog.bump(0.4)
			rules.update(DT, input)
			if live and dog.invulnerable > 0.0 and dog.body_sprite.modulate.a < 1.0:
				blinked = true
			trace.append([dog.gx, dog.gy, dog.vx, dog.state, dog.invulnerable, rules.stats["lives"], rules.hunger.value])
		runs.append(trace)
		if live:
			assert_true(blinked, "the invulnerability blink was shown")
			tree.root.remove_child(dog)
		dog.free()
	assert_eq(runs[0], runs[1], "identical rule state with and without presentation")


class InputStub:
	extends RefCounted
	var move_x := 0.0
	var move_y := 0.0
	var run_held := false

	func consume(_a: StringName) -> bool:
		return false


func test_SLICE_android_back_pauses_and_never_quits() -> void:
	assert_eq(ProjectSettings.get_setting("application/config/quit_on_go_back"), false, "Back does not quit the app")
	_spawn()
	scene.notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	assert_true(scene.paused, "Back pauses an active run")
	scene.notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	assert_false(scene.paused, "Back again resumes")
	assert_false(tree.root.get_node("SaveService").write_blocked, "no side effect on saves")


## Live playbacks cannot run in the suite (the Dummy driver never mixes them, so they leak at
## exit); tools/audio_suspend_probe.gd checks real playbacks pause and resume.
func test_SLICE_audio_background_suspends_music_and_effects() -> void:
	_spawn()
	for pair in [[Node.NOTIFICATION_APPLICATION_PAUSED, Node.NOTIFICATION_APPLICATION_RESUMED],
			[Node.NOTIFICATION_APPLICATION_FOCUS_OUT, Node.NOTIFICATION_APPLICATION_FOCUS_IN]]:
		AudioService.notification(pair[0])
		assert_true(AudioService.suspended, "suspended on %d" % pair[0])
		AudioService.play(&"pee")
		var last: Array = AudioService.started[AudioService.started.size() - 1]
		assert_true(last[2], "an effect requested in the background starts suspended")
		AudioService.notification(pair[1])
		assert_false(AudioService.suspended, "resumed on %d" % pair[1])
	AudioService.play(&"bark")
	assert_false(AudioService.started[AudioService.started.size() - 1][2], "effects play normally after resuming")


func test_SLICE_audio_effects_skip_source_leading_silence() -> void:
	_spawn()
	var fx: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/audio/sfx_leading_silence.json"))
	for cue in ["bark", "treat", "poop", "pee", "drink", "splash"]:
		AudioService.play(StringName(cue))
		var last: Array = AudioService.started[AudioService.started.size() - 1]
		assert_eq(last[0], StringName(cue), cue)
		assert_near(last[1], fx["offsets"][cue]["48000"]["offset"], 1e-9, cue + " start offset")
	assert_true(AudioService.offsets[&"bark"] > 0.09, "the bark's 95 ms of silence is skipped")
	# Gameplay events reach the recorded cues.
	scene.rules.treat_eaten.emit(0, 1.0, 1.0, 50)
	assert_eq(AudioService.requested.get(&"treat", 0), 2, "treat cue on a treat")


func test_P_VIEW_004_whole_pixel_world_and_nearest_filtering() -> void:
	_spawn()
	assert_eq(ProjectSettings.get_setting("rendering/textures/canvas_textures/default_texture_filter"), 0, "nearest filtering")
	assert_true(ProjectSettings.get_setting("rendering/2d/snap/snap_2d_transforms_to_pixel"), "transform snapping")
	assert_true(ProjectSettings.get_setting("physics/common/physics_interpolation"), "physics interpolation (no manual interpolation)")
	var r := DeterministicRng.new(11)
	for k in 240:
		var a := r.range_float(0.0, TAU)
		InputService.inject_move(cos(a) * 0.8, sin(a) * 0.8, k % 3 == 0)
		_step(1, 1)
		if k % 40 == 39:
			for n in scene.world.object_layer.get_children():
				if n.visible and n.position != n.position.round():
					fail("fractional world position %s on %s at tick %d" % [n.position, n.name, k])
					return
			var origin := scene.world.camera_rig.view_rect().position
			assert_eq(origin, origin.round(), "whole-pixel camera origin")
	for n in [scene.hud, scene.controls]:
		assert_eq(n.position, n.position.round(), "UI on whole pixels")


func test_AST_014_green_zone_never_applies_the_obsolete_arcade_floor() -> void:
	_spawn()
	var design: Dictionary = fixture("floor_design_1_arcade")
	assert_eq([int(design["width"]), int(design["height"])], [96, 96], "the obsolete composition fits the map size")
	for c: Vector2i in scene.world.ground_layer.get_used_cells():
		if scene.world.ground_layer.get_cell_source_id(c) != 0:
			fail("authored floor frame drawn at %s" % c)
			return
	assert_eq(scene.world.floor_design_rejection, "", "no design was requested")
