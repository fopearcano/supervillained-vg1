extends TestCase
## M4 product shell through the real Main: the title and its overlays, options and controls with
## persistence, the Couch and Glossary cards, NEW GAME / CONTINUE, the Green Zone persistence order,
## save recovery notices, replays that change no persistent byte, navigation, queued input and Back.
## The runner isolates the save directory per case.

const MAIN := preload("res://main/main.tscn")
const DT := 1.0 / 60.0
const NOW := 1795608000000

var main: Node
var opened: Array = []
var quits := [0]


func before_each() -> void:
	AppState.clock = func() -> int: return NOW
	opened = []
	quits = [0]


func after_each() -> void:
	if main and is_instance_valid(main):
		main.get_parent().remove_child(main)
		main.free()
	InputService.clear_injection()
	InputService.auto_update = false
	AppState.end_replay()
	AppState.clock = func() -> int: return int(Time.get_unix_time_from_system() * 1000.0)


func _main(start: String = "") -> Node:
	tree.root.size = Vector2i(432, 864)
	main = MAIN.instantiate()
	main.start_target = start
	main.open_url = func(url: String) -> void: opened.append(url)
	main.quit_app = func() -> void: quits[0] += 1
	tree.root.add_child(main)
	await tree.process_frame
	return main


func _frames(n: int) -> void:
	for k in n:
		await tree.process_frame


func _until(cond: Callable, limit: int = 5000) -> bool:
	for k in limit:
		if cond.call():
			return true
		await tree.process_frame
	return cond.call()


func _title() -> TitleScreen:
	return main.current_scene as TitleScreen


func _ready_title() -> TitleScreen:
	var t := _title()
	t.time = 1.0
	return t


func _disk() -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(SaveService.base_dir + "save_v3.json"))
	return parsed if parsed is Dictionary else {}


func _save_bytes() -> PackedByteArray:
	return FileAccess.get_file_as_bytes(SaveService.base_dir + "save_v3.json")


func _gz_step(gz: GreenZoneScene, n: int) -> void:
	for k in n:
		InputService.update(DT)
		AudioService.advance_pending(DT)
		gz.tick(DT)


## Runs the walk to its result card through Main: teleport to the exit, the snap, the card.
func _finish_walk(gz: GreenZoneScene) -> LevelEndOverlay:
	gz.manual_ticks = true
	if gz._overlay is BriefingOverlay:
		gz._close_overlay()
		gz.start_play()
	var m := gz.world.map
	gz.world.player.set_grid_position(m.exit.x + 0.3, m.exit.y + 0.3)
	_gz_step(gz, 72)
	var sv := gz._overlay as SupervillainedOverlay
	if sv:
		sv.step(GameConfig.Supervillained.HOLD + 0.05)
	var end := gz._overlay as LevelEndOverlay
	if end:
		end.skip = true
		end._process(DT)
	return end


func test_SLICE_fresh_launch_reaches_title() -> void:
	await _main()
	assert_true(main.current_scene is TitleScreen, "Main starts at the title")
	var t := _title()
	assert_eq(t.items.map(func(i: Dictionary) -> String: return i["label"]), ["NEW GAME", "CONTINUE", "COUCH", "OPTIONS", "GLOSSARY", "QUIT"], "the six title actions")
	assert_eq(t.selected, 0, "no saved story: NEW GAME preselected")
	assert_eq(AudioService.current_track, &"intro", "intro music")
	assert_eq(main.overlay_host.get_child_count(), 0, "no notice on a fresh save")


