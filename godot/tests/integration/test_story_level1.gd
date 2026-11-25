extends TestCase
## M5R: the story engine and the rewritten Level 1 (docs/porting/STORY_REWRITE_SPEC.md §9). Content
## validation of the shipped Resources; each scene by the scripted smoke (debug skip) and by the
## real-input driver (the InputService path a player uses); state snapshots against the rewrite's
## branch fixtures; both 1.3 choices; Jack's gate success and failure/recovery; pause/restart at
## every step family; replays byte-identical; force-close/reload at every save boundary; the 1.0 ->
## 1.1 handoff and the end of Level 1 through the real Main.

const STORY := preload("res://scenes/story/story_scene.tscn")
const MAIN := preload("res://main/main.tscn")
const DT := 1.0 / 60.0
const NOW := 1795608000000
const IDS := ["1.1", "1.2", "1.3", "1.4", "1.5"]

var main: Node
var scenes: Array = []


func before_each() -> void:
	AppState.clock = func() -> int: return NOW
	InputService.auto_update = false
	InputService.clear_injection()


func after_each() -> void:
	for s: Node in scenes:
		if is_instance_valid(s):
			if s.get_parent():
				s.get_parent().remove_child(s)
			s.free()
	scenes.clear()
	if main and is_instance_valid(main):
		main.get_parent().remove_child(main)
		main.free()
	InputService.clear_injection()
	InputService.release_all()
	InputService.auto_update = true
	SaveService.file_ops = SaveFileOps.new()
	SaveService.write_blocked = false
	AppState.end_replay()
	AppState.clock = func() -> int: return int(Time.get_unix_time_from_system() * 1000.0)


## The campaign a scene is entered with: everything before it completed (1.0 walked with 12 coins
## and 60 s), meters at their start.
static func _entry(id: String) -> Dictionary:
	var st := CampaignSchema.new_campaign()
	st["completed"] = ["1.0"]
	st["coins"] = 12
	st["playTime"] = 60
	for k in IDS:
		if k == id:
			break
		st["completed"].append(k)
	return st


func _scene(id: String, state: Dictionary, persist: bool = true) -> StoryScene:
	var s: StoryScene = STORY.instantiate()
	s.manual_ticks = true
	s.setup(StoryLibrary.scene(id), state, persist)
	scenes.append(s)
	tree.root.add_child(s)
	return s


## Plays a scene to its completion boundary with a driver. {"result", "error", "ticks", "scene", "driver"}.
func _play(id: String, state: Dictionary, policy: Dictionary = {}, gate: String = "bark", scripted: bool = false, max_ticks: int = 60 * 240) -> Dictionary:
	var s := _scene(id, state)
	var out := {"scene": s}
	s.completed.connect(func(r: Dictionary) -> void: out["result"] = r)
	s.failed.connect(func(m: String) -> void: out["error"] = m)
	var d := StoryDriver.new(s, policy, gate, scripted)
	out["driver"] = d
	for k in max_ticks:
		d.drive(DT)
		InputService.update(DT)
		s.tick(DT)
		if out.has("result") or out.has("error"):
			out["ticks"] = k + 1
			break
	return out


func test_CONTENT_001_002_chapter_1_validates_in_catalog_order() -> void:
	var v := StoryValidator.for_project()
	var ch := StoryLibrary.chapter(1)
	assert_true(ch != null, "chapter 1 Resource")
	assert_eq(v.validate_chapter(ch), PackedStringArray(), "chapter 1 and its scenes validate")
	assert_eq(ch.scenes.map(func(s: StorySceneData) -> String: return s.id), IDS, "1.1–1.5 in catalog order")
	assert_eq(Array(SaveService.CATALOG.ids()).size(), 37, "the 37-entry catalog is unchanged")
	for id in IDS:
		assert_true(StoryLibrary.has_scene(id) and SaveService.CATALOG.playable_in_build(id), "%s playable" % id)
	assert_false(StoryLibrary.has_scene("2.1"), "Level 2 not implemented")


func test_SLICE_scripted_smoke_every_level_1_scene() -> void:
	for id in IDS:
		var out := _play(id, _entry(id), {}, "bark", true, 60 * 120)
		assert_false(out.has("error"), "%s: no error (%s)" % [id, out.get("error", "")])
		assert_true(out.has("result"), "%s: reaches its completion boundary (%d ticks)" % [id, out.get("ticks", -1)])


func test_SLICE_real_input_completes_every_level_1_scene() -> void:
	for id in IDS:
		var out := _play(id, _entry(id))
		assert_false(out.has("error"), "%s: no error (%s)" % [id, out.get("error", "")])
		assert_true(out.has("result"), "%s: real input reaches the completion boundary (%s ticks)" % [id, out.get("ticks", "timeout")])
		if out.has("result"):
			var r: Dictionary = out["result"]
			print("       %s real input: %d ticks (%.1f s), %d steps, actions %d, taps %d, flags %s, meters %s, book %s, abilities %s" % [id, out["ticks"], out["ticks"] * DT, (r["trace"] as PackedStringArray).size(), (out["driver"] as StoryDriver).actions, (out["driver"] as StoryDriver).taps, r["state"]["flags"], r["state"]["meters"], r["state"]["book"]["shards"] + r["state"]["book"]["remembered"], r["state"]["abilities"]])


# --- Branch fixtures of the rewrite (STORY_REWRITE_SPEC.md §9) ---------------------------------

