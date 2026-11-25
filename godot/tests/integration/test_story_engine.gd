extends TestCase
## M5R: the story engine's dialogue, objectives and actors (DLG-001–009, WALK-001–009 and
## NPC-001–007 in their Level 1 scope, TEST_PLAN.md). Small scenes built in code exercise one
## behaviour each; Level 1's own scenes cover the objectives and the gestures in place.

const STORY := preload("res://scenes/story/story_scene.tscn")
const DT := 1.0 / 60.0
const NOW := 1795608000000

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
	InputService.clear_injection()
	InputService.release_all()
	InputService.auto_update = true
	AppState.set_setting("textSpeed", "normal")
	AppState.clock = func() -> int: return int(Time.get_unix_time_from_system() * 1000.0)


# --- Builders -----------------------------------------------------------------------------------

static func _stage(actors: Array = []) -> StageStep:
	var s := StageStep.new()
	s.id = "stage"
	s.map = "neighborhood"
	s.player_at = "S"
	s.player_face = "E"
	s.actors = actors
	return s


static func _say(id: String, speaker: String, text: String) -> DialogueStep:
	var d := DialogueStep.new()
	d.id = id
	d.speaker = speaker
	d.text = text
	return d


static func _option(id: String, label: String, cost: int = 0, locked_text: String = "") -> StoryChoiceOption:
	var o := StoryChoiceOption.new()
	o.id = id
	o.label = label
	o.cost = cost
	o.locked_text = locked_text
	return o


static func _data(steps: Array, cast: Array = ["zampano", "professor", "jack"]) -> StorySceneData:
	var d := StorySceneData.new()
	d.id = "1.1"
	d.title = "A bucket on his head"
	d.level = 1
	d.map = "neighborhood"
	d.music = "greenzone"
	d.cast = PackedStringArray(cast)
	var done := CompleteStep.new()
	done.id = "done"
	d.steps = steps + [done]
	d.completion = {"boundary": "scene"}
	return d


func _run(data: StorySceneData, state: Dictionary = CampaignSchema.new_campaign()) -> StoryScene:
	var s: StoryScene = STORY.instantiate()
	s.manual_ticks = true
	s.setup(data, state, true)
	scenes.append(s)
	tree.root.add_child(s)
	return s


func _ticks(s: StoryScene, n: int) -> void:
	for k in n:
		InputService.update(DT)
		s.tick(DT)


func _until_step(s: StoryScene, id: String, limit: int = 600) -> bool:
	for k in limit:
		if s.runner.current != null and s.runner.current.id == id:
			return true
		InputService.trigger(&"confirm")
		_ticks(s, 1)
	return s.runner.current != null and s.runner.current.id == id


# --- Missing content ----------------------------------------------------------------------------

## Missing content fails explicitly at run time, never silently (STORY_REWRITE_SPEC.md §6): a map
## that does not exist, a marker that is not on the map, an actor that was never placed. The scene
## stops, emits `failed` with the reason (Main shows it on the story error card) and reports it as
## an engine error once; nothing completes. (The validator refuses all three before a build.)
func test_SLICE_missing_content_fails_explicitly_at_run_time() -> void:
	var no_map := _stage()
	no_map.map = "nowhere"
	var no_marker := _stage()
	no_marker.player_at = "Q"
	var face := ActorStep.new()
	face.id = "face"
	face.actor = "ghost"
	face.action = "face"
	face.face = "N"
	var cap: ErrorCapture = tree.get("_capture")
	for c: Array in [[[no_map], "missing map 'nowhere'"], [[no_marker], "missing marker 'Q' on map 'neighborhood'"], [[_stage(), face], "missing actor 'ghost'"]]:
		var why: String = c[1]
		var s := _run(_data(c[0]))
		var out := {}
		s.failed.connect(func(m: String) -> void: out["error"] = m)
		s.completed.connect(func(r: Dictionary) -> void: out["result"] = r)
		_ticks(s, 3)
		assert_eq(String(out.get("error", "")), "story 1.1: " + why, "fails with the reason")
		assert_false(out.has("result"), "%s: nothing completes" % why)
		assert_true(s.finished and s.ctx.error != "", "%s: the scene stopped" % why)
		var logged := cap.take() if cap else []
		assert_eq(logged.filter(func(e: Dictionary) -> bool: return String(e["code"]).contains(why) or String(e["rationale"]).contains(why)).size(), 1, "%s: reported as an engine error once (%s)" % [why, logged])