## UI-007: the title's actions in the source order and colours; CONTINUE preselected over a saved
## story; each action reaches its screen; SUPERVOID EDITIONS opens the publisher's site; QUIT
## closes the app where it can and shows the Goodbye card where it cannot.
func test_UI_007_title_layout_and_actions() -> void:
	SaveService.save_campaign({"version": 2, "completed": ["1.0"], "meters": {}, "flags": {}, "book": {}, "abilities": [], "coins": 3, "playTime": 10, "savedAt": null, "notice": null}, NOW)
	await _main()
	var t := _ready_title()
	assert_eq(t.items.map(func(i: Dictionary) -> Color: return i["color"]), [PixelText.RED, PixelText.YELLOW, PixelText.ORANGE, PixelText.CYAN, TitleScreen.VIOLET, PixelText.PINK], "source colours")
	assert_eq(t.selected, 1, "saved story: CONTINUE preselected")
	t._layout()
	t.queue_redraw()
	await tree.process_frame
	assert_eq(t.item_rects().size(), 6, "six buttons drawn")
	for pair: Array in [[2, CouchOverlay], [3, OptionsOverlay], [4, GlossaryOverlay]]:
		t.activate(pair[0])
		assert_true(is_instance_of(main.top_overlay(), pair[1]), "action %d opens its screen" % pair[0])
		main.clear_overlays()
	t.on_tap(t.footer_rect.get_center())
	assert_eq(opened, [GameConfig.Title.PUBLISHER_URL], "SUPERVOID EDITIONS opens the publisher")
	t.activate(5)
	assert_eq(quits[0], 1, "QUIT closes the app (desktop/Android)")
	main.can_quit = false
	t.activate(5)
	assert_true(main.top_overlay() is MessageOverlay and (main.top_overlay() as MessageOverlay).heading == "THANKS FOR PLAYING", "Goodbye where an app cannot close")
	(main.top_overlay() as MessageOverlay).time = 1.0
	(main.top_overlay() as MessageOverlay).on_tap(Vector2(10, 10))
	assert_eq(main.overlay_host.get_child_count(), 0, "a tap returns to the title")


## UI-008: the animated portrait plays its converted frames at the title's dog width.
func test_UI_008_title_portrait_animates_at_its_width() -> void:
	await _main()
	var t := _ready_title()
	var p: TitlePortrait = t._portrait
	assert_true(p != null and p.is_playing() and p.animation == &"portrait", "portrait playing")
	assert_near(p.scale.x, t.dog_rect.size.x / float(TitlePortrait.CANONICAL_WIDTH), 1e-6, "fitted to the dog width")
	assert_eq(p.position, t.dog_rect.position, "placed in the portrait slot")
	var f0 := p.frame
	await _until(func() -> bool: return p.frame != f0, 600)
	assert_true(p.frame != f0, "frames advance")
	t.time = 0.2
	t.queue_redraw()
	await tree.process_frame
	assert_false(p.visible, "hidden for the glitchy entrance (0.35 s)")


## UI-009 (partial: the film grain, scratches, vignette and the lettering's glitch filter are
## simplified, M8): the glint crosses one button at a time and never the same one twice in a row;
## the entrance jitter settles by 0.9 s.
func test_P_UI_009_shine_and_entrance() -> void:
	await _main()
	var t := _ready_title()
	var seen: Array = []
	for k in 1800:
		t._animate_shine(DT)
		if t._shine_button >= 0 and (seen.is_empty() or seen.back() != t._shine_button):
			seen.append(t._shine_button)
	assert_true(seen.size() >= 3, "several glints (%s)" % [seen])
	for k in range(1, seen.size()):
		assert_true(seen[k] != seen[k - 1], "never the same button twice in a row")


## UI-010: INSERT BRAIN and LIFE FOR SPEED blink (shown 60 % of each second); the lives counter
## steps on a tap or LEFT/RIGHT from 2 to 9 and back to 2, saves at once and sets the walk's speed.
func test_UI_010_insert_brain_and_lives_counter() -> void:
	await _main()
	var t := _ready_title()
	t.time = 1.2
	assert_true(t.insert_brain_visible(), "on at 0.2 of the cycle")
	t.time = 1.7
	assert_false(t.insert_brain_visible(), "off at 0.7 of the cycle")
	t.time = 1.0
	t.queue_redraw()
	await tree.process_frame
	var seen: Array = []
	for k in 8:
		t.on_tap(t.lives_rect.get_center())
		seen.append(AppState.lives())
	assert_eq(seen, [3, 4, 5, 6, 7, 8, 9, 2], "tap cycles 2..9")
	t.change_lives(-1)
	assert_eq(AppState.lives(), 9, "LEFT goes back")
	assert_eq(int(_disk()["settings"]["lives"]), 9, "saved at once")
	main.start_green_zone(true)
	await tree.process_frame
	assert_eq((main.current_scene as GreenZoneScene).world.player.speed_mul, LivesRules.lives_speed(9), "the walk uses it")