const LINES := {
	"1.1": "THERE WAS A BUCKET, AND IT FELT LIKE A HELMET.",
	"1.2": "THERE WAS A GATE, AND IT WAS A CHIHUAHUA.",
	"1.3": "THERE WAS A BOWL, AND IT WAS ALWAYS ONE STEP AWAY.",
	"1.4": "THERE WAS A GATE, AND IT WAS A STAGE.",
	"1.5": "THERE WAS A RAG, AND IT WAS A CROSS, AND NOBODY LOOKED.",
}
const SHARDS := ["A FLEET BOUGHT ON CREDIT", "A KNIGHT WHO KEPT WALKING", "A CITY SEEN FROM ITS WALLS"]


## The working copy a scene must complete with, on a branch ("paw"/"water" for 1.3, "one"/"quiet"
## for 1.5), from `_entry(id)`.
static func _expected(id: String, branch: String = "") -> Dictionary:
	var st := _entry(id)
	(st["book"]["remembered"] as Array).append(LINES[id])
	match id:
		"1.2":
			st["book"]["shards"] = SHARDS.duplicate()
		"1.3":
			st["flags"] = {"pawOffered": branch != "water", "longWay": true}
			if branch != "water":
				st["meters"]["supervillain"] = 7
		"1.4":
			st["flags"] = {"santinaBall": "performed"}
		"1.5":
			st["abilities"] = ["cross"]
			if branch == "quiet":
				st["meters"]["commozione"] = 23
			else:
				st["meters"]["supervillain"] = 13
	return st


## Book arrays compared as sets (the driver may take the scraps in any order).
static func _norm(st: Dictionary) -> Dictionary:
	var n := st.duplicate(true)
	for k: String in n["book"]:
		(n["book"][k] as Array).sort()
	return n


func _snapshot(out: Dictionary, id: String, branch: String, what: String) -> void:
	if not assert_true(out.has("result"), "%s: completed (%s)" % [what, out.get("error", "timeout")]):
		return
	assert_eq(_norm(out["result"]["state"]), _norm(_expected(id, branch)), "%s: state snapshot" % what)


func _no_armour(s: StoryScene, what: String) -> void:
	var body := s.world.player.get_node("VisualRoot/Body") as AnimatedSprite2D
	assert_eq(body.sprite_frames, s.world.player.profile.normal_frames, "%s: plain skin in reality (no armour)" % what)


func test_STY_101_bucket_visor_slap_and_helmet_setup() -> void:
	_snapshot(_play("1.1", _entry("1.1"), {}, "bark", true), "1.1", "", "1.1 scripted smoke")
	_snapshot(_play("1.1", _entry("1.1")), "1.1", "", "1.1 real input")
	# The bucket: standing still or barking lowers it, walking pushes it up.
	var s := _scene("1.1", _entry("1.1"))
	var d := StoryDriver.new(s, {}, "bark", true)
	for k in 60 * 20:
		if s.runner.current is ObjectiveStep:
			break
		d.drive(DT)
		InputService.update(DT)
		s.tick(DT)
	assert_true(s.runner.current is ObjectiveStep and s.ctx.visor > 0.8, "the bucket comes down before the walk (visor %.2f)" % s.ctx.visor)
	for k in 60:
		InputService.inject_move(1.0, 0.0)
		InputService.update(DT)
		s.tick(DT)
	var walking := s.ctx.visor
	assert_true(walking < 0.1, "walking pushes it up (%.2f)" % walking)
	for k in 90:
		InputService.inject_move(0.0, 0.0)
		InputService.update(DT)
		s.tick(DT)
	assert_true(s.ctx.visor > 0.5, "standing still lets it slide down (%.2f)" % s.ctx.visor)
	assert_eq([s.ctx.action_label, s.ctx.no_run, s.hud.objective], ["BARK", true, "WALK HOME TO THE HEDGE GAP. KEEP YOUR HEAD UP"], "the walk's action, no running, objective line")
	_no_armour(s, "1.1")


func test_STY_102_lecture_scraps_and_jacks_gate_success() -> void:
	_snapshot(_play("1.2", _entry("1.2"), {}, "bark", true), "1.2", "", "1.2 scripted smoke")
	var out := _play("1.2", _entry("1.2"))
	_snapshot(out, "1.2", "", "1.2 real input")
	var s: StoryScene = out["scene"]
	assert_eq([s.ctx.metrics["echoes"], s.ctx.metrics["bumps"]], [3, 0], "three barks open the gate, no pushing")
	assert_true(s.actors.has("h1") and s.actors.has("h2"), "heads popped up along the fences")
	assert_eq(s.ctx.map_id, "neighborhood", "ends outside, at the bowl")
	assert_eq((out["result"]["state"]["book"]["remembered"] as Array).size(), 1, "one remembered line (RD-06)")
	_no_armour(s, "1.2")


## Jack's gate, failure and recovery: pushing into him only gets NOPE!, a hint after 3 and 8 pushes,
## and after 14 the window creaks anyway (RD-19).
func test_SLICE_jacks_gate_failure_and_recovery() -> void:
	var out := _play("1.2", _entry("1.2"), {}, "push")
	_snapshot(out, "1.2", "", "1.2 pushing")
	var s: StoryScene = out["scene"]
	assert_eq(s.ctx.metrics["echoes"], 0, "no bark")
	assert_eq(s.ctx.metrics["bumps"], 14, "recovered at the 14th push")
	var hints := (s.ctx.metrics["notices"] as Array).filter(func(n: String) -> bool: return n == "JACK WILL NOT MOVE. BARK?")
	assert_eq(hints.size(), 2, "the hint after 3 and 8 pushes")