# --- Dialogue -----------------------------------------------------------------------------------

## DLG-001: the typewriter runs at the OPTIONS text speed (24/45/90 characters per second, instant).
func test_DLG_001_typewriter_follows_the_text_speed() -> void:
	var text := "A LINE LONG ENOUGH TO TYPE FOR A WHILE AT EVERY SPEED, SLOW OR FAST, UNTIL IT IS ALL THERE."
	for speed: String in ["slow", "normal", "fast", "instant"]:
		AppState.set_setting("textSpeed", speed)
		var s := _run(_data([_stage(), _say("l", "professor", text)]))
		_ticks(s, 1)
		_ticks(s, 30)
		var want := minf(float(text.length()), float(GameConfig.Story.TEXT_CPS[speed]) * 31 * DT)
		assert_near(s.hud.shown, want, 1.0, "%s: %.1f characters after 31 ticks" % [speed, want])


## DLG-002: a tap or confirm in the first 0.15 s does nothing; the first after it finishes the
## typing, the next advances.
func test_DLG_002_confirm_finishes_then_advances() -> void:
	var s := _run(_data([_stage(), _say("l", "professor", "NOW. WHERE WERE WE. THE FOURTH CRUSADE. AGAIN, FROM THE TOP."), _say("m", "zampano", "AND A DOG DREAMS LECTURES.")]))
	_ticks(s, 1)
	InputService.trigger(&"confirm")
	_ticks(s, 1)
	assert_true(s.hud.typing and s.runner.current.id == "l", "too early: ignored")
	_ticks(s, 10)
	InputService.trigger(&"confirm")
	_ticks(s, 1)
	assert_true(not s.hud.typing and s.runner.current.id == "l", "first confirm: the whole line")
	InputService.trigger(&"confirm")
	_ticks(s, 1)
	assert_eq(s.runner.current.id, "m", "second confirm: the next line")
	# A real tap works like confirm.
	_ticks(s, 12)
	InputService.pointer_down(3, Vector2(100, 300))
	InputService.pointer_up(3, Vector2(100, 300))
	_ticks(s, 1)
	assert_false(s.hud.typing, "a tap finishes the typing too")


## DLG-003: the box is the classic four lines (74 px) and grows upward for a long line; every
## wrapped line fits.
func test_DLG_003_wrapping_and_growing_box() -> void:
	var s := _run(_data([_stage(), _say("l", "professor", "SHORT.")]))
	_ticks(s, 1)
	assert_eq(s.hud._box_height(216.0), 74.0, "short line: minimum height")
	var long := "THE FLEET WAS READY FIRST, THE ARMY CAME LATER AND SMALLER, AND THE MONEY WAS ANOTHER MATTER ENTIRELY; NOBODY HAD COUNTED IT TWICE, AND THE VENETIANS COUNTED IT THREE TIMES, YOU UNDERSTAND, BEFORE A SINGLE SHIP SAILED."
	s.hud.show_line("THE PROFESSOR", Color.WHITE, null, long)
	s.hud.finish_typing()
	var h := s.hud._box_height(216.0)
	assert_true(h > 74.0, "a long line grows the box (%.0f)" % h)
	var lines: Array = s.hud.dialogue_spans(216.0)
	assert_true(lines.size() > 4, "wrapped to %d lines" % lines.size())
	for spans: Array in lines:
		var t := "".join(spans.map(func(x: Array) -> String: return x[0]))
		assert_true(PixelText.width(t) <= 216 - 8 - 10, "'%s' fits" % t)


func _choice(options: Array, cost_state: int = -1) -> StoryScene:
	var c := ChoiceStep.new()
	c.id = "c"
	c.speaker = "jack"
	c.prompt = "WELL?"
	c.options = options
	var st := CampaignSchema.new_campaign()
	if cost_state >= 0:
		st["meters"]["commozione"] = cost_state
	var s := _run(_data([_stage(), c, _say("after", "jack", "NEXT.")]), st)
	for k in 120:
		InputService.trigger(&"confirm")
		_ticks(s, 1)
		if s.runner.st.get("phase", "") == "choosing":
			break
	return s


