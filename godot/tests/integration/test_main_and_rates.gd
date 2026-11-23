extends TestCase
## The persistent Main scene (safe area, pixel SubViewport, real touch routing, underlay) and the
## independence of the logic from the render rate (physics interpolation contract).

const MAIN := preload("res://main/main.tscn")
const GZ := preload("res://scenes/green_zone/green_zone_scene.tscn")
const DT := 1.0 / 60.0

var main: Node
var scene: Node
var _saved_window := Vector2i.ZERO


func before_each() -> void:
	_saved_window = tree.root.size


func after_each() -> void:
	for n in [main, scene]:
		if n and is_instance_valid(n):
			n.get_parent().remove_child(n)
			n.free()
	tree.root.size = _saved_window
	InputService.clear_injection()


## Main with the walk started (briefing closed) so touches reach the gameplay controls.
func _main_playing(window: Vector2i, safe: Rect2i) -> void:
	tree.root.size = window
	main = MAIN.instantiate()
	tree.root.add_child(main)
	main.viewport_controller.safe_rect_override = safe
	main.viewport_controller.apply()
	await tree.process_frame
	var gz: GreenZoneScene = main.current_scene
	gz.manual_ticks = true
	gz._close_overlay()
	gz.start_play()
	await tree.process_frame


func _touch(index: int, pos: Vector2, pressed: bool) -> void:
	var e := InputEventScreenTouch.new()
	e.index = index
	e.position = pos
	e.pressed = pressed
	Input.parse_input_event(e)


func _drag(index: int, pos: Vector2) -> void:
	var e := InputEventScreenDrag.new()
	e.index = index
	e.position = pos
	Input.parse_input_event(e)


func test_VIEW_003_safe_area_and_touch_round_trip() -> void:
	var safe := Rect2i(24, 60, 520, 900)
	await _main_playing(Vector2i(568, 1000), safe)
	var vc: PixelViewportController = main.viewport_controller
	var container: SubViewportContainer = vc.container
	var area_origin := Vector2(safe.position)
	var origin := area_origin + container.position
	var view := Rect2(origin, container.size)
	assert_true(Rect2(safe).encloses(view), "pixel viewport inside the safe area (%s in %s)" % [view, safe])
	assert_eq(container.size, Vector2(vc.logical_size * vc.scale), "container = logical x integer scale")
	assert_eq(container.stretch_shrink, vc.scale, "stretch shrink = scale")
	# Physical -> logical through the real Window -> SubViewportContainer -> SubViewport -> Control path.
	var worst := 0.0
	var r := DeterministicRng.new(17)
	for k in 12:
		var logical := Vector2(r.range_float(4.0, vc.logical_size.x * 0.55), r.range_float(70.0, vc.logical_size.y - 10.0))
		var physical := origin + logical * vc.scale
		_touch(k, physical, true)
		await tree.process_frame
		if not assert_true(InputService.joystick["active"], "touch %d reached the joystick" % k):
			return
		worst = maxf(worst, (InputService.joystick["base"] as Vector2).distance_to(logical))
		_touch(k, physical, false)
		await tree.process_frame
	assert_true(worst <= 0.5, "physical->logical round trip within 0.5 logical px (worst %.3f)" % worst)
	# Touches in the letterbox / outside the safe area never reach the game.
	_touch(30, Vector2(safe.position) - Vector2(10, 10), true)
	await tree.process_frame
	assert_false(InputService.joystick["active"], "outside the viewport: ignored")
	_touch(30, Vector2(safe.position) - Vector2(10, 10), false)


func test_SLICE_subviewport_multi_touch_routing() -> void:
	await _main_playing(Vector2i(432, 864), Rect2i())
	var vc: PixelViewportController = main.viewport_controller
	var origin: Vector2 = vc.container.position
	var to_phys := func(l: Vector2) -> Vector2: return origin + l * vc.scale
	var pee_c: Vector2 = InputService.buttons[&"pee"]["center"]
	var run_c: Vector2 = InputService.buttons[&"run"]["center"]
	# Finger 0: joystick; finger 1: RUN held; finger 2: PEE tapped — all at once.
	_touch(0, to_phys.call(Vector2(50, 300)), true)
	_touch(1, to_phys.call(run_c), true)
	await tree.process_frame
	_drag(0, to_phys.call(Vector2(50, 270)))
	_touch(2, to_phys.call(pee_c), true)
	await tree.process_frame
	InputService.update(DT)
	assert_true(InputService.joystick["active"], "joystick owned by finger 0")
	assert_true(InputService.move_y < -0.9, "dragged up = screen up (%.3f)" % InputService.move_y)
	assert_true(InputService.run_held, "RUN held by finger 1")
	assert_true(InputService.consume(&"pee"), "PEE tapped by finger 2")
	# Releasing RUN does not release the joystick (pointer ownership).
	_touch(1, to_phys.call(run_c), false)
	_touch(2, to_phys.call(pee_c), false)
	await tree.process_frame
	assert_false(InputService.run_held, "RUN released")
	assert_true(InputService.joystick["active"], "joystick still owned by finger 0")
	_touch(0, to_phys.call(Vector2(50, 270)), false)
	await tree.process_frame
	assert_false(InputService.joystick["active"], "joystick released")


