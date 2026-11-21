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
## only in presentation); test hooks are off in the shipped scene defaults. CORE-002 in full. The interpolation-reset assertions (spawn, teleport, camera snap) are partial
## DOG-008 evidence: stage change does not exist before M5, and the rendered 30/60/90/120 FPS
## presentation is measured by tools/interpolation_probe.gd under a real renderer.
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