## DLG-004: the options appear once the prompt is typed; keys move and confirm, or a tap picks a
## row; Zampanò says the picked option (or stays silent) and its follow-up runs.
func test_DLG_004_choices_by_keys_and_by_tap() -> void:
	var a := _option("a", "FIRST")
	var b := _option("b", "SECOND")
	b.said = "I MEANT THE SECOND."
	var s := _choice([a, b])
	assert_eq(s.hud.choices.map(func(v: Dictionary) -> String: return v["label"]), ["FIRST", "SECOND"], "two rows after the prompt")
	assert_eq(s.hud.choice_rects.size(), 2, "laid out before any draw")
	var c := s.hud.choice_rects[1].get_center()
	InputService.pointer_down(4, c)
	InputService.pointer_up(4, c)
	_ticks(s, 1)
	assert_true(s.runner.current is DialogueStep and (s.runner.current as DialogueStep).text == "I MEANT THE SECOND." and (s.runner.current as DialogueStep).speaker == "zampano", "the tapped option, said by Zampanò")
	assert_eq(s.ctx.metrics["choices"], ["c:b"], "recorded")
	s = _choice([_option("a", "FIRST"), _option("b", "SECOND")])
	InputService.trigger(&"confirm")
	_ticks(s, 1)
	assert_eq((s.runner.current as DialogueStep).text, "FIRST", "confirm picks the preselected first open row")


## DLG-005: a costly option shows its cost and spends it; short of Commozione it is locked with the
## reason and picking it only shows the reason; a permanently locked option stays greyed.
func test_DLG_005_locked_and_costly_options() -> void:
	var s := _choice([_option("speak", "SPEAK UP", 10), _option("hush", "STAY QUIET"), _option("never", "SAIL HOME", 0, "NOT IN THIS DREAM")], 20)
	assert_eq(s.hud.choices, [{"label": "SPEAK UP  (-10 COMMOZIONE)", "locked": ""}, {"label": "STAY QUIET", "locked": ""}, {"label": "SAIL HOME", "locked": "NOT IN THIS DREAM"}], "cost shown; the permanent lock greyed")
	var c := s.hud.choice_rects[0].get_center()
	InputService.pointer_down(4, c)
	InputService.pointer_up(4, c)
	_ticks(s, 1)
	assert_eq(int(s.ctx.state["meters"]["commozione"]), 10, "spent")
	s = _choice([_option("speak", "SPEAK UP", 10), _option("hush", "STAY QUIET")], 5)
	assert_eq(s.hud.choices[0], {"label": "SPEAK UP", "locked": "TOO UNMOVED: NEEDS 10 COMMOZIONE"}, "an unmoved Zampanò cannot act")
	c = s.hud.choice_rects[0].get_center()
	InputService.pointer_down(4, c)
	InputService.pointer_up(4, c)
	_ticks(s, 1)
	assert_true(s.runner.current is ChoiceStep and (s.ctx.metrics["notices"] as Array).has("TOO UNMOVED: NEEDS 10 COMMOZIONE"), "picking it shows the reason and stays")


## DLG-006: when every option is locked they are all offered unlocked (no dead end); a costly pick
## he cannot afford costs nothing.
func test_DLG_006_no_all_locked_dead_end() -> void:
	var s := _choice([_option("a", "SPEAK UP", 10), _option("b", "SHARE THE LOAF", 8)], 0)
	assert_eq(s.hud.choices, [{"label": "SPEAK UP", "locked": ""}, {"label": "SHARE THE LOAF", "locked": ""}], "all offered")
	InputService.trigger(&"confirm")
	_ticks(s, 1)
	assert_true(s.runner.current is DialogueStep, "the pick goes on")
	assert_eq(int(s.ctx.state["meters"]["commozione"]), 0, "nothing spent he did not have")


