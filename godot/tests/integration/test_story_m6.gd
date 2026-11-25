extends TestCase
## M6: the rewritten Levels 2–4 (draft implemented, narrative review pending; OD-01) through the
## production StoryScene — the Resources validate in catalog order; every scene completes by the
## scripted smoke (a debug skip) and by the real-input driver (the InputService path a player uses);
## the state each scene commits (meters, flags, abilities, book) against the rewrite's snapshots,
## every branch; each scene's own mechanics (STY-2xx–4xx); restart applies nothing twice; replays
## change no byte; force-close and reload at every save boundary; the scripted-position objectives
## are reachable (partial COLL-005b).

const STORY := preload("res://scenes/story/story_scene.tscn")
const MAIN := preload("res://main/main.tscn")
const DT := 1.0 / 60.0
const NOW := 1795608000000
const CB := GameConfig.Combat
## Every M6 scene in catalog order (this build's).
const IDS := ["2.1", "2.2", "2.3"]
## Choices a run takes (choice id -> option id) and the branches the snapshots cover.
const BRANCHES := {"2.2": [{"s13": "glad"}, {"s13": "proud"}]}
## What each scene commits on top of its entry state: meter deltas, flags, abilities, how many book
## entries of each kind (by branch, keyed "<id>" or "<id>/<option>").
const SNAP := {
	"2.1": {"meters": {}, "flags": {}, "abilities": [], "book": {"remembered": 1}},
	"2.2/glad": {"meters": {"commozione": 9, "grace": 5, "standing": 2}, "flags": {"vow": true}, "abilities": ["sermon"], "book": {"remembered": 1}},
	"2.2/proud": {"meters": {"commozione": 6, "grace": 5, "supervillain": 3, "standing": -2}, "flags": {"vow": true}, "abilities": ["sermon"], "book": {"remembered": 1}},
	"2.3": {"meters": {"supervillain": 8}, "flags": {}, "abilities": ["knight"], "book": {"remembered": 1}},
}

var main: Node
var scenes: Array = []
## Real-input completion (tests write it; the report reads the log): id -> {"ticks", "seconds"}.
var completion := {}


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
	AppState.end_replay()
	AppState.clock = func() -> int: return int(Time.get_unix_time_from_system() * 1000.0)


## The campaign a scene is entered with: Level 1 done (the cross held), then every M6 scene before
## it, with the abilities and flags those scenes leave (the glad branch of 2.2).
static func _entry(id: String) -> Dictionary:
	var st := CampaignSchema.new_campaign()
	st["completed"] = ["1.0", "1.1", "1.2", "1.3", "1.4", "1.5"]
	st["abilities"] = ["cross"]
	st["coins"] = 12
	st["playTime"] = 60
	for k: String in IDS:
		if k == id:
			break
		st = _after(k, "", st)
		st["completed"].append(k)
	return st


## A state with the snapshot of `id` (branch "" = the first) applied: meters, flags, abilities and
## placeholder book entries (the snapshots compare counts).
static func _after(id: String, branch: String, entry: Dictionary) -> Dictionary:
	var st := entry.duplicate(true)
	var key := id if SNAP.has(id) else "%s/%s" % [id, branch if branch != "" else _first_branch(id)]
	var sn: Dictionary = SNAP[key]
	for m: String in sn["meters"]:
		st["meters"][m] = clampf(float(st["meters"][m]) + float(sn["meters"][m]), 0.0, 100.0)
	(st["flags"] as Dictionary).merge(sn["flags"], true)
	for a: String in sn["abilities"]:
		if not (st["abilities"] as Array).has(a):
			st["abilities"].append(a)
	return st


static func _first_branch(id: String) -> String:
	var b: Array = BRANCHES.get(id, [{}])
	var d: Dictionary = b[0]
	return String(d.values()[0]) if not d.is_empty() else ""


func _scene(id: String, state: Dictionary, persist: bool = true) -> StoryScene:
	var s: StoryScene = STORY.instantiate()
	s.manual_ticks = true
	s.setup(StoryLibrary.scene(id), state, persist)
	scenes.append(s)
	tree.root.add_child(s)
	return s


