extends SceneTree
## Deterministic visual capture of the Green Zone slice (TEST_PLAN.md §18). Needs a renderer:
##   xvfb-run -a godot --path godot --rendering-driver opengl3 --script res://tools/capture_suite.gd \
##     -- --out <dir> [--size 432x864]
## Runs the real Main scene and drives it only through InputService (no teleports).

var _out := "res://tests/captures/latest"
var _mode := "tour"
var _main: Node


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	for k in args.size():
		if args[k] == "--out":
			_out = args[k + 1]
		elif args[k] == "--mode":
			_mode = args[k + 1]
		elif args[k] == "--size":
			var p := args[k + 1].split("x")
			root.size = Vector2i(int(p[0]), int(p[1]))
	_run.call_deferred()


func _frames(n: int) -> void:
	for k in n:
		await process_frame


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(_out)
	var path := _out.path_join(name + ".png")
	img.save_png(path)
	print("captured ", path, " ", img.get_size())


func _hold(x: float, y: float, run: bool, frames: int) -> void:
	var input := root.get_node("InputService")
	input.inject_move(x, y, run)
	await _frames(frames)


func _run() -> void:
	if _mode == "run":
		await _full_run()
		return
	if _mode == "diagnostic":
		await _diagnostic()
		return
	_main = load("res://main/main.tscn").instantiate()
	root.add_child(_main)
	var input := root.get_node("InputService")
	await _frames(40)
	await _shot("01_briefing")
	input.trigger(&"confirm")
	await _frames(20)
	await _shot("02_start")
	await _hold(0.0, -0.8, false, 50)
	await _shot("03_walk_north")
	await _hold(0.8, 0.0, false, 40)
	await _shot("04_walk_east")
	await _hold(-0.566, -0.566, true, 45)
	await _shot("05_run_northwest")
	await _hold(0.0, 0.0, false, 30)
	input.trigger(&"pee")
	await _frames(20)
	await _shot("06_pee_clean")
	await _frames(60)
	input.trigger(&"menu")
	await _frames(15)
	await _shot("07_pause")
	input.trigger(&"confirm")
	await _frames(15)
	# Touch path: press the virtual PEE button and drag the floating joystick.
	var scene = _main.current_scene
	var view: Vector2i = _main.logical_size()
	input.clear_injection()
	input.pointer_down(1, Vector2(50, view.y - 120))
	input.pointer_move(1, Vector2(50, view.y - 145))
	await _frames(40)
	await _shot("08_touch_joystick")
	input.pointer_up(1, Vector2(50, view.y - 145))
	print("visible objects: ", scene.world.visible_count, "  dog at ", scene.world.player.gx, ",", scene.world.player.gy)
	quit(0)


## Plays the whole level in real time with the real-input driver and captures key moments.
func _full_run() -> void:
	_main = load("res://main/main.tscn").instantiate()
	root.add_child(_main)
	var input := root.get_node("InputService")
	await _frames(20)
	input.trigger(&"confirm")
	await _frames(5)
	# Untyped on purpose: an entry --script cannot statically reference classes that use autoloads.
	var scene = _main.current_scene
	var driver = load("res://tests/automation/green_zone_driver.gd").new()
	var stepper := func() -> void:
		if scene.active and not scene.paused and scene.rules.state == "playing":
			driver.step(scene)
	physics_frame.connect(stepper)
	var events := {"poop": -1, "clean": -1}
	scene.rules.poop_dropped.connect(func(_p) -> void:
		if events["poop"] < 0:
			events["poop"] = 0)
	scene.rules.poop_cleaned.connect(func(_x: float, _y: float, _s: int) -> void:
		if events["clean"] < 0:
			events["clean"] = 0)
	var shots := {}
	for frame in 60 * 120:
		await process_frame
		if frame % 300 == 0:
			print("frame %d: active=%s paused=%s state=%s time=%.1f dog=%.1f,%.1f poops=%d" % [frame, scene.active, scene.paused, scene.rules.state, scene.rules.stats["time"], scene.world.player.gx, scene.world.player.gy, scene.rules.stats["poops"]])
		for key: String in events:
			if events[key] >= 0:
				events[key] += 1
		if events["poop"] == 25 and not shots.has("poop"):
			shots["poop"] = true
			await _shot("10_poop_dirt")
		if events["clean"] == 20 and not shots.has("clean"):
			shots["clean"] = true
			await _shot("11_pee_cleans_poop")
		if not shots.has("occlusion"):
			for n in scene.world.object_layer.get_children():
				if "map_prop" in n and n.visible and n.iso.fadeable and n.iso.fade < 0.6:
					shots["occlusion"] = true
					await _shot("12_occlusion_fade")
					break
		if scene.result.get("state", "") != "" :
			await _frames(45)
			await _shot("13_level_end_reveal" if scene.result["state"] == "complete" else "13_game_over")
			input.trigger(&"confirm")
			await _frames(30)
			await _shot("14_level_end_final")
			print("result: ", scene.result.get("state"), " total ", scene.result.get("total"), " time ", scene.rules.stats["time"])
			break
	physics_frame.disconnect(stepper)
	input.clear_injection()
	root.get_node("AudioService").stop_all()
	quit(0)


## Deep water, walls (base tile + depth-sorted blocks), story grounds and void through the shared
## IsoWorld inside the real Main viewport: void shows the in-viewport 0x0c3a10 underlay, the
## pillarbox outside the viewport stays black.
const DIAG := [
	"#############",
	"#~~~~~%%%%%%#",
	"#~.........%#",
	"#~.,,_::-*.%#",
	"#~.WW^^++B.%#",
	"#~.....S...%#",
	"#~.WW.....T%#",
	"#~.........%#",
	"#~~~~~%%%%%%#",
	"#############",
]


func _diagnostic() -> void:
	_main = load("res://main/main.tscn").instantiate()
	root.add_child(_main)
	await _frames(5)
	var world = _main.change_scene(load("res://world/world_2d.tscn"))
	var parsed: Dictionary = load("res://world/ascii_map_loader.gd").parse(PackedStringArray(DIAG), ".", false)
	world.setup(load("res://world/world_map_model.gd").new(parsed["level"]), {"forest": true})
	world.camera_rig.set_view_size(Vector2(_main.logical_size()))
	world.snap_camera()
	for k in 30:
		world.end_step(1.0 / 60.0)
		world.render(1.0 / 60.0)
		await process_frame
	await _shot("20_diagnostic_deep_water_walls_story_grounds")
	quit(0)
