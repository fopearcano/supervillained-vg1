extends TestCase
## M5R-A: the story content schema and StoryValidator (docs/porting/STORY_REWRITE_SPEC.md §5–§6).
## A valid in-memory scene passes; each broken variant fails with an explicit message (missing
## marker, map, speaker, actor, role, sprite, sound, step order, choices, effects, metadata,
## completion on every branch); the Level 1 maps are the executed source's, verbatim; the story
## engine's scripts hold no player text.

var v: StoryValidator


func before_each() -> void:
	v = StoryValidator.for_project()


func _stage(map: String = "neighborhood", actors: Array = []) -> StageStep:
	var s := StageStep.new()
	s.id = "stage"
	s.map = map
	s.player_at = "S"
	s.player_face = "E"
	s.actors = actors
	return s


func _actor(name: String, role: String, at: String) -> StoryActorSpec:
	var a := StoryActorSpec.new()
	a.name = name
	a.role = role
	a.at = at
	return a


func _say(id: String, speaker: String, text: String) -> DialogueStep:
	var d := DialogueStep.new()
	d.id = id
	d.speaker = speaker
	d.text = text
	return d


func _done() -> CompleteStep:
	var c := CompleteStep.new()
	c.id = "done"
	return c


func _option(id: String, label: String, effects: Dictionary = {}, then_steps: Array = []) -> StoryChoiceOption:
	var o := StoryChoiceOption.new()
	o.id = id
	o.label = label
	o.effects = effects
	o.then_steps = then_steps
	return o


func _choice(options: Array) -> ChoiceStep:
	var c := ChoiceStep.new()
	c.id = "choice"
	c.speaker = "watson"
	c.prompt = "WELL?"
	c.options = options
	return c


func _scene(steps: Array) -> StorySceneData:
	var s := StorySceneData.new()
	s.id = "1.1"
	s.title = "A bucket on his head"
	s.level = 1
	s.summary = "A TEST SCENE."
	s.map = "neighborhood"
	s.music = "greenzone"
	s.cast = PackedStringArray(["zampano", "watson"])
	s.steps = steps
	s.persistent_effects = PackedStringArray(["book.remembered", "flags.pawOffered", "meter.supervillain"])
	s.completion = {"boundary": "scene"}
	s.reality = true
	s.historical_tags = PackedStringArray(["reality"])
	s.source_refs = PackedStringArray(["docs/STORY.md 1.1"])
	s.review_status = "draft_implemented_review_pending"
	s.technical_status = "implemented"
	return s


func _valid() -> StorySceneData:
	return _scene([_stage("neighborhood", [_actor("watson", "watson", "7")]), _say("hello", "watson", "OOPS, MAN."), _done()])


func _errors_of(scene: StorySceneData) -> String:
	return "\n".join(v.validate_scene(scene))


func _expect(scene: StorySceneData, fragment: String, what: String) -> void:
	var e := _errors_of(scene)
	assert_true(e.contains(fragment), "%s: expected an error containing '%s', got:\n%s" % [what, fragment, e])