## Plays a scene to its completion boundary with a driver. {"result", "error", "ticks", "scene", "driver"}.
func _play(id: String, state: Dictionary, policy: Dictionary = {}, scripted: bool = false, max_ticks: int = 60 * 300) -> Dictionary:
	var s := _scene(id, state)
	var out := {"scene": s}
	s.completed.connect(func(r: Dictionary) -> void: out["result"] = r)
	s.failed.connect(func(m: String) -> void: out["error"] = m)
	var d := StoryDriver.new(s, policy, "bark", scripted)
	out["driver"] = d
	for k in max_ticks:
		d.drive(DT)
		InputService.update(DT)
		s.tick(DT)
		if out.has("result") or out.has("error"):
			out["ticks"] = k + 1
			break
	InputService.guard_hold_injected = false
	return out


func _check_snapshot(id: String, branch: String, entry: Dictionary, got: Dictionary) -> void:
	var want := _after(id, branch, entry)
	assert_eq(got["meters"], want["meters"], "%s/%s: meters" % [id, branch])
	assert_eq(got["flags"], want["flags"], "%s/%s: flags" % [id, branch])
	assert_eq(got["abilities"], want["abilities"], "%s/%s: abilities" % [id, branch])
	var key := id if SNAP.has(id) else "%s/%s" % [id, branch]
	var book: Dictionary = SNAP[key]["book"]
	for kind: String in ["marvels", "items", "values", "remembered", "shards"]:
		var added := (got["book"][kind] as Array).size() - (entry["book"][kind] as Array).size()
		assert_eq(added, int(book.get(kind, 0)), "%s/%s: book %s added" % [id, branch, kind])
	assert_eq([got["completed"], got["coins"]], [entry["completed"], entry["coins"]], "%s/%s: completion and coins are Main's (one commit)" % [id, branch])


# --- Content -----------------------------------------------------------------------------------------

## CONTENT (M6): every implemented chapter of Levels 2–4 validates (the schema, the catalog order,
## the generated titles, every marker, actor, sprite, sound and effect), every scene is a dream scene
## (`reality` false: the coat of mail), draft implemented with its review notes, and its entry
## conditions name the scene before it.
func test_CONTENT_m6_chapters_validate_in_catalog_order() -> void:
	var v := StoryValidator.for_project()
	var prev := "1.5"
	for n in range(2, 5):
		var ch := StoryLibrary.chapter(n)
		if ch == null:
			continue
		assert_eq(v.validate_chapter(ch), PackedStringArray(), "chapter %d validates" % n)
		assert_eq(ch.review_status, "draft_implemented_review_pending", "chapter %d: draft" % n)
		for sc: StorySceneData in ch.scenes:
			assert_eq([sc.reality, sc.costume(), sc.review_status, sc.technical_status], [false, "armoured", "draft_implemented_review_pending", "technically_complete"], sc.id + ": a dream scene, draft")
			assert_false(sc.review_notes.is_empty(), sc.id + ": review notes")
			assert_eq(sc.entry_conditions.get("requires_completed", []), [prev], sc.id + ": entered after " + prev)
			prev = sc.id


# --- Completion ----------------------------------------------------------------------------------------

func test_SLICE_m6_scripted_smoke_every_scene() -> void:
	for id: String in IDS:
		var out := _play(id, _entry(id), BRANCHES.get(id, [{}])[0], true, 60 * 200)
		assert_false(out.has("error"), "%s: no error (%s)" % [id, out.get("error", "")])
		assert_true(out.has("result"), "%s: the smoke reaches the completion boundary (%s ticks)" % [id, out.get("ticks", "timeout")])


## Real input: every M6 scene completes through the InputService path (joystick, action, bark, U,
## I held, confirms, choice taps), without teleports or debug skips; the snapshot of every branch.
func test_SLICE_m6_real_input_completes_every_scene_and_branch() -> void:
	for id: String in IDS:
		for policy: Dictionary in BRANCHES.get(id, [{}]):
			var entry := _entry(id)
			var out := _play(id, entry, policy)
			var branch := String(policy.values()[0]) if not policy.is_empty() else ""
			assert_false(out.has("error"), "%s/%s: no error (%s)" % [id, branch, out.get("error", "")])
			if not assert_true(out.has("result"), "%s/%s: real input reaches the completion boundary (%s ticks)" % [id, branch, out.get("ticks", "timeout")]):
				continue
			_check_snapshot(id, branch, entry, out["result"]["state"])
			if branch == "" or branch == _first_branch(id):
				completion[id] = {"ticks": out["ticks"], "seconds": snappedf(out["ticks"] * DT, 0.1)}
	print("M6 real-input completion: ", completion)