## DLG-007: a replay plays the same lines (the same Resource) and its card says the campaign will
## not change.
func test_DLG_007_replay_text() -> void:
	var a := _run(_data([_stage(), _say("l", "professor", "NOW. WHERE WERE WE.")]))
	var b: StoryScene = STORY.instantiate()
	b.manual_ticks = true
	b.setup(a.data, CampaignSchema.new_campaign(), false)
	scenes.append(b)
	tree.root.add_child(b)
	for s: StoryScene in [a, b]:
		for k in 60:
			InputService.trigger(&"confirm")
			_ticks(s, 1)
	assert_eq(a.hud.shown_texts, b.hud.shown_texts, "the same text in a replay")
	assert_false(b.persist, "the replay is not committed")
	var text: ShellText = load("res://data/shell/shell_text.tres")
	assert_eq(text.get_text("story_replay_note"), "REPLAY: THE CAMPAIGN WILL NOT CHANGE", "the replay card's note")


## DLG-008: the speaker's name in its colour in the box; the cast's and history's names in yellow
## on the story cards (scene card, the Professor's aside).
func test_DLG_008_names_in_their_colours() -> void:
	var s := _run(_data([_stage(), _say("l", "jack", "EVERYBODY EXCEPT YOU.")]))
	_ticks(s, 1)
	assert_eq([s.hud.speaker_name, s.hud.name_color], ["JACK", s.cast.color("jack")], "JACK in his colour")
	var m: StoryMarkup = load("res://data/story/markup.tres")
	var spans := m.name_spans("THE PROFESSOR IS REHEARSING HIS LECTURE; CLARI'S LORD.", Color.WHITE)
	assert_eq(spans, [["THE ", Color.WHITE], ["PROFESSOR", m.name_color], [" IS REHEARSING HIS LECTURE; ", Color.WHITE], ["CLARI'S", m.name_color], [" LORD.", Color.WHITE]], "names (and a possessive) in yellow")
	assert_true(m.names.has("D'AMIENS") and m.names.size() == 25 and m.old_words.size() == 22, "the source lists, complete")


## DLG-009: every period word is amber while it is typed and after the line is complete.
func test_DLG_009_period_words_amber_while_typing_and_after() -> void:
	var s := _run(_data([_stage(), _say("l", "professor", "THE PILGRIMS CALLED HIM MESSIRE, NOT PILGRIMSHIP.")]))
	_ticks(s, 1)
	var m: StoryMarkup = load("res://data/story/markup.tres")
	s.hud.shown = 7.0
	var typing: Array = s.hud.dialogue_spans()
	assert_eq(typing[0], [["THE ", Color.WHITE], ["PIL", m.old_word_color]], "amber while typed")
	s.hud.finish_typing()
	var all: Array = []
	for line: Array in s.hud.dialogue_spans():
		all.append_array(line)
	var amber := all.filter(func(x: Array) -> bool: return x[1] == m.old_word_color).map(func(x: Array) -> String: return x[0])
	assert_eq(amber, ["PILGRIMS", "MESSIRE"], "amber after completion; a longer word is not one")


# --- Objectives ---------------------------------------------------------------------------------

func _level(id: String) -> StoryScene:
	var st := CampaignSchema.new_campaign()
	st["completed"] = ["1.0"]
	return _run(StoryLibrary.scene(id), st)


func _until_objective(s: StoryScene, id: String) -> ObjectiveStep:
	var d := StoryDriver.new(s, {}, "bark", true)
	for k in 60 * 60:
		if s.runner.current is ObjectiveStep and s.runner.current.id == id:
			return s.runner.current as ObjectiveStep
		d.drive(DT)
		_ticks(s, 1)
	return null