func test_SLICE_viewport_underlay_and_black_letterbox() -> void:
	await _main_playing(Vector2i(800, 600), Rect2i())
	var underlay: ColorRect = main.underlay
	assert_eq(underlay.color, Color8(0x0c, 0x3a, 0x10), "source renderer background 0x0c3a10 inside the viewport")
	assert_eq(underlay.size, Vector2(main.viewport_controller.logical_size), "covers the logical viewport")
	assert_true((underlay.get_parent() as CanvasLayer).layer < 0, "below the world")
	assert_eq(ProjectSettings.get_setting("rendering/environment/defaults/default_clear_color"), Color(0, 0, 0, 1), "black outer letterbox")
	var view := Rect2(main.viewport_controller.container.position, main.viewport_controller.container.size)
	assert_true(view.size.x < 800, "wide window pillarboxed (black bars outside the viewport)")


## The same input gives the same logic at 30/60/90/120 rendered FPS (60 Hz physics, interpolation
## only in presentation); test hooks are off in the shipped scene defaults. CORE-002 in full. The interpolation-reset assertions (spawn, teleport, camera snap) are part
## of DOG-008a's combined evidence: the restart reset is test_P_DOG_008a_main_restart_…, the
## rendered 30/60/90/120 FPS presentation is the architect-accepted tools/interpolation_probe.gd
## run under a real renderer, and stage change is DOG-008b (M5).
func test_CORE_002_logic_independent_of_render_rate() -> void:
	assert_eq([Engine.physics_ticks_per_second, ProjectSettings.get_setting("physics/common/physics_ticks_per_second")], [60, 60], "60 Hz physics")
	# Reference: 150 manual ticks.
	var ref: Array = []
	scene = GZ.instantiate()
	scene.show_briefing = false
	scene.manual_ticks = true
	tree.root.add_child(scene)
	for t in 150:
		InputService.inject_move(0.6, -0.4, t % 50 < 20)
		InputService.update(DT)
		scene.tick(DT)
		ref.append([scene.world.player.gx, scene.world.player.gy, scene.rules.stats["time"]])
	tree.root.remove_child(scene)
	scene.free()
	InputService.auto_update = true
	for fps in [30, 60, 90, 120]:
		Engine.max_fps = fps
		scene = GZ.instantiate()
		scene.show_briefing = false
		tree.root.add_child(scene)
		var frames := 0
		var t0 := Time.get_ticks_usec()
		var samples: Array = []
		while scene.ticks < 120 and frames < 2000:
			InputService.inject_move(0.6, -0.4, scene.ticks % 50 < 20)
			await tree.process_frame
			frames += 1
			if scene.ticks > 0:
				samples.append([scene.ticks, scene.world.player.gx, scene.world.player.gy, scene.rules.stats["time"]])
		var seconds := (Time.get_ticks_usec() - t0) / 1e6
		var mismatches := 0
		for sm: Array in samples:
			var e: Array = ref[sm[0] - 1]
			if sm[1] != e[0] or sm[2] != e[1] or sm[3] != e[2]:
				mismatches += 1
		assert_eq(mismatches, 0, "%d fps: logic identical to the manual 60 Hz reference at every sampled tick" % fps)
		var last: Array = samples[samples.size() - 1]
		assert_near(last[3], last[0] / 60.0, 1e-9, "%d fps: game time = ticks / 60" % fps)
		var tick_rate: float = scene.ticks / seconds
		assert_true(tick_rate > 45.0 and tick_rate < 75.0, "%d fps: ~60 physics ticks per second (%.1f)" % [fps, tick_rate])
		print("       %3d fps cap: %d frames for %d ticks in %.2f s (%.1f frames/s, %.1f ticks/s)" % [fps, frames, scene.ticks, seconds, frames / seconds, tick_rate])
		# Interpolation resets: spawn, teleport and camera snap.
		var dog: PlayableDog = scene.world.player
		var resets := dog.interpolation_resets
		assert_true(resets >= 1, "spawn reset the dog's interpolation")
		dog.set_grid_position(dog.gx + 2.0, dog.gy)
		assert_eq(dog.interpolation_resets, resets + 1, "teleport resets interpolation")
		var cam_resets: int = scene.world.camera_rig.interpolation_resets
		scene.world.snap_camera()
		assert_eq(scene.world.camera_rig.interpolation_resets, cam_resets + 1, "camera snap resets interpolation")
		tree.root.remove_child(scene)
		scene.free()
	Engine.max_fps = 0
	InputService.auto_update = false
	# Test hooks do not leak into the shipped defaults.
	var probe: GreenZoneScene = GZ.instantiate()
	assert_eq([probe.manual_ticks, probe.show_briefing], [false, true], "scene ships with real ticks and the briefing")
	probe.free()
	var fresh: Node = load("res://autoload/input_service.gd").new()
	assert_eq(fresh.auto_update, true, "InputService updates itself by default")
	fresh.free()
	InputService.clear_injection()
	InputService.update(DT)
	assert_eq([InputService.move_x, InputService.move_y], [0.0, 0.0], "no injected movement after clearing")


