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
	if _mode == "shell":
		await _shell()
		return
	if _mode == "story":
		await _story()
		return
	if _mode == "m6":
		await _m6()
		return
	if _mode == "m7":
		await _m7()
		return
	if _mode == "run":
		await _full_run()
		return
	if _mode == "diagnostic":
		await _diagnostic()
		return
	_main = load("res://main/main.tscn").instantiate()
	_main.set("start_target", "walk")
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
	_main.set("start_target", "walk")
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
		# M3 prototype shots: the full HUD in play, a cat or ball near the dog, Bagnaskiz under attack.
		var dog = scene.world.player
		if frame == 240 and not shots.has("hud"):
			shots["hud"] = true
			await _shot("20_green_zone_full_hud")
		if not shots.has("critter"):
			for c in scene.threats.cats + scene.threats.balls:
				if absf(c.gx - dog.gx) + absf(c.gy - dog.gy) < 4.0:
					shots["critter"] = true
					await _shot("21_cat_or_ball")
					break
		var pug = scene.threats.pug
		if pug != null and pug.is_active() and scene.threats.director.elapsed > 1.2 and not shots.has("attack"):
			shots["attack"] = true
			await _shot("22_attack_bagnaskiz")
		if not shots.has("occlusion"):
			for n in scene.world.object_layer.get_children():
				if "map_prop" in n and n.visible and n.iso.fadeable and n.iso.fade < 0.6:
					shots["occlusion"] = true
					await _shot("12_occlusion_fade")
					break
		if scene.result.get("state", "") != "" :
			await _frames(45)
			if scene.result["state"] == "complete":
				# M3: the Supervillained snap first, then the result card.
				await _shot("23_supervillained")
				for k in 400:
					if scene._overlay != null and String(scene._overlay.get_script().resource_path).ends_with("level_end_overlay.gd"):
						break
					await process_frame
			await _frames(30)
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
	_main.set("start_target", "walk")
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


## M4 shell at the minimum, target and maximum logical widths (windows 384, 432 and 540 px wide at
## 2x): the title, the COUCH card (a campaign after the walk, with a Green Zone best), the GLOSSARY
## card with its ring drawn; OPTIONS, CONTROLS and the level list at the target width. The save is
## in memory (a --script tool never touches a real save).
func _shell() -> void:
	var save := root.get_node("SaveService")
	var camp: Dictionary = save.call("get_campaign")
	camp["completed"] = ["1.0"]
	camp["coins"] = 25
	camp["playTime"] = 75.5
	save.call("save_campaign", camp, 1795608000000)
	save.call("save_record", "level1", {"score": 6360, "stars": 3.5, "time": 60.7})
	for win: Vector2i in [Vector2i(384, 768), Vector2i(432, 864), Vector2i(540, 1080)]:
		root.size = win
		await _frames(5)
		_main = load("res://main/main.tscn").instantiate()
		root.add_child(_main)
		await _frames(90)
		var w: int = _main.call("logical_size").x
		await _shot("30_title_w%d" % w)
		_main.call("open_couch")
		await _frames(30)
		await _shot("31_couch_w%d" % w)
		_main.call("clear_overlays")
		_main.call("open_glossary")
		await _frames(80)
		await _shot("32_glossary_w%d" % w)
		_main.call("clear_overlays")
		# The save-error card as a failed CONTINUE shows it (TRY AGAIN, TITLE, BACK).
		_main.call("show_save_error", "continue", "rename_failed", func() -> void: pass, [{"label": "TITLE", "color": Color("#ff6bd6"), "action": func() -> void: pass}])
		await _frames(30)
		await _shot("36_save_error_w%d" % w)
		_main.call("clear_overlays")
		if w == 216:
			_main.call("open_options")
			await _frames(20)
			await _shot("33_options_w216")
			var o = _main.call("top_overlay")
			o.call("activate", 3)
			await _frames(20)
			await _shot("34_controls_w216")
			_main.call("clear_overlays")
			_main.call("open_levels")
			await _frames(20)
			await _shot("35_levels_w216")
			_main.call("clear_overlays")
		root.remove_child(_main)
		_main.free()
	root.get_node("AudioService").stop_all()
	quit(0)


# --- M5R story (Level 1) ------------------------------------------------------------------------

var _story_scene: Node = null
var _driver: RefCounted = null