func test_SLICE_valid_scene_passes_and_every_defect_fails_explicitly() -> void:
	assert_eq(v.validate_scene(_valid()), PackedStringArray(), "a valid scene has no errors")
	# Stage, markers, actors, roles.
	var s := _valid()
	(s.steps[0] as StageStep).map = "nowhere"
	_expect(s, "unknown map 'nowhere'", "missing map")
	s = _valid()
	(s.steps[0] as StageStep).player_at = "X"
	_expect(s, "marker 'X' is not on map 'neighborhood'", "missing player marker")
	s = _valid()
	((s.steps[0] as StageStep).actors[0] as StoryActorSpec).at = "Q"
	_expect(s, "marker 'Q' is not on map", "missing marker")
	s = _valid()
	((s.steps[0] as StageStep).actors[0] as StoryActorSpec).role = "nobody"
	_expect(s, "cast role 'nobody' has no SpriteFrames", "missing actor art")
	s = _valid()
	var face := ActorStep.new()
	face.id = "face"
	face.actor = "ghost"
	face.action = "face"
	face.face = "N"
	s.steps.insert(1, face)
	_expect(s, "actor 'ghost' is used before it is placed", "missing actor")
	# Speakers.
	s = _valid()
	(s.steps[1] as DialogueStep).speaker = "stranger_x"
	_expect(s, "unknown speaker 'stranger_x'", "unknown speaker")
	s = _valid()
	(s.steps[1] as DialogueStep).speaker = "jack"
	_expect(s, "speaker 'jack' is not in the scene's cast", "speaker outside the cast")
	# Steps: ids, order, completion.
	s = _valid()
	(s.steps[1] as DialogueStep).id = "stage"
	_expect(s, "duplicate step id", "duplicate id")
	s = _valid()
	s.steps.pop_back()
	_expect(s, "the last step must be a CompleteStep", "no completion")
	s = _valid()
	s.steps = []
	_expect(s, "no steps", "empty scene")
	s = _valid()
	s.steps.insert(1, Resource.new())
	_expect(s, "is not a StoryStep", "not a step")
	# Assets.
	s = _valid()
	var cue := CueStep.new()
	cue.id = "cue"
	cue.sound = "trumpet"
	s.steps.insert(1, cue)
	_expect(s, "unknown sound 'trumpet'", "unknown sound")
	s = _valid()
	var prop := PropStep.new()
	prop.id = "prop"
	prop.prop = "bowl"
	prop.sprite = "bowl_9"
	prop.at = "1"
	s.steps.insert(1, prop)
	_expect(s, "unknown sprite 'bowl_9'", "unknown sprite")
	s = _valid()
	s.music = "polka"
	_expect(s, "unknown music 'polka'", "unknown music")


func test_SLICE_choices_effects_metadata_and_branch_completion() -> void:
	# All-locked choice; a locked option that still has a branch.
	var a := _option("a", "A")
	a.cost = 5
	var b := _option("b", "B")
	b.locked_text = "NOT YET"
	var s := _valid()
	s.steps.insert(2, _choice([a, b]))
	_expect(s, "every option can be locked at once", "all-locked choice")
	var c := _option("c", "C", {"supervillain": -3})
	c.locked_text = "NEVER"
	s = _valid()
	s.steps.insert(2, _choice([_option("a", "A"), c]))
	_expect(s, "permanently locked but has effects", "unreachable branch")
	# Effects: unknown key, unknown flag, invalid value, undeclared write, unknown ability.
	for pair: Array in [[{"luck": 3}, "unknown effect key 'luck'"], [{"flags": {"newFlag": true}}, "flag 'newFlag' is not in CampaignFlagSchema"],
			[{"flags": {"oath": "maybe"}}, "flag 'oath' has an invalid value"], [{"grace": 2}, "effect 'meter.grace' is not declared"],
			[{"unlock": "wings"}, "unknown ability 'wings'"], [{"supervillain": 0}, "needs a nonzero number"]]:
		var e := EffectStep.new()
		e.id = "fx"
		e.effects = pair[0]
		s = _valid()
		s.steps.insert(2, e)
		_expect(s, pair[1], "effect %s" % [pair[0]])
	# Metadata.
	for field: Array in [["source_refs", PackedStringArray(), "no source references"], ["historical_tags", PackedStringArray(), "no historical/place tags"],
			["review_status", "approved!", "bad review_status"], ["technical_status", "", "bad technical_status"], ["summary", "", "no summary"],
			["title", "A different title", "differs from the catalog's"], ["reality", false, "reality flag does not match"], ["content_version", 0, "content_version must be >= 1"]]:
		s = _valid()
		s.set(field[0], field[1])
		_expect(s, field[2], "metadata %s" % field[0])
	s = _valid()
	s.id = "1.0"
	_expect(s, "not a scripted scene of the catalog", "the Green Zone ID")
	s = _valid()
	s.id = "9.9"
	_expect(s, "not a scripted scene of the catalog", "an unknown ID")
	# The completion's required flag must be set on every branch.
	s = _valid()
	s.completion = {"boundary": "scene", "requires_flags": ["pawOffered"]}
	s.steps.insert(2, _choice([_option("paw", "PAW", {"flags": {"pawOffered": true}}), _option("look", "LOOK")]))
	_expect(s, "a branch completes without setting flag 'pawOffered'", "a branch skips the required flag")
	s = _valid()
	s.completion = {"boundary": "scene", "requires_flags": ["pawOffered"]}
	s.steps.insert(2, _choice([_option("paw", "PAW", {"flags": {"pawOffered": true}}), _option("look", "LOOK", {"flags": {"pawOffered": false}})]))
	assert_eq(v.validate_scene(s), PackedStringArray(), "both branches set it: valid")
	# A stage change inside a branch is refused; so is a completion inside a branch.
	s = _valid()
	s.steps.insert(2, _choice([_option("a", "A", {}, [_stage("study")]), _option("b", "B")]))
	_expect(s, "stage changes are not allowed inside a choice branch", "stage in a branch")
	var inner := _done()
	inner.id = "inner_done"
	s = _valid()
	s.steps.insert(2, _choice([_option("a", "A", {}, [inner]), _option("b", "B")]))
	_expect(s, "a CompleteStep must be the scene's last top-level step", "completion in a branch")