## Observation only: records each physics-interpolation reset that reaches its parent
## (Node.reset_physics_interpolation() propagates NOTIFICATION_RESET_PHYSICS_INTERPOLATION to the
## children) with the process frame, the parent's position and, for a CameraRig, its view size.
class ResetSpy extends Node:
	var resets: Array = []

	func _notification(what: int) -> void:
		if what != NOTIFICATION_RESET_PHYSICS_INTERPOLATION:
			return
		var p := get_parent() as Node2D
		var rec := {"frame": Engine.get_process_frames(), "position": p.position}
		if p is CameraRig:
			rec["view"] = Vector2((p as CameraRig).model.view_w, (p as CameraRig).model.view_h)
		resets.append(rec)


func _key(code: Key, pressed: bool) -> void:
	var e := InputEventKey.new()
	e.keycode = code
	e.physical_keycode = code
	e.pressed = pressed
	Input.parse_input_event(e)


## Presses a key, releases it after the frame that delivers it (key events are buffered until the
## next frame) and returns once that frame's _process callbacks have read it.
func _tap_key(code: Key) -> void:
	await tree.process_frame
	_key(code, true)
	await tree.process_frame
	_key(code, false)
	await tree.process_frame


func _frames_until(cond: Callable, max_frames: int) -> bool:
	for k in max_frames:
		if cond.call():
			return true
		await tree.process_frame
	return cond.call()


static func _nodes_of(node: Node, type: Script) -> Array:
	var out: Array = []
	if is_instance_of(node, type):
		out.append(node)
	for c in node.get_children():
		out.append_array(_nodes_of(c, type))
	return out


