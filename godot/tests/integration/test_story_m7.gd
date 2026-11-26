extends TestCase
## M7: the rewritten Levels 5–8 and both endings (draft implemented, narrative review pending; OD-01)
## through the production StoryScene — the Resources validate in catalog order; every scene completes
## by the scripted smoke and by the real-input driver; the state each scene commits against the
## rewrite's snapshots, every branch; each scene's own mechanics (STY-5xx–8xx, MINI-006–012, END);
## restart applies nothing twice; replays change no byte; force-close and reload; partial COLL-005b.

const STORY := preload("res://scenes/story/story_scene.tscn")
const MAIN := preload("res://main/main.tscn")
const DT := 1.0 / 60.0
const NOW := 1795608000000
const CB := GameConfig.Combat
const RS := GameConfig.Story
## Every M7 scene in catalog order (this build's).
const IDS := ["5.1", "5.2", "5.3", "5.4", "5.5", "6.1", "6.2", "6.3"]
## Choices a run takes (choice id -> option id; "letter": the letter's outcome) and the branches.
const BRANCHES := {"5.1": [{"s16": "jerusalem"}, {"s16": "host"}], "5.3": [{"s07": "pope"}, {"s07": "host"}, {"s07": "debt"}], "5.4": [{"letter": "named"}, {"letter": "necessity"}], "6.1": [{"s10": "share"}, {"s10": "dice"}], "6.3": [{"s14": "stay"}, {"s14": "syria"}]}
## What each scene commits on top of its entry state: meter deltas, flags, abilities, coins, how many
## book entries of each kind (by branch, keyed "<id>" or "<id>/<option>").
const SNAP := {
	"5.1/jerusalem": {
		"meters": {
			"standing": -12,
			"supervillain": 5,
			"grace": 4,
			"commozione": -10
		},
		"flags": {
			"dissent": true
		},
		"abilities": [],
		"book": {
			"remembered": 1
		}
	},
	"5.1/host": {
		"meters": {
			"standing": 5
		},
		"flags": {},
		"abilities": [],
		"book": {
			"remembered": 1
		}
	},
	"5.2": {
		"meters": {
			"supervillain": 4
		},
		"flags": {
			"clothRoute": true
		},
		"abilities": [],
		"coins": 5,
		"book": {
			"remembered": 1
		}
	},
	"5.3/pope": {
		"meters": {
			"grace": 5,
			"standing": -3
		},
		"flags": {
			"zaraOwe": "pope"
		},
		"abilities": [],
		"book": {
			"remembered": 1
		}
	},
	"5.3/host": {
		"meters": {
			"standing": 4
		},
		"flags": {
			"zaraOwe": "host"
		},
		"abilities": [],
		"book": {
			"remembered": 1
		}
	},
	"5.3/debt": {
		"meters": {
			"supervillain": 2,
			"grace": -3
		},
		"flags": {
			"zaraOwe": "debt"
		},
		"abilities": [],
		"book": {
			"remembered": 1
		}
	},
	"5.4/named": {
		"meters": {
			"grace": 4
		},
		"flags": {
			"letter": "named"
		},
		"abilities": [],
		"book": {
			"remembered": 1
		}
	},
	"5.4/necessity": {
		"meters": {
			"grace": 4
		},
		"flags": {
			"letter": "necessity"
		},
		"abilities": [],
		"book": {
			"remembered": 1
		}
	},
	"5.5": {
		"meters": {},
		"flags": {},
		"abilities": [],
		"book": {
			"remembered": 1
		}
	},
	"6.1/share": {
		"meters": {
			"supervillain": 8,
			"commozione": -8
		},
		"flags": {
			"comradeship": true
		},
		"abilities": [],
		"book": {
			"values": 1,
			"remembered": 1
		}
	},
	"6.1/dice": {
		"meters": {
			"standing": 4
		},
		"flags": {
			"comradeship": false
		},
		"abilities": [],
		"book": {
			"remembered": 1
		}
	},
	"6.2": {
		"meters": {
			"supervillain": 3
		},
		"flags": {},
		"abilities": [],
		"book": {
			"remembered": 1
		}
	},
	"6.3/stay": {
		"meters": {
			"standing": 6
		},
		"flags": {
			"corfu": "stay"
		},
		"abilities": [],
		"book": {
			"remembered": 1
		}
	},
	"6.3/syria": {
		"meters": {
			"supervillain": 3,
			"standing": -3
		},
		"flags": {
			"corfu": "syria"
		},
		"abilities": [],
		"book": {
			"remembered": 1
		}
	}
}