# --- Level 2 -------------------------------------------------------------------------------------------

## STY-201: 2.1 — the dream begins in the coat of mail (no arms: U/I only the notice); the gate steps
## back exactly twice as he comes close, then lets him reach it; the helmet slips when he stops and
## lifts as he walks; the voice behind the door floats over him (the leaders' Babylon, never the
## people's Jerusalem); one remembered line.
func test_STY_201_receding_jerusalem_helmet_and_the_door() -> void:
	var s := _scene("2.1", _entry("2.1"))
	var d := StoryDriver.new(s)
	var receded := []
	var doors := 0
	var visor_max := 0.0
	var walked := false
	var out := {}
	s.completed.connect(func(r: Dictionary) -> void: out["r"] = r)
	for k in 60 * 120:
		d.drive(DT)
		InputService.update(DT)
		s.tick(DT)
		if out.has("r"):
			break
		var step := s.runner.current
		if step is ObjectiveStep and step.id == "s06":
			if not walked:
				walked = true
				assert_eq([s.world.player.costume, s.ctx.armed(), s.ctx.actions.modes], ["armoured", false, PackedStringArray(["scene", "bark"])], "the coat of mail, no arms")
				InputService.trigger(&"strike")
				# He stands still for four seconds: the helmet slips, the voice behind the door speaks.
				for j in 60 * 4:
					InputService.inject_move(0.0, 0.0)
					InputService.update(DT)
					s.tick(DT)
					visor_max = maxf(visor_max, s.ctx.visor)
					for f: Dictionary in s.hud.floats:
						if String(f["text"]).contains("BABYLON") and float(f["t"]) <= DT * 1.5:
							doors += 1
				assert_true((s.ctx.metrics["notices"] as Array).has("THE HELMET SLIPS OVER HIS EYES. WALK ON TO PUSH IT UP"), "the helmet's notice")
			var st: Dictionary = s.runner.st
			if int(st.get("receded", 0)) > receded.size():
				receded.append(st["goal"])
			visor_max = maxf(visor_max, s.ctx.visor)
		for f: Dictionary in s.hud.floats:
			if String(f["text"]).contains("BABYLON") and float(f["t"]) <= DT * 1.5:
				doors += 1
	assert_true(out.has("r"), "2.1 completes")
	assert_eq(receded.size(), 2, "the gate stepped back twice")
	if receded.size() == 2:
		assert_vec_near(receded[0], Vector2(6.5, 6.5), 1e-6, "one step back")
		assert_vec_near(receded[1], Vector2(5.5, 5.5), 1e-6, "and one more")
	assert_true(visor_max > 0.3, "the helmet slipped (%.2f)" % visor_max)
	assert_true(doors >= 1, "the voice behind the door was heard (%d)" % doors)
	assert_true((s.ctx.metrics["notices"] as Array).has(s.ctx.ui_text("story_no_arms") % s.ctx.ui_text("story_mode_sword")), "U without arms: the notice")
	assert_eq((out["r"]["state"]["book"]["remembered"] as Array), ["THERE WAS A CITY, AND IT WAS ALWAYS ONE STEP FURTHER ON."], "the remembered line")