func test_STY_103_both_toll_choices_and_the_long_way() -> void:
	for branch in ["paw", "water"]:
		_snapshot(_play("1.3", _entry("1.3"), {"s16": branch}, "bark", true), "1.3", branch, "1.3 %s scripted smoke" % branch)
		var out := _play("1.3", _entry("1.3"), {"s16": branch})
		_snapshot(out, "1.3", branch, "1.3 %s real input" % branch)
		var s: StoryScene = out["scene"]
		assert_true((s.ctx.metrics["choices"] as Array).has("s16:" + branch), "%s taken by a real tap" % branch)
		_no_armour(s, "1.3 " + branch)
	# The direct path is denied: pushing east along the upper lane, Jack cuts him off; the hedge is open.
	var s := _scene("1.3", _entry("1.3"))
	var d := StoryDriver.new(s, {"s16": "paw"}, "bark", true)
	for k in 60 * 60:
		if s.runner.current is ObjectiveStep:
			break
		d.drive(DT)
		InputService.update(DT)
		s.tick(DT)
	for k in 60 * 4:
		InputService.inject_move(0.894, 0.447)
		InputService.update(DT)
		s.tick(DT)
	assert_true(int(s.ctx.metrics.get("cuts", 0)) >= 1 and s.world.player.gx < 17.4, "cut off at the gate (cuts %d, x %.2f)" % [s.ctx.metrics.get("cuts", 0), s.world.player.gx])
	assert_true((s.ctx.metrics["notices"] as Array).has("JACK CUTS HIM OFF. THE HEDGE IS ALWAYS OPEN"), "the hedge notice")


func test_STY_104_the_performance_and_the_ball_left_on_his_side() -> void:
	_snapshot(_play("1.4", _entry("1.4"), {}, "bark", true), "1.4", "", "1.4 scripted smoke")
	var out := _play("1.4", _entry("1.4"))
	_snapshot(out, "1.4", "", "1.4 real input")
	var s: StoryScene = out["scene"]
	var taken: Array = (s.ctx.metrics["choices"] as Array).duplicate()
	taken.sort()
	assert_eq(taken, ["s06:bow", "s06:compliment", "s06:strength"], "each performance once (once_each)")
	var ball: StoryProp = s.props.get("ball")
	assert_true(ball != null and ball.gx < 22.0, "the ball stays on his side of the gate (x %.2f)" % (ball.gx if ball else -1.0))


func test_STY_105_cross_of_rag_and_the_exact_sleep_boundary() -> void:
	for branch in ["one", "quiet"]:
		_snapshot(_play("1.5", _entry("1.5"), {"s08": branch}, "bark", true), "1.5", branch, "1.5 %s scripted smoke" % branch)
		var out := _play("1.5", _entry("1.5"), {"s08": branch})
		_snapshot(out, "1.5", branch, "1.5 %s real input" % branch)
		var s: StoryScene = out["scene"]
		var trace: PackedStringArray = out["result"]["trace"]
		assert_eq([trace[trace.size() - 2], trace[trace.size() - 1]], PackedStringArray(["s19", "done"]), "%s: the UNDER THE DESK card is the last step before the boundary" % branch)
		assert_eq(StoryLibrary.scene("1.5").completion["boundary"], "sleep", "the sleep boundary")
		_no_armour(s, "1.5 " + branch)
		assert_eq(s.hud.carry_label, "A RAG CROSS ON HIS BACK", "%s: the rag rides on his back" % branch)
	# Reality even with every dream ability unlocked (a replay after 2.3): still no armour.
	var st := _entry("1.5")
	st["abilities"] = ["cross", "sermon", "knight"]
	var s := _scene("1.5", st)
	s.tick(DT)
	_no_armour(s, "1.5 with the knight unlocked")


## Pause by real input (the MENU edge), RESTART SCENE at a step of every family, then play to the
## end: the scene restarted from its entry state and nothing was applied twice.
func test_FLOW_008_restart_at_every_step_family_applies_nothing_twice() -> void:
	var cases := [["stage", "1.2", "s09", ""], ["actor", "1.3", "s07", "paw"], ["move", "1.3", "s06", "paw"], ["narration", "1.3", "s09", "paw"],
		["dialogue", "1.3", "s10", "paw"], ["choice", "1.3", "s16", "paw"], ["objective", "1.3", "s20", "paw"], ["effect", "1.3", "s21", "paw"],
		["card", "1.3", "s22", "paw"], ["wait", "1.2", "s15", ""], ["cue", "1.1", "s03", ""], ["prop", "1.3", "s17", "paw"], ["carry", "1.5", "s09", "one"]]
	for c: Array in cases:
		var what := "%s (%s %s)" % c.slice(0, 3)
		var id: String = c[1]
		var policy := {"s16": c[3]} if id == "1.3" else ({"s08": c[3]} if id == "1.5" else {})
		var s := _scene(id, _entry(id))
		var out := {}
		s.completed.connect(func(r: Dictionary) -> void: out["result"] = r)
		s.failed.connect(func(m: String) -> void: out["error"] = m)
		var d := StoryDriver.new(s, policy)
		var restarted := false
		for k in 60 * 300:
			if not restarted and s.runner.trace.has(String(c[2])):
				assert_eq(StoryLibrary.scene(id).steps.filter(func(x: StoryStep) -> bool: return x.id == c[2])[0].kind(), c[0], what + ": the step's family")
				InputService.trigger(&"menu")
				InputService.update(DT)
				s.tick(DT)
				if not assert_true(s.paused and s._pause is StoryPauseOverlay, what + ": MENU paused the scene"):
					break
				(s._pause as StoryPauseOverlay).activate(1)
				restarted = true
				assert_eq([s.restarts, s.paused, s.runner.trace], [1, false, PackedStringArray()], what + ": restarted from the start")
				assert_eq(s.ctx.state, _entry(id), what + ": the working copy is the entry state again")
				continue
			d.drive(DT)
			InputService.update(DT)
			s.tick(DT)
			if out.has("result") or out.has("error"):
				break
		assert_true(restarted, what + ": reached the step")
		_snapshot(out, id, String(c[3]), what + " after the restart")
		if out.has("result"):
			assert_true(float(out["result"]["play_time"]) > s.runner.trace.size() * 0.0, what + ": play time kept")