var main: Node
var scenes: Array = []
## Real-input completion (the report reads the log): id -> {"ticks", "seconds"}.
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


## The campaign after Level 4 (the glad branch of 2.2; every Level 1–4 effect), then every M7 scene
## before `id` with its first branch.
static func _base() -> Dictionary:
	var st := CampaignSchema.new_campaign()
	st["completed"] = ["1.0", "1.1", "1.2", "1.3", "1.4", "1.5", "2.1", "2.2", "2.3", "3.1", "3.2", "3.3", "3.4", "4.1", "4.2", "4.3"]
	st["abilities"] = ["cross", "sermon", "knight"]
	st["coins"] = 12
	st["playTime"] = 60
	st["meters"] = {"commozione": 64.0, "supervillain": 18.0, "grace": 75.0, "standing": 52.0}
	st["flags"] = {"pawOffered": true, "longWay": true, "santinaBall": "performed", "vow": true, "shortfall": 36000, "weptWell": true, "zaraDeal": true, "heardZara": true}
	st["book"]["marvels"] = ["THE HORSE TRANSPORTS", "THE GALLEYS", "THE GREAT SHIPS", "THE FLEET LEAVING VENICE"]
	st["book"]["items"] = ["MERAVIGLIA, THE BOOK OF MARVELS"]
	return st


static func _entry(id: String) -> Dictionary:
	var st := _base()
	for k: String in IDS:
		if k == id:
			break
		st = _after(k, "", st)
		st["completed"].append(k)
	return st


## A state with the snapshot of `id` (branch "" = the first) applied: meters, flags, abilities, coins.
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
	st["coins"] = int(st["coins"]) + int(sn.get("coins", 0))
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
	assert_eq(got["coins"], want["coins"], "%s/%s: coins" % [id, branch])
	var key := id if SNAP.has(id) else "%s/%s" % [id, branch]
	var book: Dictionary = SNAP[key]["book"]
	for kind: String in ["marvels", "items", "values", "remembered", "shards"]:
		var added := (got["book"][kind] as Array).size() - (entry["book"][kind] as Array).size()
		assert_eq(added, int(book.get(kind, 0)), "%s/%s: book %s added" % [id, branch, kind])
	assert_eq(got["completed"], entry["completed"], "%s/%s: completion is Main's (one commit)" % [id, branch])


# --- Content -----------------------------------------------------------------------------------------

## CONTENT (M7): every implemented chapter of Levels 5–8 validates; every scene is draft
## implemented with review notes; Levels 5–7 are dream scenes (the coat of mail), Level 8 reality;
## each scene's entry condition names the scene before it.
func test_CONTENT_m7_chapters_validate_in_catalog_order() -> void:
	var v := StoryValidator.for_project()
	var prev := "4.3"
	for n in range(5, 9):
		var ch := StoryLibrary.chapter(n)
		if ch == null:
			continue
		assert_eq(v.validate_chapter(ch), PackedStringArray(), "chapter %d validates" % n)
		assert_eq(ch.review_status, "draft_implemented_review_pending", "chapter %d: draft" % n)
		for sc: StorySceneData in ch.scenes:
			assert_eq([sc.reality, sc.review_status, sc.technical_status], [n == 8, "draft_implemented_review_pending", "technically_complete"], sc.id + ": reality, draft")
			assert_false(sc.review_notes.is_empty(), sc.id + ": review notes")
			assert_eq(sc.entry_conditions.get("requires_completed", []), [prev], sc.id + ": entered after " + prev)
			prev = sc.id


# --- Completion ----------------------------------------------------------------------------------------

func test_SLICE_m7_scripted_smoke_every_scene() -> void:
	for id: String in IDS:
		var out := _play(id, _entry(id), BRANCHES.get(id, [{}])[0], true, 60 * 200)
		assert_false(out.has("error"), "%s: no error (%s)" % [id, out.get("error", "")])
		assert_true(out.has("result"), "%s: the smoke reaches the completion boundary (%s ticks)" % [id, out.get("ticks", "timeout")])


## Real input: every M6 scene completes through the InputService path (joystick, action, bark, U,
## I held, confirms, choice taps), without teleports or debug skips; the snapshot of every branch.
func test_SLICE_m7_real_input_completes_every_scene_and_branch() -> void:
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
	print("M7 real-input completion: ", completion)


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