## UI-011: the title block fits short, target and tall screens at the minimum, target and maximum
## logical widths: everything inside, in order, nothing overlapping; the portrait shrinks first.
func test_UI_011_title_fits_short_and_tall_screens() -> void:
	await _main()
	var t := _ready_title()
	for size: Vector2i in [Vector2i(192, 310), Vector2i(192, 457), Vector2i(216, 349), Vector2i(216, 432), Vector2i(216, 514), Vector2i(270, 436), Vector2i(270, 643)]:
		t.resize(size)
		t.queue_redraw()
		await tree.process_frame
		var r := Rect2(Vector2.ZERO, Vector2(size))
		var logo_bottom := roundf(size.y * GameConfig.Title.TOP) + PixelText.CELL_H * t.logo_scale + 10 + 8
		var rows := t.item_rects()
		assert_true(t.dog_rect.position.y >= logo_bottom - 2, "%s: portrait under the title" % size)
		assert_true(rows[0].position.y >= t.dog_rect.end.y, "%s: buttons under the portrait" % size)
		assert_true(t.lives_rect.position.y > rows[5].end.y, "%s: INSERT BRAIN under the buttons" % size)
		assert_true(t.footer_rect.position.y > t.lives_rect.end.y + 8, "%s: the footer last" % size)
		for x: Rect2 in rows + [t.dog_rect, t.lives_rect, t.footer_rect]:
			assert_true(r.encloses(x), "%s: %s inside" % [size, x])
		assert_true(t.dog_rect.size.x <= roundf(size.x * GameConfig.Title.DOG_WIDTH), "%s: portrait width" % size)
		assert_true(T_fits(PixelText.width(TitleScreen.LOGO, t.logo_scale) + 8, size.x), "%s: logo fits" % size)


static func T_fits(w: float, avail: float) -> bool:
	return w <= avail


## UI-012–014: the COUCH card shows, for the source's five fixture campaigns, the next scene or the
## finished story and its ending, scenes per level, meters, book counts, coins, costume, the Green
## Zone best, play time and the last campaign save, exactly as src/campaign/summary.ts computes
## them; it closes with CLOSE, a tap outside, confirm and Back.
func test_UI_012_014_couch_shows_progress_meters_records_and_times() -> void:
	var cf: Dictionary = fixture()["couch"]
	await _main()
	SaveService.save_record("level1", {"score": 1234, "stars": 3.5, "time": 75.0})
	for c: Dictionary in cf["cases"]:
		var s: Dictionary = c["summary"]
		var o := CouchOverlay.new()
		var closed := [0]
		o.setup(c["state"], SaveService.CATALOG, SaveService.get_record("level1"), load("res://data/shell/shell_text.tres"), int(cf["now"]), 0, func() -> void: closed[0] += 1)
		main.push_overlay(o)
		await tree.process_frame
		var lines := o.lines()
		if s["next"] != null:
			assert_true(lines.has("LEVEL %d: %s %s" % [s["next"]["level"], s["next"]["id"], String(s["next"]["title"]).to_upper()]), "%s: next scene" % c["name"])
		else:
			assert_true(lines.has("ENDING: %s" % ("THE KNIGHT" if s["ending"] == "knight" else "THE WITNESS")), "%s: ending" % c["name"])
		assert_true(lines.has("SCENES %d / %d  %d%%" % [s["done"], s["total"], int(round(float(s["done"]) * 100.0 / float(s["total"])))]), "%s: scenes" % c["name"])
		assert_true(lines.has("COMMOZIONE %d" % int(s["meters"]["commozione"])) and lines.has("GRACE %d" % int(s["meters"]["grace"])), "%s: meters" % c["name"])
		assert_true(lines.has("VALUES %d  MARVELS %d" % [s["values"], s["marvels"]]) and lines.has("COINS %d" % s["coins"]), "%s: book and coins" % c["name"])
		assert_true(lines.has("SCORE 1234  STARS 4") and lines.has("TIME 01:15"), "%s: the Green Zone best" % c["name"])
		assert_true(lines.has("PLAY TIME %s" % c["playTime"]) and lines.has("SAVED %s" % c["savedAt"]), "%s: play and save time" % c["name"])
		for v: String in ["COUCH", "CLOSE"]:
			assert_true(o.drawn.has(v), "%s: %s drawn" % [c["name"], v])
		o.time = 1.0
		match c["name"]:
			"fresh":
				o.on_tap(o.close_rect.get_center())
			"walked":
				o.on_tap(Vector2(1, 1))
			"mid":
				InputService.trigger(&"confirm")
				o._process(DT)
			_:
				o.back()
		assert_eq(closed[0], 1, "%s: closed once" % c["name"])
		main.pop_overlay(o)


