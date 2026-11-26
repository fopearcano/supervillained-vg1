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
const IDS := ["5.1", "5.2", "5.3", "5.4", "5.5", "6.1", "6.2", "6.3", "7.1", "7.2", "7.3", "7.4", "7.5", "7.6", "7.7", "7.8", "7.9", "8.1", "8.2", "8.3", "8.4"]
## Choices a run takes (choice id -> option id; "letter": the letter's outcome) and the branches.
const BRANCHES := {"5.1": [{"s16": "jerusalem"}, {"s16": "host"}], "5.3": [{"s07": "pope"}, {"s07": "host"}, {"s07": "debt"}], "5.4": [{"letter": "named"}, {"letter": "necessity"}], "6.1": [{"s10": "share"}, {"s10": "dice"}], "6.3": [{"s14": "stay"}, {"s14": "syria"}], "7.8": [{"oath": "call"}, {"oath": "silent"}], "7.9": [{"s03": "declared"}, {"s03": "kept"}], "8.2": [{"s11": "ships"}, {"s11": "bowl"}]}
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
	},
	"7.1": {
		"meters": {
			"commozione": 12
		},
		"flags": {},
		"abilities": [],
		"book": {
			"marvels": 3,
			"remembered": 1
		}
	},
	"7.2": {
		"meters": {},
		"flags": {},
		"abilities": [],
		"book": {
			"remembered": 1
		}
	},
	"7.3": {
		"meters": {
			"supervillain": 15
		},
		"flags": {
			"vanguard": true
		},
		"abilities": [],
		"book": {
			"values": 1,
			"remembered": 1
		}
	},
	"7.4": {
		"meters": {
			"commozione": 13
		},
		"flags": {
			"visitedCity": true
		},
		"abilities": [],
		"book": {
			"marvels": 4,
			"remembered": 1
		}
	},
	"7.5": {
		"meters": {},
		"flags": {},
		"abilities": [],
		"book": {
			"remembered": 1
		}
	},
	"7.6": {
		"meters": {},
		"flags": {},
		"abilities": [],
		"book": {
			"remembered": 1
		}
	},
	"7.7": {
		"meters": {
			"grace": 5,
			"commozione": 6,
			"supervillain": 10
		},
		"flags": {
			"sworn": true,
			"followed": true
		},
		"abilities": [],
		"book": {
			"values": 1,
			"remembered": 1
		}
	},
	"7.8/call": {
		"meters": {
			"commozione": 5,
			"supervillain": 15,
			"grace": 5,
			"standing": -6
		},
		"flags": {
			"oath": "enforced"
		},
		"abilities": [],
		"book": {
			"marvels": 2,
			"values": 1,
			"remembered": 2
		}
	},
	"7.8/silent": {
		"meters": {
			"commozione": 10
		},
		"flags": {
			"oath": "silent"
		},
		"abilities": [],
		"book": {
			"marvels": 2,
			"remembered": 2
		}
	},
	"7.9/declared": {
		"meters": {
			"grace": 6,
			"commozione": 4
		},
		"flags": {
			"lamp": "declared",
			"columnAgain": true
		},
		"abilities": [],
		"coins": 2,
		"book": {
			"values": 1,
			"marvels": 1,
			"remembered": 1
		}
	},
	"7.9/kept": {
		"meters": {
			"grace": -8,
			"commozione": 4
		},
		"flags": {
			"lamp": "kept",
			"columnAgain": true
		},
		"abilities": [],
		"coins": 5,
		"book": {
			"marvels": 1,
			"remembered": 1
		}
	},
	"8.1": {
		"meters": {},
		"flags": {},
		"abilities": [],
		"book": {
			"remembered": 1
		}
	},
	"8.2/ships": {
		"meters": {
			"commozione": 10
		},
		"flags": {
			"told": true,
			"drawing": "ships",
			"tellingTier": "high"
		},
		"abilities": [],
		"book": {
			"items": 2,
			"remembered": 1
		}
	},
	"8.2/bowl": {
		"meters": {
			"commozione": 10
		},
		"flags": {
			"told": true,
			"drawing": "bowl",
			"tellingTier": "high"
		},
		"abilities": [],
		"book": {
			"items": 2,
			"remembered": 1
		}
	},
	"8.3": {
		"meters": {
			"supervillain": 25
		},
		"flags": {
			"lawnHeld": true
		},
		"abilities": [],
		"book": {
			"values": 1,
			"remembered": 1
		}
	},
	"8.4": {
		"meters": {},
		"flags": {
			"ballReturned": true,
			"courtesy84": "unanswered"
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


## The scene's own starting state: the entry less the fade at a dream scene's start (RD-05).
static func _faded(id: String, entry: Dictionary) -> Dictionary:
	var st := entry.duplicate(true)
	var data := StoryLibrary.scene(id)
	CampaignRules.fade_commozione(st, 0 if data.reality else data.level)
	return st


func _check_snapshot(id: String, branch: String, entry: Dictionary, got: Dictionary) -> void:
	var want := _after(id, branch, _faded(id, entry))
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
	assert_eq(s.ctx.state, _faded("5.3", s.entry_state), "a restart returns to the entry state, faded once (the costs gone with it)")
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


# --- Level 7: 7.1–7.4 ------------------------------------------------------------------------------

## STY-701, MINI-009: 7.1 — three marvels from the camp (each once); then the row along the walls is a
## tug meant to be lost: each pull takes the rope back, the force keeps growing, and however fast he
## rows the result is "lost" (there is no won result); its effect (Commozione +3) once; the scene goes
## on once to "NOBODY KNOWS HIM".
func test_STY_701_MINI_009_three_marvels_and_the_tug_lost_by_design() -> void:
	var g := TugGame.new()
	var r := ""
	var t := 0.0
	var next := 0.0
	while r != "lost" and t < 120.0:
		var n := 0
		if t >= next:
			n = 1
			next = t + 1.0 / 8.0
		r = g.update(DT, n)
		t += DT
	assert_eq(r, "lost", "rowing as fast as a person can: still lost (%.1f s)" % t)
	var idle := TugGame.new()
	var t2 := 0.0
	while idle.update(DT, 0) != "lost":
		t2 += DT
	assert_true(t2 < t, "without rowing it is lost sooner (%.1f s < %.1f s)" % [t2, t])
	var src := FileAccess.get_file_as_string("res://story/minigames/tug_game.gd")
	assert_false(src.contains("\"won\""), "the tug has no won result")
	var out := _mini_run("7.1", true)
	if not assert_true(out.has("r"), "7.1 completes by real input"):
		return
	var sc: StoryScene = out["scene"]
	var st: Dictionary = out["r"]["state"]
	assert_eq([sc.ctx.metrics["minis"], sc.runner.trace.count("s08"), sc.runner.trace.count("s10")], [["tug:lost"], 1, 1], "lost once; the scene goes on once")
	var base := _entry("7.1")
	assert_eq(float(st["meters"]["commozione"]) - (float(base["meters"]["commozione"]) - RS.COMMOZIONE_FADE), 12.0, "three marvels (+9) and the tug's loss (+3), once each")
	for m in ["THE GREAT WALLS", "THE CITY OF ROOFS", "THE GOLDEN DOMES"]:
		assert_eq((st["book"]["marvels"] as Array).count(m), 1, m + " once")


## STY-702: 7.2 — the banner followed through the landing; the hold by the banner lasts 18 s against
## three parrying axe-men (no one need be routed); the real inputs fight it (U, I held, B, the round
## button, a swipe); a knockdown shows its card and starts the hold again (the clock back to 0, the
## guards back, hearts full) with nothing applied; then the driver holds the full 18 s (no skip) and
## carries word to the camp.
func test_STY_702_hold_ground_real_inputs_knockdown_and_survival() -> void:
	var s := _scene("7.2", _entry("7.2"))
	if not _to_step(s, "s11"):
		return
	var c := s.ctx.combat
	assert_eq([c.need(), bool(c.def["parry"]), (s.runner.current as ObjectiveStep).survive], [0, true, 18.0], "hold 18 s; no rout needed; they parry")
	for a: StoryActor in c.foes:
		a.foe.cooldown = 5.0
	await tree.process_frame
	for code: Key in [KEY_U, KEY_B]:
		var e := InputEventKey.new()
		e.keycode = code
		e.physical_keycode = code
		e.pressed = true
		Input.parse_input_event(e)
		await tree.process_frame
		e = e.duplicate()
		e.pressed = false
		Input.parse_input_event(e)
		await tree.process_frame
		_ticks(s, int(CB.BARK_COOLDOWN / DT) + 2)
	assert_true(c.events.has("strike") and c.events.has("bark"), "U swung, B barked")
	var ei := InputEventKey.new()
	ei.keycode = KEY_I
	ei.physical_keycode = KEY_I
	ei.pressed = true
	Input.parse_input_event(ei)
	await tree.process_frame
	_ticks(s, int(CB.SHIELD_PULSE / DT) + 10)
	assert_true(c.guarding, "I held: the shield stays up")
	ei = ei.duplicate()
	ei.pressed = false
	Input.parse_input_event(ei)
	await tree.process_frame
	_ticks(s, int(CB.SHIELD_PULSE / DT) + 2)
	var gp := Vector2(s.view_size().x - 30, s.view_size().y * 0.4)
	InputService.pointer_down(4, gp)
	InputService.pointer_move(4, gp + Vector2(0, -16))
	InputService.pointer_move(4, gp + Vector2(0, -32))
	InputService.pointer_up(4, gp + Vector2(0, -32))
	_ticks(s, 1)
	assert_eq([InputService.last_gesture.get("kind", ""), c.events.count("strike")], ["swipeUp", 2], "a swipe up swings")
	var lay: Dictionary = s.controls._layout
	_ticks(s, int(CB.SWORD_COOLDOWN / DT) + 2)
	InputService.trigger(&"switch")
	_ticks(s, 1)
	InputService.pointer_down(5, lay["action"])
	InputService.pointer_up(5, lay["action"])
	_ticks(s, 1)
	assert_eq(c.events.count("strike"), 3, "the round button in SWORD mode swings")
	# A knockdown: the hold starts again, nothing applied.
	var before := s.ctx.state.duplicate(true)
	_ticks(s, 120)
	assert_true(float(s.runner.st["t"]) > 1.5, "the clock runs")
	c.health = 1
	c.invuln = 0.0
	var v0: StoryActor = c.foes[0]
	v0.set_grid_position(s.ctx.player_pos().x + 0.8, s.ctx.player_pos().y)
	v0.knock(0.0, 0.0)
	v0.foe.stun = 0.0
	v0.foe.cooldown = 0.0
	assert_true(_ticks_until(s, func() -> bool: return s.runner.st.has("interrupt"), 300), "knocked down")
	assert_true(_ticks_until(s, func() -> bool: return not s.runner.st.has("interrupt"), 300), "up again")
	assert_true(float(s.runner.st["t"]) < 0.1, "the hold starts again")
	assert_eq([c.health, s.ctx.state], [c.max_health, before], "hearts full; nothing applied")
	var out := {}
	s.completed.connect(func(x: Dictionary) -> void: out["r"] = x)
	var held := [0.0]
	var d := StoryDriver.new(s)
	for k in 60 * 120:
		if out.has("r"):
			break
		if s.runner.current != null and s.runner.current.id == "s11":
			held[0] = maxf(held[0], float(s.runner.st.get("t", 0.0)))
		d.drive(DT)
		InputService.update(DT)
		s.tick(DT)
	InputService.guard_hold_injected = false
	# The last tick inside the hold reads the clock one frame short of 18 s.
	assert_true(held[0] >= 18.0 - 2.0 * DT, "held the full 18 s by real input (%.2f)" % held[0])
	assert_true(out.has("r"), "then carried word to the camp")


## STY-703, NPC-008–011 (7.3): the companions' pace — Saint-Pol keeps beside Pierre; Flanders turns
## back, then (at 45 % of the march) comes round and falls in beside Pierre. Staying level fills the
## nerve; behind, ahead or aside empties it with its own notice; at no nerve OUT OF STEP sends both back
## to the start (Pierre marches again); the cooks join; the window's words float. Level to the end:
## `vanguard`, Supervillain +15 and the value PHYSICAL COURAGE, once.
func test_STY_703_companion_pace_feedback_out_of_step_and_vanguard() -> void:
	var s := _scene("7.3", _entry("7.3"))
	if not _to_step(s, "s11"):
		return
	var pierre: StoryActor = s.actors["pierre"]
	var stpol: StoryActor = s.actors["stpol"]
	assert_eq([stpol.behavior, stpol.follow_actor == pierre], ["follow", true], "Saint-Pol keeps beside Pierre")
	assert_eq(s.actors["flanders"].behavior, "goto", "Flanders turned back")
	# Standing still: Pierre walks on; behind, the nerve drains to OUT OF STEP.
	assert_true(_ticks_until(s, func() -> bool: return (s.ctx.metrics.get("pace", []) as Array).has("behind"), 600), "behind: its notice")
	assert_true(_ticks_until(s, func() -> bool: return s.runner.st.has("interrupt"), 60 * 20), "out of step")
	assert_eq(s.hud.card_big, "OUT OF STEP", "the card")
	assert_true(_ticks_until(s, func() -> bool: return not s.runner.st.has("interrupt"), 300), "the card passes")
	assert_vec_near(s.ctx.player_pos(), s.ctx.marker("S"), 0.01, "back at the start")
	assert_true(pierre.behavior == "goto" and Vector2(pierre.gx, pierre.gy).distance_to(s.ctx.marker("S") - Vector2(1, 0)) < 0.2, "Pierre back at the start, marching")
	# Ahead: its own notice.
	# Six tiles ahead (Pierre walks 1.5 tiles a second, so still ahead when the notice comes due).
	s.world.player.set_grid_position(pierre.gx, pierre.gy - 6.0)
	assert_true(_ticks_until(s, func() -> bool: return (s.ctx.metrics.get("pace", []) as Array).has("ahead"), 200), "ahead: its notice")
	s.world.player.set_grid_position(pierre.gx + 1.0, pierre.gy)
	var out := {}
	s.completed.connect(func(x: Dictionary) -> void: out["r"] = x)
	var flanders_fell_in := [false]
	var d := StoryDriver.new(s)
	for k in 60 * 120:
		if out.has("r"):
			break
		var fl: StoryActor = s.actors.get("flanders")
		if fl and fl.behavior == "follow" and fl.follow_actor == pierre:
			flanders_fell_in[0] = true
		d.drive(DT)
		InputService.update(DT)
		s.tick(DT)
	assert_true(out.has("r"), "7.3 completes level with Pierre")
	assert_true(flanders_fell_in[0], "Flanders rejoined beside Pierre")
	var shown: Array = s.ctx.metrics["notices"]
	assert_true(shown.has("THE GROOMS AND COOKS COME TOO, WITH POTS AND PESTLES") and shown.has("FLANDERS COMES ROUND AND REJOINS THEM"), "the cooks and Flanders")
	if out.has("r"):
		var st: Dictionary = out["r"]["state"]
		assert_eq([st["flags"].get("vanguard"), (st["book"]["values"] as Array).count("Physical courage")], [true, 1], "vanguard; PHYSICAL COURAGE once")
		assert_eq(float(st["meters"]["supervillain"]) - float(_entry("7.3")["meters"]["supervillain"]), 15.0, "Supervillain +15 once")


## STY-704: 7.4 — Watson walks beside him; four marvels (the palace, Hercules, the column, the
## courtyard), each once (+13 Commozione); `visitedCity`; a second visit awards nothing new.
func test_STY_704_four_marvels_once_and_the_visited_city() -> void:
	var out := _play("7.4", _entry("7.4"))
	if not assert_true(out.has("result"), "7.4 completes"):
		return
	var st: Dictionary = out["result"]["state"]
	assert_eq([st["flags"].get("visitedCity"), float(st["meters"]["commozione"]) - (float(_entry("7.4")["meters"]["commozione"]) - RS.COMMOZIONE_FADE)], [true, 13.0], "visitedCity; +13")
	for m in ["THE PALACE OF THE LION'S MOUTH", "THE BRONZE HERCULES", "THE CARVED COLUMN", "A LAMP IN A COURTYARD"]:
		assert_eq((st["book"]["marvels"] as Array).count(m), 1, m + " once")
	assert_eq(((out["scene"] as StoryScene).actors["watson"] as StoryActor).behavior, "follow", "Watson walks beside him")
	var again := _play("7.4", st)
	if assert_true(again.has("result"), "a second visit"):
		assert_eq((again["result"]["state"]["book"]["marvels"] as Array).size(), (st["book"]["marvels"] as Array).size(), "no marvel twice")


# --- Level 7: 7.5–7.9 ------------------------------------------------------------------------------

## STY-705 (7.5): the chests carried (A CHEST on his back while he gathers them, each one lighter,
## then put down); the Doge's rebuke; the mosque card; she follows him; the fire walk completes by
## real input and only the remembered line persists.
func test_STY_705_chests_the_mosque_and_the_walk_home() -> void:
	var s := _scene("7.5", _entry("7.5"))
	var out := {}
	s.completed.connect(func(r: Dictionary) -> void: out["r"] = r)
	var d := StoryDriver.new(s)
	var carried := []
	var follows := false
	for k in 60 * 120:
		if out.has("r"):
			break
		if s.ctx.carrying != "" and not carried.has(s.ctx.carrying):
			carried.append(s.ctx.carrying)
		if s.runner.current != null and s.runner.current.id == "s13":
			follows = follows or (s.actors["woman"] as StoryActor).behavior == "follow"
		d.drive(DT)
		InputService.update(DT)
		s.tick(DT)
	if not assert_true(out.has("r"), "7.5 completes by real input"):
		return
	assert_eq(carried, ["A CHEST"], "the chests carried")
	assert_true(follows, "she follows him home")
	var trace: PackedStringArray = out["r"]["trace"]
	for id: String in ["s04", "s07", "s09", "s13", "s16"]:
		assert_eq(trace.count(id), 1, id + " once")
	var shown: Array = out["r"]["metrics"]["notices"]
	for t in ["FULL. HALF OF IT ALREADY BELONGS TO THE VENETIANS.", "HALF FULL. THE REST AFTER THE HARVEST, THEY SAY.", "EMPTY, EXCEPT FOR AN APOLOGY."]:
		assert_true(shown.has(t), "a chest: " + t)
	var st: Dictionary = out["r"]["state"]
	assert_eq([st["meters"], st["flags"], st["coins"]], [_faded("7.5", _entry("7.5"))["meters"], _entry("7.5")["flags"], _entry("7.5")["coins"]], "nothing but the fade and the remembered line")
	assert_eq(float(out["r"]["metrics"]["faded"]), RS.COMMOZIONE_FADE, "the feeling faded once at the start")


## WALK-019–021 (7.5's fire): no fire before 0.6 s; then it starts at marker 1 (FIRE!) and spreads
## from the scene's seeded generator (the same tiles on the same ticks in another run); never onto the
## goal, the walk's start or the checkpoint (safe); a burning tile pushes him back toward the restart
## point with HOT!; passing the checkpoint makes it the restart point; the third burn is THE SMOKE: he
## is back at the checkpoint with the woman beside him, the fire out and starting again, nothing applied.
func test_WALK_019_021_fire_spread_push_safe_checkpoints_and_restart() -> void:
	var s := _scene("7.5", _entry("7.5"))
	if not _to_step(s, "s13"):
		return
	var st: Dictionary = s.runner.st
	_ticks(s, int(0.5 / DT))
	assert_false(bool(st["fire_on"]), "no fire before 0.6 s")
	_ticks(s, int(0.2 / DT))
	assert_true(bool(st["fire_on"]) and FireRule.burning(st, s.ctx.marker("1")), "the fire starts at marker 1")
	assert_eq(s.hud.card_big, "FIRE!", "its card")
	_ticks(s, int(6.0 / DT))
	var n := (st["fire"] as Dictionary).size()
	assert_true(n > 12, "it spreads (%d tiles in 6 s)" % n)
	for p: Vector2 in [st["start"], st["goal"], s.ctx.marker("2")]:
		assert_false(FireRule.burning(st, p), "safe: %s never burns" % p)
	# The same tiles on the same ticks in another run (the seeded generator).
	var s2 := _scene("7.5", _entry("7.5"))
	if not _to_step(s2, "s13"):
		return
	_ticks(s2, int(0.5 / DT) + int(0.2 / DT) + int(6.0 / DT))
	assert_eq((s2.runner.st["fire"] as Dictionary).keys(), (st["fire"] as Dictionary).keys(), "the same fire, run and run again")
	# The checkpoint: the restart point.
	var cp := s.ctx.marker("2")
	s.world.player.set_grid_position(cp.x, cp.y)
	_ticks(s, 1)
	assert_true((st["passed"] as Array).has("2") and (st["start"] as Vector2).is_equal_approx(cp), "the checkpoint is the restart point")
	assert_true((s.ctx.metrics["notices"] as Array).has("CHECKPOINT"), "its notice")
	# A burning tile pushes him back toward it.
	var before := s.ctx.state.duplicate(true)
	var hot: Vector2i = (st["fire_order"] as Array)[(st["fire_order"] as Array).size() / 2]
	var at := Vector2(hot.x + 0.5, hot.y + 0.5)
	s.world.player.set_grid_position(at.x, at.y)
	_ticks(s, 1)
	assert_eq(int(st["burns"]), 1, "one burn")
	assert_true((s.ctx.metrics["notices"] as Array).has("HOT!"), "HOT!")
	var d0 := at.distance_to(cp)
	_ticks(s, 6)
	assert_true(s.ctx.player_pos().distance_to(cp) < d0, "pushed back toward the restart point")
	# Two more burns: THE SMOKE.
	for b in 2:
		_ticks(s, int(RS.FIRE_HURT_TIME / DT) + 1)
		var order: Array = st["fire_order"]
		var k2: Vector2i = order[mini(order.size() - 1, order.size() / 2 + b + 1)]
		s.world.player.set_grid_position(k2.x + 0.5, k2.y + 0.5)
		_ticks(s, 1)
	assert_true(st.has("interrupt"), "the third burn: the smoke")
	assert_eq(s.hud.card_big, "THE SMOKE", "its card")
	assert_true(_ticks_until(s, func() -> bool: return not st.has("interrupt"), 300), "the card passes")
	assert_vec_near(s.ctx.player_pos(), cp, 0.01, "back at the last checkpoint")
	assert_true(Vector2(s.actors["woman"].gx, s.actors["woman"].gy).distance_to(cp) < 1.0, "the woman beside him")
	assert_eq([(st["fire"] as Dictionary).size(), bool(st["fire_on"]), int(st["burns"]), int(st["fire_restarts"])], [0, false, 0, 1], "the fire out; it starts again")
	assert_eq(s.ctx.state, before, "nothing applied")
	assert_eq(s.ctx.metrics["smoke"], ["s13"], "the smoke once")
	_ticks(s, int(0.8 / DT))
	assert_true(bool(st["fire_on"]) and FireRule.burning(st, s.ctx.marker("1")), "and the fire starts again at its origin")


## STY-706 (7.6): the envoys walk beside him; running stops the walk (YOU RAN; back at the start,
## the envoys beside him, nothing applied); at a walk, in and out; the two accounts of the deaths are
## kept apart (the marshal's, the small knight's, then both kept); Bagnaskiz under a different crown.
func test_STY_706_envoy_walk_at_pace_and_the_two_accounts() -> void:
	var s := _scene("7.6", _entry("7.6"))
	if not _to_step(s, "s05"):
		return
	assert_eq([s.actors["envoy"].behavior, s.actors["envoy2"].behavior], ["follow", "follow"], "the envoys walk beside him")
	var before := s.ctx.state.duplicate(true)
	var start: Vector2 = s.runner.st["start"]
	var ran := false
	for k in 120:
		InputService.inject_move(0.0, -1.0, true)
		InputService.update(DT)
		s.tick(DT)
		if s.runner.st.has("interrupt"):
			ran = true
			break
	InputService.clear_injection()
	assert_true(ran and s.hud.card_big == "YOU RAN", "running stops the walk")
	assert_true(_ticks_until(s, func() -> bool: return not s.runner.st.has("interrupt"), 300), "the card passes")
	assert_vec_near(s.ctx.player_pos(), start, 0.01, "back at the start")
	assert_true(Vector2(s.actors["envoy"].gx, s.actors["envoy"].gy).distance_to(start) < 1.0, "the envoys with him")
	assert_eq([s.ctx.state, s.ctx.metrics["ran"]], [before, ["s05"]], "nothing applied; once")
	var out := {}
	s.completed.connect(func(r: Dictionary) -> void: out["r"] = r)
	var d := StoryDriver.new(s)
	for k in 60 * 120:
		if out.has("r"):
			break
		d.drive(DT)
		InputService.update(DT)
		s.tick(DT)
	if not assert_true(out.has("r"), "7.6 completes at a walk"):
		return
	assert_eq(out["r"]["metrics"]["ran"], ["s05"], "the driver never ran")
	var trace: PackedStringArray = out["r"]["trace"]
	assert_true(trace.find("s12") < trace.find("s13") and trace.find("s13") < trace.find("s14"), "the marshal's account, the small knight's, both kept")
	var cards := {}
	for step: StoryStep in StoryLibrary.scene("7.6").steps:
		if step is CardStep:
			cards[step.id] = (step as CardStep).small
	assert_false(cards["s12"] == cards["s13"], "two different accounts")
	assert_true(String(cards["s13"]).contains("BOTH"), "the small knight: both strangled")
	assert_eq(s.actors["usurper"].role, "bagnaskizEmperor", "Bagnaskiz, under a different crown")


## STY-707, MINI-010 (7.7): the oath said (Grace +5, `sworn`); the cloth-route readback (only with
## `clothRoute`); the tug at the hole is lost by design and the scene goes on once (Commozione +6
## once); with `comradeship` his voice guides him in, without it only the rattle of his mail (found by
## ear); Supervillain +10, `followed`; the value COMRADESHIP is not added twice.
func test_STY_707_MINI_010_oath_tug_lost_and_the_comradeship_readback() -> void:
	var e1 := _entry("7.7")
	e1["book"]["values"] = ["Comradeship"]
	assert_true(bool(e1["flags"].get("comradeship")) and bool(e1["flags"].get("clothRoute")), "the first branches: comradeship, the cloth")
	var a := _play("7.7", e1)
	if not assert_true(a.has("result"), "7.7 with comradeship completes"):
		return
	var ta: PackedStringArray = a["result"]["trace"]
	assert_eq([a["result"]["metrics"]["minis"], ta.count("s10"), ta.count("s11")], [["tug:lost"], 1, 1], "the tug lost once; the scene goes on once")
	assert_true(ta.has("s05a") and ta.has("s13a") and ta.has("s13b") and not ta.has("s13c"), "the cloth readback; his voice")
	var sa: Dictionary = a["result"]["state"]
	var want := {"grace": 5.0, "commozione": 6.0, "supervillain": 10.0}
	for m: String in want:
		assert_eq(float(sa["meters"][m]) - float(_faded("7.7", e1)["meters"][m]), float(want[m]), m + " (from the faded start)")
	assert_eq([sa["flags"].get("sworn"), sa["flags"].get("followed"), (sa["book"]["values"] as Array).count("Comradeship")], [true, true, 1], "sworn; followed; COMRADESHIP once")
	var e2 := _entry("7.7")
	e2["flags"]["comradeship"] = false
	e2["flags"].erase("clothRoute")
	var b := _play("7.7", e2)
	if not assert_true(b.has("result"), "7.7 without comradeship completes (by ear)"):
		return
	var tb: PackedStringArray = b["result"]["trace"]
	assert_true(tb.has("s13c") and tb.has("s13d") and not tb.has("s13a") and not tb.has("s05a"), "only the rattle; no cloth readback")
	assert_eq((b["result"]["state"]["book"]["values"] as Array).count("Comradeship"), 1, "COMRADESHIP")


## STY-708A (7.8): two marvels; the page turned; in a lull he calls the pilgrims to their oath by
## real input: `oath` enforced, Commozione 5 spent, Supervillain +15, Grace +5, Standing −6, KEPT
## OATHS, his own words remembered; the girl is let go; THE KNIGHT. With less than 5 Commozione the
## call takes all he has left.
func test_STY_708A_the_call_in_a_lull_and_the_knight_route() -> void:
	var e := _entry("7.8")
	var out := _play("7.8", e, {"oath": "call"})
	if not assert_true(out.has("result"), "7.8 (call) completes"):
		return
	var st: Dictionary = out["result"]["state"]
	var dm := {}
	for m: String in ["commozione", "supervillain", "grace", "standing"]:
		dm[m] = float(st["meters"][m]) - float(_faded("7.8", e)["meters"][m])
	assert_eq(dm, {"commozione": 5.0, "supervillain": 15.0, "grace": 5.0, "standing": -6.0}, "marvels +10, the call −5; +15, +5, −6")
	assert_eq(st["flags"].get("oath"), "enforced", "oath enforced")
	assert_true((st["book"]["values"] as Array).has("Kept oaths") and (st["book"]["remembered"] as Array).has("NO HAND ON A WOMAN! YOU SWORE! (IN HIS OWN WORDS)"), "KEPT OATHS; his words")
	var m: Dictionary = out["result"]["metrics"]
	assert_eq([m["lull_acts"], m.get("silence", [])], [["s13"], []], "one heard call; no silence")
	var tr: PackedStringArray = out["result"]["trace"]
	assert_true(tr.has("s16a") and tr.has("s16b") and not tr.has("s16c"), "the pilgrims answer him")
	var sc: StoryScene = out["scene"]
	assert_eq([sc.actors["girl"].behavior, sc.actors["jack"].behavior], ["goto", "flee"], "the girl let go; Jack runs")
	assert_eq(CampaignFlow.ending(st), "knight", "THE KNIGHT")
	for mv in ["THE GREAT CHURCH", "THE HIPPODROME"]:
		assert_eq((st["book"]["marvels"] as Array).count(mv), 1, mv)
	# Short of Commozione: it takes all he has left.
	var s := _scene("7.8", _entry("7.8"))
	if not _to_step(s, "s13"):
		return
	s.ctx.state["meters"]["commozione"] = 3.0
	assert_true(_drive_until(s, func() -> bool: return (s.ctx.metrics.get("lull_acts", []) as Array).size() > 0, 60 * 30), "called")
	assert_eq(float(s.ctx.state["meters"]["commozione"]), 0.0, "all he had left")
	assert_true((s.ctx.metrics["notices"] as Array).has("IT TAKES ALL HE HAS LEFT"), "its notice")


## STY-708B (7.8): he stands silent by real input (no action); after 16 s Niketas calls the oath
## himself: `oath` silent, his words remembered as overheard, nothing spent, no Supervillain; the
## girl is let go; THE WITNESS (ending key `alpha`).
func test_STY_708B_silence_niketas_calls_and_the_witness_route() -> void:
	var e := _entry("7.8")
	var out := _play("7.8", e, {"oath": "silent"})
	if not assert_true(out.has("result"), "7.8 (silent) completes"):
		return
	var st: Dictionary = out["result"]["state"]
	var dm := {}
	for m: String in ["commozione", "supervillain", "grace", "standing"]:
		dm[m] = float(st["meters"][m]) - float(_faded("7.8", e)["meters"][m])
	assert_eq(dm, {"commozione": 10.0, "supervillain": 0.0, "grace": 0.0, "standing": 0.0}, "only the marvels")
	assert_eq(st["flags"].get("oath"), "silent", "oath silent")
	assert_true((st["book"]["remembered"] as Array).has("YOU SWORE AN OATH! LET HER GO! (NIKETAS, OVERHEARD)"), "Niketas, overheard")
	assert_false((st["book"]["values"] as Array).has("Kept oaths"), "no KEPT OATHS")
	var m: Dictionary = out["result"]["metrics"]
	assert_eq([m.get("lull_acts", []), m["silence"]], [[], ["s13"]], "no call; the silence")
	var tr: PackedStringArray = out["result"]["trace"]
	assert_true(tr.has("s16c") and tr.has("s16d") and not tr.has("s16a"), "the pilgrims answer Niketas")
	var sc: StoryScene = out["scene"]
	assert_eq(sc.actors["girl"].behavior, "goto", "the girl let go")
	assert_eq(CampaignFlow.ending(st), "alpha", "THE WITNESS (alpha)")


## STY-709 (7.9): the lamp picked up and carried; declared (Grace +6, AN HONEST SHARE, carried to the
## pile) or kept (Grace −8, coins +3, put out of sight at once, the hanging card); the empty pedestal
## (a marvel, once) and the column (`columnAgain`); the pile; the cloth-route readback only with
## `clothRoute`; coins +2; JERUSALEM: LOADING… and it never loads (from Level 5 on no stage is
## Jerusalem; the chapter ends here).
func test_STY_709_lamp_declared_or_kept_the_pile_and_jerusalem_never_loads() -> void:
	for want: String in ["declared", "kept"]:
		var e := _entry("7.9")
		if want == "kept":
			e["flags"].erase("clothRoute")
		var s := _scene("7.9", e)
		var out := {}
		s.completed.connect(func(r: Dictionary) -> void: out["r"] = r)
		var d := StoryDriver.new(s, {"s03": want})
		var carried_at := {}
		for k in 60 * 120:
			if out.has("r"):
				break
			if s.runner.current != null and not carried_at.has(s.runner.current.id):
				carried_at[s.runner.current.id] = s.ctx.carrying
			d.drive(DT)
			InputService.update(DT)
			s.tick(DT)
		if not assert_true(out.has("r"), "7.9/%s completes" % want):
			continue
		var st: Dictionary = out["r"]["state"]
		var tr: PackedStringArray = out["r"]["trace"]
		assert_eq(st["flags"].get("lamp"), want, want)
		assert_eq(float(st["meters"]["grace"]), float(_after("7.9", want, e)["meters"]["grace"]), "Grace %s (clamped to the meter)" % ("+6" if want == "declared" else "-8"))
		assert_eq(int(st["coins"]) - int(e["coins"]), 2 if want == "declared" else 5, "coins")
		assert_eq((st["book"]["values"] as Array).has("An honest share"), want == "declared", "AN HONEST SHARE")
		assert_eq(carried_at.get("s04", "?"), "A LAMP" if want == "declared" else "", "the lamp carried to the pile, or out of sight")
		assert_eq(tr.has("s03c"), want == "kept", "the hanging card")
		assert_eq(tr.has("s07a"), want == "declared", "the cloth readback only with clothRoute")
		assert_eq([(st["book"]["marvels"] as Array).count("AN EMPTY PEDESTAL"), st["flags"].get("columnAgain")], [1, true], "the pedestal; the column")
		assert_true(tr.has("s15") and tr.has("s16") and tr[tr.size() - 2] == "s16", "JERUSALEM: LOADING..., then never")
	assert_eq(StoryLibrary.scene("7.9").completion["boundary"], "chapter_end", "the chapter ends")
	# 2.1's dream of the pastel city is a promise; from the departure (Level 5) on, no stage is Jerusalem.
	for ch: StoryChapterData in StoryLibrary.chapters():
		if ch.number < 5:
			continue
		for sc: StorySceneData in ch.scenes:
			for step: StoryStep in sc.steps:
				assert_false(step is StageStep and (step as StageStep).map == "jerusalem", "%s: Jerusalem never loads" % sc.id)


# --- Level 8 ---------------------------------------------------------------------------------------

const SHIP_MARVELS := ["THE GREAT SHIPS", "THE HORSE TRANSPORTS", "THE GALLEYS", "THE FLEET LEAVING VENICE"]
## src/campaign/home.ts HOME_OBJECTS (the marvel -> home object mapping), the four of the study.
const HOME := {"THE CARVED COLUMN": "THE CHAIR LEG, WITH HIS TOOTH MARKS ON IT", "THE GOLDEN DOMES": "THE LAMPSHADE (IT IS A DOME)",
	"THE HIPPODROME": "THE RUG (IT IS A RACETRACK)", "A LAMP IN A COURTYARD": "THE DESK LAMP"}
## Every marvel the campaign can award (src/campaign/home.ts KNOWN_MARVELS).
const KNOWN_MARVELS := ["THE GREAT SHIPS", "THE HORSE TRANSPORTS", "THE GALLEYS", "THE FLEET LEAVING VENICE", "THE GREAT WALLS", "THE CITY OF ROOFS",
	"THE GOLDEN DOMES", "THE PALACE OF THE LION'S MOUTH", "THE CARVED COLUMN", "THE BRONZE HERCULES", "A LAMP IN A COURTYARD", "THE GREAT CHURCH",
	"THE HIPPODROME", "AN EMPTY PEDESTAL"]


## STY-801, WALK-018 (8.1): reality (the plain costume); the controls scramble at once and every
## 2.6 s by one of 90, 180, −90, 135 degrees (the scene's seeded generator: the same turns in another
## run), and the joystick really turns by that angle; JERUSALEM moves one step away whenever he comes
## near; within 30 % of the way the controls settle for good. Then the real-input driver, which learns
## the turn from where his legs take him, reaches the chair leg.
func test_STY_801_WALK_018_scrambled_legs_settling_and_jerusalem_out_of_reach() -> void:
	var s := _scene("8.1", _entry("8.1"))
	if not _to_step(s, "s04"):
		return
	assert_eq(s.world.player.costume, "normal", "reality: the plain costume")
	_ticks(s, 1)
	var turns: Array = s.ctx.metrics["scramble"]
	assert_true(turns.size() == 1 and [90.0, 180.0, -90.0, 135.0].has(float(turns[0])), "a scramble at once: %s" % [turns])
	assert_near(s.ctx.scramble_angle, deg_to_rad(float(turns[0])), 1e-6, "the joystick's turn")
	assert_true((s.ctx.metrics["notices"] as Array).has("THE CONTROLS SCRAMBLE"), "its notice")
	# The joystick really turns: pressed right, he goes the turned way.
	s.world.player.set_grid_position(8.5, 20.5)
	for k in 12:
		InputService.inject_move(1.0, 0.0)
		InputService.update(DT)
		s.tick(DT)
	InputService.clear_injection()
	var v := IsoGrid.grid_vec_to_screen(s.world.player.vx, s.world.player.vy).normalized()
	assert_vec_near(v, Vector2(1, 0).rotated(s.ctx.scramble_angle), 0.05, "pressed right, he goes the turned way")
	_ticks(s, int(2.7 / DT))
	assert_eq(turns.size(), 2, "again after 2.6 s")
	var s2 := _scene("8.1", _entry("8.1"))
	if _to_step(s2, "s04"):
		_ticks(s2, 1 + 12 + int(2.7 / DT))
		assert_eq(s2.ctx.metrics["scramble"], turns, "the same turns in another run")
	# Jerusalem: one step away.
	s.world.player.set_grid_position(7.5, 24.0)
	_ticks(s, 1)
	var moved: Array = s.ctx.metrics.get("jerusalem_moves", [])
	assert_eq(moved.size(), 1, "near Jerusalem: it moves away")
	s.world.player.set_grid_position((moved[0] as Vector2).x, (moved[0] as Vector2).y)
	_ticks(s, 1)
	assert_eq(moved.size(), 2, "and again: never within reach")
	# Settling: within 30 % of the way.
	s.world.player.set_grid_position(8.5, 10.5)
	_ticks(s, 1)
	assert_true(turns.has("settled") and s.ctx.scramble_angle == 0.0, "the controls settle")
	var n := turns.size()
	_ticks(s, int(3.0 / DT))
	assert_eq(turns.size(), n, "for good")
	var out := _play("8.1", _entry("8.1"))
	if assert_true(out.has("result"), "8.1 completes by real input (the driver learns the turn)"):
		var m: Dictionary = out["result"]["metrics"]
		assert_true((m["scramble"] as Array).size() >= 2 and (m["scramble"] as Array).has("settled"), "scrambled, then settled: %s" % [m["scramble"]])
		assert_true((out["result"]["state"]["book"]["remembered"] as Array).has("THERE WAS A DOG, AND HE WAS WAKING UP."), "his line")
		assert_false(m.has("faded"), "Level 8: no fade")


## STY-802, CAMP-009–011 (8.2): the study objects are what the dream made of them only for the marvels
## he saw (the source's home mapping); the oath told as it happened (his own words or Niketas's); the
## lamp and the letter read back; the drawings locked unless he saw them (the bowl always open); Grace
## sets the telling tier; the rag cross and the drawing are the only things in his book from here.
func test_STY_802_CAMP_009_011_study_objects_telling_drawing_and_readbacks() -> void:
	var e := _entry("8.2")
	e["book"]["marvels"] = SHIP_MARVELS + ["THE CARVED COLUMN", "THE HIPPODROME", "AN EMPTY PEDESTAL"]
	e["flags"].merge({"oath": "enforced", "lamp": "kept", "letter": "named"}, true)
	e["meters"]["grace"] = 75.0
	var a := _play("8.2", e, {"s11": "pedestal"})
	if not assert_true(a.has("result"), "8.2 (seen, called, kept, named) completes"):
		return
	var shown: Array = a["result"]["metrics"]["notices"]
	for pair: Array in [["THE CARVED COLUMN", true], ["THE HIPPODROME", true], ["THE GOLDEN DOMES", false], ["A LAMP IN A COURTYARD", false]]:
		assert_eq(shown.has("%s. HE KNOWS EXACTLY WHAT IT WAS." % HOME[pair[0]]), pair[1], "%s: %s" % [pair[0], "what the dream made of it" if pair[1] else "only itself"])
	for plain in ["THE LAMPSHADE. IT IS DUSTY.", "THE DESK LAMP. IT IS OFF."]:
		assert_true(shown.has(plain), plain)
	var ta: PackedStringArray = a["result"]["trace"]
	for id in ["s08a", "s08b", "s08c", "s09a", "s10a", "s13b"]:
		assert_true(ta.has(id), "readback " + id)
	for id in ["s08d", "s09b", "s10b", "s13d", "s13f"]:
		assert_false(ta.has(id), "not " + id)
	var sa: Dictionary = a["result"]["state"]
	assert_eq([sa["flags"].get("drawing"), sa["flags"].get("tellingTier"), sa["flags"].get("told")], ["pedestal", "high", true], "the pedestal drawing; told straight")
	assert_eq(sa["book"]["items"], e["book"]["items"] + ["THE RAG CROSS", "A DRAWING OF AN EMPTY PEDESTAL"], "the rag cross and the drawing")
	assert_eq(float(sa["meters"]["commozione"]) - float(e["meters"]["commozione"]), 10.0, "Commozione +10 (no fade in Level 8)")
	assert_eq(a["scene"].world.player.costume, "normal", "reality")
	# Unseen city, no pedestal, silent, declared, necessity, Grace 50: the locks and the other readbacks.
	var e2 := _entry("8.2")
	e2["book"]["marvels"] = SHIP_MARVELS.duplicate()
	e2["flags"].merge({"oath": "silent", "lamp": "declared", "letter": "necessity"}, true)
	e2["meters"]["grace"] = 50.0
	var s := _scene("8.2", e2)
	if not _drive_until(s, func() -> bool: return s.runner.current != null and s.runner.current.id == "s11" and String(s.runner.st.get("phase", "")) == "choosing", 60 * 60):
		fail("8.2: no drawing choice")
		return
	var locks := {}
	for k in (s.runner.st["open"] as Array).size():
		locks[(s.runner.st["open"][k] as StoryChoiceOption).id] = String((s.runner.st["views"][k] as Dictionary)["locked"])
	assert_eq(locks, {"ships": "", "city": "HE NEVER LOOKED AT THE CITY", "pedestal": "HE NEVER SAW IT EMPTY", "bowl": ""}, "locked unless he saw them; the bowl always open")
	var b := _play("8.2", e2, {"s11": "bowl"})
	if assert_true(b.has("result"), "8.2 (unseen, silent, declared, necessity) completes"):
		var tb: PackedStringArray = b["result"]["trace"]
		for id in ["s08d", "s08e", "s08f", "s09b", "s10b", "s13d"]:
			assert_true(tb.has(id), "readback " + id)
		assert_eq([b["result"]["state"]["flags"].get("drawing"), b["result"]["state"]["flags"].get("tellingTier")], ["bowl", "mid"], "the bowl; mostly straight")
	var e3 := _entry("8.2")
	e3["meters"]["grace"] = 39.0
	var c := _play("8.2", e3)
	if assert_true(c.has("result"), "8.2 (Grace 39) completes"):
		assert_eq([c["result"]["state"]["flags"].get("tellingTier"), (c["result"]["trace"] as PackedStringArray).has("s13f")], ["low", true], "told beautifully")
	# CAMP-009/010: the study's four objects follow the source's mapping; every marvel the campaign
	# awards is a known one.
	for step: StoryStep in StoryLibrary.scene("8.2").steps:
		if step is ObjectiveStep:
			for p: StoryPickup in (step as ObjectiveStep).pickups:
				assert_eq(p.seen_text, "%s. HE KNOWS EXACTLY WHAT IT WAS." % HOME[p.seen_marvel], p.id + ": the home object of " + p.seen_marvel)
	var awarded := {}
	for ch: StoryChapterData in StoryLibrary.chapters():
		for sc: StorySceneData in ch.scenes:
			for fx: Dictionary in _all_effects(sc.steps):
				if fx.has("marvel"):
					awarded[String(fx["marvel"])] = true
	for m: String in awarded:
		assert_true(KNOWN_MARVELS.has(m), m + " is a known marvel")
	assert_eq(awarded.size(), KNOWN_MARVELS.size(), "every known marvel can be awarded")


static func _all_effects(steps: Array) -> Array:
	var out: Array = []
	for st: StoryStep in steps:
		out.append_array(st.effect_sets())
		for b: Array in st.branches():
			out.append_array(_all_effects(b))
	return out


## STY-803, NPC-008–011 (8.3): Sbrimbrulon and Confusione follow at his sides; a flinch (standing still
## 0.6 s) and they stop and wait, turned to him; when he walks on they fall in again; past the middle
## of the lane the line shows once; Bagnaskiz steps aside; DRINK at the bowl, which is pushed back
## onto the lane (where any dog can reach it); Supervillain +25, RESISTANCE, `lawnHeld`; the
## SUPERVILLAINED card.
func test_STY_803_NPC_008_011_friends_fall_in_wait_and_the_bowl_left_open() -> void:
	var s := _scene("8.3", _entry("8.3"))
	if not _to_step(s, "s08"):
		return
	var sb: StoryActor = s.actors["sbrim"]
	var cf: StoryActor = s.actors["conf"]
	assert_eq([sb.behavior, cf.behavior, sb.follow_side, cf.follow_side], ["follow", "follow", -0.9, 0.9], "they follow at his sides")
	_ticks(s, int(0.7 / DT))
	assert_eq([sb.behavior, cf.behavior], ["idle", "idle"], "he flinches: they wait for him")
	assert_true((s.ctx.metrics["notices"] as Array).has("HE FLINCHES. THEY WAIT FOR HIM"), "its notice")
	for k in 20:
		InputService.inject_move(1.0, 0.2)
		InputService.update(DT)
		s.tick(DT)
	InputService.clear_injection()
	assert_eq([sb.behavior, cf.behavior], ["follow", "follow"], "he walks on: they fall in again")
	assert_eq([s.ctx.metrics["flinch"], s.ctx.metrics["rejoined"]], [["s08"], ["s08"]], "one wait, one rejoin")
	var out := {}
	s.completed.connect(func(r: Dictionary) -> void: out["r"] = r)
	var d := StoryDriver.new(s)
	for k in 60 * 120:
		if out.has("r"):
			break
		d.drive(DT)
		InputService.update(DT)
		s.tick(DT)
	if not assert_true(out.has("r"), "8.3 completes by real input"):
		return
	assert_eq((out["r"]["metrics"]["notices"] as Array).count("SBRIMBRULON AND CONFUSIONE FALL IN BESIDE HIM"), 1, "the fall-in line once")
	assert_eq(s.actors["bag"].behavior, "goto", "Bagnaskiz steps aside")
	var bowl: StoryProp = s.props["bowl"]
	assert_vec_near(Vector2(bowl.gx, bowl.gy), Vector2(13.5, 3.5), 0.01, "the bowl pushed back onto the lane")
	var st: Dictionary = out["r"]["state"]
	assert_eq([st["flags"].get("lawnHeld"), (st["book"]["values"] as Array).count("Resistance")], [true, 1], "lawnHeld; RESISTANCE once")
	assert_eq(float(st["meters"]["supervillain"]), minf(100.0, float(_entry("8.3")["meters"]["supervillain"]) + 25.0), "Supervillain +25 (to the meter's top)")
	assert_true((out["r"]["trace"] as PackedStringArray).has("s18"), "YOU HAVE BEEN SUPERVILLAINED")


## STY-804 (8.4): his day told (with `vanguard`, the walk; without it, not); the ball pushed through
## the bars by PUSH at the ball; it rolls to her; another dog drinks from the bowl; `ballReturned`,
## `courtesy84` = unanswered, her question remembered; CUT.; the campaign's last scene.
func test_STY_804_the_ball_returned_and_the_question_unanswered() -> void:
	for walked: bool in [true, false]:
		var e := _entry("8.4")
		e["flags"]["vanguard"] = walked
		if not walked:
			e["flags"].erase("vanguard")
		var out := _play("8.4", e)
		if not assert_true(out.has("result"), "8.4 completes (vanguard %s)" % walked):
			continue
		var tr: PackedStringArray = out["result"]["trace"]
		assert_eq(tr.has("s07a"), walked, "the walk told only with vanguard")
		var st: Dictionary = out["result"]["state"]
		assert_eq([st["flags"].get("ballReturned"), st["flags"].get("courtesy84")], [true, "unanswered"], "the ball returned; her question unanswered")
		assert_true((st["book"]["remembered"] as Array).has("WHO TOLD YOU THEY SAID THAT?"), "her question remembered")
		var sc: StoryScene = out["scene"]
		var ball: StoryProp = sc.props["ball"]
		assert_vec_near(Vector2(ball.gx, ball.gy), Vector2(23.1, 3.7), 0.01, "through the bars to her")
		assert_eq(sc.actors["dog"].behavior, "goto", "another dog goes to drink")
		assert_eq(tr[tr.size() - 3], "s23", "CUT.")
	assert_eq(StoryLibrary.scene("8.4").completion["boundary"], "chapter_end", "the campaign's last boundary")
	assert_eq(SaveService.CATALOG.next_unfinished(Array(SaveService.CATALOG.ids())), {}, "nothing after 8.4")


## CAMP-004 (the fade, RD-05): every dream scene of Levels 2–7 starts with 2 less Commozione on its
## working copy (never below 0, with its notice); reality scenes (Levels 1 and 8) do not fade; a
## restart fades once from the entry state, never twice; nothing is saved by the fade itself.
func test_CAMP_004_commozione_fades_once_per_dream_scene() -> void:
	for id: String in ["5.1", "6.2", "7.6", "8.1"]:
		var s := _scene(id, _entry(id))
		_ticks(s, 1)
		var faded := 0.0 if id == "8.1" else RS.COMMOZIONE_FADE
		assert_eq(float(s.ctx.state["meters"]["commozione"]), float(_entry(id)["meters"]["commozione"]) - faded, "%s: -%s" % [id, faded])
		assert_eq((s.ctx.metrics["notices"] as Array).has("-2 COMMOZIONE: THE FEELING FADES"), id != "8.1", id + ": the notice")
		s.restart()
		_ticks(s, 1)
		assert_eq(float(s.ctx.state["meters"]["commozione"]), float(_entry(id)["meters"]["commozione"]) - faded, id + ": a restart fades once, not twice")
	var low := _entry("6.2")
	low["meters"]["commozione"] = 1.0
	var s2 := _scene("6.2", low)
	_ticks(s2, 1)
	assert_eq([float(s2.ctx.state["meters"]["commozione"]), float(s2.ctx.metrics["faded"])], [0.0, 1.0], "never below 0")
	for lv in [1, 8]:
		var st := CampaignSchema.new_campaign()
		assert_eq(CampaignRules.fade_commozione(st, lv), 0.0, "Level %d: no fade" % lv)


## CAMP-005/006, END-003/004: the Grace tiers (8.2's telling, the ending's line) and the Standing tiers
## at both boundaries and next to them; 8.2's branch thresholds are the same numbers; the exact lines.
func test_CAMP_005_006_END_003_004_grace_and_standing_tiers_and_lines() -> void:
	var text: ShellText = StoryScene.TEXT
	var st := CampaignSchema.new_campaign()
	for row: Array in [[100.0, "high"], [70.0, "high"], [69.99, "mid"], [40.0, "mid"], [39.99, "low"], [0.0, "low"]]:
		st["meters"]["grace"] = row[0]
		assert_eq(CampaignFlow.grace_tier(st), row[1], "Grace %s" % row[0])
		assert_eq(CampaignFlow.ending_notes(st, text)[0], text.get_text("ending_grace_" + String(row[1])), "Grace %s: its line" % row[0])
	assert_eq(text.get_text("ending_grace_high"), "HE KEPT THE FORMS HE SWORE TO, EVEN THE SMALL ONES NOBODY CHECKS.", "the high line")
	assert_eq(text.get_text("ending_grace_mid"), "HE KEPT MOST OF THE FORMS HE SWORE TO. ABOUT THE REST HE HAS A LONG EXPLANATION.", "the mid line")
	assert_eq(text.get_text("ending_grace_low"), "HE BROKE THE FORMS HE SWORE TO, AND EVERY AUTHORITY FORGAVE HIM. HE HAS NOT QUITE FORGIVEN HIMSELF.", "the low line")
	for row: Array in [[100.0, "fond"], [60.0, "fond"], [59.99, "fair"], [35.0, "fair"], [34.99, "low"], [0.0, "low"]]:
		st["meters"]["standing"] = row[0]
		assert_eq(CampaignFlow.standing_tier(st), row[1], "Standing %s" % row[0])
		assert_eq(CampaignFlow.ending_notes(st, text)[1], text.get_text("ending_standing_" + String(row[1])), "Standing %s: its line" % row[0])
	assert_eq([text.get_text("ending_standing_fond"), text.get_text("ending_standing_fair"), text.get_text("ending_standing_low")],
		["THE CAMP REMEMBERS HIM FONDLY. THE DOGS AT THE FENCES WATCH HIM DRINK AND SAY NOTHING.", "THE CAMP REMEMBERS HIM, MORE OR LESS.", "THE MARSHAL REMEMBERS WHO SPOKE AGAINST HIM. HE WALKED ON ANYWAY."], "the Standing lines")
	var cases := {}
	for step: StoryStep in StoryLibrary.scene("8.2").steps:
		if step is BranchStep and step.id == "s13":
			for c: StoryBranchCase in (step as BranchStep).cases:
				cases[c.id] = float(c.when["gte"])
	assert_eq(cases, {"high": RS.GRACE_HIGH, "mid": RS.GRACE_LOW}, "8.2's telling uses the same thresholds")


## END-001/002: the ending is decided by 7.8 alone: `oath` enforced is THE KNIGHT with his own-words
## account; silent, undecided or absent is THE WITNESS, whose key stays `alpha`.
func test_END_001_002_knight_or_witness_by_the_oath_alone() -> void:
	var st := CampaignSchema.new_campaign()
	var text: ShellText = StoryScene.TEXT
	for row: Array in [["enforced", "knight"], ["silent", "alpha"], ["undecided", "alpha"], [null, "alpha"]]:
		if row[0] == null:
			st["flags"].erase("oath")
		else:
			st["flags"]["oath"] = row[0]
		assert_eq(CampaignFlow.ending(st), row[1], "oath %s" % [row[0]])
	assert_eq([text.get_text("ending_knight"), text.get_text("ending_alpha")], ["THE KNIGHT", "THE WITNESS"], "their names")
	assert_true(text.get_text("ending_story_knight").begins_with("IN A LULL IN THE LOOTING HE CALLED THE PILGRIMS TO THEIR OATH, IN HIS OWN WORDS"), "the knight's account: his own words")
	assert_true(text.get_text("ending_story_alpha").begins_with("HE STOOD SILENT WHILE NIKETAS CALLED THE PILGRIMS TO THEIR OATH"), "the witness's account: Niketas's words")


## CAMP-013: the dream skin: every dream scene (Levels 2–7) dresses him in the coat of mail, every
## reality scene (Levels 1 and 8) in his own coat, whatever abilities he holds.
func test_CAMP_013_costume_follows_dream_or_reality() -> void:
	for ch: StoryChapterData in StoryLibrary.chapters():
		for sc: StorySceneData in ch.scenes:
			var want := "normal" if ch.number == 1 or ch.number == 8 else "armoured"
			assert_eq([sc.reality, sc.costume()], [want == "normal", want], "%s: %s" % [sc.id, want])


## The full COLL-005b aggregate (M7): every scripted spatial objective of every chapter (1–8) is
## reachable under the grid solver from where its scene places Zampanò when the walk starts; each scene
## runs from a state with the scenes before it completed and every ability held.
func test_COLL_005b_every_chapter_scripted_objectives_reachable() -> void:
	var done: Array = ["1.0"]
	var checked := 0
	var n_scenes := 0
	for ch: StoryChapterData in StoryLibrary.chapters():
		for sc: StorySceneData in ch.scenes:
			var st := _base()
			st["completed"] = done.duplicate()
			st["flags"]["oath"] = "enforced"
			st["flags"]["lamp"] = "declared"
			var s := _scene(sc.id, st)
			var d := StoryDriver.new(s, {}, "bark", true)
			var seen := {}
			var here := 0
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
						assert_true(reach, "%s %s: %s reachable from %s" % [sc.id, o.id, t, from])
						here += 1
				d.drive(DT)
				InputService.update(DT)
				s.tick(DT)
			InputService.guard_hold_injected = false
			assert_true(s.finished, sc.id + ": the scripted run ends")
			if here == 0:
				assert_false(_has_spatial(sc.steps), "%s has scripted targets, none checked" % sc.id)
			checked += here
			n_scenes += 1
			done.append(sc.id)
	print("COLL-005b aggregate: %d targets in %d scenes" % [checked, n_scenes])
	assert_eq(n_scenes, 36, "every story scene of the campaign (1.1–8.4)")


## The campaign's 37 entries in order (1.0 the Green Zone walk, then 1.1–8.4), each story entry with
## its Resource, each chapter's scenes in the catalog's order, and an explicit, unchanged-save failure
## for content that cannot run (a missing marker).
func test_CAMP_order_37_entries_and_explicit_failure_on_missing_content() -> void:
	var want := ["1.0", "1.1", "1.2", "1.3", "1.4", "1.5", "2.1", "2.2", "2.3", "3.1", "3.2", "3.3", "3.4", "4.1", "4.2", "4.3",
		"5.1", "5.2", "5.3", "5.4", "5.5", "6.1", "6.2", "6.3", "7.1", "7.2", "7.3", "7.4", "7.5", "7.6", "7.7", "7.8", "7.9", "8.1", "8.2", "8.3", "8.4"]
	assert_eq(Array(SaveService.CATALOG.ids()), want, "37 entries in order")
	for id: String in want:
		assert_eq(StoryLibrary.has_scene(id), id != "1.0", id + ": its Resource (1.0 is the walk)")
	for ch: StoryChapterData in StoryLibrary.chapters():
		var ids: Array = ch.scenes.map(func(x: StorySceneData) -> String: return x.id)
		var listed := (SaveService.CATALOG.chapter(ch.number)["sub_levels"] as Array).map(func(x: Dictionary) -> String: return String(x["id"])).filter(func(x: String) -> bool: return x != "1.0")
		assert_eq(ids, listed, "Level %d's order (1.0 is the walk)" % ch.number)
	var bad: StorySceneData = StoryLibrary.scene("8.4").duplicate(true)
	var steps: Array = bad.steps.duplicate()
	var stage: StageStep = (steps[0] as StageStep).duplicate()
	stage.player_at = "Q"
	stage.player_point = Vector2.ZERO
	steps[0] = stage
	bad.steps = steps
	assert_true(StoryValidator.for_project().validate_scene(bad).size() > 0, "the validator names it")
	var before := SaveService.get_campaign().duplicate(true)
	var s: StoryScene = STORY.instantiate()
	var failed := [""]
	s.failed.connect(func(m: String) -> void: failed[0] = m)
	s.setup(bad, _entry("8.4"), true)
	tree.root.add_child(s)
	scenes.append(s)
	s.manual_ticks = true
	await tree.process_frame
	for k in 5:
		s.tick(DT)
	assert_eq(failed[0], "story 8.4: missing marker 'Q' on map 'neighborhood'", "an explicit failure names the scene and the marker")
	var cap: ErrorCapture = tree.get("_capture")
	var logged := cap.take() if cap else []
	assert_eq(logged.filter(func(x: Dictionary) -> bool: return String(x["code"]).contains("missing marker 'Q'") or String(x["rationale"]).contains("missing marker 'Q'")).size(), 1, "reported once as an engine error")
	assert_eq(SaveService.get_campaign(), before, "the save is unchanged")


## CAMP-014: full Supervillain (source `unshakeable`, the meter at its top, 100): the book shows
## SUPERVILLAIN 100 (FULL); below the top it shows the number alone. The draft's other use, softening
## the generic pace walk's nerve loss, has no scene in the campaign (FEATURE_MATRIX: excluded unless
## reused); 7.3's and 8.3's walks are their own rules, as in the draft.
func test_CAMP_014_full_supervillain_unshakeable_and_the_books_label() -> void:
	var st := CampaignSchema.new_campaign()
	for row: Array in [[100.0, true, "SUPERVILLAIN 100 (FULL)"], [99.99, false, "SUPERVILLAIN 99.99"], [10.0, false, "SUPERVILLAIN 10"]]:
		st["meters"]["supervillain"] = row[0]
		assert_eq(CampaignRules.unshakeable(st), row[1], "Supervillain %s: unshakeable %s" % [row[0], row[1]])
		var book := MeravigliaOverlay.new().setup(st, StoryScene.TEXT, func() -> void: pass)
		var lines: Array = book.rows.map(func(r: Dictionary) -> String: return String(r["text"]))
		assert_true(lines.has(row[2]), "the book: %s (%s)" % [row[2], lines.slice(0, 6)])
		book.free()
	assert_eq(CampaignSchema.METER_MAX, 100, "the top of the meter")


# --- The whole campaign through the real Main ----------------------------------------------------

const LEVEL_LAST := ["1.5", "2.3", "3.4", "4.3", "5.5", "6.3", "7.9", "8.4"]


func _key_tap(code: Key) -> void:
	for down: bool in [true, false]:
		var e := InputEventKey.new()
		e.keycode = code
		e.physical_keycode = code
		e.pressed = down
		Input.parse_input_event(e)
		await tree.process_frame


## Waits until the overlay `o` has been up for `guard` seconds of its own time (real frames).
func _aged(o: Object, guard: float) -> bool:
	return await _until(func() -> bool: return not is_instance_valid(o) or float(o.get("time")) > guard, 20000)


## Moves a menu's selection to `index` with the arrow keys, then presses Enter (the keyboard path a
## player uses; InputService updates itself on frames).
func _choose_row(panel: OverlayPanel, index: int, guard: float = 0.3) -> void:
	await _aged(panel, guard)
	for k in 12:
		if panel.selected == index:
			break
		await _key_tap(KEY_DOWN if panel.selected < index else KEY_UP)
	await _key_tap(KEY_ENTER)


static func _row(panel: OverlayPanel, label: String) -> int:
	return panel.items.map(func(i: Dictionary) -> String: return String(i["label"])).find(label)


## Waits for the card of `id` and presses Enter once it accepts it (0.5 s); returns its StoryScene,
## ticked by hand from then on.
func _key_card(id: String) -> StoryScene:
	if not await _until(func() -> bool: return main.top_overlay() is MessageOverlay and main.top_overlay().get_meta(&"story_card", "") == id, 20000):
		fail("no story card for %s" % id)
		return null
	await _aged(main.top_overlay(), 0.55)
	await _key_tap(KEY_ENTER)
	if not await _until(func() -> bool: return main.current_scene is StoryScene and (main.current_scene as StoryScene).data.id == id, 20000):
		fail("%s did not start" % id)
		return null
	var s := main.current_scene as StoryScene
	s.manual_ticks = true
	return s


## One whole campaign through the real Main by real input only, from the title's NEW GAME (and its
## YES when a story is saved): the Green Zone walk (GreenZoneDriver: movement, RUN, PEE, BARK); its
## snap, result card and CONTINUE; every scene card; every scene of 1.1–8.4 (StoryDriver at `skill`;
## choices by `choice_mode`; 5.4's letter and 7.8's oath by policy; a lost fight is played again
## through its own reset, a lost minigame goes on, nothing is skipped); each level's end (the snap,
## the Professor's aside); the ending card and THE END, which opens the level list. Every menu, card
## and screen is answered with real key presses (arrows, Enter) once it accepts them; nothing is
## called on a screen and no save is written by the test. At the card of `reload_at` the game is
## closed without warning and started again from the save file: the title's CONTINUE resumes there.
func _campaign(label: String, choice_mode: String, oath: String, letter: String, skill: float, reload_at: String) -> Dictionary:
	var rep := {"label": label, "scenes": {}, "knockdowns": 0, "lapses": 0, "restarts": 0, "minis": [], "asides": [], "ending": "", "reload": "", "ok": false}
	InputService.auto_update = true
	await _main_start()
	await _settle()
	var title := main.current_scene as TitleScreen
	await _choose_row(title, _row(title, "NEW GAME"), 0.7)
	if await _until(func() -> bool: return main.top_overlay() is ConfirmOverlay, 300):
		var c := main.top_overlay() as ConfirmOverlay
		await _choose_row(c, _row(c, "YES"))
	if not await _until(func() -> bool: return main.current_scene is GreenZoneScene, 20000):
		fail(label + ": no Green Zone after NEW GAME")
		return rep
	assert_eq(SaveService.get_campaign()["completed"], [], label + ": NEW GAME saved a new campaign")
	var gz := main.current_scene as GreenZoneScene
	var briefing: OverlayPanel = gz._overlay
	if briefing:
		await _aged(briefing, 0.6)
	await _key_tap(KEY_ENTER)
	if not await _until(func() -> bool: return gz.active, 600):
		fail(label + ": the briefing did not start the walk")
		return rep
	gz.manual_ticks = true
	InputService.auto_update = false
	var gd := GreenZoneDriver.new()
	for k in 60 * 400:
		if gz.rules.state != "playing":
			break
		gd.step(gz)
		InputService.update(DT)
		AudioService.advance_pending(DT)
		gz.tick(DT)
		if gz.ticks % 6 == 0:
			gz._process(DT)
	InputService.clear_injection()
	rep["walk"] = {"state": gz.rules.state, "time": snappedf(float(gz.rules.stats["time"]), 0.1), "coins": int(gz.rules.stats["coins"])}
	if not assert_true(gz.rules.state == "complete", "%s: the walk reaches the exit by real input (%s)" % [label, gz.rules.state]):
		return rep
	for k in 80:
		InputService.update(DT)
		AudioService.advance_pending(DT)
		gz.tick(DT)
	InputService.auto_update = true
	if not assert_true(await _until(func() -> bool: return gz._overlay is SupervillainedOverlay, 3000), label + ": the walk's snap"):
		return rep
	await _aged(gz._overlay, GameConfig.Supervillained.SKIP_AFTER + 0.05)
	await _key_tap(KEY_ENTER)
	if not assert_true(await _until(func() -> bool: return gz._overlay is LevelEndOverlay, 3000), label + ": the walk's result card"):
		return rep
	var end := gz._overlay as LevelEndOverlay
	await _key_tap(KEY_ENTER)
	await _until(func() -> bool: return end.menu_visible(), 3000)
	await _choose_row(end, _row(end, "CONTINUE"))
	for id: String in Array(SaveService.CATALOG.ids()):
		if id == "1.0":
			continue
		if id == reload_at:
			# Closed without warning at the card, then started again from the save file.
			if not await _until(func() -> bool: return main.top_overlay() is MessageOverlay and main.top_overlay().get_meta(&"story_card", "") == id, 20000):
				fail("%s: no card for %s before the close" % [label, id])
				return rep
			var bytes := FileAccess.get_file_as_bytes(SaveService.base_dir + "save_v3.json")
			var before := SaveService.get_campaign().duplicate(true)
			main.get_parent().remove_child(main)
			main.free()
			main = null
			SaveService.load_from_disk()
			assert_eq([FileAccess.get_file_as_bytes(SaveService.base_dir + "save_v3.json"), SaveService.get_campaign()], [bytes, before], "%s: the save file holds the campaign after the close" % label)
			await _main_start()
			await _settle()
			var t2 := main.current_scene as TitleScreen
			assert_eq(t2.selected, _row(t2, "CONTINUE"), label + ": with a saved story the title preselects CONTINUE")
			await _choose_row(t2, _row(t2, "CONTINUE"), 0.7)
			rep["reload"] = id
		var s := await _key_card(id)
		if s == null:
			return rep
		InputService.auto_update = false
		var d := StoryDriver.new(s, {"oath": oath, "letter": letter})
		d.skill = skill
		d.choice_mode = choice_mode
		d.rng.seed = hash("%s:%s" % [label, id])
		var ticks := 0
		while not s.finished and ticks < 60 * 900:
			d.drive(DT)
			InputService.update(DT)
			s.tick(DT)
			ticks += 1
		InputService.guard_hold_injected = false
		InputService.clear_injection()
		InputService.auto_update = true
		if not assert_true(s.finished, "%s %s: played to the end by real input (%d ticks)" % [label, id, ticks]):
			return rep
		var m: Dictionary = s.ctx.metrics
		rep["scenes"][id] = snappedf(ticks * DT, 0.1)
		rep["knockdowns"] = int(rep["knockdowns"]) + (m["knockdowns"] as Array).size()
		rep["lapses"] = int(rep["lapses"]) + d.lapses
		rep["restarts"] = int(rep["restarts"]) + s.restarts
		for r: String in m.get("minis", []):
			(rep["minis"] as Array).append("%s %s" % [id, r])
		var saved := await _until(func() -> bool: return (SaveService.get_campaign()["completed"] as Array).has(id), 600)
		assert_true(saved, "%s %s: saved" % [label, id])
		if LEVEL_LAST.has(id):
			if not assert_true(await _until(func() -> bool: return main.top_overlay() is SupervillainedOverlay, 3000), "%s %s: the snap at the level's end" % [label, id]):
				return rep
			await _aged(main.top_overlay(), GameConfig.Supervillained.SKIP_AFTER + 0.05)
			await _key_tap(KEY_ENTER)
			if not assert_true(await _until(func() -> bool: return main.top_overlay() is MessageOverlay and main.top_overlay().has_meta(&"professor_aside"), 3000), "%s %s: the aside" % [label, id]):
				return rep
			var aside := main.top_overlay() as MessageOverlay
			(rep["asides"] as Array).append(int(aside.get_meta(&"professor_aside")))
			await _aged(aside, 0.55)
			await _key_tap(KEY_ENTER)
	if not assert_true(await _until(func() -> bool: return main.top_overlay() is MessageOverlay and main.top_overlay().has_meta(&"ending"), 20000), label + ": the ending card"):
		return rep
	var ending := main.top_overlay() as MessageOverlay
	rep["ending"] = String(ending.get_meta(&"ending"))
	rep["ending_heading"] = ending.heading
	rep["ending_paragraphs"] = ending.paragraphs.map(func(p: Array) -> String: return String(p[0]))
	await _aged(ending, 0.55)
	await _key_tap(KEY_ENTER)
	assert_true(await _until(func() -> bool: return main.top_overlay() is LevelListOverlay), label + ": THE END opens the level list")
	var camp := SaveService.get_campaign()
	rep["final"] = {"meters": camp["meters"], "flags": camp["flags"], "abilities": camp["abilities"], "coins": camp["coins"],
		"book": {"marvels": (camp["book"]["marvels"] as Array).size(), "values": camp["book"]["values"], "items": (camp["book"]["items"] as Array).size(),
			"remembered": (camp["book"]["remembered"] as Array).size()}, "completed": (camp["completed"] as Array).size()}
	rep["ok"] = true
	print("CAMPAIGN %s: %s" % [label, JSON.stringify(rep)])
	return rep


## Back out of every open menu with Esc, then open the COUCH from the title by keys.
func _couch_by_keys() -> CouchOverlay:
	for k in 6:
		if main.top_overlay() == null:
			break
		await _aged(main.top_overlay(), 0.15)
		await _key_tap(KEY_ESCAPE)
		await _until(func() -> bool: return not main.transition.running, 600)
	var title := main.current_scene as TitleScreen
	if title == null or main.top_overlay() != null:
		fail("not back at the title")
		return null
	await _choose_row(title, _row(title, "COUCH"), 0.7)
	await _until(func() -> bool: return main.top_overlay() is CouchOverlay, 600)
	return main.top_overlay() as CouchOverlay


func _check_campaign(rep: Dictionary, ending: String) -> void:
	if not assert_true(rep["ok"], rep["label"] + ": completed"):
		return
	var f: Dictionary = rep["final"]
	assert_eq(f["completed"], 37, "37 entries completed")
	assert_eq(rep["asides"], [1, 2, 3, 4, 5, 6, 7, 8], "eight level ends, each with its aside")
	assert_true(rep["reload"] != "", "closed and resumed from the save file once (at %s)" % rep["reload"])
	assert_eq(f["abilities"], ["cross", "sermon", "knight"], "CAMP-012: the cross, the sermon, the knight, once each")
	assert_eq([rep["ending"], CampaignFlow.ending(SaveService.get_campaign())], [ending, ending], "the ending decided by 7.8")
	var text: ShellText = StoryScene.TEXT
	assert_eq(rep["ending_heading"], text.get_text("ending_" + ending), "its name")
	assert_eq((rep["ending_paragraphs"] as Array)[0], text.get_text("ending_story_" + ending), "its account")
	assert_eq((rep["ending_paragraphs"] as Array)[1], " ".join(CampaignFlow.ending_notes(SaveService.get_campaign(), text)), "the Grace and Standing lines")
	for k: String in ["told", "lawnHeld", "ballReturned", "sworn", "followed", "visitedCity"]:
		assert_eq((f["flags"] as Dictionary).get(k), true, k)
	assert_eq((f["flags"] as Dictionary).get("courtesy84"), "unanswered", "her question unanswered")
	for k: String in ["oath", "lamp", "drawing", "tellingTier", "letter", "zaraOwe", "corfu"]:
		assert_true((f["flags"] as Dictionary).has(k), k + " set")
	for m: String in f["meters"]:
		assert_true(float(f["meters"][m]) >= 0.0 and float(f["meters"][m]) <= 100.0, m + " within 0–100")


## The Knight campaign: first open choices, the letter that names the debt, the oath called in a
## lull; skill 0.7. Through the real Main from the title, by real input only.
func test_CAMP_full_campaign_knight_first_choices_skill_07() -> void:
	var rep := await _campaign("knight-first-0.7", "first", "call", "named", 0.7, "5.1")
	_check_campaign(rep, "knight")
	if rep["ok"]:
		assert_eq((rep["final"]["flags"] as Dictionary).get("oath"), "enforced", "oath enforced")
		# The menus after the end: the level list, Level 8's scenes from the Resources, the Couch.
		var ll := main.top_overlay() as LevelListOverlay
		await _choose_row(ll, 8)
		await _until(func() -> bool: return main.top_overlay() is ChapterListOverlay, 600)
		var ch := main.top_overlay() as ChapterListOverlay
		var listed := []
		for it: Dictionary in ch.items:
			if it.has("id"):
				listed.append(String(it["id"]))
		assert_eq(listed, ["8.1", "8.2", "8.3", "8.4"], "Level 8's list")
		# A replay of 8.4 never triggers the level end or the ending, and changes no saved byte.
		var bytes := FileAccess.get_file_as_bytes(SaveService.base_dir + "save_v3.json")
		var before := SaveService.get_campaign().duplicate(true)
		await _settle()
		var at := -1
		for k in ch.items.size():
			if String((ch.items[k] as Dictionary).get("id", "")) == "8.4":
				at = k
		await _choose_row(ch, at)
		var s := await _key_card("8.4")
		if s != null:
			assert_true(AppState.replaying, "8.4 replayed")
			InputService.auto_update = false
			var d := StoryDriver.new(s)
			for k in 60 * 300:
				if s.finished:
					break
				d.drive(DT)
				InputService.update(DT)
				s.tick(DT)
			InputService.clear_injection()
			InputService.auto_update = true
			assert_true(await _until(func() -> bool: return main.top_overlay() is ChapterListOverlay), "the replay returns to the level's list")
			for k in 30:
				await tree.process_frame
			var top: Control = main.top_overlay()
			assert_false(top is SupervillainedOverlay or (top != null and top.has_meta(&"ending")), "no level end, no ending after a replay")
			assert_eq([SaveService.get_campaign(), FileAccess.get_file_as_bytes(SaveService.base_dir + "save_v3.json")], [before, bytes], "the replay changed no saved byte")
		var couch := await _couch_by_keys()
		assert_true(couch != null and couch.lines().has("ENDING: THE KNIGHT") and couch.lines().has("THE STORY IS FINISHED"), "the Couch (by keys): finished, THE KNIGHT")


## The Witness campaign: last open choices, the letter of necessity, silence at 7.8; skill 0.7.
func test_CAMP_full_campaign_witness_last_choices_skill_07() -> void:
	var rep := await _campaign("witness-last-0.7", "last", "silent", "necessity", 0.7, "7.9")
	_check_campaign(rep, "alpha")
	if rep["ok"]:
		assert_eq((rep["final"]["flags"] as Dictionary).get("oath"), "silent", "oath silent")
		var couch := await _couch_by_keys()
		assert_true(couch != null and couch.lines().has("ENDING: THE WITNESS"), "the Couch (by keys): THE WITNESS")


## The mixed campaign: random open choices, a random letter and oath (seeded), skill 0.4 (late shield,
## missed openings, attention lapses, off-beat presses): fights are lost and played again through the
## walk's reset, minigames lost and gone on from; nothing is skipped.
func test_CAMP_full_campaign_mixed_random_choices_skill_04() -> void:
	var r := RandomNumberGenerator.new()
	r.seed = hash("mixed-campaign")
	var oath := "call" if r.randf() < 0.5 else "silent"
	var letter := "named" if r.randf() < 0.5 else "necessity"
	var rep := await _campaign("mixed-random-0.4", "random", oath, letter, 0.4, "8.1")
	_check_campaign(rep, "knight" if oath == "call" else "alpha")
	# Failures happened and were recovered through the game's own paths (a knockdown's reset; a lost
	# minigame going on), never skipped.
	var lost := (rep["minis"] as Array).filter(func(x: String) -> bool: return x.ends_with(":lost") and not x.contains("tug"))
	assert_true(int(rep["knockdowns"]) + lost.size() >= 1, "failures recovered: %d knockdowns, %s" % [rep["knockdowns"], lost])


## The scripted smoke of every branch of every M7 scene (the debug placement that still runs every
## step and rule): each reaches its completion boundary without an error.
func test_SLICE_m7_scripted_smoke_every_branch() -> void:
	var n := 0
	for id: String in IDS:
		for policy: Dictionary in BRANCHES.get(id, [{}]):
			var out := _play(id, _entry(id), policy, true, 60 * 200)
			var branch := String(policy.values()[0]) if not policy.is_empty() else ""
			assert_false(out.has("error"), "%s/%s: no error (%s)" % [id, branch, out.get("error", "")])
			assert_true(out.has("result"), "%s/%s: the smoke reaches the completion boundary" % [id, branch])
			n += 1
	print("M7 scripted smoke: %d scene branches" % n)

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