# --- Level 5 -------------------------------------------------------------------------------------------

## STY-501: 5.1 — the message carried both ways (THE MESSAGE, then THE ANSWER on his back), then
## said aloud: the Jerusalem dissent costs 10 Commozione (locked when he has less) and sets `dissent`,
## Standing -12, Supervillain +5, Grace +4; the host route Standing +5 (no `dissent`).
func test_STY_501_messages_and_the_dissent_choice() -> void:
	var s := _scene("5.1", _entry("5.1"))
	var carried := []
	var d := StoryDriver.new(s, {"s16": "jerusalem"})
	for k in 60 * 120:
		if s.runner.current != null and s.runner.current.id == "s16":
			break
		if s.ctx.carrying != "" and not carried.has(s.ctx.carrying):
			carried.append(s.ctx.carrying)
		d.drive(DT)
		InputService.update(DT)
		s.tick(DT)
	assert_eq(carried, ["THE MESSAGE", "THE ANSWER"], "the message there, the answer back")
	assert_vec_near(Vector2(s.actors["marshal"].gx, s.actors["marshal"].gy), s.ctx.marker("7"), 0.01, "the marshal comes over")
	var poor := _entry("5.1")
	poor["meters"]["commozione"] = 5.0
	var p := _scene("5.1", poor)
	if _to_step(p, "s16"):
		_ticks_until(p, func() -> bool: return String(p.runner.st.get("phase", "")) == "choosing", 300)
		var views: Array = p.runner.st.get("views", [])
		assert_true(views.size() == 2 and String((views[0] as Dictionary)["locked"]) != "" and String((views[1] as Dictionary)["locked"]) == "", "with 5 Commozione the dissent is locked, the host open")


## STY-502, MINI-006–008: 5.2 — the ladder has exactly 16 rungs; however fast he presses, he climbs at
## most one rung per LADDER_CLIMB_GAP; a stone's warning comes first, then the stone, and a hit
## stops him LADDER_HIT_TIME and slides him down (progress lost, no lost result) until he reaches
## the top; the hero is drawn in his costume's authored walk frames, one cycle per four rungs; the
## dormant pitch/axe/hard branches do not exist. Then the steady ladder (moving restarts the clock),
## the cloth followed to the pile: `clothRoute`, 5 coins.
func test_STY_502_MINI_006_008_ladder_rungs_cap_stones_and_frames() -> void:
	var s := _scene("5.2", _entry("5.2"))
	if not _to_step(s, "s03"):
		return
	var g: LaddersGame = s.runner.st["game"]
	assert_eq([g.rungs, (s.runner.current as MiniGameStep).params["rungs"]], [16, 16], "exactly 16 rungs")
	# The input cap: a press every tick for a second climbs at most 1 / CLIMB_GAP rungs.
	g.spawn_t = 99.0
	var r0 := g.rung
	for k in 60:
		InputService.trigger(&"action")
		_ticks(s, 1)
	assert_true(g.rung - r0 <= ceil(1.0 / RS.LADDER_CLIMB_GAP) and g.rung - r0 >= floor(1.0 / RS.LADDER_CLIMB_GAP) - 1, "capped: %d rungs in 1 s" % int(g.rung - r0))
	# A stone in his lane: the warning, then the hit, the stun and the slide.
	g.falling = [{"lane": g.lane, "y": g.hero_y() - 14.0 - 40.0, "warn": RS.LADDER_WARN}]
	var before := g.rung
	_ticks(s, 2)
	assert_eq(g.hits, 0, "the warning first: no hit yet")
	assert_true(_ticks_until(s, func() -> bool: return g.hits == 1, 120), "then the stone hits")
	assert_true(g.hit_t > 0.0 and g.slide > 0.0, "stunned and sliding")
	_ticks(s, int(RS.LADDER_SLIDE_TIME / DT) + 2)
	assert_true(g.rung < before - 1.0, "progress lost: %.1f -> %.1f" % [before, g.rung])
	assert_eq(String(s.runner.st.get("result", "")), "", "a hit is no lost result")
	InputService.trigger(&"action")
	_ticks(s, 1)
	assert_true(g.hit_t > 0.0, "no climbing while stunned")
	# The hero's frames: his costume's own walk_n, frame floor(rung × n / 4) mod n.
	var v: MiniGameView = s.hud.get_parent().get_node("MiniGameView")
	var frames: SpriteFrames = s.world.player.body_sprite.sprite_frames
	var n := frames.get_frame_count(&"walk_n")
	g.rung = 5.0
	assert_true(v.hero_frame(g) == frames.get_frame_texture(&"walk_n", int(floor(5.0 * n / 4.0)) % n), "the authored walk frame for rung 5 (%d frames)" % n)
	assert_eq(s.world.player.costume, "armoured", "in his coat of mail")
	var src := FileAccess.get_file_as_string("res://story/minigames/ladders_game.gd")
	for word in ["pitch", "axe", "hard"]:
		assert_false(src.contains("var " + word) or src.contains("\"" + word + "\""), "no " + word + " branch")
	# On to the top, then the rest of the scene by real input.
	var out := {}
	s.completed.connect(func(r: Dictionary) -> void: out["r"] = r)
	var steady_reset := [false]
	var d := StoryDriver.new(s)
	for k in 60 * 120:
		if out.has("r"):
			break
		if s.runner.current != null and s.runner.current.id == "s06" and not steady_reset[0] and float(s.runner.st.get("t", 0.0)) > 1.0:
			steady_reset[0] = true
			InputService.inject_move(1.0, 0.0)
			_ticks(s, 10)
			assert_true(float(s.runner.st["t"]) < 0.2, "moving restarts the steady clock")
			assert_true((s.ctx.metrics["notices"] as Array).has("IT WOBBLES! STAND STILL"), "it wobbles")
			InputService.clear_injection()
		d.drive(DT)
		InputService.update(DT)
		s.tick(DT)
	assert_true(out.has("r"), "5.2 completes")
	if out.has("r"):
		assert_eq([out["r"]["state"]["flags"].get("clothRoute"), int(out["r"]["state"]["coins"]) - int(_entry("5.2")["coins"]), s.ctx.metrics["minis"]], [true, 5, ["ladders:won"]], "clothRoute, 5 coins, the ladder won")