## Plays `id` through Main from `state`, ticking the story scene by hand with the real-input driver
## (tests/automation/story_driver.gd) under `policy`; the frames are drawn as it goes.
func _start_story(id: String, state: Dictionary, policy: Dictionary = {}, gate: String = "bark") -> void:
	var save := root.get_node("SaveService")
	save.call("save_campaign", state, 1795608000000)
	_main.call("clear_overlays")
	_main.call("start_story", id)
	await _frames(2)
	_story_scene = _main.get("current_scene")
	_story_scene.set("manual_ticks", true)
	root.get_node("InputService").set("auto_update", false)
	_driver = load("res://tests/automation/story_driver.gd").new(_story_scene, policy, gate, false)


## Ticks until `cond` holds (one logic tick per drawn frame), then draws a few frames.
func _story_until(cond: Callable, limit: int = 60 * 90) -> void:
	var input := root.get_node("InputService")
	for k in limit:
		if cond.call():
			break
		_driver.call("drive", 1.0 / 60.0)
		input.call("update", 1.0 / 60.0)
		_story_scene.call("tick", 1.0 / 60.0)
		await process_frame
	await _frames(2)


func _current_id() -> String:
	var step: Variant = _story_scene.get("runner").get("current")
	return String((step as Resource).get("id")) if step != null else ""


## Level 1 at the target width (432 x 864 window, logical 216): the scene card, the bucket's visor,
## a dialogue line, the lecture while following the Professor, Jack's gate with the heads up, the
## toll choice, the cut-off, Santina's second ask, the rag carried, the sleep card, the Professor's
## aside and the explicit Level 2 boundary. The save is in memory.
func _story() -> void:
	root.size = Vector2i(432, 864)
	await _frames(5)
	_main = load("res://main/main.tscn").instantiate()
	root.add_child(_main)
	await _frames(30)
	var campaign := func(done: Array) -> Dictionary:
		var st: Dictionary = load("res://campaign/campaign_schema.gd").call("new_campaign")
		st["completed"] = ["1.0"] + done
		st["coins"] = 12
		return st
	_main.call("show_story_card", "1.1")
	await _frames(40)
	await _shot("40_story_card_1_1")
	await _start_story("1.1", campaign.call([]))
	await _story_until(func() -> bool: return _current_id() == "s06")
	for k in 80:
		root.get_node("InputService").call("inject_move", 0.0, 0.0)
		root.get_node("InputService").call("update", 1.0 / 60.0)
		_story_scene.call("tick", 1.0 / 60.0)
		await process_frame
	await _shot("41_1_1_bucket_visor_down")
	await _story_until(func() -> bool: return _current_id() == "s12")
	await _story_until(func() -> bool: return not _story_scene.get("hud").get("typing"), 120)
	await _shot("42_1_1_confusione_dialogue")
	await _start_story("1.2", campaign.call(["1.1"]))
	await _story_until(func() -> bool: return _current_id() == "s03")
	await _story_until(func() -> bool: return int(_story_scene.get("runner").get("st").get("leg", 0)) >= 2)
	await _shot("43_1_2_following_the_lecture")
	await _story_until(func() -> bool: return _story_scene.get("actors").has("h1"))
	await _frames(10)
	await _shot("44_1_2_jacks_gate_heads_up")
	await _start_story("1.3", campaign.call(["1.1", "1.2"]), {"s16": "paw"})
	await _story_until(func() -> bool: return _current_id() == "s16" and String(_story_scene.get("runner").get("st").get("phase", "")) == "choosing")
	await _shot("45_1_3_the_toll_choice")
	await _story_until(func() -> bool: return _current_id() == "s20")
	for k in 150:
		root.get_node("InputService").call("inject_move", 0.894, 0.447)
		root.get_node("InputService").call("update", 1.0 / 60.0)
		_story_scene.call("tick", 1.0 / 60.0)
		await process_frame
		if int(_story_scene.get("ctx").get("metrics").get("cuts", 0)) >= 1 and k > 100:
			break
	await _shot("46_1_3_jack_cuts_him_off")
	await _start_story("1.4", campaign.call(["1.1", "1.2", "1.3"]))
	await _story_until(func() -> bool: return _current_id() == "s06" and (_story_scene.get("ctx").get("choices_taken").get("s06", []) as Array).size() == 1 and String(_story_scene.get("runner").get("st").get("phase", "")) == "choosing")
	await _shot("47_1_4_santina_asks_again")
	await _start_story("1.5", campaign.call(["1.1", "1.2", "1.3", "1.4"]), {"s08": "one"})
	await _story_until(func() -> bool: return _current_id() == "s03")
	await _story_until(func() -> bool: return _story_scene.get("world").get("player").get("gx") < 15.0)
	await _shot("48_1_5_carrying_the_rag")
	await _story_until(func() -> bool: return _current_id() == "s19")
	await _frames(20)
	await _shot("49_1_5_the_sleep_boundary")
	_main.call("clear_overlays")
	_main.call("_professor_aside", 1)
	await _frames(40)
	await _shot("50_professor_aside_level_1")
	_main.call("show_boundary", "2.1")
	await _frames(40)
	await _shot("51_level_2_not_in_this_build")
	root.get_node("InputService").set("auto_update", true)
	root.get_node("AudioService").call("stop_all")
	quit(0)