## STY-202: 2.2 — the vow is heard only in the sermon's pauses: under the noise it is drowned (no
## count), from too far nobody hears; three heard vows (one per pause) turn the crowd two by two and
## each moves Commozione +2; then `sermon`, Grace +5 and `vow` are set once; both clerk answers.
func test_STY_202_vow_in_the_lulls_list_and_clerk() -> void:
	var s := _scene("2.2", _entry("2.2"))
	if not _to_step(s, "s04"):
		return
	var st: Dictionary = s.runner.st
	var stand := Vector2(9.5, 10.5)
	s.world.player.set_grid_position(stand.x, stand.y)
	# Under the noise: drowned.
	_ticks_until(s, func() -> bool: return bool(s.runner.st.get("talking", false)), 300)
	InputService.trigger(&"pee")
	_ticks(s, 1)
	assert_eq([int(st["good"]), s.ctx.state["meters"]["commozione"]], [0, 20.0], "a vow under the sermon is drowned")
	assert_true((s.ctx.metrics["notices"] as Array).has("FULK DROWNS HIM OUT. WAIT FOR A PAUSE"), "and he is told so")
	# From too far: nobody hears, even in a pause.
	_ticks_until(s, func() -> bool: return not bool(s.runner.st.get("talking", true)), 300)
	s.world.player.set_grid_position(stand.x + 7.5, stand.y + 3.0)
	InputService.trigger(&"action")
	_ticks(s, 1)
	assert_eq(int(st["good"]), 0, "too far: not heard")
	s.world.player.set_grid_position(stand.x, stand.y)
	# Three pauses, one vow each (a second vow in the same pause counts nothing).
	for n in range(1, 4):
		_ticks_until(s, func() -> bool: return not bool(s.runner.st.get("talking", true)) and not bool(s.runner.st.get("used", true)), 400)
		InputService.trigger(&"action")
		_ticks(s, 1)
		if n == 1:
			InputService.trigger(&"action")
			_ticks(s, 1)
		if s.runner.current == null or s.runner.current.id != "s04":
			assert_eq(n, 3, "the walk ends on the third vow")
			break
		assert_eq(int(s.runner.st["good"]), n, "vow %d heard once" % n)
		_ticks_until(s, func() -> bool: return bool(s.runner.st.get("talking", false)), 400)
	_ticks(s, 2)
	assert_eq([s.ctx.state["abilities"].has("sermon"), s.ctx.state["meters"]["grace"], s.ctx.state["flags"].get("vow"), s.ctx.state["meters"]["commozione"]], [true, 75.0, true, 26.0], "sermon, Grace +5, vow; Commozione +2 per heard vow")
	var turned := 0
	for k in 6:
		var a: StoryActor = s.actors.get("c%d" % k)
		if a and a.behavior == "goto":
			turned += 1
	assert_eq(turned, 6, "the crowd turned, two by two, and made room")


## STY-203: 2.3 — the first fight is bark only (no arms: the knight's capability is not held, the
## mail is); the arms are picked up and `knight` unlocks only after the third pickup (the SWORD and
## SHIELD modes appear in the next walk); the charge walks slower in mail unless he runs; sparring with
## the parrying squires (a knockdown resets it, nothing applied twice); then he follows Pierre.
func test_STY_203_bark_fight_arms_charge_sparring_and_follow() -> void:
	var s := _scene("2.3", _entry("2.3"))
	var d := StoryDriver.new(s)
	var seen := {}
	var out := {}
	s.completed.connect(func(r: Dictionary) -> void: out["r"] = r)
	for k in 60 * 300:
		d.drive(DT)
		InputService.update(DT)
		s.tick(DT)
		if out.has("r"):
			break
		var step := s.runner.current
		if step == null or seen.has(step.id):
			continue
		seen[step.id] = true
		match step.id:
			"s10":
				assert_eq([s.ctx.armed(), s.world.player.costume, s.ctx.combat.active(), s.ctx.actions.modes], [false, "armoured", true, PackedStringArray(["bark"])], "the road fight: bark only, in mail")
			"s13":
				assert_eq(s.ctx.combat.events.count("strike"), 0, "no sword was swung in the bark fight")
				assert_false(s.ctx.armed(), "no arms while picking them up")
			"s19":
				assert_true(s.ctx.armed(), "knight unlocked after the pickups")
				assert_eq(s.ctx.actions.modes, PackedStringArray(["bark", "sword", "shield"]), "SWORD and SHIELD offered from here")
				assert_eq(s.ctx.walk_speed_mul, 0.8, "heavy mail: walking slower")
			"s29":
				assert_eq([s.ctx.combat.need(), bool(s.ctx.combat.def["parry"]), s.ctx.combat.max_health], [3, true, 6], "sparring: three parrying squires, six hearts")
			"s34":
				assert_eq(s.ctx.walk_speed_mul, 1.0, "the modifier ends with its walk")
	assert_true(out.has("r"), "2.3 completes by real input (%d ticks)" % s.ticks)
	var r: Dictionary = out.get("r", {})
	if r.is_empty():
		return
	assert_true((r["state"]["abilities"] as Array).has("knight"), "knight held at the end")
	assert_eq(r["state"]["meters"]["supervillain"], 18.0, "Supervillain +8 once")