## STY-503 and the sword's Grace: in 5.3's brawl every sword swing that lands costs Grace -1 once
## (with its explanation, shown once); a miss, a bark, a blow parried, and a blow taken on the shield
## cost nothing; a knockdown keeps what was paid and charges nothing more; a restart returns to the
## entry state; the three debts are heard and `zaraOwe` is the answer chosen.
func test_STY_503_sword_grace_cost_boundaries_and_the_three_debts() -> void:
	var entry := _entry("5.3")
	var s := _scene("5.3", entry)
	if not _to_step(s, "s11"):
		return
	var c := s.ctx.combat
	var grace := func() -> float: return float(s.ctx.state["meters"]["grace"])
	var g0: float = grace.call()
	var b1: StoryActor = s.actors["b1"]
	for a: StoryActor in c.foes:
		a.set_idle()
		a.foe.cooldown = 5.0
		a.set_grid_position(s.ctx.player_pos().x + 6.0, s.ctx.player_pos().y)
	# A miss: nobody in the arc.
	InputService.trigger(&"strike")
	_ticks(s, 2)
	assert_eq([grace.call(), c.events.count("sword_cost")], [g0, 0], "a miss costs nothing")
	# A bark that reaches him costs nothing either.
	b1.set_grid_position(s.ctx.player_pos().x + 1.0, s.ctx.player_pos().y)
	_ticks(s, int(CB.SWORD_COOLDOWN / DT) + 2)
	InputService.trigger(&"bark")
	_ticks(s, 2)
	assert_eq([grace.call(), c.events.count("bark_hit")], [g0, 1], "a bark costs nothing")
	# A parried blow (a closed foe in a parrying fight) costs nothing.
	c.def["parry"] = true
	b1.foe.stun = 0.0
	b1.foe.cooldown = 0.5
	b1.knock(0.0, 0.0)
	b1.set_grid_position(s.ctx.player_pos().x + 0.9, s.ctx.player_pos().y)
	InputService.trigger(&"strike")
	_ticks(s, 2)
	assert_eq([grace.call(), c.events.count("parried")], [g0, 1], "a parried blow costs nothing")
	c.def["parry"] = false
	# A blow that lands: Grace -1, once, with its explanation.
	_ticks(s, int(CB.SWORD_COOLDOWN / DT) + 2)
	b1.knock(0.0, 0.0)
	b1.set_grid_position(s.ctx.player_pos().x + 0.9, s.ctx.player_pos().y)
	InputService.trigger(&"strike")
	_ticks(s, 2)
	assert_eq([grace.call(), c.events.count("sword_cost")], [g0 - 1.0, 1], "a landed swing: Grace -1")
	assert_true((s.ctx.metrics["notices"] as Array).has("A SWORD ON A CHRISTIAN, AT ZARA: THE FORBIDDEN THING"), "with its explanation")
	_ticks(s, int(CB.SWORD_COOLDOWN / DT) + 2)
	b1.knock(0.0, 0.0)
	b1.set_grid_position(s.ctx.player_pos().x + 0.9, s.ctx.player_pos().y)
	b1.foe.stun = 0.2
	InputService.trigger(&"strike")
	_ticks(s, 2)
	assert_eq([grace.call(), (s.ctx.metrics["notices"] as Array).count("A SWORD ON A CHRISTIAN, AT ZARA: THE FORBIDDEN THING")], [g0 - 2.0, 1], "each landed swing costs; the explanation once")
	# A blow on the shield costs nothing.
	InputService.guard_hold_injected = true
	var b2: StoryActor = s.actors["b2"]
	b2.set_idle()
	b1.set_grid_position(s.ctx.player_pos().x + 6.0, s.ctx.player_pos().y)
	_ticks(s, 30)
	b2.knock(0.0, 0.0)
	b2.set_grid_position(s.ctx.player_pos().x - 0.8, s.ctx.player_pos().y)
	b2.foe.cooldown = 0.0
	assert_true(_ticks_until(s, func() -> bool: return c.events.has("blocked") or c.events.has("hurt"), 240), "a blow comes")
	InputService.guard_hold_injected = false
	assert_eq(grace.call(), g0 - 2.0, "a blocked blow costs nothing")
	# A knockdown keeps what was paid and charges nothing more.
	c.health = 1
	c.invuln = 0.0
	b2.set_grid_position(s.ctx.player_pos().x - 0.8, s.ctx.player_pos().y)
	b2.foe.stun = 0.0
	b2.foe.cooldown = 0.0
	assert_true(_ticks_until(s, func() -> bool: return s.runner.st.has("interrupt"), 300), "knocked down")
	_ticks_until(s, func() -> bool: return not s.runner.st.has("interrupt"), 300)
	assert_eq([grace.call(), c.events.count("sword_cost")], [g0 - 2.0, 2], "the knockdown neither refunds nor charges again")
	s.restart()
	assert_eq(s.ctx.state, s.entry_state, "a restart returns to the entry state (the costs gone with it)")
	# The three debts and the answer (real input, the debt answer).
	var out := _play("5.3", entry, {"s07": "debt"})
	if assert_true(out.has("result"), "5.3 completes"):
		assert_eq([out["result"]["state"]["flags"]["zaraOwe"], (out["scene"] as StoryScene).runner.trace.count("s06")], ["debt", 1], "zaraOwe from the answer; the three speeches heard")
		var shown: Array = (out["scene"] as StoryScene).ctx.metrics["notices"]
		for t in ["YOU WERE FORBIDDEN. YOU OWE THE POPE AN APOLOGY, AND THE PEOPLE OF THIS CITY MORE.", "YOU OWE THE HOST. IF WE SCATTER, NOBODY GETS ANYWHERE.", "YOU OWE US THIRTY-SIX THOUSAND MARKS. THE REST IS SERMONS."]:
			assert_true(shown.has(t), "heard: " + t)