## Each completion is a save boundary: a force-close inside a scene leaves the saved campaign byte
## for byte as it was and CONTINUE replays that scene; after its completion (one atomic save) a
## relaunch goes on to the next scene with every effect applied once. After 1.5: 2.1's boundary.
func test_FLOW_007_force_close_and_reload_at_each_save_boundary() -> void:
	SaveService.save_campaign(_entry("1.1"), NOW - 1000)
	var policies := {"1.3": {"s16": "paw"}, "1.5": {"s08": "one"}}
	var time := 60.0
	for id in IDS:
		var before := FileAccess.get_file_as_bytes(SaveService.base_dir + "save_v3.json")
		var s := _scene(id, AppState.story_entry_state())
		var d := StoryDriver.new(s, policies.get(id, {}))
		var half := StoryLibrary.scene(id).steps.size() / 2
		for k in 60 * 120:
			if s.runner.trace.size() >= half:
				break
			d.drive(DT)
			InputService.update(DT)
			s.tick(DT)
		# Force-close: the scene is gone without its completion; the next launch reads the disk.
		scenes.erase(s)
		s.get_parent().remove_child(s)
		s.free()
		SaveService.load_from_disk()
		assert_eq(FileAccess.get_file_as_bytes(SaveService.base_dir + "save_v3.json"), before, "%s: nothing of the unfinished scene was saved" % id)
		assert_eq(String(AppState.continue_target()["id"]), id, "%s: CONTINUE plays it again" % id)
		var out := _play(id, AppState.story_entry_state(), policies.get(id, {}))
		if not assert_true(out.has("result"), "%s: completed" % id):
			return
		var r := AppState.commit_scene(id, out["result"]["state"], float(out["result"]["play_time"]))
		assert_eq([r["saved"], r["applied"]], [true, true], "%s: committed in one save" % id)
		time += float(out["result"]["play_time"])
		SaveService.load_from_disk()
		var camp := SaveService.get_campaign()
		assert_true((camp["completed"] as Array).has(id) and int(camp["savedAt"]) == NOW, "%s: completion saved" % id)
		assert_near(float(camp["playTime"]), time, 1e-6, "%s: story play time committed once" % id)
		assert_eq(AppState.commit_scene(id, out["result"]["state"], 99.0)["applied"], false, "%s: a second commit adds nothing" % id)
	var camp := SaveService.get_campaign()
	assert_eq([camp["meters"]["supervillain"], camp["abilities"], camp["flags"]], [10 - 3 + 3, ["cross"], {"pawOffered": true, "longWay": true, "santinaBall": "performed"}], "every effect exactly once across the level")
	assert_eq((camp["book"]["remembered"] as Array).size(), 5, "five remembered lines")
	assert_eq(String(AppState.continue_target()["id"]), "2.1", "after 1.5: 2.1 (this build's boundary)")


# --- Through the real Main ----------------------------------------------------------------------

func _main_start() -> Node:
	tree.root.size = Vector2i(432, 864)
	main = MAIN.instantiate()
	main.open_url = func(_url: String) -> void: pass
	main.quit_app = func() -> void: pass
	tree.root.add_child(main)
	await tree.process_frame
	return main


func _until(cond: Callable, limit: int = 6000) -> bool:
	for k in limit:
		if cond.call():
			return true
		await tree.process_frame
	return cond.call()


func _settle() -> void:
	await _until(func() -> bool: return not main.transition.running)


## Taps the story card for `id` and waits for its StoryScene, ticked by hand from then on.
func _enter_card(id: String) -> StoryScene:
	if not await _until(func() -> bool: return main.top_overlay() is MessageOverlay and main.top_overlay().get_meta(&"story_card", "") == id):
		fail("no story card for %s" % id)
		return null
	var card := main.top_overlay() as MessageOverlay
	card.time = 1.0
	card.on_tap(Vector2(5, 5))
	if not await _until(func() -> bool: return main.current_scene is StoryScene and (main.current_scene as StoryScene).data.id == id):
		fail("%s did not start" % id)
		return null
	var s := main.current_scene as StoryScene
	s.manual_ticks = true
	return s


func _drive_to_end(s: StoryScene, policy: Dictionary = {}) -> bool:
	var d := StoryDriver.new(s, policy)
	for k in 60 * 300:
		if s.finished:
			return true
		d.drive(DT)
		InputService.update(DT)
		s.tick(DT)
	return s.finished


## Runs the walk to its result card (teleport to the exit, the snap, the card).
func _finish_walk(gz: GreenZoneScene) -> LevelEndOverlay:
	gz.manual_ticks = true
	if gz._overlay is BriefingOverlay:
		gz._close_overlay()
		gz.start_play()
	var m := gz.world.map
	gz.world.player.set_grid_position(m.exit.x + 0.3, m.exit.y + 0.3)
	for k in 72:
		InputService.update(DT)
		AudioService.advance_pending(DT)
		gz.tick(DT)
	var sv := gz._overlay as SupervillainedOverlay
	if sv:
		sv.step(GameConfig.Supervillained.HOLD + 0.05)
	var end := gz._overlay as LevelEndOverlay
	if end:
		end.skip = true
		end._process(DT)
	return end