## UI-015–021: every option and control changes at once, is saved, applies to audio and input, and
## survives a restart (reload from disk): sound, volume, text speed, lives, the three gesture
## bindings, RUN hold/toggle, the switcher and the hand (the touch layout mirrors); DEFAULTS resets
## the controls.
func test_UI_015_021_options_and_controls_persist_and_apply() -> void:
	await _main()
	var t := _ready_title()
	t.activate(3)
	var o := main.top_overlay() as OptionsOverlay
	o.toggle_sound()
	assert_true(AudioService.muted, "SOUND: OFF applied")
	o.cycle_volume()
	assert_eq(AudioService.volume, 1.0, "0.7 -> 1.0")
	o.cycle_volume()
	assert_eq(AudioService.volume, 0.25, "1.0 -> 0.25")
	o.cycle_text_speed()
	assert_eq(AppState.settings["textSpeed"], "fast", "normal -> fast")
	assert_eq(o.items.map(func(i: Dictionary) -> String: return i["label"]).slice(0, 3), ["SOUND: OFF", "VOLUME: 25%", "TEXT: FAST"], "labels refresh")
	o.activate(3)
	var c := main.top_overlay() as ControlsOverlay
	c.cycle("swipeUp")
	c.cycle("swipeDown")
	c.cycle("doubleTap")
	c.activate(3)
	c.activate(4)
	c.activate(5)
	assert_eq(InputService.gesture_bindings, {"swipeUp": "shield", "swipeDown": "switch", "doubleTap": "sword"}, "gestures applied (each one step on)")
	assert_eq([InputService.run_toggle, InputService.switcher_enabled, InputService.left_handed], [true, false, true], "run toggle, switcher off, left hand applied")
	AppState.step_lives(1)
	var expected := AppState.settings.duplicate(true)
	assert_eq(_disk()["settings"], expected, "every change saved")
	# Restart: reload everything from disk.
	SaveService.load_from_disk()
	AppState.reload()
	assert_eq(AppState.settings, expected, "same settings after a restart")
	assert_eq([AudioService.muted, AudioService.volume, InputService.run_toggle, InputService.left_handed, InputService.switcher_enabled], [true, 0.25, true, true, false], "and applied again")
	main.start_green_zone(true)
	await tree.process_frame
	var gz := main.current_scene as GreenZoneScene
	var pee: Vector2 = InputService.buttons[&"pee"]["center"]
	assert_true(pee.x < 108, "left hand: PEE on the left (%s)" % pee)
	main.show_title()
	await tree.process_frame
	_ready_title().activate(3)
	(main.top_overlay() as OptionsOverlay).activate(3)
	(main.top_overlay() as ControlsOverlay).defaults()
	assert_eq(AppState.settings["controls"], SaveService.default_settings()["controls"], "DEFAULTS")
	assert_eq(_disk()["settings"]["controls"], SaveService.default_settings()["controls"], "saved")