## STY-504, MINI-011: 5.4's letter — the account is assembled from its fragments in order; a tap on
## a word cycles it; READ IT ALOUD sends it (the answer shows both accounts of the absolution, kept
## apart); WRITE IT AGAIN returns; HEAR THE ANSWER OUT finishes: `letter` named (the debt named) or
## necessity, Grace +4 once, the scene goes on once.
func test_STY_504_MINI_011_letter_fragments_feedback_and_both_accounts() -> void:
	var s := _scene("5.4", _entry("5.4"))
	if not _to_step(s, "s03"):
		return
	var g: LetterGame = s.runner.st["game"]
	var w := float(s.view_size().x)
	assert_eq(g.letter(), "HOLY FATHER, AT ZARA WE WERE COMPELLED, BY NECESSITY. WE ARE PENITENT.", "the fragments in order")
	var tap := func(id: String) -> void:
		for b: Dictionary in g.layout(w):
			if String(b["id"]) == id:
				InputService.pointer_down(2, (b["rect"] as Rect2).get_center())
				InputService.pointer_up(2, (b["rect"] as Rect2).get_center())
		_ticks(s, 1)
	tap.call("slot1")
	assert_eq(g.letter(), "HOLY FATHER, AT ZARA WE WERE COMPELLED, BY OUR DEBT TO VENICE. WE ARE PENITENT.", "a tap changes the word")
	tap.call("send")
	assert_eq([g.phase, g.sent], ["answer", 1], "read aloud and sent")
	var answer := String((s.runner.current as MiniGameStep).lines["answer"])
	assert_true(answer.contains("ABSOLVED THE PILGRIMS") and answer.contains("THE VENETIANS TOO"), "both accounts in the answer, kept apart")
	tap.call("again")
	assert_eq(g.phase, "write", "WRITE IT AGAIN")
	InputService.trigger(&"confirm")
	_ticks(s, 1)
	InputService.trigger(&"confirm")
	_ticks(s, 1)
	assert_eq([String(s.runner.st["result"]), s.ctx.state["flags"].get("letter"), s.ctx.metrics["letter"]], ["won", "named", ["named"]], "the debt named")
	assert_eq(float(s.ctx.state["meters"]["grace"]) - float(_entry("5.4")["meters"]["grace"]), 4.0, "Grace +4 once")
	_ticks(s, int(RS.MINI_RESULT_HOLD / DT) + 2)
	assert_eq([s.runner.current.id, s.runner.trace.count("s03")], ["s04", 1], "the scene goes on once")
	var n := _play("5.4", _entry("5.4"), {"letter": "necessity"})
	if assert_true(n.has("result"), "5.4 by real input, necessity"):
		assert_eq(n["result"]["state"]["flags"]["letter"], "necessity", "necessity")


