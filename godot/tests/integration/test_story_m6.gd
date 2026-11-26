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
const IDS := ["2.1", "2.2", "2.3", "3.1", "3.2", "3.3", "3.4", "4.1", "4.2", "4.3"]
## Choices a run takes (choice id -> option id) and the branches the snapshots cover.
const BRANCHES := {"2.2": [{"s13": "glad"}, {"s13": "proud"}]}
## What each scene commits on top of its entry state: meter deltas, flags, abilities, how many book
## entries of each kind (by branch, keyed "<id>" or "<id>/<option>").
const SNAP := {
	"2.1": {"meters": {}, "flags": {}, "abilities": [], "book": {"remembered": 1}},
	"2.2/glad": {"meters": {"commozione": 9, "grace": 5, "standing": 2}, "flags": {"vow": true}, "abilities": ["sermon"], "book": {"remembered": 1}},
	"2.2/proud": {"meters": {"commozione": 6, "grace": 5, "supervillain": 3, "standing": -2}, "flags": {"vow": true}, "abilities": ["sermon"], "book": {"remembered": 1}},
	"2.3": {"meters": {"supervillain": 8}, "flags": {}, "abilities": ["knight"], "book": {"remembered": 1}},
	"3.1": {"meters": {"commozione": 9}, "flags": {}, "abilities": [], "book": {"marvels": 3, "items": 1, "remembered": 1}},
	"3.2": {"meters": {}, "flags": {"shortfall": 36000}, "abilities": [], "book": {"remembered": 1}},
	"3.3": {"meters": {"commozione": 10}, "flags": {"weptWell": true}, "abilities": [], "book": {"remembered": 1}},
	"3.4": {"meters": {}, "flags": {"zaraDeal": true}, "abilities": [], "book": {"remembered": 1}},
	"4.1": {"meters": {"commozione": 8}, "flags": {}, "abilities": [], "book": {"marvels": 1, "remembered": 1}},
	"4.2": {"meters": {"commozione": 4}, "flags": {}, "abilities": [], "book": {"remembered": 1}},
	"4.3": {"meters": {"commozione": 4}, "flags": {"heardZara": true}, "abilities": [], "book": {"remembered": 1}},
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
			var sc: StoryScene = out["scene"]
			assert_eq([sc.ctx.metrics["caught"], sc.ctx.metrics["knockdowns"]], [[], []], "%s/%s: never caught, never knocked down" % [id, branch])
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


# --- Level 3 -------------------------------------------------------------------------------------------

## Plays `s` with the real-input driver until `cond` holds (or the scene ends).
func _drive_until(s: StoryScene, cond: Callable, limit: int = 60 * 120, policy: Dictionary = {}) -> bool:
	var d := StoryDriver.new(s, policy)
	for k in limit:
		if cond.call():
			InputService.guard_hold_injected = false
			return true
		if s.finished:
			break
		d.drive(DT)
		InputService.update(DT)
		s.tick(DT)
	InputService.guard_hold_injected = false
	return bool(cond.call())


## STY-301: 3.1 — following Pierre along the quay while the harbour bell clangs over the water
## (the sounder: CLONG at the bell every 1.6 s); LOOK (the walk's own action) says OOOH; the three
## marvels go into the book, each once (a second pass awards nothing); MERAVIGLIA is received; the
## three empty berths are counted.
func test_STY_301_quay_bell_marvels_once_meraviglia_and_berths() -> void:
	var s := _scene("3.1", _entry("3.1"))
	assert_true(_drive_until(s, func() -> bool: return s.runner.current != null and s.runner.current.id == "s04"), "past the quay")
	assert_true((s.ctx.metrics.get("sounds", []) as Array).count("s03") >= 3, "the bell rang along the quay (%d)" % (s.ctx.metrics.get("sounds", []) as Array).count("s03"))
	InputService.trigger(&"pee")
	_ticks(s, 1)
	assert_true(s.hud.floats.any(func(f: Dictionary) -> bool: return f["text"] == "OOOH."), "LOOK: OOOH.")
	assert_true(_drive_until(s, func() -> bool: return s.runner.current != null and s.runner.current.id == "s07"), "the ships looked at")
	var book: Dictionary = s.ctx.state["book"]
	var marvels: Array = book["marvels"]
	marvels.sort()
	assert_eq(marvels, ["THE GALLEYS", "THE GREAT SHIPS", "THE HORSE TRANSPORTS"], "three marvels")
	assert_eq(book["items"], ["MERAVIGLIA, THE BOOK OF MARVELS"], "Meraviglia received")
	assert_eq(s.ctx.state["meters"]["commozione"], _entry("3.1")["meters"]["commozione"] + 9.0, "Commozione +3 per marvel")
	# A second pass over the same marvels awards nothing (unique book entries).
	var again := CampaignRules.apply_effects(s.ctx.state, {"marvel": "THE GALLEYS"})
	assert_eq([again, (s.ctx.state["book"]["marvels"] as Array).count("THE GALLEYS")], [[], 1], "a marvel is awarded once")
	# Replay on a state that already holds them: no duplicates.
	var full := _entry("3.1")
	full["book"]["marvels"] = ["THE HORSE TRANSPORTS", "THE GALLEYS", "THE GREAT SHIPS"]
	full["book"]["items"] = ["MERAVIGLIA, THE BOOK OF MARVELS"]
	var out := _play("3.1", full, {}, true)
	assert_true(out.has("result"), "3.1 again")
	if out.has("result"):
		assert_eq([(out["result"]["state"]["book"]["marvels"] as Array).size(), (out["result"]["state"]["book"]["items"] as Array).size()], [3, 1], "no duplicate marvel or item")


## STY-302: 3.2 — the bowl carried (on his back, on the HUD) through two collections (six pilgrims,
## then five lords), both chroniclers' counts kept apart (Clari's 50,000 and 36,000 on the cards, the
## marshal's 34,000 in his line), the bowl handed over, and `shortfall` = 36000 (Clari's count, as
## authored) set once.
func test_STY_302_two_collections_two_counts_and_the_shortfall() -> void:
	var s := _scene("3.2", _entry("3.2"))
	assert_true(_drive_until(s, func() -> bool: return s.runner.current != null and s.runner.current.id == "s06"), "at the first collection")
	assert_eq([s.ctx.carrying, s.hud.carry_label], ["THE COLLECTING BOWL", "THE COLLECTING BOWL"], "the bowl is carried")
	var cards := []
	var lines := []
	var d := StoryDriver.new(s)
	var out := {}
	s.completed.connect(func(r: Dictionary) -> void: out["r"] = r)
	for k in 60 * 120:
		if out.has("r"):
			break
		if s.hud.card_visible and not cards.has(s.hud.card_big):
			cards.append(s.hud.card_big)
		if s.hud.line_visible and not lines.has(s.hud.full_text):
			lines.append(s.hud.full_text)
		if s.runner.current != null and s.runner.current.id == "s13":
			assert_eq(s.ctx.carrying, "", "the bowl handed over")
		d.drive(DT)
		InputService.update(DT)
		s.tick(DT)
	assert_true(out.has("r"), "3.2 completes")
	assert_eq(cards, ["50,000 STILL OWED", "36,000 STILL OWED"], "Clari's two counts, in order")
	assert_true(lines.has("THIRTY-FOUR THOUSAND STILL OWED.") and lines.has("I COUNTED THIRTY-SIX."), "the marshal's count and Zampano's, side by side")
	if out.has("r"):
		assert_eq(out["r"]["state"]["flags"]["shortfall"], 36000, "shortfall: Clari's 36,000, as authored")
		assert_eq(s.runner.trace.count("s06") + s.runner.trace.count("s09"), 2, "two collections")


## STY-303 and WALK-015: 3.3 — at the front of the envoys he kneels and weeps; under the trumpets a
## sob is lost; in a lull it is heard: the first moves one Venetian (his notice), the second the
## whole square, each Commozione +5; `weptWell` set once; the unused weeping() minigame does not
## exist in the port.
func test_STY_303_weeping_in_the_lulls_moves_the_square() -> void:
	var s := _scene("3.3", _entry("3.3"))
	assert_true(_drive_until(s, func() -> bool: return s.runner.current != null and s.runner.current.id == "s05"), "kneeling at the front")
	var st: Dictionary = s.runner.st
	_ticks_until(s, func() -> bool: return bool(s.runner.st.get("talking", false)), 300)
	InputService.trigger(&"action")
	_ticks(s, 1)
	assert_eq([int(st["good"]), (s.ctx.metrics["notices"] as Array).has("A SOB UNDER A TRUMPET IS LOST. WAIT")], [0, true], "under the trumpets the sob is lost")
	assert_true(_drive_until(s, func() -> bool: return int(s.runner.st.get("good", 0)) >= 1), "a sob in a lull")
	assert_true((s.ctx.metrics["notices"] as Array).has("THE FIRST VENETIAN IS MOVED. HIS NEIGHBOUR LOOKS AT HIM"), "the first Venetian is moved")
	var out := {}
	s.completed.connect(func(r: Dictionary) -> void: out["r"] = r)
	assert_true(_drive_until(s, func() -> bool: return out.has("r"), 60 * 90), "the square answers; 3.3 completes")
	if out.has("r"):
		assert_eq([out["r"]["state"]["flags"].get("weptWell"), out["r"]["state"]["meters"]["commozione"]], [true, _entry("3.3")["meters"]["commozione"] + 10.0], "weptWell; Commozione +5 per heard sob")
	assert_false(ResourceLoader.exists("res://story/minigames/weeping_game.gd"), "no weeping() minigame")
	var mini_files: PackedStringArray = DirAccess.get_files_at("res://story/minigames") if DirAccess.dir_exists_absolute("res://story/minigames") else PackedStringArray()
	for f: String in mini_files:
		assert_false(FileAccess.get_file_as_string("res://story/minigames/" + f).contains("weeping"), f + ": no weeping game")


## WALK-010–013 (rules): a watcher sees within its range and cone and only with a clear line of sight
## (walls and tall props block it); in a bush, or by a hiding spot a scene placed, he is seen only from
## within BUSH_HIDE; on a stealth walk a full cone or a hostile's touch catches him.
func test_WALK_010_013_sight_cone_range_los_hiding_and_contact() -> void:
	var m: StoryMapData = load("res://data/story/maps/neighborhood.tres")
	var map := WorldMapModel.new(m.parse()["level"])
	var w := StoryActor.new()
	w.sight_range = 5.0
	w.sight_half_angle = 0.5
	w.gx = 2.5
	w.gy = 9.5
	w.face("E")
	w.facing_vec = Vector2(1, 0)
	assert_true(StorySight.can_see(map, w, 5.5, 9.5), "in front, in range, clear: seen")
	assert_false(StorySight.can_see(map, w, 8.5, 9.5), "beyond the range")
	assert_false(StorySight.can_see(map, w, 4.5, 11.5), "outside the cone")
	assert_false(StorySight.can_see(map, w, 1.5, 9.5), "behind")
	assert_true(StorySight.can_see(map, w, 2.9, 9.0), "right next to him: seen whatever the cone")
	# The bush at (7, 9): from 5 tiles, hidden; a hiding spot placed by the scene hides likewise.
	w.gx = 2.5
	assert_false(StorySight.can_see(map, w, 7.5, 9.5), "in a bush (beyond BUSH_HIDE): hidden")
	w.gx = 6.6
	assert_true(StorySight.can_see(map, w, 7.5, 9.5), "in a bush but within BUSH_HIDE: seen")
	w.gx = 2.5
	assert_true(StorySight.can_see(map, w, 5.5, 9.5), "open ground")
	assert_false(StorySight.can_see(map, w, 5.5, 9.5, [Vector2(5.6, 9.4)]), "by a hiding spot: hidden")
	# Line of sight: the wall row 6 blocks a watcher below it from seeing above it.
	var v := StoryActor.new()
	v.sight_range = 6.0
	v.sight_half_angle = 0.8
	v.gx = 4.5
	v.gy = 8.5
	v.facing_vec = Vector2(0, -1)
	assert_false(StorySight.line_of_sight(map, 4.5, 8.5, 4.5, 4.5), "the wall blocks the line")
	assert_false(StorySight.can_see(map, v, 4.5, 4.5), "so he is not seen through it")
	w.free()
	v.free()


## STY-304, WALK-010–014 (in play): 3.4 — the guard's cone fills while he is in it; a full cone shows
## A GUARD SAW YOU and sends him back to the walk's start (or, once passed, the checkpoint by the
## tents), cones emptied; the seller waits while he lags and walks on when he catches up; a hostile's
## touch catches him too; the real-input driver then follows unseen to the awning, overhears five
## seconds, finds the gangplank by the bell's sound (no ring), and the Zara deal is in the working copy
## only (the save gets it with the completion, once).
func test_STY_304_stealth_detection_checkpoint_recovery_and_the_deal() -> void:
	var entry := _entry("3.4")
	SaveService.save_campaign(entry, NOW - 1000)
	var s := _scene("3.4", AppState.story_entry_state())
	assert_true(_drive_until(s, func() -> bool: return s.runner.current != null and s.runner.current.id == "s11"), "at the stealth walk")
	var st: Dictionary = s.runner.st
	var start: Vector2 = st["start"]
	var g: StoryActor = s.actors["g1"]
	var seller: StoryActor = s.actors["seller"]
	# Detection: stand in front of the guard, in his cone.
	g.set_grid_position(13.5, 13.5)
	g.set_idle()
	g.face("S")
	g.facing_vec = Vector2(0, 1)
	s.world.player.set_grid_position(13.5, 15.0)
	assert_true(_ticks_until(s, func() -> bool: return g.alert > 0.3, 120), "the cone fills while he is in it")
	assert_true(_ticks_until(s, func() -> bool: return s.runner.st.has("interrupt"), 120), "caught when it is full")
	assert_eq([s.hud.card_big, s.ctx.metrics["caught"]], ["A GUARD SAW YOU", ["s11"]], "the caught card")
	assert_true(_ticks_until(s, func() -> bool: return not s.runner.st.has("interrupt"), 200), "the card passes")
	assert_vec_near(s.ctx.player_pos(), start, 0.01, "back at the walk's start")
	assert_eq(g.alert, 0.0, "the cones emptied")
	# A hostile's touch catches him as well.
	g.hostile = true
	g.set_grid_position(s.ctx.player_pos().x + 0.3, s.ctx.player_pos().y)
	g.sight_range = 0.0
	_ticks(s, 1)
	assert_true(s.runner.st.has("interrupt"), "a hostile's touch catches him")
	_ticks_until(s, func() -> bool: return not s.runner.st.has("interrupt"), 200)
	g.hostile = false
	# (The guard looks away while the leader and the checkpoint are checked.)
	g.sight_range = 0.0
	g.patrol([s.ctx.marker("5"), s.ctx.marker("8")], 1.0, 1.2)
	# The seller waits while he lags (WALK-014).
	assert_true(_ticks_until(s, func() -> bool: return bool(s.runner.st.get("waiting", false)), 400), "the seller waits for him")
	var held := Vector2(seller.gx, seller.gy)
	_ticks(s, 30)
	assert_vec_near(Vector2(seller.gx, seller.gy), held, 0.01, "and stays put while he lags")
	s.world.player.set_grid_position(seller.gx + 0.9, seller.gy)
	_ticks(s, 2)
	assert_eq([bool(s.runner.st["waiting"]), seller.behavior], [false, "goto"], "he catches up: the seller walks on")
	_ticks(s, 20)
	assert_true(Vector2(seller.gx, seller.gy).distance_to(held) > 0.2, "and moves")
	# The checkpoint: once passed it is where a capture sends him.
	var cp := s.ctx.marker("1")
	s.world.player.set_grid_position(cp.x, cp.y)
	_ticks(s, 1)
	assert_vec_near(s.runner.st["start"], cp, 0.01, "checkpoint passed: the restart point")
	s.world.player.set_grid_position(start.x, start.y)
	g.sight_range = 3.0
	# Then the real-input driver follows unseen, overhears and finds the gangplank by ear.
	var caught_before := (s.ctx.metrics["caught"] as Array).size()
	var hidden_ok := [false]
	var out := {}
	s.completed.connect(func(r: Dictionary) -> void: out["r"] = r)
	var d := StoryDriver.new(s)
	for k in 60 * 180:
		if out.has("r"):
			break
		if s.runner.current != null and s.runner.current.id == "s19" and not hidden_ok[0]:
			hidden_ok[0] = not s.runner.st.has("goal_node")
		if s.runner.current != null and s.runner.current.id == "s18":
			assert_eq([s.ctx.state["flags"].get("zaraDeal"), SaveService.get_campaign()["flags"].get("zaraDeal")], [true, null], "the deal is in the working copy, not the save")
		d.drive(DT)
		InputService.update(DT)
		s.tick(DT)
	assert_true(out.has("r"), "3.4 completes by real input")
	assert_true(hidden_ok[0], "the gangplank has no ring: found by the bell")
	print("3.4 captures after the forced ones: ", (s.ctx.metrics["caught"] as Array).size() - caught_before)
	if out.has("r"):
		assert_eq(SaveService.get_campaign()["flags"].get("zaraDeal"), null, "nothing saved before the completion")
		var r := AppState.commit_scene("3.4", out["r"]["state"], float(out["r"]["play_time"]))
		assert_eq([r["saved"], SaveService.get_campaign()["flags"].get("zaraDeal")], [true, true], "the deal commits with the completion")


## WALK-016–017: a hidden sound goal shows no ring and sounds at the goal; movement modifiers: a
## no-run walk refuses RUN (2.1), heavy mail walks at 0.8 unless he runs (2.3).
func test_WALK_016_017_hidden_sound_goal_and_movement_modifiers() -> void:
	var s := _scene("3.4", _entry("3.4"))
	assert_true(_to_step(s, "s19"), "at the bell walk")
	assert_false(s.runner.st.has("goal_node"), "no ring at the hidden goal")
	_ticks(s, 2)
	var goal: Vector2 = s.runner.st["goal"]
	assert_true(s.hud.floats.any(func(f: Dictionary) -> bool: return f["text"] == "CLONG." and (f["at"] as Vector2).distance_to(goal) < 0.01), "the sound pops at the goal")
	var a := _scene("2.1", _entry("2.1"))
	assert_true(_to_step(a, "s06"), "2.1's walk")
	InputService.inject_move(0.0, -1.0, true)
	_ticks(a, 30)
	assert_eq([a.ctx.no_run, a.world.player.running, a.controls.can_run], [true, false, false], "no-run: RUN refused, no RUN button")
	InputService.clear_injection()
	var b := _scene("2.3", _entry("2.3"))
	assert_true(_to_step(b, "s19"), "2.3's charge")
	InputService.inject_move(0.0, -1.0, false)
	_ticks(b, 40)
	assert_eq([b.world.player.speed_mul, b.world.player.running], [0.8, false], "walking in mail: 0.8")
	InputService.inject_move(0.0, -1.0, true)
	_ticks(b, 5)
	assert_eq([b.world.player.speed_mul, b.world.player.running], [1.0, true], "charging: full speed")
	InputService.clear_injection()


## The Meraviglia book: opened from the level list and OPTIONS, it shows the committed campaign's
## meters, things, marvels, values, scraps and remembered lines, paged by height (a heading is never
## left alone at a page's foot); NEXT, PREV, a tap on the page and BACK work; replaying a scene
## changes nothing it shows.
func test_SLICE_meraviglia_book_opens_pages_and_persists() -> void:
	var st := _entry("3.2")
	st["book"]["marvels"] = ["THE HORSE TRANSPORTS", "THE GALLEYS", "THE GREAT SHIPS"]
	st["book"]["items"] = ["MERAVIGLIA, THE BOOK OF MARVELS"]
	st["book"]["remembered"] = ["THERE WAS A CITY, AND IT WAS ALWAYS ONE STEP FURTHER ON.", "THERE WAS A LIST, AND MY NAME WAS AT THE BOTTOM OF IT.", "THERE WAS A COAT OF MAIL, AND I WAS SOMEWHERE INSIDE IT.", "THERE WERE SHIPS, AND THEY WERE TALLER THAN THE CHURCH."]
	st["book"]["shards"] = ["A FLEET BOUGHT ON CREDIT", "A KNIGHT WHO KEPT WALKING", "A CITY SEEN FROM ITS WALLS"]
	SaveService.save_campaign(st, NOW - 1000)
	await _main_start()
	await _settle()
	main.clear_overlays()
	main.open_levels()
	var levels := main.top_overlay() as LevelListOverlay
	levels.actions["book"].call()
	var b := main.top_overlay() as MeravigliaOverlay
	if not assert_true(b != null, "the book opens from the level list"):
		return
	await tree.process_frame
	await tree.process_frame
	assert_true(b.pages.size() >= 2, "several pages (%d)" % b.pages.size())
	var all := ""
	for p: Array in b.pages:
		assert_false(bool((p.back() as Dictionary)["head"]), "no heading alone at a page's foot")
		for r: Dictionary in p:
			all += String(r["text"]) + "\n"
	for want: String in ["COMMOZIONE %s" % CampaignSchema.clean_number(float(st["meters"]["commozione"])), "THE GALLEYS", "MERAVIGLIA, THE BOOK OF MARVELS", "\"THERE WERE SHIPS, AND THEY WERE TALLER THAN THE CHURCH.\"", "A FLEET BOUGHT ON CREDIT", "NOTHING IN THE BOOK YET."]:
		assert_true(all.contains(want), "the book lists %s" % want)
	b.time = 1.0
	b.next_page()
	assert_eq(b.page, 1, "NEXT")
	b.prev_page()
	assert_eq(b.page, 0, "PREV")
	b.on_tap(Vector2(20, 60))
	assert_eq(b.page, 1, "a tap on the page turns it")
	b.close()
	assert_false(main.top_overlay() is MeravigliaOverlay, "BACK closes it")
	main.clear_overlays()
	main.open_options()
	(main.top_overlay() as OptionsOverlay).actions["book"].call()
	assert_true(main.top_overlay() is MeravigliaOverlay, "and from OPTIONS")


# --- Level 4 and the minigames ------------------------------------------------------------------------

const RS := GameConfig.Story


## MINI-001 (rules): beats are deterministic (k × 60/bpm, from −START_DELAY); a press within the
## window of an unjudged beat is a hit, a second press on the same beat is "too early" (no double
## count), a press away from every beat is "too early", an unpressed beat is a miss once its window
## has passed; the result comes RESULT_AFTER the last beat: won with `need` hits, otherwise lost.
func test_MINI_001_rhythm_windows_errors_and_result() -> void:
	var g := RhythmGame.new().setup(4, 60.0, 3)
	assert_eq([g.time, g.beat_at(0), g.beat_at(3)], [-RS.RHYTHM_START_DELAY, 0.0, 3.0], "deterministic beats")
	var step := 1.0 / 60.0
	var r := ""
	var pressed := {}
	var early_done := false
	while r != "won" and r != "lost":
		var press := false
		var n := g.nearest()
		var k := int(n[0])
		if k == 0 and not pressed.has(0) and absf(g.time + step - g.beat_at(0)) <= RS.RHYTHM_WINDOW - 0.02:
			press = true
			pressed[0] = true
		elif k == 0 and pressed.has(0) and not pressed.has("again") and g.judged.has(0):
			press = true
			pressed["again"] = true
		elif not early_done and g.time > 0.5 and g.time < 0.6:
			press = true
			early_done = true
		elif (k == 2 or k == 3) and not pressed.has(k) and absf(g.time + step - g.beat_at(k)) <= 0.02:
			press = true
			pressed[k] = true
		r = g.update(step, press)
	assert_eq([g.judged, g.hits], [{0: true, 1: false, 2: true, 3: true}, 3], "hit, miss (unpressed), hit, hit; no double count")
	assert_eq(r, "won", "three hits of four: won")
	assert_true(g.time >= g.beat_at(3) + RhythmGame.RESULT_AFTER, "the result after the last beat")
	var lost := RhythmGame.new().setup(4, 60.0, 3)
	var lr := ""
	while lr != "won" and lr != "lost":
		lr = lost.update(step, false)
	assert_eq([lr, lost.hits, lost.judged.values().count(false)], ["lost", 0, 4], "no presses: four misses, lost")
	# Through real input (4.1's parade): the driver presses on the cues it sees and wins; with no press
	# it is lost: each result's exact effect once, the game run once, the scene advanced once.
	var entry := _entry("4.1")
	for pair: Array in [[true, "parade:won", 8.0], [false, "parade:lost", 2.0]]:
		var out := _mini_run("4.1", pair[0])
		if not assert_true(out.has("r"), "4.1 %s completes" % pair[1]):
			continue
		var sc: StoryScene = out["scene"]
		assert_eq([sc.ctx.metrics["minis"], sc.runner.trace.count("s07"), sc.runner.trace.count("s08")], [[pair[1]], 1, 1], "%s: one result, one game, one advance" % pair[1])
		assert_eq(float(out["r"]["state"]["meters"]["commozione"]) - float(entry["meters"]["commozione"]), pair[2], "%s: its exact effect once" % pair[1])


func _mini_run(id: String, plays: bool, policy: Dictionary = {}) -> Dictionary:
	var s := _scene(id, _entry(id))
	var out := {"scene": s}
	s.completed.connect(func(r: Dictionary) -> void: out["r"] = r)
	var d := StoryDriver.new(s, policy)
	d.plays_minigames = plays
	var views := 0
	for k in 60 * 200:
		if out.has("r"):
			break
		if s.runner.current is MiniGameStep and s.hud.get_parent().has_node("MiniGameView"):
			views = maxi(views, s.hud.get_parent().get_children().filter(func(c: Node) -> bool: return c is MiniGameView).size())
		d.drive(DT)
		InputService.update(DT)
		s.tick(DT)
	out["views"] = views
	out["left"] = s.hud.get_parent().get_children().filter(func(c: Node) -> bool: return c is MiniGameView).size()
	return out


## MINI-002: 4.1's parade (VENI CREATOR, RAISE on every beat): played on the beat it is won
## (Commozione +8 and the fleet's marvel); with no press it is lost (Commozione +2 and the marvel):
## each result's effects once, and the scene goes on either way.
func test_MINI_002_parade_rhythm_won_and_lost_effects() -> void:
	var entry := _entry("4.1")
	var won := _mini_run("4.1", true)
	var lost := _mini_run("4.1", false)
	for pair: Array in [[won, 8.0, "won"], [lost, 2.0, "lost"]]:
		var out: Dictionary = pair[0]
		if not assert_true(out.has("r"), "4.1 %s: completes" % pair[2]):
			continue
		var st: Dictionary = out["r"]["state"]
		assert_eq([st["meters"]["commozione"] - entry["meters"]["commozione"], st["book"]["marvels"].count("THE FLEET LEAVING VENICE")], [pair[1], 1], "4.1 %s: its effects, once" % pair[2])
		assert_eq(((out["scene"] as StoryScene).ctx.metrics["minis"] as Array), ["parade:" + String(pair[2])], "4.1 %s: one game, one result" % pair[2])


## MINI-003: 4.3's rowing (ROW, 8 BPM slower than the parade): won +4, lost +1; `heardZara` is set
## either way before it; the scene goes on to Zara.
func test_MINI_003_rowing_rhythm_won_and_lost_effects() -> void:
	var entry := _entry("4.3")
	var won := _mini_run("4.3", true)
	var lost := _mini_run("4.3", false)
	var row := (StoryLibrary.scene("4.3").steps.filter(func(x: StoryStep) -> bool: return x is MiniGameStep)[0] as MiniGameStep).rhythm()
	assert_eq([row.bpm, row.beats, row.need], [RS.PARADE_BPM - RS.ROWING_BPM_DROP, RS.PARADE_BEATS, RS.PARADE_NEED], "the rowing's numbers")
	for pair: Array in [[won, 4.0, "won"], [lost, 1.0, "lost"]]:
		var out: Dictionary = pair[0]
		if not assert_true(out.has("r"), "4.3 %s: completes" % pair[2]):
			continue
		var st: Dictionary = out["r"]["state"]
		assert_eq([st["meters"]["commozione"] - entry["meters"]["commozione"], st["flags"].get("heardZara")], [pair[1], true], "4.3 %s: its effect once; heardZara" % pair[2])
		assert_eq((out["scene"] as StoryScene).runner.trace.count("s09"), 1, "4.3 %s: the game ran once (no automatic retry)" % pair[2])


## MINI-004: the game's view and result are cleaned up on a win and on a loss (no view left, no
## second result); a loss advances once; a restart from the pause in the middle of a game removes its
## view and plays it again from the start, nothing applied twice; the dormant weeping() game is absent.
func test_MINI_004_cleanup_loss_continuation_and_restart() -> void:
	var lost := _mini_run("4.1", false)
	assert_eq([lost["views"], lost["left"]], [1, 0], "one view while it runs, none after")
	var s := _scene("4.1", _entry("4.1"))
	if not _to_step(s, "s07"):
		return
	_ticks(s, 120)
	var g: RhythmGame = s.runner.st["game"]
	assert_true(g.time > 0.0, "the game is running")
	s.open_pause()
	s.restart()
	assert_eq(s.hud.get_parent().get_children().filter(func(c: Node) -> bool: return c is MiniGameView).size(), 0, "restart removed the view")
	var out := {}
	s.completed.connect(func(r: Dictionary) -> void: out["r"] = r)
	var d := StoryDriver.new(s)
	for k in 60 * 120:
		if out.has("r"):
			break
		d.drive(DT)
		InputService.update(DT)
		s.tick(DT)
	assert_true(out.has("r"), "4.1 completes after the restart")
	if out.has("r"):
		assert_eq([out["r"]["state"]["meters"]["commozione"] - _entry("4.1")["meters"]["commozione"], s.ctx.metrics["minis"]], [8.0, ["parade:won"]], "one result, applied once")
	assert_false(ResourceLoader.exists("res://story/minigames/weeping_game.gd"), "the dormant weeping() game is not ported")
	for game_id: String in MiniGameStep.GAMES:
		assert_true(["parade", "rowing", "boat", "ladders", "letter", "rumour", "tug"].has(game_id), game_id + " is one of the campaign's own games (no framework)")


## MINI-005: 4.2's skiff: strokes closer than BOAT_MIN_GAP slosh water in; a full boat swamps it (half
## the distance lost, BOAT_SWAMP_TIME without strokes); gentle strokes bring it alongside: won,
## Commozione +4 once; there is no lost result.
func test_MINI_005_boat_alignment_objective_and_result() -> void:
	var b := BoatGame.new()
	var step := 1.0 / 60.0
	b.update(step, 1)
	assert_eq([b.events, b.progress], [["stroke"], RS.BOAT_STROKE], "a stroke moves it closer")
	b.update(step, 1)
	assert_eq([b.events, b.water], [["splash"], RS.BOAT_SPLASH - RS.BOAT_DRAIN * step], "too soon: water in")
	for k in 4:
		b.update(step, 1)
	assert_true(b.events.has("swamped") or b.swamped_t > 0.0, "a full boat swamps")
	assert_true(b.progress < RS.BOAT_STROKE and b.swamped_t > 0.0, "half the distance lost, a pause")
	var before := b.progress
	b.update(step, 1)
	assert_eq(b.progress, before, "no strokes while swamped")
	var g := BoatGame.new()
	var r := ""
	var t := 0.0
	var next := 0.0
	while r != "won" and t < 60.0:
		var n := 0
		if t >= next:
			n = 1
			next = t + RS.BOAT_MIN_GAP * 1.1
		r = g.update(step, n)
		t += step
	assert_eq([r, g.water], ["won", 0.0], "gentle strokes: alongside, dry")
	var out := _mini_run("4.2", true)
	assert_true(out.has("r"), "4.2 completes")
	if out.has("r"):
		assert_eq(out["r"]["state"]["meters"]["commozione"] - _entry("4.2")["meters"]["commozione"], 4.0, "Commozione +4 once")
		assert_eq(((out["scene"] as StoryScene).ctx.metrics["minis"] as Array), ["boat:won"], "won")
	var data := StoryLibrary.scene("4.2")
	var mg: MiniGameStep = data.steps.filter(func(x: StoryStep) -> bool: return x is MiniGameStep)[0]
	assert_eq([mg.game, mg.lines["objective"], mg.lost_effects], ["boat", "EASE THE SKIFF ALONGSIDE THE TRANSPORT WITHOUT SWAMPING IT", {}], "the objective; no lost result")


## STY-401–403: 4.1 Watson walks beside him to the bow before the parade; 4.2 the three horses are
## fed (three spots), the hay and water carried and dropped, and Watson's bucket moves out of reach
## with its CLONG; 4.3 four rumours asked, the marshal names Zara, `heardZara`, the rowing, the eve
## of Saint Martin.
func test_STY_401_403_deck_horses_bucket_and_rumours() -> void:
	var s := _scene("4.1", _entry("4.1"))
	assert_true(_drive_until(s, func() -> bool: return s.runner.current != null and s.runner.current.id == "s04"), "the deck walk")
	_ticks(s, 90)
	var w: StoryActor = s.actors["watson"]
	assert_eq(w.behavior, "follow", "Watson walks with him")
	assert_true(_drive_until(s, func() -> bool: return s.runner.current is MiniGameStep), "to the parade")
	assert_true(s.ctx.player_pos().distance_to(s.ctx.marker("3")) < 1.0, "at the bow")
	var h := _scene("4.2", _entry("4.2"))
	assert_true(_drive_until(h, func() -> bool: return h.runner.current != null and h.runner.current.id == "s08"), "feeding")
	assert_eq([h.ctx.carrying, h.props.has("horse1"), h.props.has("horse2"), h.props.has("horse3")], ["HAY AND WATER", true, true, true], "carrying hay and water; three horses")
	assert_true(_drive_until(h, func() -> bool: return h.runner.current != null and h.runner.current.id == "s11"), "fed")
	assert_eq(h.ctx.carrying, "", "dropped")
	var bucket: StoryProp = h.props["bucket"]
	var at := Vector2(bucket.gx, bucket.gy)
	assert_true(_drive_until(h, func() -> bool: return h.runner.current != null and h.runner.current.id == "s13"), "Watson moves it")
	assert_vec_near(Vector2(bucket.gx, bucket.gy), at + Vector2(1.6, 0.8), 1e-6, "just out of reach")
	assert_true(h.hud.floats.any(func(f: Dictionary) -> bool: return f["text"] == "CLONG."), "CLONG.")
	var r := _scene("4.3", _entry("4.3"))
	var out := {}
	r.completed.connect(func(x: Dictionary) -> void: out["r"] = x)
	var d := StoryDriver.new(r)
	for k in 60 * 120:
		if out.has("r"):
			break
		d.drive(DT)
		InputService.update(DT)
		r.tick(DT)
	var rumours := (r.data.steps.filter(func(x: StoryStep) -> bool: return x.id == "s03")[0] as ObjectiveStep).pickups.map(func(p: StoryPickup) -> String: return p.text)
	var heard := rumours.filter(func(t: String) -> bool: return (r.ctx.metrics["notices"] as Array).has(t))
	assert_eq([rumours.size(), heard.size()], [4, 4], "four rumours, each heard: %s" % [heard])
	assert_true(out.has("r") and out["r"]["state"]["flags"].get("heardZara") == true, "Zara named: heardZara")
	# The named results of each scene by real input.
	for row: Array in [["4.1", "parade:won", 8.0, "THE FLEET LEAVING VENICE"], ["4.2", "boat:won", 4.0, ""], ["4.3", "rowing:won", 4.0, ""]]:
		var res := _mini_run(row[0], true)
		if not assert_true(res.has("r"), "%s completes" % row[0]):
			continue
		var stt: Dictionary = res["r"]["state"]
		assert_eq([(res["scene"] as StoryScene).ctx.metrics["minis"], float(stt["meters"]["commozione"]) - float(_entry(row[0])["meters"]["commozione"])], [[row[1]], row[2]], "%s: %s and its effect" % [row[0], row[1]])
		if row[3] != "":
			assert_eq((stt["book"]["marvels"] as Array).count(row[3]), 1, "%s: the fleet's marvel once" % row[0])
		if row[0] == "4.2":
			assert_eq(((res["scene"] as StoryScene).runner.trace.count("s08")), 1, "4.2: the horses fed once")


# --- The campaign: 1.1 to 4.3 ----------------------------------------------------------------------------

## The scripted smoke through the whole build: 1.1 to 4.3 in catalog order on one campaign, each
## scene's result committed (one save each) before the next starts from the saved state.
func test_SLICE_scripted_smoke_1_1_through_4_3() -> void:
	var st := CampaignSchema.new_campaign()
	st["completed"] = ["1.0"]
	SaveService.save_campaign(st, NOW - 1000)
	var policies := {"1.3": {"s16": "paw"}, "1.5": {"s08": "one"}, "2.2": {"s13": "glad"}}
	var order := ["1.1", "1.2", "1.3", "1.4", "1.5"] + IDS
	for id: String in order:
		assert_eq(String(AppState.continue_target()["id"]), id, "CONTINUE points at " + id)
		var out := _play(id, AppState.story_entry_state(), policies.get(id, {}), true)
		if not assert_true(out.has("result"), "%s completes (%s)" % [id, out.get("error", "")]):
			return
		var r := AppState.commit_scene(id, out["result"]["state"], float(out["result"]["play_time"]))
		assert_true(r["saved"], id + ": saved")
	var camp := SaveService.get_campaign()
	assert_eq(String(AppState.continue_target()["id"]), "5.1", "then 5.1 (this build's boundary)")
	assert_eq([camp["abilities"], camp["flags"].get("vow"), camp["flags"].get("shortfall"), camp["flags"].get("weptWell"), camp["flags"].get("zaraDeal"), camp["flags"].get("heardZara")],
		[["cross", "sermon", "knight"], true, 36000, true, true, true], "every ability and flag of Levels 1–4, once")
	assert_eq((camp["book"]["remembered"] as Array).size(), 15, "fifteen remembered lines")
	assert_eq((camp["book"]["marvels"] as Array).size(), 4, "four marvels")


## Real-input autoplay through the real Main from 2.1 to 4.3: CONTINUE, each scene card, every scene
## played by the InputService driver (no teleports, no skips), each completion one save, each level's
## end (the Supervillained snap, the Professor's aside), and after 4.3 the explicit boundary of 5.1.
## The rewritten titles reach the cards, the level list, the chapter lists and the Couch.
func test_SLICE_real_input_autoplay_2_1_through_4_3_through_main() -> void:
	var st := _entry("2.1")
	SaveService.save_campaign(st, NOW - 1000)
	await _main_start()
	await _settle()
	(main.current_scene as TitleScreen).time = 1.0
	(main.current_scene as TitleScreen).activate(1)
	var asides := []
	for id: String in IDS:
		var s := await _enter_card(id)
		if s == null:
			return
		assert_eq(s.data.title, StoryLibrary.scene(id).title, id + ": the Resource's title")
		if not assert_true(_drive_to_end(s, BRANCHES.get(id, [{}])[0]), id + ": played to the end by real input"):
			return
		assert_eq([s.ctx.metrics["caught"], s.ctx.metrics["knockdowns"]], [[], []], id + ": never caught, never knocked down")
		var level := int(id.get_slice(".", 0))
		if id == "2.3" or id == "3.4" or id == "4.3":
			assert_true(await _until(func() -> bool: return main.top_overlay() is SupervillainedOverlay), id + ": the snap at the level's end")
			(main.top_overlay() as SupervillainedOverlay).step(GameConfig.Supervillained.HOLD + 0.05)
			assert_true(await _until(func() -> bool: return main.top_overlay() is MessageOverlay and main.top_overlay().has_meta(&"professor_aside")), id + ": the aside")
			var aside := main.top_overlay() as MessageOverlay
			assert_eq(aside.paragraphs[0][0], StoryLibrary.chapter(level).professor_aside, "Level %d's aside" % level)
			asides.append(level)
			aside.time = 1.0
			aside.on_tap(Vector2(5, 5))
		assert_true((SaveService.get_campaign()["completed"] as Array).has(id), id + ": saved")
	assert_eq(asides, [2, 3, 4], "three level ends")
	if StoryLibrary.has_scene("5.1"):
		assert_true(await _until(func() -> bool: return main.top_overlay() is MessageOverlay and main.top_overlay().get_meta(&"story_card", "") == "5.1"), "after 4.3: Level 5's first card (M7)")
	else:
		assert_true(await _until(func() -> bool: return main.top_overlay() is MessageOverlay and (main.top_overlay() as MessageOverlay).heading == "NOT IN THIS BUILD"), "after 4.3: the 5.1 boundary")
	# Titles in the menus come from the Resources.
	await _settle()
	main.clear_overlays()
	main.open_levels()
	for n in range(2, 5):
		(main.top_overlay() as LevelListOverlay).activate(n)
		var ch := main.top_overlay() as ChapterListOverlay
		var listed := []
		for it: Dictionary in ch.items:
			if it.has("id"):
				listed.append(String(it["id"]))
		var want := StoryLibrary.chapter(n).scenes.map(func(x: StorySceneData) -> String: return x.id)
		assert_eq(listed, want, "Level %d's list" % n)
		main.pop_overlay(ch)
	assert_true((SaveService.get_campaign()["completed"] as Array).has("4.3"), "the campaign has 4.3")


# --- M7 Phase 0: evidence for M6 ------------------------------------------------------------------

## WALK-014: the leader waits while he lags (LEAD_WAIT_DISTANCE) and walks on when he catches up
## (3.1's quay). WALK-015: a lull opens and closes (2.2): the voice alternates talk and quiet, a vow is
## counted only in the quiet, once per quiet.
func test_WALK_014_015_leader_wait_catch_up_and_lull_windows() -> void:
	var s := _scene("3.1", _entry("3.1"))
	if not _to_step(s, "s03"):
		return
	var lead: StoryActor = s.actors["pierre"]
	assert_true(_ticks_until(s, func() -> bool: return bool(s.runner.st.get("waiting", false)), 600), "he stands still: Pierre waits")
	var held := Vector2(lead.gx, lead.gy)
	_ticks(s, 60)
	assert_vec_near(Vector2(lead.gx, lead.gy), held, 0.01, "and stays while he lags")
	assert_true(Vector2(lead.gx, lead.gy).distance_to(s.ctx.player_pos()) > GameConfig.Story.LEAD_WAIT_DISTANCE, "lagging beyond the wait distance")
	s.world.player.set_grid_position(lead.gx + 1.0, lead.gy)
	_ticks(s, 2)
	assert_eq([bool(s.runner.st["waiting"]), lead.behavior], [false, "goto"], "caught up: he walks on")
	var l := _scene("2.2", _entry("2.2"))
	if not _to_step(l, "s04"):
		return
	l.world.player.set_grid_position(9.5, 10.5)
	var phases := []
	var counted := []
	for k in 60 * 12:
		var talking := bool(l.runner.st.get("talking", true))
		if phases.is_empty() or phases.back() != talking:
			phases.append(talking)
		if l.runner.current == null or l.runner.current.id != "s04":
			break
		var before := int(l.runner.st.get("good", 0))
		InputService.trigger(&"action")
		_ticks(l, 1)
		if l.runner.current != null and l.runner.current.id == "s04" and int(l.runner.st["good"]) > before:
			counted.append(talking)
		_ticks(l, 9)
	assert_true(phases.size() >= 4, "the voice talked and paused, again and again: %s" % [phases])
	assert_false(counted.has(true), "never counted while he talks")
	assert_true(counted.size() >= 1 and counted.size() <= phases.count(false), "at most one vow per quiet (%d vows, %d quiets)" % [counted.size(), phases.count(false)])


## The minigame boundary (M7 Phase 0): presses on the result's last frame (J, Space, Enter, B, Q, U, I
## through the real key path, and a touch) are drained with the game: nothing is pending after it,
## the next step (4.1's card) is not shortened, and the walk after it performs nothing.
func test_SLICE_minigame_result_frame_drains_every_edge() -> void:
	var s := _scene("4.1", _entry("4.1"))
	if not _to_step(s, "s07"):
		return
	assert_true(_ticks_until(s, func() -> bool: return String(s.runner.st.get("result", "")) != "" and float(s.runner.st["hold"]) <= 2.0 * DT, 60 * 30), "the result's last frames")
	await tree.process_frame
	for code: Key in [KEY_J, KEY_SPACE, KEY_ENTER, KEY_B, KEY_Q, KEY_U, KEY_I]:
		var e := InputEventKey.new()
		e.keycode = code
		e.physical_keycode = code
		e.pressed = true
		Input.parse_input_event(e)
	await tree.process_frame
	for code: Key in [KEY_J, KEY_SPACE, KEY_ENTER, KEY_B, KEY_Q, KEY_U, KEY_I]:
		var e := InputEventKey.new()
		e.keycode = code
		e.physical_keycode = code
		e.pressed = false
		Input.parse_input_event(e)
	await tree.process_frame
	InputService.pointer_down(7, Vector2(100, 400))
	InputService.pointer_up(7, Vector2(100, 400))
	_ticks(s, 3)
	assert_eq(s.runner.current.id, "s08", "the game ended; the card is up")
	for a: StringName in [&"action", &"pee", &"confirm", &"bark", &"switch", &"strike", &"guard"]:
		assert_false(InputService.consume(a), "%s drained" % a)
	assert_eq(InputService.consume_taps().size(), 0, "taps drained")
	_ticks(s, 60)
	assert_eq(s.runner.current.id, "s08", "the card is not shortened by a press on the result frame")


## CONTENT-003/004/005 over the M6+ Resources (chapters 2–8 as they exist): every metadata field;
## every text nonempty pixel-font capitals with no placeholder, matching its content_version's
## snapshot; no metadata on a player card or line.
func test_CONTENT_003_004_005_rewritten_resources_after_level_1() -> void:
	var snap: Dictionary = fixture("story_text_m6")
	var meta := PackedStringArray()
	for ch: StoryChapterData in StoryLibrary.chapters():
		if ch.number < 2:
			continue
		assert_true(ch.title != "" and ch.menu_title != "" and ch.intro != "" and ch.cast_note != "" and ch.professor_aside != "" and ch.music != "" and ch.content_version >= 1 and not ch.review_notes.is_empty(), "chapter %d: every field" % ch.number)
		meta.append(ch.cast_note)
		meta.append_array(ch.review_notes)
		for sc: StorySceneData in ch.scenes:
			var w := sc.id
			assert_true(sc.title != "" and sc.old_title != "" and sc.summary != "" and sc.map != "" and sc.music == ch.music and not sc.cast.is_empty(), "%s: title, old title, summary, map, music, cast" % w)
			assert_true(not sc.persistent_effects.is_empty() and ["scene", "chapter_end", "sleep", "ending"].has(String(sc.completion.get("boundary", ""))), "%s: effects, boundary" % w)
			assert_true(not sc.historical_tags.is_empty() and not sc.source_refs.is_empty() and not sc.review_notes.is_empty(), "%s: tags, sources, review notes" % w)
			assert_eq([sc.review_status, sc.technical_status], ["draft_implemented_review_pending", "technically_complete"], "%s: draft, technically complete" % w)
			meta.append_array(sc.source_refs)
			meta.append_array(sc.historical_tags)
			meta.append_array(sc.review_notes)
			var texts := _texts_of(sc.steps)
			texts.insert(0, sc.summary)
			var hc := HashingContext.new()
			hc.start(HashingContext.HASH_SHA256)
			hc.update("\n".join(texts).to_utf8_buffer())
			var sha := hc.finish().hex_encode()
			print("       text snapshot %s v%d %s" % [w, sc.content_version, sha])
			if not snap.has(w):
				fail("no text snapshot for %s" % w)
			else:
				assert_eq([sc.content_version, sha], [int(snap[w]["content_version"]), snap[w]["sha256"]], "%s: text snapshot of its content_version" % w)
			for t in texts:
				assert_true(t.strip_edges() != "" and t == t.to_upper(), "%s: '%s' is nonempty capitals" % [w, t])
				for marker in ["TODO", "TBD", "FIXME", "PLACEHOLDER", "LOREM", "XXX", "???", "[", "]", "{", "}", "%S", "%D", "REVIEW REQUIRED", "docs/", "RD-", "OQ-", "src/"]:
					assert_false(t.contains(marker), "%s: '%s' holds '%s'" % [w, t, marker])
	for ch: StoryChapterData in StoryLibrary.chapters():
		if ch.number < 2:
			continue
		var shown := PackedStringArray([ch.intro, ch.professor_aside])
		for sc: StorySceneData in ch.scenes:
			shown.append_array(_texts_of(sc.steps))
			shown.append(sc.summary)
		for t in shown:
			for m in meta:
				assert_false(m != "" and t.contains(m), "'%s' shows metadata '%s'" % [t, m])


static func _texts_of(steps: Array) -> PackedStringArray:
	var out := PackedStringArray()
	for s: StoryStep in steps:
		out.append_array(s.texts())
		for b: Array in s.branches():
			out.append_array(_texts_of(b))
	return out


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