## WALK-001–006 (Level 1 scope: reach, collect, action and follow objectives, progress, success,
## failure and recovery): a reach goal completes only inside its radius; a collect needs every
## pickup; the action button acts (BARK, SNIFF); the leader waits while Zampanò lags and goes on
## when he comes; pushing at Jack fails and recovers (test_story_level1).
func test_WALK_001_006_level_1_objectives() -> void:
	var s := _level("1.1")
	var o := _until_objective(s, "s06")
	if not assert_true(o != null, "1.1's walk"):
		return
	var goal: Vector2 = s.runner.st["goal"]
	assert_eq([o.objective_kind, s.ctx.controls, s.hud.objective], ["reach", true, o.objective], "reach: walking, objective shown")
	s.world.player.set_grid_position(goal.x - 1.0, goal.y + 0.2)
	_ticks(s, 1)
	assert_eq(s.runner.current, o, "outside the radius: still walking")
	InputService.trigger(&"action")
	_ticks(s, 1)
	assert_true(s.hud.shown_texts.has("WOOF! (IT ECHOES INSIDE THE BUCKET.)"), "the action button barks")
	s.world.player.set_grid_position(goal.x + 0.3, goal.y)
	_ticks(s, 1)
	assert_true(s.runner.current != o and not s.ctx.controls, "inside: done, controls off")
	# Collect and follow (1.2).
	s = _level("1.2")
	var f := _until_objective(s, "s03")
	assert_true(f != null and f.objective_kind == "follow", "1.2 follows the Professor")
	var lead: StoryActor = s.actors["prof"]
	_ticks(s, 30)
	var moved := Vector2(lead.gx, lead.gy)
	s.world.player.set_grid_position(1.5, 12.5)
	_ticks(s, 40)
	assert_true(s.runner.st["waiting"] and lead.behavior == "idle", "he lags: the leader waits")
	var waited := Vector2(lead.gx, lead.gy)
	_ticks(s, 30)
	assert_eq(Vector2(lead.gx, lead.gy), waited, "and stays")
	s.world.player.set_grid_position(lead.gx - 0.8, lead.gy + 0.4)
	_ticks(s, 20)
	assert_true(not s.runner.st["waiting"] and Vector2(lead.gx, lead.gy) != waited, "he comes: the leader goes on")
	assert_true(moved != Vector2.ZERO, "moved at first")
	var c := _until_objective(s, "s05")
	assert_true(c != null and c.objective_kind == "collect", "collect the scraps")
	var spots: Dictionary = s.runner.st["spots"]
	var first: Vector2 = (spots["chair"] as Dictionary)["at"]
	# (He may start on the coat's scrap: the Professor's last stop is the hem of his coat.)
	var before := (s.runner.st["picked"] as Array).size()
	s.world.player.set_grid_position(first.x, first.y)
	_ticks(s, 1)
	var picked: Array = s.runner.st["picked"]
	assert_true(s.runner.current == c and picked.has("chair") and picked.size() == before + 1 and picked.size() < 3, "one more, still collecting (%s)" % [picked])
	InputService.trigger(&"action")
	_ticks(s, 1)
	assert_true(s.hud.shown_texts.has("SNIFF..."), "SNIFF")


## WALK-007–009: spot rings and sprites while an objective runs (gone after), pickups apply their
## effects with notices, the carried thing rides on his back and is cleared when dropped.
func test_WALK_007_009_spots_pickups_and_carry() -> void:
	var s := _level("1.2")
	_until_objective(s, "s05")
	var markers: Array = s.markers.duplicate()
	var already := (s.runner.st["picked"] as Array).size()
	assert_eq(markers.size(), 3 - already, "a spot ring per scrap still on the floor")
	for mk: ObjectiveMarker in markers:
		assert_true(mk.get_parent() == s.world.object_layer and mk is Area2D, "a ring on the stage (Area2D)")
	var spots: Dictionary = s.runner.st["spots"]
	for id: String in spots:
		var at: Vector2 = (spots[id] as Dictionary)["at"]
		s.world.player.set_grid_position(at.x, at.y)
		_ticks(s, 1)
		# Rendered frames pass while the scene runs: a picked ring is freed before the objective ends.
		await tree.process_frame
		await tree.process_frame
	assert_eq((s.ctx.state["book"]["shards"] as Array).size(), 3, "three scraps")
	assert_true((s.ctx.metrics["notices"] as Array).has("SCRAP: A FLEET BOUGHT ON CREDIT"), "with their notices")
	assert_true(markers.all(func(mk: Variant) -> bool: return not is_instance_valid(mk) or (mk as Node).is_queued_for_deletion()), "rings removed")
	# Carry (1.5): the rag with its sprite; dropped at home; the rag cross on his back.
	s = _level("1.5")
	var d := StoryDriver.new(s, {"s08": "one"}, "bark", true)
	var seen := {}
	for k in 60 * 120:
		if s.finished:
			break
		var carried := s.hud.carry_label
		if carried != "":
			seen[carried] = s.world.player.get_children().any(func(n: Node) -> bool: return n is Sprite2D and (n as Sprite2D).texture == s.world.catalog.texture("rag_0"))
		if s.runner.trace.has("s05") and not seen.has("dropped"):
			seen["dropped"] = s.hud.carry_label == ""
		d.drive(DT)
		_ticks(s, 1)
	assert_eq(seen, {"RED CLOTH": true, "dropped": true, "A RAG CROSS ON HIS BACK": true}, "carried with its sprite, dropped, carried again")