## STY-100 (1.0 -> 1.1): the walk's CONTINUE saves coins, time and 1.0 (M4); then 1.1's card, and
## 1.1 starts from exactly that saved campaign.
func test_STY_100_green_zone_hands_over_to_1_1_with_exact_coins_and_time() -> void:
	await _main_start()
	AppState.new_game()
	main.start_green_zone(true)
	await tree.process_frame
	var gz := main.current_scene as GreenZoneScene
	gz.rules.stats["coins"] = 15
	var end := _finish_walk(gz)
	var walk_time: float = gz.rules.stats["time"]
	end.activate(0)
	var s := await _enter_card("1.1")
	if s == null:
		return
	var camp := SaveService.get_campaign()
	assert_eq([camp["completed"], camp["coins"]], [["1.0"], 15], "1.0 and its coins saved")
	assert_near(float(camp["playTime"]), walk_time, 1e-9, "the walk's time saved")
	assert_eq(s.entry_state, camp, "1.1 starts from the saved campaign")
	assert_true(s.persist, "a story run, not a replay")


## The end of Level 1 through Main: 1.5 commits, the Supervillained snap, then the Professor's
## aside (names in yellow), then 2.1's explicit "not in this build" card over the title.
func test_SLICE_end_of_level_1_snap_aside_and_level_2_boundary() -> void:
	var st := _entry("1.5")
	SaveService.save_campaign(st, NOW - 1000)
	await _main_start()
	await _settle()
	(main.current_scene as TitleScreen).time = 1.0
	(main.current_scene as TitleScreen).activate(1)
	var s := await _enter_card("1.5")
	if s == null or not assert_true(_drive_to_end(s, {"s08": "quiet"}), "1.5 completed"):
		return
	assert_true(await _until(func() -> bool: return main.top_overlay() is SupervillainedOverlay), "the snap after 1.5")
	assert_true((SaveService.get_campaign()["completed"] as Array).has("1.5"), "1.5 saved before the snap")
	var sv := main.top_overlay() as SupervillainedOverlay
	sv.step(GameConfig.Supervillained.HOLD + 0.05)
	assert_true(await _until(func() -> bool: return main.top_overlay() is MessageOverlay and main.top_overlay().has_meta(&"professor_aside")), "then the Professor's aside")
	var aside := main.top_overlay() as MessageOverlay
	assert_eq(aside.paragraphs[0][0], StoryLibrary.chapter(1).professor_aside, "the Level 1 aside")
	assert_true(aside.markup.name_spans(String(aside.paragraphs[0][0]), Color.WHITE).has(["CLARI", aside.markup.name_color]), "CLARI in yellow")
	aside.time = 1.0
	aside.on_tap(Vector2(5, 5))
	assert_true(await _until(func() -> bool: return main.current_scene is TitleScreen and main.top_overlay() is MessageOverlay and (main.top_overlay() as MessageOverlay).heading == "NOT IN THIS BUILD"), "2.1: the explicit boundary")
	assert_eq((main.top_overlay() as MessageOverlay).paragraphs[0][0], "LEVEL 2: 2.1 ONE STEP FROM JERUSALEM", "names the next scene")


## Arms a save fault (main and backup exist first): a failing file operation, or a blocked session.
func _fault(fail: Dictionary, blocked: bool = false) -> void:
	SaveService.file_ops = SaveFileOps.new()
	SaveService.write_to_disk()
	SaveService.write_to_disk()
	var f := FaultyFileOps.new()
	f.fail = fail
	SaveService.file_ops = f
	SaveService.write_blocked = blocked


## Committed bytes: the main, or the backup while a failed write left no main.
func _committed() -> PackedByteArray:
	var d := SaveService.base_dir
	return FileAccess.get_file_as_bytes(d + ("save_v3.json" if FileAccess.file_exists(d + "save_v3.json") else "save_v3.bak"))


func _no_fault() -> void:
	SaveService.file_ops = SaveFileOps.new()
	SaveService.write_blocked = false