## UI-022: the glossary entry (source text), the red ring drawing itself after RING_DELAY over
## RING_TIME, and every close path: CLOSE, a tap outside, confirm, Back.
func test_UI_022_glossary_content_ring_and_close_paths() -> void:
	await _main()
	assert_eq([GlossaryOverlay.HEADWORD, GlossaryOverlay.IPA, GlossaryOverlay.NOUN, GlossaryOverlay.VERB],
		["SUPERVILLAIN,\nSUPERVILLAINED", "/ˈsuːpərvilən/", "A FICTIONAL VILLAIN HAVING EXTRAORDINARY OR SUPERHUMAN POWERS", "TO GROW UP STRONG;\nTO GET CHARACTER"], "source text")
	for path in ["close", "outside", "confirm", "back"]:
		var closed := [0]
		var g := GlossaryOverlay.new()
		g.setup(func() -> void: closed[0] += 1)
		main.push_overlay(g)
		await tree.process_frame
		g.time = 0.3
		assert_eq(g.ring_progress(), 0.0, "no ring before RING_DELAY")
		g.time = GameConfig.Glossary.RING_DELAY + GameConfig.Glossary.RING_TIME / 2.0
		assert_near(g.ring_progress(), 0.5, 1e-9, "half drawn")
		g.time = 2.0
		g.queue_redraw()
		await tree.process_frame
		assert_eq(g.ring_points.size(), 64 + GameConfig.Glossary.RING_OVERSHOOT + 1, "64 steps + overshoot")
		match path:
			"close":
				g.on_tap(g.close_rect.get_center())
			"outside":
				g.on_tap(Vector2(1, 1))
			"confirm":
				InputService.trigger(&"confirm")
				g._process(DT)
			"back":
				g.back()
		g.close()
		assert_eq(closed[0], 1, "%s closes once" % path)
		main.pop_overlay(g)


## NEW GAME: without a saved story it starts 1.0; over one it asks (NO preselected; NO and Back
## keep the story); YES creates the exact default campaign, saved, and starts the walk.
func test_SLICE_new_game_confirmation_and_exact_default() -> void:
	var st := CampaignSchema.new_campaign()
	st["completed"] = ["1.0"]
	st["coins"] = 40
	SaveService.save_campaign(st, NOW - 1000)
	await _main()
	var t := _ready_title()
	t.activate(0)
	var c := main.top_overlay() as ConfirmOverlay
	assert_true(c != null and c.selected == 1 and c.heading == "NEW GAME?", "asked, NO preselected")
	c.activate(1)
	assert_eq([main.overlay_host.get_child_count(), SaveService.get_campaign()["coins"]], [0, 40], "NO keeps the story")
	t.activate(0)
	(main.top_overlay() as ConfirmOverlay).back()
	assert_eq(SaveService.get_campaign()["completed"], ["1.0"], "Back keeps it too")
	t.activate(0)
	(main.top_overlay() as ConfirmOverlay).activate(0)
	var want := CampaignSchema.new_campaign()
	want["savedAt"] = NOW
	assert_eq(_disk()["campaign"], want, "the exact default, saved")
	assert_true(await _until(func() -> bool: return main.current_scene is GreenZoneScene), "1.0 starts")
	assert_true((main.current_scene as GreenZoneScene)._overlay is BriefingOverlay, "with its briefing")


## CONTINUE: the one-time migration notice first; then 1.0 (no story yet), the honest 1.1 boundary
## after the walk (progress kept, no other run), the level list when the story is finished.
func test_SLICE_continue_destinations() -> void:
	var st := CampaignSchema.new_campaign()
	st["notice"] = "dream-rewritten"
	SaveService.save_campaign(st, NOW)
	await _main()
	_ready_title().activate(1)
	var m := main.top_overlay() as MessageOverlay
	assert_true(m != null and m.heading == "THE DREAM HAS BEEN REWRITTEN", "the notice first")
	assert_eq(_disk()["campaign"]["notice"], null, "cleared and saved once")
	m.time = 1.0
	m.on_tap(Vector2(5, 5))
	assert_true(await _until(func() -> bool: return main.current_scene is GreenZoneScene), "then 1.0 (the next scene)")
	main.show_title()
	await tree.process_frame
	st = SaveService.get_campaign()
	st["completed"] = ["1.0"]
	SaveService.save_campaign(st, NOW)
	_ready_title().activate(1)
	assert_true(await _until(func() -> bool: return main.top_overlay() is MessageOverlay and (main.top_overlay() as MessageOverlay).heading == "NOT IN THIS BUILD"), "1.1: the boundary")
	assert_true(main.current_scene is TitleScreen, "no other run started")
	assert_eq(SaveService.get_campaign()["completed"], ["1.0"], "progress kept")
	main.clear_overlays()
	st["completed"] = Array(SaveService.CATALOG.ids())
	SaveService.save_campaign(st, NOW)
	_ready_title().activate(1)
	assert_true(main.top_overlay() is LevelListOverlay, "finished: the level list")