## M6 (Levels 2–4), representative captures at the target width: one per level (2.1's card, the
## marvels of 3.1, the parade of 4.1) and one per major mechanic (the receding gate and helmet, the
## vow in a lull, the bark-only fight, sparring with the shield and the wind-up ring, stealth with
## the guard's cone, the Meraviglia book, the skiff), and the 5.1 boundary after Level 4. Played by
## the real-input driver from the campaign each scene is entered with. The save is in memory.
func _m6() -> void:
	root.size = Vector2i(432, 864)
	await _frames(5)
	_main = load("res://main/main.tscn").instantiate()
	root.add_child(_main)
	await _frames(30)
	var order := ["1.0", "1.1", "1.2", "1.3", "1.4", "1.5", "2.1", "2.2", "2.3", "3.1", "3.2", "3.3", "3.4", "4.1", "4.2", "4.3"]
	var gains := {"1.5": ["cross"], "2.2": ["sermon"], "2.3": ["knight"]}
	var campaign := func(id: String) -> Dictionary:
		var st: Dictionary = load("res://campaign/campaign_schema.gd").call("new_campaign")
		st["coins"] = 12
		for k: String in order:
			if k == id:
				break
			st["completed"].append(k)
			for a: String in gains.get(k, []):
				st["abilities"].append(a)
		if order.find(id) > order.find("3.1"):
			st["book"]["marvels"] = ["THE HORSE TRANSPORTS", "THE GALLEYS", "THE GREAT SHIPS"]
			st["book"]["items"] = ["MERAVIGLIA, THE BOOK OF MARVELS"]
		return st
	var input := root.get_node("InputService")
	var still := func(frames: int) -> void:
		for k in frames:
			input.call("inject_move", 0.0, 0.0)
			input.call("update", 1.0 / 60.0)
			_story_scene.call("tick", 1.0 / 60.0)
			await process_frame
	_main.call("show_story_card", "2.1")
	await _frames(40)
	await _shot("60_story_card_2_1")
	await _start_story("2.1", campaign.call("2.1"))
	await _story_until(func() -> bool: return _current_id() == "s06")
	await _story_until(func() -> bool: return int(_story_scene.get("runner").get("st").get("receded", 0)) >= 1)
	await still.call(70)
	await _shot("61_2_1_receding_gate_and_helmet")
	await _start_story("2.2", campaign.call("2.2"), {"s13": "glad"})
	await _story_until(func() -> bool: return _current_id() == "s04" and int(_story_scene.get("runner").get("st").get("good", 0)) >= 1 and String(_story_scene.get("hud").get("mode_label")) != "")
	await _shot("62_2_2_vow_in_the_lull")
	await _start_story("2.3", campaign.call("2.3"))
	await _story_until(func() -> bool: return _current_id() == "s10" and _story_scene.get("ctx").get("combat") != null and (_story_scene.get("ctx").get("combat").get("events") as Array).has("bark_hit"))
	await _frames(4)
	await _shot("63_2_3_bark_only_fight")
	await _story_until(func() -> bool:
		if _current_id() != "s29":
			return false
		for a: Node in (_story_scene.get("actors") as Dictionary).values():
			var f: Variant = a.get("foe")
			if f != null and float(f.get("windup")) > 0.2:
				return bool(_story_scene.get("ctx").get("combat").get("guarding"))
		return false, 60 * 120)
	await _shot("64_2_3_sparring_shield_and_ring")
	await _start_story("3.1", campaign.call("3.1"))
	await _story_until(func() -> bool: return _current_id() == "s04" and (_story_scene.get("runner").get("st").get("picked", []) as Array).size() >= 1)
	await _frames(10)
	await _shot("65_3_1_marvels_and_meraviglia")
	await _start_story("3.4", campaign.call("3.4"))
	await _story_until(func() -> bool:
		if _current_id() != "s11":
			return false
		var g: Node = (_story_scene.get("actors") as Dictionary).get("g1")
		var p: Node = _story_scene.get("world").get("player")
		return g != null and Vector2(float(g.get("gx")), float(g.get("gy"))).distance_to(Vector2(float(p.get("gx")), float(p.get("gy")))) < 4.5, 60 * 60)
	await _shot("66_3_4_stealth_guard_cone_and_bushes")
	_main.call("clear_overlays")
	_main.call("open_book")
	await _frames(30)
	await _shot("67_meraviglia_book")
	_main.call("clear_overlays")
	await _start_story("4.1", campaign.call("4.1"))
	await _story_until(func() -> bool: return _current_id() == "s07" and float(_story_scene.get("runner").get("st").get("game").get("time")) > 2.2)
	await _shot("68_4_1_parade_rhythm")
	await _start_story("4.2", campaign.call("4.2"))
	await _story_until(func() -> bool: return _current_id() == "s03" and float(_story_scene.get("runner").get("st").get("game").get("progress")) > 0.4)
	await _shot("69_4_2_easing_the_skiff")
	_main.call("clear_overlays")
	_main.call("show_boundary", "5.1")
	await _frames(40)
	await _shot("70_level_5_not_in_this_build")
	root.get_node("InputService").set("auto_update", true)
	root.get_node("AudioService").call("stop_all")
	quit(0)