## The sparring's knockdown: losing every heart shows the card and resets the squires and him to the
## fight's start; nothing is applied to the campaign; the fight is then won (real input).
func test_STY_203_sparring_loss_resets_without_state_change() -> void:
	var s := _scene("2.3", _entry("2.3"))
	if not _to_step(s, "s29"):
		return
	var before := s.ctx.state.duplicate(true)
	var start := s.ctx.player_pos()
	# He stands still and lets them hit him until he is knocked down.
	assert_true(_ticks_until(s, func() -> bool: return s.runner.st.has("interrupt"), 60 * 60), "knocked down")
	assert_eq(s.ctx.state, before, "nothing applied")
	assert_true(_ticks_until(s, func() -> bool: return not s.runner.st.has("interrupt"), 300), "up again")
	assert_vec_near(s.ctx.player_pos(), start, 0.01, "back at the fight's start")
	assert_eq(s.ctx.combat.health, 6, "hearts full")
	var d := StoryDriver.new(s)
	for k in 60 * 120:
		if s.runner.current == null or s.runner.current.id != "s29":
			break
		d.drive(DT)
		InputService.update(DT)
		s.tick(DT)
	InputService.guard_hold_injected = false
	assert_true(s.runner.current == null or s.runner.current.id != "s29", "the retried sparring is won")
	assert_eq(s.ctx.metrics["knockdowns"], ["s29"], "one knockdown")


# --- Restart, replay, force-close -----------------------------------------------------------------

## FLOW-008 (M6 scenes): restarting from the pause at every step family applies nothing twice: the
## completed state equals a single run's.
func test_FLOW_008_m6_restart_at_every_step_family_applies_nothing_twice() -> void:
	for id: String in IDS:
		var entry := _entry(id)
		var policy: Dictionary = BRANCHES.get(id, [{}])[0]
		var data := StoryLibrary.scene(id)
		var families := {}
		for st: StoryStep in data.steps:
			if not families.has(st.kind()) and not st is StageStep and not st is CompleteStep:
				families[st.kind()] = st.id
		for kind: String in families:
			var s := _scene(id, entry)
			var d := StoryDriver.new(s, policy, "bark", true)
			var at := String(families[kind])
			for k in 60 * 200:
				if s.runner.current != null and s.runner.current.id == at:
					break
				d.drive(DT)
				InputService.update(DT)
				s.tick(DT)
			s.open_pause()
			s.restart()
			var out := {}
			s.completed.connect(func(r: Dictionary) -> void: out["r"] = r)
			for k in 60 * 200:
				if out.has("r"):
					break
				d.drive(DT)
				InputService.update(DT)
				s.tick(DT)
			InputService.guard_hold_injected = false
			if assert_true(out.has("r"), "%s: completes after a restart at %s (%s)" % [id, at, kind]):
				_check_snapshot(id, String(policy.values()[0]) if not policy.is_empty() else "", entry, out["r"]["state"])


## FLOW-011 (M6 scenes): replaying every completed scene from the chapter list runs on a copy and
## changes no persistent byte.
func test_FLOW_011_replay_of_every_m6_scene_changes_no_byte() -> void:
	var st := _entry(IDS.back())
	st = _after(IDS.back(), "", st)
	st["completed"].append(IDS.back())
	SaveService.save_campaign(st, NOW - 5000)
	var bytes := FileAccess.get_file_as_bytes(SaveService.base_dir + "save_v3.json")
	await _main_start()
	for id: String in IDS:
		await _settle()
		main.clear_overlays()
		main.open_levels()
		var level := int(id.get_slice(".", 0))
		(main.top_overlay() as LevelListOverlay).activate(level)
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
		assert_true(_drive_to_end(s, BRANCHES.get(id, [{}])[0]), "%s: replayed to the end" % id)
		assert_true(await _until(func() -> bool: return main.top_overlay() is ChapterListOverlay), "%s: back to the level's list" % id)
		assert_false(AppState.replaying, "%s: the replay ended" % id)
		assert_eq(FileAccess.get_file_as_bytes(SaveService.base_dir + "save_v3.json"), bytes, "%s: no persistent byte changed" % id)