func test_SLICE_chapter_order_and_metadata() -> void:
	var ch := StoryChapterData.new()
	ch.number = 1
	ch.title = "The Greenzone"
	ch.intro = "INTRO."
	ch.professor_aside = "ASIDE."
	ch.music = "greenzone"
	ch.review_status = "draft_implemented_review_pending"
	var s11 := _valid()
	var s12 := _valid()
	s12.id = "1.2"
	s12.title = "Under the Professor's desk"
	ch.scenes = [s11, s12]
	assert_eq(v.validate_chapter(ch), PackedStringArray(), "1.1, 1.2: a valid prefix of the catalog order")
	ch.scenes = [s12, s11]
	assert_true("\n".join(v.validate_chapter(ch)).contains("are not the catalog order"), "out of order")
	ch.scenes = [s11]
	ch.title = "Elsewhere"
	assert_true("\n".join(v.validate_chapter(ch)).contains("differs from the catalog's"), "chapter title")


func test_SLICE_level_1_maps_are_the_executed_sources_and_cast_has_art() -> void:
	var fx: Dictionary = fixture("source_story_maps")["maps"]
	for id: String in ["neighborhood", "study"]:
		var m: StoryMapData = v.maps[id]
		assert_eq(Array(m.rows), fx[id]["rows"], "%s rows verbatim" % id)
		assert_eq([m.base, m.theme], [fx[id]["base"], fx[id]["theme"]], "%s base and theme" % id)
		var p := m.parse()
		assert_true(p["ok"], "%s parses" % id)
		var want: Array = (fx[id]["markers"] as Dictionary).keys()
		want.append("S")
		want.sort()
		var got := Array(m.marker_ids())
		got.sort()
		assert_eq(got, want, "%s markers" % id)
	for sp: String in v.cast.speakers:
		assert_true(StoryCast.frames_path(v.cast.portrait(sp)) != "", "%s has portrait frames" % sp)


func test_SLICE_story_scripts_hold_no_player_text() -> void:
	assert_eq(StoryValidator.scan_scripts(), PackedStringArray(), "no player text in the story engine's scripts")
	# The scan finds a planted line.
	var dir := SaveService.base_dir.path_join("scan_probe")
	DirAccess.make_dir_recursive_absolute(dir)
	var f := FileAccess.open(dir.path_join("probe.gd"), FileAccess.WRITE)
	f.store_string("extends Node\n## A COMMENT IN CAPITALS IS FINE\nfunc x() -> String:\n\treturn \"THERE WAS A BOWL, AND IT WAS ALWAYS ONE STEP AWAY.\"\n")
	f.close()
	var found := StoryValidator.scan_scripts([dir])
	assert_eq(found.size(), 1, "the planted line is found: %s" % [found])
	assert_true(found.size() == 1 and found[0].ends_with(":4: THERE WAS A BOWL, AND IT WAS ALWAYS ONE STEP AWAY."), "with its file and line")