## STY-505: 5.5 — the last sail carried to the storehouse and put down; CHALK does nothing away from
## the board and finishes the walk at it; the board reads back `shortfall` (36,000) or, without it,
## the undated balance; the chapter's end boundary.
func test_STY_505_sail_chalk_and_the_board_readback() -> void:
	var s := _scene("5.5", _entry("5.5"))
	assert_true(_drive_until(s, func() -> bool: return s.runner.current != null and s.runner.current.id == "s04"), "carrying the sail")
	assert_eq(s.ctx.carrying, "THE LAST ROLLED SAIL", "the sail on his back")
	assert_true(_drive_until(s, func() -> bool: return s.runner.current != null and s.runner.current.id == "s07"), "at the board walk")
	assert_eq(s.ctx.carrying, "", "the sail put down")
	InputService.trigger(&"action")
	_ticks(s, 2)
	assert_eq(s.runner.current.id, "s07", "CHALK away from the board does nothing")
	var board: Vector2 = s.runner.st["goal"]
	s.world.player.set_grid_position(board.x, board.y)
	_ticks(s, 1)
	assert_eq(s.runner.current.id, "s07", "reaching the board is not enough")
	InputService.trigger(&"action")
	_ticks(s, 1)
	assert_true(s.runner.current == null or s.runner.current.id != "s07", "CHALK at the board finishes it")
	_ticks(s, 2)
	assert_true(s.hud.card_visible and s.hud.card_small.contains("36,000 MARKS"), "the board reads back 36,000")
	assert_eq(s.ctx.metrics["branches"], ["s08:owed36"], "the shortfall case")
	var none := _entry("5.5")
	(none["flags"] as Dictionary).erase("shortfall")
	var t := _scene("5.5", none)
	if _to_step(t, "s07"):
		var tb: Vector2 = t.runner.st["goal"]
		t.world.player.set_grid_position(tb.x, tb.y)
		InputService.trigger(&"action")
		_ticks(t, 3)
		assert_true(t.hud.card_visible and not t.hud.card_small.contains("36,000"), "without the flag, no number")
		assert_eq(t.ctx.metrics["branches"], ["s08:otherwise"], "the other case")
	assert_eq(String(StoryLibrary.scene("5.5").completion["boundary"]), "chapter_end", "the chapter's end")


# --- Level 6 -------------------------------------------------------------------------------------------