## M7 (Levels 5–8 and the ending), representative captures at the target width, one per new
## mechanic: 5.2's ladder, 5.3's brawl, 5.4's letter, 6.2's rumour, 7.1's tug,
## 7.2's hold by the banner, 7.3's pace beside Pierre, 7.5's fire, 7.8's oath in a lull, 8.1's
## scrambled legs, 8.2's drawing choice, 8.3's friends falling in, and THE KNIGHT. Played by the
## real-input driver from a campaign with every scene before it completed. The save is in memory.
func _m7() -> void:
	root.size = Vector2i(432, 864)
	await _frames(5)
	_main = load("res://main/main.tscn").instantiate()
	root.add_child(_main)
	await _frames(30)
	var catalog: Resource = load("res://data/campaign/story_catalog.tres")
	var order: Array = Array(catalog.call("ids"))
	var campaign := func(id: String) -> Dictionary:
		var st: Dictionary = load("res://campaign/campaign_schema.gd").call("new_campaign")
		st["coins"] = 12
		st["abilities"] = ["cross", "sermon", "knight"]
		st["book"]["marvels"] = ["THE HORSE TRANSPORTS", "THE GALLEYS", "THE GREAT SHIPS", "THE FLEET LEAVING VENICE", "THE CARVED COLUMN", "THE HIPPODROME"]
		st["book"]["items"] = ["MERAVIGLIA, THE BOOK OF MARVELS"]
		st["flags"] = {"comradeship": true, "clothRoute": true, "oath": "enforced", "lamp": "declared", "letter": "named", "vanguard": true}
		for k: String in order:
			if k == id:
				break
			st["completed"].append(k)
		return st
	var st_of := func() -> Dictionary: return _story_scene.get("runner").get("st")
	var game_of := func() -> Object: return (st_of.call() as Dictionary).get("game")
	await _start_story("5.2", campaign.call("5.2"))
	await _story_until(func() -> bool: return _current_id() == "s03" and game_of.call() != null and float(game_of.call().get("rung")) >= 6.0)
	await _shot("71_5_2_ladders")
	await _start_story("5.3", campaign.call("5.3"))
	await _story_until(func() -> bool: return _current_id() == "s11" and float((st_of.call() as Dictionary).get("t", 0.0)) > 2.5, 60 * 120)
	await _shot("72_5_3_through_the_brawl")
	await _start_story("5.4", campaign.call("5.4"))
	await _story_until(func() -> bool: return _current_id() == "s03" and game_of.call() != null and (game_of.call().get("picks") as Array).size() >= 2)
	await _shot("73_5_4_the_letter")
	await _start_story("6.2", campaign.call("6.2"))
	await _story_until(func() -> bool: return _current_id() == "s04" and game_of.call() != null and (game_of.call().get("placed") as Array).size() >= 2, 60 * 120)
	await _shot("74_6_2_the_rumour")
	await _start_story("7.1", campaign.call("7.1"))
	await _story_until(func() -> bool: return _current_id() == "s08" and game_of.call() != null and float(game_of.call().get("pos")) > 0.45, 60 * 120)
	await _shot("75_7_1_the_tug_along_the_walls")
	await _start_story("7.2", campaign.call("7.2"))
	await _story_until(func() -> bool: return _current_id() == "s11" and float((st_of.call() as Dictionary).get("t", 0.0)) > 6.0, 60 * 120)
	await _shot("76_7_2_hold_by_the_banner")
	await _start_story("7.3", campaign.call("7.3"))
	await _story_until(func() -> bool: return _current_id() == "s11" and bool((st_of.call() as Dictionary).get("rejoined", false)), 60 * 120)
	await _shot("77_7_3_level_with_pierre")
	await _start_story("7.5", campaign.call("7.5"))
	await _story_until(func() -> bool: return _current_id() == "s13" and bool((st_of.call() as Dictionary).get("fire_on", false)), 60 * 120)
	# He stands at the start (safe) while it spreads, so the flames are in the frame.
	var input := root.get_node("InputService")
	for k in 150:
		input.call("inject_move", 0.0, 0.0)
		input.call("update", 1.0 / 60.0)
		_story_scene.call("tick", 1.0 / 60.0)
		await process_frame
	await _shot("78_7_5_the_fire_walk")
	await _start_story("7.8", campaign.call("7.8"))
	await _story_until(func() -> bool: return _current_id() == "s13" and not bool((st_of.call() as Dictionary).get("talking", true)), 60 * 120)
	await _frames(10)
	await _shot("79_7_8_the_oath_in_a_lull")
	await _start_story("8.1", campaign.call("8.1"))
	await _story_until(func() -> bool: return _current_id() == "s04" and (_story_scene.get("ctx").get("metrics").get("scramble", []) as Array).size() >= 2, 60 * 120)
	await _shot("80_8_1_scrambled_legs")
	await _start_story("8.2", campaign.call("8.2"))
	await _story_until(func() -> bool: return _current_id() == "s11" and String((st_of.call() as Dictionary).get("phase", "")) == "choosing", 60 * 120)
	await _frames(20)
	await _shot("81_8_2_the_drawing_choice")
	await _start_story("8.3", campaign.call("8.3"))
	await _story_until(func() -> bool: return _current_id() == "s08" and float(_story_scene.get("world").get("player").get("gx")) > 8.0, 60 * 120)
	await _shot("82_8_3_friends_fall_in")
	var done: Dictionary = campaign.call("8.4")
	done["completed"].append("8.4")
	# The Knight campaign's end (report 33): its meters, values and marvels.
	done["meters"] = {"commozione": 39.0, "supervillain": 100.0, "grace": 100.0, "standing": 33.0}
	done["book"]["values"] = ["Comradeship", "Physical courage", "Kept oaths", "An honest share", "Resistance"]
	done["book"]["marvels"] = ["THE HORSE TRANSPORTS", "THE GALLEYS", "THE GREAT SHIPS", "THE FLEET LEAVING VENICE", "THE GREAT WALLS", "THE CITY OF ROOFS",
		"THE GOLDEN DOMES", "THE PALACE OF THE LION'S MOUTH", "THE BRONZE HERCULES", "THE CARVED COLUMN", "A LAMP IN A COURTYARD", "THE GREAT CHURCH",
		"THE HIPPODROME", "AN EMPTY PEDESTAL"]
	root.get_node("SaveService").call("save_campaign", done, 1795608000000)
	_main.call("clear_overlays")
	_main.call("show_ending")
	await _frames(40)
	await _shot("83_the_ending_the_knight")
	root.get_node("InputService").set("auto_update", true)
	root.get_node("AudioService").call("stop_all")
	quit(0)