## A scene whose completion save fails (STORY_REWRITE_SPEC.md §7) stays on its last screen with the
## save-error card (TRY AGAIN, TITLE; no BACK, and Android Back keeps the card: a finished scene has
## nothing to go back to); nothing is applied in memory or on disk. TRY AGAIN once the fault is gone
## commits the scene exactly once and goes on to the next card. In a blocked (read-only) session
## the card offers only TITLE, which abandons the scene like a force-close.
func test_SLICE_scene_save_failure_stays_on_the_scene_and_retries_once() -> void:
	SaveService.save_campaign(_entry("1.4"), NOW - 1000)
	await _main_start()
	await _settle()
	(main.current_scene as TitleScreen).time = 1.0
	(main.current_scene as TitleScreen).activate(1)
	var s := await _enter_card("1.4")
	if s == null:
		return
	_fault({"rename": "save_v3.tmp"})
	var before: Dictionary = SaveService.data.duplicate(true)
	var committed := _committed()
	if not assert_true(_drive_to_end(s), "1.4 reaches its completion"):
		return
	var card := main.top_overlay() as MessageOverlay
	_no_fault()
	if not assert_true(card != null and card.has_meta(&"save_error"), "the save-error card"):
		return
	assert_eq(card.get_meta(&"save_error"), {"context": "scene", "reason": "rename_failed"}, "what failed")
	assert_eq(card.items.map(func(i: Dictionary) -> String: return i["label"]), ["TRY AGAIN", "TITLE"], "TRY AGAIN or TITLE, no BACK")
	assert_eq([main.current_scene == s, s.finished], [true, true], "stays on the scene's last screen")
	assert_eq(SaveService.data, before, "nothing applied in memory")
	assert_eq(_committed(), committed, "nor in the committed file")
	assert_false(card.back(), "Android Back keeps the card")
	assert_eq(main.top_overlay(), card, "the card is still there")
	card.activate(0)
	var camp := SaveService.get_campaign()
	assert_true((camp["completed"] as Array).has("1.4") and camp["flags"].get("santinaBall") == "performed", "TRY AGAIN: 1.4 committed")
	assert_eq((camp["book"]["remembered"] as Array).size(), 1, "its remembered line once")
	var s15 := await _enter_card("1.5")
	if s15 == null:
		return
	# A blocked session: only TITLE, which abandons 1.5 (CONTINUE plays it again).
	_fault({}, true)
	if not assert_true(_drive_to_end(s15, {"s08": "quiet"}), "1.5 reaches its completion"):
		return
	card = main.top_overlay() as MessageOverlay
	if not assert_true(card != null and card.has_meta(&"save_error"), "blocked: the save-error card"):
		return
	assert_eq(card.items.map(func(i: Dictionary) -> String: return i["label"]), ["TITLE"], "blocked: TITLE only")
	card.activate(0)
	_no_fault()
	assert_true(await _until(func() -> bool: return main.current_scene is TitleScreen), "TITLE: back to the title")
	assert_false((SaveService.get_campaign()["completed"] as Array).has("1.5"), "1.5 not committed")
	assert_eq(String(AppState.continue_target()["id"]), "1.5", "CONTINUE plays 1.5 again")


## The story pause through Main (UI-023–030, partial): Android Back on a running scene opens the
## pause (RESUME, RESTART SCENE, QUIT TO TITLE; no SKIP SCENE, RD-23) and freezes the scene; Back on
## the pause resumes, so does RESUME; QUIT TO TITLE goes to the title with nothing of the scene
## saved (CONTINUE plays it again).
func test_SLICE_story_pause_through_main_back_resume_and_quit() -> void:
	SaveService.save_campaign(_entry("1.1"), NOW - 1000)
	await _main_start()
	await _settle()
	(main.current_scene as TitleScreen).time = 1.0
	(main.current_scene as TitleScreen).activate(1)
	var s := await _enter_card("1.1")
	if s == null:
		return
	var committed := _committed()
	var d := StoryDriver.new(s)
	for k in 120:
		d.drive(DT)
		InputService.update(DT)
		s.tick(DT)
	main.notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	var pause := main.top_overlay() as StoryPauseOverlay
	if not assert_true(pause != null and s.paused, "Android Back opened the story pause"):
		return
	assert_eq(pause.items.map(func(i: Dictionary) -> String: return i["label"]), ["RESUME", "RESTART SCENE", "QUIT TO TITLE"], "no SKIP SCENE (RD-23)")
	var ticks := s.ticks
	s.tick(DT)
	assert_eq(s.ticks, ticks, "the scene is frozen while paused")
	main.notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	assert_eq([s.paused, main.top_overlay()], [false, null], "Back on the pause resumes")
	main.notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	(main.top_overlay() as StoryPauseOverlay).activate(0)
	assert_eq([s.paused, main.top_overlay()], [false, null], "RESUME resumes")
	s.tick(DT)
	assert_eq(s.ticks, ticks + 1, "and the scene runs again")
	main.notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	(main.top_overlay() as StoryPauseOverlay).activate(2)
	assert_true(await _until(func() -> bool: return main.current_scene is TitleScreen), "QUIT TO TITLE: the title")
	assert_eq(_committed(), committed, "nothing of the scene saved")
	assert_eq(String(AppState.continue_target()["id"]), "1.1", "CONTINUE plays 1.1 again")


## Replaying every finished Level 1 scene from the level list changes no persistent byte and
## returns to the list (AppState's deep-copy session).
func test_FLOW_011_replay_of_every_level_1_scene_changes_no_byte() -> void:
	var st := _expected("1.5", "one")
	st["completed"] = ["1.0", "1.1", "1.2", "1.3", "1.4", "1.5"]
	st["flags"] = {"pawOffered": true, "longWay": true, "santinaBall": "performed"}
	SaveService.save_campaign(st, NOW - 5000)
	var bytes := FileAccess.get_file_as_bytes(SaveService.base_dir + "save_v3.json")
	await _main_start()
	for id in IDS:
		await _settle()
		main.clear_overlays()
		main.open_levels()
		(main.top_overlay() as LevelListOverlay).activate(1)
		var ch := main.top_overlay() as ChapterListOverlay
		var idx := -1
		for k in ch.items.size():
			if String((ch.items[k] as Dictionary).get("id", "")) == id:
				idx = k
		if not assert_true(idx >= 0, "%s listed" % id):
			return
		ch.activate(idx)
		assert_true(AppState.replaying, "%s: a replay" % id)
		var s := await _enter_card(id)
		if s == null:
			return
		assert_false(s.persist, "%s: nothing persists" % id)
		assert_true(_drive_to_end(s, {"s16": "water", "s08": "quiet"}), "%s: replayed to the end" % id)
		assert_true(await _until(func() -> bool: return main.top_overlay() is ChapterListOverlay), "%s: back to the level's list" % id)
		assert_false(AppState.replaying, "%s: the replay ended" % id)
		assert_eq(FileAccess.get_file_as_bytes(SaveService.base_dir + "save_v3.json"), bytes, "%s: no persistent byte changed" % id)