# --- Actors -------------------------------------------------------------------------------------

## NPC-001–006 (Level 1 scope: idle, goto, follow): goto arrives and stops; a wall stops it on the
## grid solver; follow keeps its gap behind the player; idle stays put.
func test_NPC_001_006_idle_goto_follow_on_the_grid() -> void:
	var s := _run(_data([_stage()]))
	_ticks(s, 1)
	var a := s.spawn_actor("t", "watson", Vector2(4.5, 3.5), "E")
	a.go_to(Vector2(9.5, 3.5), 2.0)
	for k in 200:
		a.tick(DT, s.world.map, Vector2(s.world.player.gx, s.world.player.gy))
	assert_true(a.arrived and Vector2(a.gx, a.gy).distance_to(Vector2(9.5, 3.5)) < 0.06, "goto arrives")
	a.go_to(Vector2(9.5, 0.2), 2.0)
	for k in 200:
		a.tick(DT, s.world.map, Vector2.ZERO)
	var stopped := Vector2(a.gx, a.gy)
	for k in 60:
		a.tick(DT, s.world.map, Vector2.ZERO)
	assert_true(a.gy > 1.2 and a.gy < 1.4 and Vector2(a.gx, a.gy).distance_to(stopped) < 0.01, "the hedge stops it (gy %.2f)" % a.gy)
	a.follow(3.0)
	s.world.player.set_grid_position(14.5, 3.5)
	for k in 200:
		a.tick(DT, s.world.map, Vector2(14.5, 3.5))
	assert_near(Vector2(a.gx, a.gy).distance_to(Vector2(14.5, 3.5)), a.follow_gap, 0.05, "follow keeps its gap")
	a.set_idle()
	var at := Vector2(a.gx, a.gy)
	for k in 60:
		a.tick(DT, s.world.map, Vector2(2.5, 3.5))
	assert_eq(Vector2(a.gx, a.gy), at, "idle stays")
	assert_eq(a.anim, "idle", "idle clip")


## NPC-007: an idle human on stage makes one speaking gesture when his line starts, then resumes;
## a moving one or a dog does not.
func test_NPC_007_speaking_gesture() -> void:
	var prof := StoryActorSpec.new()
	prof.name = "p"
	prof.role = "professor"
	prof.point = Vector2(5.5, 3.5)
	var jack := StoryActorSpec.new()
	jack.name = "j"
	jack.role = "jack"
	jack.point = Vector2(6.5, 4.5)
	var s := _run(_data([_stage([prof, jack]), _say("l", "professor", "NOW."), _say("m", "jack", "NOPE!")]))
	_ticks(s, 1)
	var p: StoryActor = s.actors["p"]
	assert_eq([p.gestures, p.action_anim], [1, "bark"], "one gesture as his line starts")
	_ticks(s, 40)
	assert_eq([p.action_anim, p.anim], ["", "idle"], "then idle again")
	for k in 60:
		InputService.trigger(&"confirm")
		_ticks(s, 1)
		if s.runner.current and s.runner.current.id == "m":
			break
	assert_eq((s.actors["j"] as StoryActor).gestures, 0, "a dog does not gesture")
	p.go_to(Vector2(9.5, 3.5), 1.0)
	assert_false(p.gesture(), "a moving actor does not")