## STY-601: 6.1 — the half loaves carried round three tents (three lines of the winter heard), then
## his own half loaf to the last tent; sharing it costs 8 Commozione (locked below 8) and sets
## `comradeship`, Supervillain +8 and the value COMRADESHIP; the dice set `comradeship` false and
## Standing +4, and Aleaume walks off.
func test_STY_601_rations_share_or_dice_and_comradeship() -> void:
	var s := _scene("6.1", _entry("6.1"))
	assert_true(_drive_until(s, func() -> bool: return s.runner.current != null and s.runner.current.id == "s04"), "the rounds")
	assert_eq(s.ctx.carrying, "THE DAY'S HALF LOAVES", "carrying the loaves")
	assert_true(_drive_until(s, func() -> bool: return s.runner.current != null and s.runner.current.id == "s06"), "the last tent")
	assert_eq(s.ctx.carrying, "HIS OWN HALF LOAF", "his own half loaf left")
	for t in ["HALF A LOAF, FOR A KNIGHT. IN VENICE MY HORSE ATE BETTER.", "A SHIP LEFT FOR SYRIA THIS MORNING. THEY SWORE TO STAY WITH US.", "BABYLON? ALEXANDRIA? WITH WHAT MONEY? WITH WHAT FOOD?"]:
		assert_true((s.ctx.metrics["notices"] as Array).has(t), "heard: " + t)
	for pair: Array in [["share", true, "Comradeship"], ["dice", false, ""]]:
		var out := _play("6.1", _entry("6.1"), {"s10": pair[0]})
		if not assert_true(out.has("result"), "6.1 %s completes" % pair[0]):
			continue
		var st: Dictionary = out["result"]["state"]
		assert_eq(st["flags"]["comradeship"], pair[1], "%s: comradeship %s" % [pair[0], pair[1]])
		assert_eq((st["book"]["values"] as Array).has("Comradeship"), pair[2] != "", "%s: the value COMRADESHIP" % pair[0])
		if pair[0] == "dice":
			var conf: StoryActor = (out["scene"] as StoryScene).actors["conf"]
			assert_eq(conf.behavior, "goto", "Aleaume walks off")
	var poor := _entry("6.1")
	poor["meters"]["commozione"] = 6.0
	var p := _scene("6.1", poor)
	if _to_step(p, "s10"):
		_ticks_until(p, func() -> bool: return String(p.runner.st.get("phase", "")) == "choosing", 300)
		var views: Array = p.runner.st.get("views", [])
		assert_true(views.size() == 2 and String((views[0] as Dictionary)["locked"]) != "", "with 6 Commozione sharing is locked")


## STY-602, MINI-012: 6.2 — the talk followed in order (only the next place shows its ring); then the
## garbled offer: pieces arrive one every RUMOUR_ARRIVE_EVERY in a shuffled order; a tap on the piece
## that comes next places it, a tap on a later one says it came later and places nothing; complete
## when all six are in the offer's order: Supervillain +3 once; only twelve swear.
func test_STY_602_MINI_012_talk_in_order_and_the_rumour_ordering() -> void:
	var s := _scene("6.2", _entry("6.2"))
	if not _to_step(s, "s03"):
		return
	assert_eq((s.runner.st["spots"] as Dictionary).size(), 1, "only the first place of the trail shows")
	assert_true(_drive_until(s, func() -> bool: return s.runner.current is MiniGameStep), "the trail followed to the council tent")
	var g: RumourGame = s.runner.st["game"]
	var w := float(s.view_size().x)
	assert_eq(g.pieces.size(), 6, "six pieces")
	var sorted_order := g.order.duplicate()
	sorted_order.sort()
	assert_eq(sorted_order, [0, 1, 2, 3, 4, 5], "each piece once")
	assert_true(_ticks_until(s, func() -> bool: return g.arrived >= 2, 300), "pieces arrive over time")
	var tap := func(k: int) -> void:
		for b: Dictionary in g.layout(w):
			if int(b["id"]) == k:
				InputService.pointer_down(2, (b["rect"] as Rect2).get_center())
				InputService.pointer_up(2, (b["rect"] as Rect2).get_center())
		_ticks(s, 1)
	assert_true(_ticks_until(s, func() -> bool: return g.order.slice(0, g.arrived).has(0) and g.order.slice(0, g.arrived).any(func(k: int) -> bool: return k > 0), 600), "the first piece and a later one have arrived")
	var later: int = g.order.slice(0, g.arrived).filter(func(k: int) -> bool: return k > 0)[0]
	tap.call(later)
	assert_eq([g.placed, g.wrong], [[], 1], "a later piece is refused")
	assert_true((s.ctx.metrics["notices"] as Array).has("GARBLED: THAT CAME LATER"), "with its feedback")
	tap.call(0)
	assert_eq(g.placed, [0], "the next piece is placed")
	var out := {}
	s.completed.connect(func(r: Dictionary) -> void: out["r"] = r)
	assert_true(_drive_until(s, func() -> bool: return out.has("r"), 60 * 60), "the rest by real input")
	if out.has("r"):
		assert_eq([g.placed, s.ctx.metrics["minis"]], [[0, 1, 2, 3, 4, 5], ["rumour:won"]], "the offer in order; won")
		assert_eq(float(out["r"]["state"]["meters"]["supervillain"]) - float(_entry("6.2")["meters"]["supervillain"]), 3.0, "Supervillain +3 once")
	assert_true(_texts_in(StoryLibrary.scene("6.2")).has("ONLY TWELVE OF THEM SWEAR TO IT"), "only twelve swear")