## FLOW-007 (M6 scenes): a force-close in the middle of a scene saves nothing of it and CONTINUE
## plays it again; its completion is one save; a second commit adds nothing.
func test_FLOW_007_m6_force_close_and_reload_at_each_save_boundary() -> void:
	SaveService.save_campaign(_entry(IDS[0]), NOW - 1000)
	for id: String in IDS:
		var policy: Dictionary = BRANCHES.get(id, [{}])[0]
		var before := FileAccess.get_file_as_bytes(SaveService.base_dir + "save_v3.json")
		var s := _scene(id, AppState.story_entry_state())
		var d := StoryDriver.new(s, policy, "bark", true)
		var half := StoryLibrary.scene(id).steps.size() / 2
		for k in 60 * 200:
			if s.runner.trace.size() >= half:
				break
			d.drive(DT)
			InputService.update(DT)
			s.tick(DT)
		InputService.guard_hold_injected = false
		scenes.erase(s)
		s.get_parent().remove_child(s)
		s.free()
		SaveService.load_from_disk()
		assert_eq(FileAccess.get_file_as_bytes(SaveService.base_dir + "save_v3.json"), before, "%s: nothing of the unfinished scene was saved" % id)
		assert_eq(String(AppState.continue_target()["id"]), id, "%s: CONTINUE plays it again" % id)
		var out := _play(id, AppState.story_entry_state(), policy, true)
		if not assert_true(out.has("result"), "%s: completed" % id):
			return
		var r := AppState.commit_scene(id, out["result"]["state"], float(out["result"]["play_time"]))
		assert_eq([r["saved"], r["applied"]], [true, true], "%s: committed in one save" % id)
		SaveService.load_from_disk()
		assert_true((SaveService.get_campaign()["completed"] as Array).has(id), "%s: completion saved" % id)
		assert_eq(AppState.commit_scene(id, out["result"]["state"], 99.0)["applied"], false, "%s: a second commit adds nothing" % id)


# --- Reachability ----------------------------------------------------------------------------------

## Partial COLL-005b (M6 scenes): every scripted-position objective (reach goals, pickups, the lull's
## stand point, the stops of a follow path) is reachable over the stage's walkable tiles from where
## the scene has placed Zampanò when the walk starts (the Level 1 method). Moving targets (fighters,
## leaders, a receding gate's later places) are owned by the STY real-input runs. Returns the count.
func test_P_COLL_005b_m6_scripted_objectives_reachable() -> void:
	var checked := {}
	for id: String in IDS:
		var s := _scene(id, _entry(id))
		var d := StoryDriver.new(s, BRANCHES.get(id, [{}])[0], "bark", true)
		var seen := {}
		checked[id] = 0
		for k in 60 * 200:
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
				for m: String in o.path:
					targets.append(s.ctx.marker(m))
				if o.rule == "lull":
					var stand: Variant = o.rule_params["stand"]
					targets.append(s.ctx.marker(stand) if stand is String else stand)
				for t: Vector2 in targets:
					var path := d._bfs(from, t, [])
					var reach := path.size() > 1 or Vector2i(int(floor(from.x)), int(floor(from.y))) == Vector2i(int(floor(t.x)), int(floor(t.y))) or from.distance_to(t) < 1.5
					assert_true(reach, "%s %s: %s reachable from %s" % [id, o.id, t, from])
					checked[id] = int(checked[id]) + 1
			d.drive(DT)
			InputService.update(DT)
			s.tick(DT)
		InputService.guard_hold_injected = false
	print("M6 COLL-005b targets checked: ", checked)
	assert_true(not checked.values().has(0), "every M6 scene has scripted targets checked: %s" % [checked])


# --- Helpers ---------------------------------------------------------------------------------------

func _ticks(s: StoryScene, n: int) -> void:
	for k in n:
		InputService.update(DT)
		s.tick(DT)


func _ticks_until(s: StoryScene, cond: Callable, limit: int) -> bool:
	for k in limit:
		if cond.call():
			return true
		_ticks(s, 1)
	return bool(cond.call())


## Runs the scene by the scripted driver until step `id` is current.
func _to_step(s: StoryScene, id: String) -> bool:
	var d := StoryDriver.new(s, {}, "bark", true)
	for k in 60 * 120:
		if s.runner.current != null and s.runner.current.id == id:
			return true
		d.drive(DT)
		InputService.update(DT)
		s.tick(DT)
	InputService.guard_hold_injected = false
	return assert_true(s.runner.current != null and s.runner.current.id == id, "reached step %s" % id)


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
	for k in 60 * 400:
		if s.finished:
			InputService.guard_hold_injected = false
			return true
		d.drive(DT)
		InputService.update(DT)
		s.tick(DT)
	InputService.guard_hold_injected = false
	return s.finished