## SAV-008 through Main: the record saves when level 1 completes (campaign untouched); RETRY, the
## game over and TITLE leave the campaign as it was; CONTINUE saves coins, time and 1.0.
func test_SAV_008_green_zone_record_and_campaign_handoff_order() -> void:
	await _main()
	AppState.new_game()
	var camp0: Dictionary = _disk()["campaign"]
	main.start_green_zone(true)
	await tree.process_frame
	var gz := main.current_scene as GreenZoneScene
	gz.rules.stats["coins"] = 15
	var end := _finish_walk(gz)
	assert_true(end != null, "result card")
	var d := _disk()
	assert_true(d["records"].has("level1"), "record saved at level completion")
	assert_eq(d["campaign"], camp0, "campaign unchanged at completion")
	# RETRY: no campaign change.
	var gid := gz.get_instance_id()
	end.activate(end.items.map(func(i: Dictionary) -> String: return i["label"]).find("RETRY"))
	assert_true(await _until(func() -> bool: return main.current_scene.get_instance_id() != gid and main.current_scene is GreenZoneScene), "retry")
	assert_eq(_disk()["campaign"], camp0, "RETRY hands nothing over")
	# GAME OVER: none.
	gz = main.current_scene as GreenZoneScene
	gz.manual_ticks = true
	gz.rules.stats["lives"] = 1
	gz.rules.hunger.value = 0.01
	_gz_step(gz, 72)
	assert_true(gz._overlay is GameOverOverlay, "game over")
	assert_eq(_disk()["campaign"], camp0, "GAME OVER hands nothing over")
	(gz._overlay as GameOverOverlay).activate(1)
	assert_true(await _until(func() -> bool: return main.current_scene is TitleScreen), "QUIT TO TITLE")
	assert_eq(_disk()["campaign"], camp0, "nor does the title")
	# Result-screen TITLE (the walk outside the story) and CONTINUE (in the story).
	main.start_green_zone(true, false)
	await tree.process_frame
	end = _finish_walk(main.current_scene as GreenZoneScene)
	assert_eq(end.items.map(func(i: Dictionary) -> String: return i["label"]), ["RETRY", "TITLE"], "outside the story")
	end.activate(1)
	assert_true(await _until(func() -> bool: return main.current_scene is TitleScreen), "TITLE")
	assert_eq(_disk()["campaign"], camp0, "result-screen TITLE hands nothing over")
	main.start_green_zone(true)
	await tree.process_frame
	gz = main.current_scene as GreenZoneScene
	gz.rules.stats["coins"] = 15
	end = _finish_walk(gz)
	var walk_time: float = gz.rules.stats["time"]
	end.activate(0)
	var c: Dictionary = _disk()["campaign"]
	assert_eq([c["completed"], int(c["coins"]), int(c["savedAt"])], [["1.0"], 15, NOW], "CONTINUE: 1.0, coins")
	assert_near(float(c["playTime"]), walk_time, 1e-9, "CONTINUE: time")
	assert_eq(_disk()["legacy_arcade_coins"], {"present": false, "value": 0}, "the passive legacy coins untouched")


## SAV-021: a corrupt main with a valid backup restores the backup with no data loss (the unreadable
## file kept) and the title says so once.
func test_SAV_021_corrupt_main_restored_from_backup_with_notice() -> void:
	SaveService.save_record("level1", {"score": 777, "stars": 4.0, "time": 66.0})
	SaveService.save_record("level1", {"score": 778, "stars": 4.0, "time": 66.0})
	var backup: Variant = JSON.parse_string(FileAccess.get_file_as_string(SaveService.base_dir + "save_v3.bak"))
	var f := FileAccess.open(SaveService.base_dir + "save_v3.json", FileAccess.WRITE)
	f.store_string("{ not json")
	f.close()
	SaveService.load_from_disk()
	assert_eq(SaveService.load_status, "recovered_from_backup", "recovered")
	assert_eq(SaveService.get_record("level1"), SaveService.normalize_record(backup["records"]["level1"]), "the backup's data")
	assert_eq(FileAccess.get_file_as_string(SaveService.base_dir + "save_v3.corrupt.json"), "{ not json", "the unreadable file kept")
	await _main()
	var m := main.top_overlay() as MessageOverlay
	assert_true(m != null and String(m.paragraphs[0][0]).contains("RESTORED FROM ITS BACKUP"), "the title tells the player")
	m.time = 1.0
	m.on_tap(Vector2(4, 4))
	main.show_title()
	await tree.process_frame
	assert_eq(main.overlay_host.get_child_count(), 0, "once")