## DOG-008a restart clause, through the real flow only (partial case: the spawn, teleport and
## camera-snap resets and the test-hook defaults are test_CORE_002; the rendered 30/60/90/120 FPS
## presentation and teleport clauses are the architect-accepted tools/interpolation_probe.gd runs).
## Main starts the Green Zone; Enter closes the briefing; the dog walks on InputService movement in
## real 60 Hz physics ticks (interpolation history for the dog and the camera) and pees (Space);
## Esc opens the pause menu; Down and Enter choose RESTART, whose restart_requested reaches
## Main.start_green_zone (deferred scene replacement). The old scene, dog, camera and pause menu
## are freed; the replacement dog starts at the canonical spawn; the replacement dog and camera
## reset physics interpolation at the spawn view in the frame they enter the tree, before that frame
## is drawn, no reset keeps the old run's position, and the dog stays on the spawn pixel; settings
## persist while the run state starts over.
func test_P_DOG_008a_main_restart_resets_interpolation_and_run_state() -> void:
	AppState.update_settings({"muted": false, "volume": 0.35, "textSpeed": "fast", "lives": 5,
		"controls": {"swipeUp": "sword", "swipeDown": "shield", "doubleTap": "bark", "run": "toggle", "switcher": false, "hand": "left"}})
	var settings := SaveService.get_settings()
	assert_eq([settings["volume"], settings["lives"], settings["controls"]["hand"], settings["controls"]["run"]], [0.35, 5, "left", "toggle"], "non-default settings stored")
	var canon := GreenZoneLevel.load_model(GreenZoneLevel.definition())
	var s := IsoGrid.grid_to_screen_xy(canon.start.x, canon.start.y)
	var spawn_px := Vector2(JsMath.round(s[0]), JsMath.round(s[1]))
	InputService.auto_update = true
	tree.root.size = Vector2i(432, 864)
	main = MAIN.instantiate()
	tree.root.add_child(main)
	await tree.process_frame
	var gz: GreenZoneScene = main.current_scene
	assert_eq([gz.manual_ticks, gz.show_briefing], [false, true], "Main runs the shipped scene: real ticks, briefing first")
	var briefing: OverlayPanel = gz._overlay
	assert_true(briefing is BriefingOverlay, "briefing shown")
	await _frames_until(func() -> bool: return briefing.time > 0.6, 5000)
	await _tap_key(KEY_ENTER)
	if not assert_true(await _frames_until(func() -> bool: return gz.active, 300), "Enter closed the briefing"):
		return
	var old_dog := gz.world.player
	var old_rig := gz.world.camera_rig
	assert_eq(old_dog.position, spawn_px, "the first run starts at the canonical spawn")
	var cam0 := old_rig.position
	# Walk, pee and walk on, in real physics ticks.
	InputService.inject_move(0.8, -0.3)
	await _frames_until(func() -> bool: return gz.ticks >= 60, 20000)
	InputService.clear_injection()
	await _tap_key(KEY_SPACE)
	var t1 := gz.ticks
	await _frames_until(func() -> bool: return gz.ticks >= t1 + 60, 20000)
	InputService.inject_move(0.8, -0.3)
	await _frames_until(func() -> bool: return gz.ticks >= t1 + 150, 20000)
	InputService.clear_injection()
	var old_pos := old_dog.position
	var old_cam := old_rig.position
	assert_true(old_pos.distance_to(spawn_px) > 24.0, "the dog walked away from the spawn (%s -> %s)" % [spawn_px, old_pos])
	assert_true(old_cam.distance_to(cam0) > 8.0, "the camera followed (%s -> %s)" % [cam0, old_cam])
	assert_true(old_dog.is_physics_interpolated_and_enabled() and old_rig.camera.is_physics_interpolated_and_enabled(), "dog and camera physics-interpolated")
	var old_stats: Dictionary = gz.rules.stats.duplicate()
	assert_true(old_stats["time"] > 2.0 and old_stats["pees"] >= 1, "run state accumulated (time %.2f s, pees %d)" % [old_stats["time"], old_stats["pees"]])
	assert_true(gz.rules.bladder.charges < gz.rules.bladder.max_charges, "a bladder charge spent")
	# Esc opens the pause menu; Down + Enter choose RESTART.
	await _tap_key(KEY_ESCAPE)
	if not assert_true(await _frames_until(func() -> bool: return gz.paused, 300), "Esc opened the pause menu"):
		return
	var pause: PauseOverlay = gz._overlay
	await _frames_until(func() -> bool: return pause.time > 0.4, 5000)
	await _tap_key(KEY_DOWN)
	assert_eq(pause.items[pause.selected]["label"], "RESTART", "Down selects RESTART")
	# Observe the replacement's dog and camera from the moment they enter the tree (before _ready).
	var spies := {}
	var on_added := func(n: Node) -> void:
		if (n is PlayableDog or n is CameraRig) and not spies.has(n):
			var spy := ResetSpy.new()
			n.add_child(spy)
			spies[n] = {"spy": spy, "entered": Engine.get_process_frames()}
	tree.node_added.connect(on_added)
	var old_id := gz.get_instance_id()
	await _tap_key(KEY_ENTER)
	var replaced := await _frames_until(func() -> bool: return main.current_scene.get_instance_id() != old_id, 300)
	tree.node_added.disconnect(on_added)
	if not assert_true(replaced, "RESTART replaced the scene (restart_requested -> Main.start_green_zone)"):
		return
	var fresh: GreenZoneScene = main.current_scene
	var dog: PlayableDog = fresh.world.player
	var rig: CameraRig = fresh.world.camera_rig
	await tree.process_frame
	# The old scene, dog, camera and pause menu are gone; one scene, dog and camera remain.
	assert_false(is_instance_valid(gz) or is_instance_valid(old_dog) or is_instance_valid(old_rig) or is_instance_valid(pause), "old scene, dog, camera and pause menu freed")
	assert_eq(main.scene_host.get_children().size(), 1, "one scene in the host")
	assert_eq(_nodes_of(tree.root, PlayableDog), [dog], "one PlayableDog in the tree")
	assert_eq(_nodes_of(tree.root, CameraRig), [rig], "one CameraRig in the tree")
	assert_eq(main.game_viewport.get_camera_2d(), rig.camera, "the replacement camera is current")
	assert_true(fresh._overlay is BriefingOverlay and main.overlay_host.get_children().size() == 1, "only the new briefing overlay")
	# The replacement starts at the canonical spawn, at rest.
	assert_eq([dog.gx, dog.gy], [canon.start.x, canon.start.y], "replacement at the canonical spawn")
	assert_eq([dog.position, dog.vx, dog.vy, dog.state], [spawn_px, 0.0, 0.0, "free"], "at rest on the spawn pixel")
	# Interpolation reset at the spawn view, in the entry frame (before its draw), never at the old position.
	assert_true(dog.is_physics_interpolated_and_enabled() and rig.camera.is_physics_interpolated_and_enabled(), "replacement dog and camera physics-interpolated")
	assert_true(dog.interpolation_resets >= 2 and rig.interpolation_resets >= 1, "runtime reset counters (dog %d, camera %d)" % [dog.interpolation_resets, rig.interpolation_resets])
	var bounds := fresh.world.walkable_bounds(4)
	for pair: Array in [["dog", dog], ["camera", rig]]:
		var rec: Dictionary = spies.get(pair[1], {})
		if not assert_false(rec.is_empty(), "%s observed from its tree entry" % pair[0]):
			continue
		var resets: Array = (rec["spy"] as ResetSpy).resets
		var entry: Array = resets.filter(func(r: Dictionary) -> bool: return r["frame"] == rec["entered"])
		if not assert_true(entry.size() >= 1, "%s: interpolation reset in its entry frame %d (%s)" % [pair[0], rec["entered"], resets]):
			continue
		var last: Dictionary = entry[entry.size() - 1]
		print("       %s: entered frame %d, resets %s" % [pair[0], rec["entered"], resets])
		var expected := spawn_px
		if pair[1] is CameraRig:
			var view: Vector2 = last["view"]
			var cm := CameraModel.new()
			cm.view_w = view.x
			cm.view_h = view.y
			cm.set_bounds(bounds)
			cm.snap_to(s[0], s[1] - fresh.world.camera_lift)
			expected = cm.view_origin() + view / 2.0
		assert_eq(last["position"], expected, "%s: last entry-frame reset at the spawn view" % pair[0])
		var old_here := old_pos if pair[1] is PlayableDog else old_cam
		assert_true(resets.all(func(r: Dictionary) -> bool: return r["position"] != old_here), "%s: no reset at the old run's position %s" % [pair[0], old_here])
	assert_true(old_cam.distance_to(rig.position) > 8.0, "camera not at the old view (%s vs %s)" % [rig.position, old_cam])
	# Under the briefing the dog stays on the spawn pixel (no motion after the reset).
	await _frames_until(func() -> bool: return fresh.ticks >= 10, 20000)
	assert_eq([dog.position, fresh.active], [spawn_px, false], "still on the spawn pixel under the briefing")
	# Run state starts over; settings persist.
	assert_eq(fresh.rules.stats, ScoringRules.new_stats(5), "fresh run stats (lives from the settings)")
	assert_eq(fresh.rules.treats.size(), 30, "all 30 treats back")
	assert_eq([fresh.rules.state, fresh.paused, fresh.world.process_mode], ["playing", false, Node.PROCESS_MODE_INHERIT], "playing state, not paused")
	assert_eq(fresh.rules.bladder.charges, fresh.rules.bladder.max_charges, "bladder full again")
	assert_eq([fresh.rules.hunger.value, dog.energy.value], [NeedsSystem.Hunger.new().value, NeedsSystem.Energy.new().value], "hunger and energy at their start values")
	assert_eq(fresh.world.map.health(), canon.health(), "fresh map (no pollution from the old run)")
	assert_eq(AudioService.current_track, &"intro", "briefing music again")
	assert_eq(SaveService.get_settings(), settings, "settings unchanged in storage")
	assert_eq(AppState.settings, settings, "AppState settings unchanged")
	assert_eq([InputService.left_handed, InputService.run_toggle, AudioService.volume], [true, true, 0.35], "settings still applied")
	assert_eq(dog.speed_mul, LivesRules.lives_speed(5), "the lives setting drives the new run")
	assert_eq(dog.profile, load(AppState.PROFILES[AppState.selected_profile]), "same selected profile")
	InputService.auto_update = false