## STY-603: 6.3 — Pierre followed to the camp of those who would stay; the leaders kneel (their
## gesture); the choice is Pierre's to hear: `corfu` stay (Standing +6) or syria (Supervillain +3,
## Standing -3); the chapter's end boundary, then Level 7.
func test_STY_603_corfu_follow_kneeling_and_both_branches() -> void:
	for pair: Array in [["stay", "stay"], ["syria", "syria"]]:
		var s := _scene("6.3", _entry("6.3"))
		var knelt := [false]
		var out := {}
		s.completed.connect(func(r: Dictionary) -> void: out["r"] = r)
		var d := StoryDriver.new(s, {"s14": pair[0]})
		for k in 60 * 120:
			if out.has("r"):
				break
			if s.actors.has("l1") and (s.actors["l1"] as StoryActor).action_anim == "hurt":
				knelt[0] = true
			d.drive(DT)
			InputService.update(DT)
			s.tick(DT)
		assert_true(out.has("r") and knelt[0], "6.3 %s: completes; the leaders knelt" % pair[0])
		if out.has("r"):
			assert_eq(out["r"]["state"]["flags"]["corfu"], pair[1], "corfu %s" % pair[1])
	assert_eq(String(StoryLibrary.scene("6.3").completion["boundary"]), "chapter_end", "the chapter ends here")


static func _texts_in(sc: StorySceneData) -> PackedStringArray:
	var out := PackedStringArray()
	var stack: Array = sc.steps.duplicate()
	while not stack.is_empty():
		var st: StoryStep = stack.pop_front()
		out.append_array(st.texts())
		for b: Array in st.branches():
			stack.append_array(b)
	return out

# --- Restart, replay, force-close -----------------------------------------------------------------

## FLOW-008 (M7 scenes): restarting from the pause at every step family applies nothing twice: the
## completed state equals a single run's.
func test_FLOW_008_m7_restart_at_every_step_family_applies_nothing_twice() -> void:
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


## FLOW-011 (M7 scenes): replaying every completed scene from the chapter list runs on a copy and
## changes no persistent byte.
func test_FLOW_011_replay_of_every_m7_scene_changes_no_byte() -> void:
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


## FLOW-007 (M7 scenes): a force-close in the middle of a scene saves nothing of it and CONTINUE
## plays it again; its completion is one save; a second commit adds nothing.
func test_FLOW_007_m7_force_close_and_reload_at_each_save_boundary() -> void:
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


## Partial COLL-005b (M7 scenes): every scripted-position objective (reach goals, pickups, the lull's
## stand point, the stops of a follow path) is reachable over the stage's walkable tiles from where
## the scene has placed Zampanò when the walk starts (the Level 1 method). Moving targets (fighters,
## leaders, a receding gate's later places) are owned by the STY real-input runs. Returns the count.
func test_P_COLL_005b_m7_scripted_objectives_reachable() -> void:
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
	print("M7 COLL-005b targets checked: ", checked)
	for id: String in checked:
		if int(checked[id]) == 0:
			assert_false(_has_spatial(StoryLibrary.scene(id).steps), "%s has scripted targets, none checked" % id)


## Whether a scene has a walk objective with a scripted position (a goal, a pickup, a path, a stand).
static func _has_spatial(steps: Array) -> bool:
	for st: StoryStep in steps:
		if st is ObjectiveStep:
			var o := st as ObjectiveStep
			if o.goal_marker != "" or o.goal_point != Vector2.ZERO or not o.pickups.is_empty() or not o.path.is_empty() or o.rule == "lull":
				return true
		for b: Array in st.branches():
			if _has_spatial(b):
				return true
	return false


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