## FLOW-011: a replay of the finished walk — its completion, a RETRY, CONTINUE and a choice applied
## to the replay copy — changes no persistent byte; it returns to the level's list.
func test_FLOW_011_replay_changes_no_persistent_byte() -> void:
	var st := CampaignSchema.new_campaign()
	st["completed"] = ["1.0"]
	st["coins"] = 5
	SaveService.save_campaign(st, NOW - 5000)
	SaveService.save_record("level1", {"score": 100, "stars": 1.0, "time": 200.0})
	var bytes := _save_bytes()
	await _main()
	main.open_levels()
	(main.top_overlay() as LevelListOverlay).activate(1)
	var ch := main.top_overlay() as ChapterListOverlay
	assert_eq(ch.items[0]["id"], "1.0", "level 1's list")
	ch.activate(0)
	assert_true(AppState.replaying, "replay of a finished scene")
	assert_true(await _until(func() -> bool: return main.current_scene is GreenZoneScene), "the walk replays")
	var end := _finish_walk(main.current_scene as GreenZoneScene)
	assert_true(end.result["replay"], "result marked as a replay")
	assert_eq(_save_bytes(), bytes, "completion: no byte changed (not even the record)")
	end.activate(1)
	assert_true(await _until(func() -> bool: return main.current_scene is GreenZoneScene and (main.current_scene as GreenZoneScene).rules.state == "playing"), "RETRY")
	assert_true(AppState.replaying, "still a replay")
	CampaignRules.apply_effects(AppState.replay_state, {"grace": -30, "marvel": "X", "flags": {"oath": "enforced"}})
	end = _finish_walk(main.current_scene as GreenZoneScene)
	end.activate(0)
	assert_eq(_save_bytes(), bytes, "restart, choice and CONTINUE: no byte changed")
	assert_true(await _until(func() -> bool: return main.top_overlay() is ChapterListOverlay), "back to the level's list")
	assert_false(AppState.replaying, "the replay ended")


## FLOW-012 (partial: SKIP SCENE belongs to the story's pause menu, M5): the walk's pause offers no
## SKIP SCENE.
func test_P_FLOW_012_no_skip_scene_in_the_walk() -> void:
	await _main("walk")
	var gz := main.current_scene as GreenZoneScene
	gz._close_overlay()
	gz.start_play()
	gz.open_pause()
	assert_eq((gz._overlay as PauseOverlay).items.map(func(i: Dictionary) -> String: return i["label"]), ["RESUME", "RESTART", "QUIT"], "no SKIP SCENE")


## Navigation: an input queued before an overlay opens never activates it; Esc backs out of one
## overlay at a time; Android Back reaches the top overlay; on the bare title it quits.
func test_SLICE_overlay_navigation_queued_input_and_back() -> void:
	await _main()
	var t := _ready_title()
	InputService.trigger(&"confirm")
	t.activate(3)
	var o := main.top_overlay() as OptionsOverlay
	await tree.process_frame
	assert_false(InputService.consume(&"confirm"), "the queued confirm was cleared when OPTIONS opened")
	o.activate(3)
	var c := main.top_overlay() as ControlsOverlay
	await tree.process_frame
	c.time = 1.0
	o.time = 1.0
	InputService.trigger(&"menu")
	InputService.trigger(&"back")
	await _frames(3)
	assert_eq(main.top_overlay(), o, "Esc closed CONTROLS only")
	main.notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	assert_eq(main.overlay_host.get_child_count(), 0, "Android Back closed OPTIONS")
	main.notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	assert_eq(quits[0], 1, "Back on the bare title quits")