# --- Architecture -------------------------------------------------------------------------------

static func _public_interface(script: Script) -> Array:
	var out: Array = []
	for m: Dictionary in script.get_script_method_list():
		if not String(m["name"]).begins_with("_"):
			out.append("%s(%d)" % [m["name"], (m["args"] as Array).size()])
	for p: Dictionary in script.get_script_property_list():
		if not String(p["name"]).begins_with("_") and int(p["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE:
			out.append("var " + String(p["name"]))
	out.sort()
	return out


## ARCH-001b: the production StoryScene instantiates the shared IsoWorld as its own child (the
## Green Zone's classes and public interfaces), on the real chapter maps; only PlayableDog turns
## input into movement, tick for tick the shared controller and grid solver; freeing the scene
## frees the world, the dog, the actors and every descendant.
func test_ARCH_001b_production_story_scene_shares_the_world() -> void:
	var gz: GreenZoneScene = load("res://scenes/green_zone/green_zone_scene.tscn").instantiate()
	gz.show_briefing = false
	gz.manual_ticks = true
	tree.root.add_child(gz)
	var s := _scene("1.1", _entry("1.1"))
	var d := StoryDriver.new(s, {}, "bark", true)
	for k in 60 * 20:
		if s.runner.current is ObjectiveStep:
			break
		d.drive(DT)
		InputService.update(DT)
		s.tick(DT)
	var sw := s.world
	assert_eq(sw.get_parent(), s, "the world is the story scene's own child")
	for pair: Array in [["IsoWorld", sw, gz.world], ["PlayableDog", sw.player, gz.world.player], ["CameraRig", sw.camera_rig, gz.world.camera_rig]]:
		var a: Script = (pair[1] as Node).get_script()
		var b: Script = (pair[2] as Node).get_script()
		assert_eq(a, b, "same %s class as GreenZoneScene" % pair[0])
		assert_eq(_public_interface(a), _public_interface(b), "same %s public interface" % pair[0])
	assert_eq([sw.scene_file_path, sw.player.scene_file_path], [gz.world.scene_file_path, gz.world.player.scene_file_path], "same scenes")
	assert_eq(sw.map.width, 26, "the real neighborhood map")
	var start := Vector2(sw.player.gx, sw.player.gy)
	var intents: Array = []
	var trace: Array = []
	for k in 90:
		InputService.inject_move(0.7, -0.2)
		InputService.update(DT)
		intents.append([InputService.move_x, InputService.move_y])
		s.tick(DT)
		trace.append([sw.player.gx, sw.player.gy])
	var bare: PlayableDog = load("res://entities/playable_dog/playable_dog.tscn").instantiate()
	bare.no_run = true
	bare.set_grid_position(start.x, start.y)
	var diverged := -1
	for k in intents.size():
		bare.set_intent(intents[k][0], intents[k][1], false)
		bare.update_movement(DT, sw.map)
		if diverged < 0 and (bare.gx != trace[k][0] or bare.gy != trace[k][1]):
			diverged = k
	bare.free()
	assert_eq(diverged, -1, "story movement equals the shared controller and solver tick for tick")
	var dog := sw.player
	var descendants: Array[Node] = s.find_children("*", "", true, false)
	scenes.erase(s)
	s.get_parent().remove_child(s)
	s.free()
	assert_false(is_instance_valid(sw) or is_instance_valid(dog), "world and dog freed with the scene")
	assert_eq(descendants.filter(func(n: Variant) -> bool: return is_instance_valid(n)).size(), 0, "every descendant freed")
	tree.root.remove_child(gz)
	gz.free()


## DOG-008b: a story stage change (1.2, the study -> outside) builds a new world whose dog starts
## with a reset physics interpolation and a snapped camera at the new start.
func test_DOG_008b_stage_change_resets_interpolation() -> void:
	var s := _scene("1.2", _entry("1.2"))
	s.tick(DT)
	var first_dog := s.world.player
	var d := StoryDriver.new(s, {}, "bark", true)
	for k in 60 * 60:
		if s.runner.trace.has("s09"):
			break
		d.drive(DT)
		InputService.update(DT)
		s.tick(DT)
	assert_eq([s.ctx.map_id, s.stage_changes], ["neighborhood", 2], "the second stage")
	var dog := s.world.player
	assert_true(dog != first_dog and not is_instance_valid(first_dog) or dog != first_dog, "a new dog")
	assert_true(dog.interpolation_resets >= 1 and s.world.camera_rig.interpolation_resets >= 1, "interpolation reset (dog %d, camera %d)" % [dog.interpolation_resets, s.world.camera_rig.interpolation_resets])
	assert_eq(Vector2(dog.gx, dog.gy), s.ctx.marker("S"), "at the new start")
	assert_eq(dog.position, IsoGrid.grid_to_screen(dog.gx, dog.gy).round(), "drawn where it stands")


# --- Content ------------------------------------------------------------------------------------

## Every player-visible line of a scene, in step order (nested branches included).
static func _texts(steps: Array) -> PackedStringArray:
	var out := PackedStringArray()
	for s: StoryStep in steps:
		out.append_array(s.texts())
		for b: Array in s.branches():
			out.append_array(_texts(b))
	return out


## CONTENT-003: the rewrite metadata on every Level 1 Resource; titles equal the catalog's.
func test_CONTENT_003_rewrite_metadata_on_every_resource() -> void:
	var ch := StoryLibrary.chapter(1)
	assert_true(ch.title == "The Greenzone" and ch.intro != "" and ch.professor_aside != "" and ch.review_status == "draft_implemented_review_pending", "chapter metadata")
	for s: StorySceneData in ch.scenes:
		var f := SaveService.CATALOG.find(s.id)
		assert_eq(s.title, String(f["sub"]["title"]), "%s title" % s.id)
		assert_true(s.content_version >= 1 and s.level == 1 and s.map != "" and s.music == "greenzone" and not s.cast.is_empty(), "%s: version, level, map, music, cast" % s.id)
		assert_true(not s.entry_conditions.is_empty() and not s.persistent_effects.is_empty() and s.completion.has("boundary"), "%s: entry, effects, completion" % s.id)
		assert_true(not s.historical_tags.is_empty() and not s.source_refs.is_empty() and s.reality, "%s: tags, sources, reality" % s.id)
		assert_eq([s.review_status, s.technical_status], ["draft_implemented_review_pending", "technically_complete"], "%s: technically complete, narrative review pending" % s.id)


## CONTENT-004: all story text is in the Resources (none in the engine's scripts); every scene's
## text matches the recorded snapshot of its content_version (a text change must raise it).
func test_CONTENT_004_text_lives_in_resources_and_is_versioned() -> void:
	assert_eq(StoryValidator.scan_scripts(), PackedStringArray(), "no player text in the story engine's scripts")
	var snap: Dictionary = fixture("story_level1_text")
	for s: StorySceneData in StoryLibrary.chapter(1).scenes:
		var texts := _texts(s.steps)
		texts.insert(0, s.summary)
		var ctx := HashingContext.new()
		ctx.start(HashingContext.HASH_SHA256)
		ctx.update("\n".join(texts).to_utf8_buffer())
		var sha := ctx.finish().hex_encode()
		print("       text snapshot %s v%d %s" % [s.id, s.content_version, sha])
		if not snap.has(s.id):
			fail("no text snapshot for %s" % s.id)
			continue
		assert_eq([s.content_version, sha], [int(snap[s.id]["content_version"]), snap[s.id]["sha256"]], "%s: text snapshot of its content_version" % s.id)
		for t in texts:
			assert_true(t.strip_edges() != "" and t == t.to_upper(), "%s: '%s' is nonempty pixel-font capitals" % [s.id, t])
			# No silent placeholder: no draft markers, no template braces or brackets.
			for marker in ["TODO", "TBD", "FIXME", "PLACEHOLDER", "LOREM", "XXX", "???", "[", "]", "{", "}", "%S", "%D"]:
				assert_false(t.contains(marker), "%s: '%s' holds the placeholder '%s'" % [s.id, t, marker])


## CONTENT-005: the cast, source and review metadata never reach a player-facing card or line.
func test_CONTENT_005_metadata_never_on_player_cards() -> void:
	var meta := PackedStringArray()
	var ch := StoryLibrary.chapter(1)
	meta.append(ch.cast_note)
	meta.append_array(ch.review_notes)
	for s: StorySceneData in ch.scenes:
		meta.append_array(s.source_refs)
		meta.append_array(s.historical_tags)
		meta.append_array(s.review_notes)
	var shown := PackedStringArray([ch.intro, ch.professor_aside])
	for s: StorySceneData in ch.scenes:
		shown.append_array(_texts(s.steps))
		shown.append(s.summary)
	for t in shown:
		for m in meta:
			assert_false(m != "" and t.contains(m), "'%s' shows metadata '%s'" % [t, m])
		for marker in ["REVIEW REQUIRED", "docs/", "RD-", "OQ-", "src/"]:
			assert_false(t.contains(marker), "'%s' shows '%s'" % [t, marker])


## COLL-005b (partial, Level 1 — the full aggregate is M7): every scripted spatial objective of
## Level 1 (reach goals by marker or point, pickups) is reachable on the grid from where the scene
## places Zampanò when the objective starts (the driver's tile search over walkable, prop-free
## tiles; the cut-off gap of 1.3 counts as blocked).
func test_P_COLL_005b_level_1_scripted_objectives_reachable() -> void:
	var checked := 0
	for id in IDS:
		var s := _scene(id, _entry(id))
		var d := StoryDriver.new(s, {}, "bark", true)
		var seen := {}
		for k in 60 * 120:
			if s.finished:
				break
			var step := s.runner.current
			if step is ObjectiveStep and not seen.has(step.id):
				seen[step.id] = true
				var o := step as ObjectiveStep
				var from := Vector2(s.world.player.gx, s.world.player.gy)
				var targets: Array = []
				if s.runner.st.get("goal") != null:
					targets.append(s.runner.st["goal"])
				for spot: Dictionary in (s.runner.st.get("spots", {}) as Dictionary).values():
					targets.append(spot["at"])
				# The cut-off gap stays shut (the hedge is the way); Jack's gate opens, so its goal counts.
				var blocked: Array = [o.rule_params["gap"]] if o.rule == "cut_off" else []
				for t: Vector2 in targets:
					var path := d._bfs(from, t, blocked)
					var reach := path.size() > 1 or Vector2i(int(floor(from.x)), int(floor(from.y))) == Vector2i(int(floor(t.x)), int(floor(t.y))) or from.distance_to(t) < 1.5
					assert_true(reach, "%s %s: %s reachable from %s" % [id, o.id, t, from])
					checked += 1
			d.drive(DT)
			InputService.update(DT)
			s.tick(DT)
	assert_eq(checked, 10, "Level 1's ten scripted targets checked (1.1: 1; 1.2: 3 shards + 2 goals; 1.3: 1; 1.5: 3)")
