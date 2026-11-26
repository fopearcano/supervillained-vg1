extends TestCase
## M6-A: the dream foundation and story combat through the production StoryScene — the costume
## routed by StorySceneData.reality and the arms by the `knight` capability (DOG-009), BARK /
## SWORD / SHIELD in a fight (COM-001–014), the action modes and the real inputs that perform them
## (physical keys, touches on the story buttons, gestures), a lost fight's reset, and that nothing
## persistent changes before a scene's completion. Scenes are built here as Resources (a dream
## scene of level 2 on the neighbourhood map's open lane); the shipped Levels 2–4 have their own.

const STORY := preload("res://scenes/story/story_scene.tscn")
const DT := 1.0 / 60.0
const C := GameConfig.Combat
## Open ground on the neighbourhood lane (row 3, between the hedges): the fights happen here.
const AT := Vector2(10.5, 3.5)

var scenes: Array = []


func before_each() -> void:
	InputService.auto_update = false
	InputService.clear_injection()
	InputService.clear_pending()


func after_each() -> void:
	for s: Node in scenes:
		if is_instance_valid(s):
			if s.get_parent():
				s.get_parent().remove_child(s)
			s.free()
	scenes.clear()
	InputService.clear_injection()
	InputService.release_all()
	InputService.clear_pending()
	InputService.auto_update = true
	AppState.selected_profile = AppState.DEFAULT_PROFILE


# --- Builders -----------------------------------------------------------------------------------

static func _stage(face: String = "E") -> StageStep:
	var s := StageStep.new()
	s.id = "stage"
	s.map = "neighborhood"
	s.player_at = ""
	s.player_point = AT
	s.player_face = face
	return s


static func _spawn(handle: String, offset: Vector2, role: String = "knight") -> ActorStep:
	var a := ActorStep.new()
	a.id = "spawn_" + handle
	a.actor = handle
	a.action = "spawn"
	a.role = role
	a.near_player = true
	a.point = offset
	a.face_player = true
	return a


static func _fight(foes: Array, def: Dictionary = {}, kind: String = "fight") -> ObjectiveStep:
	var o := ObjectiveStep.new()
	o.id = "fight"
	o.objective = "SPAR"
	o.objective_kind = kind
	var f := {"foes": foes}
	f.merge(def, true)
	o.fight = f
	o.rule_lines = {"rout": ["I YIELD!", "MERCY!"]}
	return o


static func _walk(goal: Vector2 = Vector2(13.5, 3.5)) -> ObjectiveStep:
	var o := ObjectiveStep.new()
	o.id = "walk"
	o.objective = "WALK"
	o.goal_point = goal
	return o


## A scene Resource: level 2 (dream) unless `reality`.
static func _scene_data(steps: Array, reality: bool = false) -> StorySceneData:
	var d := StorySceneData.new()
	d.id = "1.1" if reality else "2.3"
	d.title = "Test"
	d.level = 1 if reality else 2
	d.reality = reality
	d.map = "neighborhood"
	d.music = "greenzone" if reality else "level2"
	d.cast = PackedStringArray(["zampano"])
	var done := CompleteStep.new()
	done.id = "done"
	d.steps = [_stage()] + steps + [done]
	d.completion = {"boundary": "scene"}
	return d


func _run(data: StorySceneData, abilities: Array = [], persist: bool = true) -> StoryScene:
	var st := CampaignSchema.new_campaign()
	st["abilities"] = abilities.duplicate()
	var s: StoryScene = STORY.instantiate()
	s.manual_ticks = true
	s.setup(data, st, persist)
	scenes.append(s)
	tree.root.add_child(s)
	return s


func _ticks(s: StoryScene, n: int) -> void:
	for k in n:
		InputService.update(DT)
		s.tick(DT)


func _until(s: StoryScene, cond: Callable, limit: int = 1200) -> bool:
	for k in limit:
		if cond.call():
			return true
		_ticks(s, 1)
	return bool(cond.call())


func _at_objective(s: StoryScene) -> bool:
	return _until(s, func() -> bool: return s.runner.current is ObjectiveStep, 120)


func _foe(s: StoryScene, h: String) -> StoryActor:
	return s.actors.get(h)


func _count(s: StoryScene, ev: String) -> int:
	return s.ctx.combat.events.count(ev) if s.ctx.combat else -1


func _key(code: Key, pressed: bool) -> void:
	var e := InputEventKey.new()
	e.keycode = code
	e.physical_keycode = code
	e.pressed = pressed
	Input.parse_input_event(e)


## A physical key press and release (delivered on the next frames), then one logic tick reads it.
func _press(s: StoryScene, code: Key) -> void:
	await tree.process_frame
	_key(code, true)
	await tree.process_frame
	_key(code, false)
	await tree.process_frame
	_ticks(s, 1)


## A touch (logical pixels) through InputService's pointer path, as StoryTouchControls feeds it.
func _tap_at(s: StoryScene, p: Vector2) -> void:
	InputService.pointer_down(3, p)
	InputService.pointer_up(3, p)
	_ticks(s, 1)


func _swipe(s: StoryScene, from: Vector2, d: Vector2) -> void:
	InputService.pointer_down(4, from)
	InputService.pointer_move(4, from + d * 0.5)
	InputService.pointer_move(4, from + d)
	InputService.pointer_up(4, from + d)
	_ticks(s, 1)


func _gesture_point(s: StoryScene) -> Vector2:
	return Vector2(s._view.x - 30, s._view.y * 0.4)


# --- Costume and capability (DOG-009) -----------------------------------------------------------

## DOG-009: the coat of mail is visible in every dream scene from 2.1 (StorySceneData.costume, from
## `reality` alone) and never in reality, whatever is held; the sword and the shield are a separate
## capability (`knight`): without it no SWORD/SHIELD mode is offered and U/I only show that he has
## no arms; with it in the dream both work; in reality (a replay of Level 1 after 2.3) the plain
## costume and no arms. Alternate debug profiles use their own normal/armoured mappings.
func test_DOG_009_armour_from_2_1_and_arms_only_with_the_knight_capability() -> void:
	var cases := [
		[false, [], "armoured", PackedStringArray(["bark"]), false],
		[false, ["sermon"], "armoured", PackedStringArray(["bark"]), false],
		[false, ["knight"], "armoured", PackedStringArray(["bark", "sword", "shield"]), true],
		[true, ["cross", "sermon", "knight"], "normal", PackedStringArray(["bark"]), false],
	]
	for c: Array in cases:
		var what := "%s %s" % ["reality" if c[0] else "dream", c[1]]
		var s := _run(_scene_data([_walk()], c[0]), c[1])
		if not assert_true(_at_objective(s), what + ": at the walk"):
			return
		var dog := s.world.player
		var prof := dog.active_profile()
		assert_eq(dog.costume, c[2], what + ": costume")
		assert_true(dog.body_sprite.sprite_frames == (prof.armoured_frames if c[2] == "armoured" else prof.normal_frames), what + ": the costume's frames are shown")
		assert_eq(s.ctx.actions.modes, c[3], what + ": action modes")
		assert_eq(s.ctx.armed(), c[4], what + ": the knight's capability")
		InputService.trigger(&"strike")
		InputService.trigger(&"guard")
		_ticks(s, 2)
		assert_eq([_count(s, "strike"), s.ctx.combat.guarding], [1 if c[4] else 0, c[4]], what + ": U swings and I raises the shield only with the capability")
		assert_eq(_count(s, "no_arms") > 0, not c[4], what + ": otherwise the no-arms notice")
	# Debug profiles: Sbrimbrulòn wears his own coat in the dream, his plain coat in reality.
	AppState.selected_profile = &"sbrimbrulon"
	for reality: bool in [false, true]:
		var s := _run(_scene_data([_walk()], reality), ["knight"])
		_at_objective(s)
		var prof := s.world.player.active_profile()
		assert_eq(String(prof.id), "sbrimbrulon", "the debug profile plays")
		var want := prof.normal_frames if reality else prof.armoured_frames
		assert_true(s.world.player.body_sprite.sprite_frames == want, "sbrimbrulon %s: own %s frames" % ["reality" if reality else "dream", "normal" if reality else "armoured"])
		assert_true(prof.armoured_frames.resource_path.contains("sbrimbrulonKnight"), "his armoured mapping is sbrimbrulonKnight")


# --- COM-001–004: the bark ------------------------------------------------------------------------

## COM-001–004: a bark pushes back and wounds (half a heart) every foe within BARK_RADIUS, in front or
## behind (an area, not an arc), staggers it briefly, is never parried (even by foes who parry the
## sword), leaves foes beyond the radius alone, and cools down for BARK_COOLDOWN in a fight.
func test_COM_001_004_bark_area_push_never_parried_small_stagger() -> void:
	var s := _run(_scene_data([_spawn("f", Vector2(1.4, 0)), _spawn("b", Vector2(-1.4, 0)), _spawn("far", Vector2(4.0, -1.0)),
		_fight(["f", "b", "far"], {"parry": true, "hp": 2.0, "speed": 0.01})]))
	if not assert_true(_at_objective(s), "at the fight"):
		return
	var f := _foe(s, "f")
	var b := _foe(s, "b")
	var far := _foe(s, "far")
	# Closed (a parrying foe would parry the sword now) and out of their attack range: no swing.
	for a: StoryActor in [f, b, far]:
		a.foe.cooldown = 0.5
		assert_false(CombatRules.is_open(a.foe), a.handle + " is closed")
	var before := [Vector2(f.gx, f.gy), Vector2(b.gx, b.gy), Vector2(far.gx, far.gy)]
	InputService.trigger(&"bark")
	_ticks(s, 1)
	assert_eq([f.foe.hp, b.foe.hp, far.foe.hp], [1.5, 1.5, 2.0], "half a heart in front and behind; nothing beyond the radius")
	assert_eq([f.foe.stun > 0.0, b.foe.stun > 0.0, f.foe.stun <= C.BARK_STUN], [true, true, true], "a small stagger")
	assert_eq([_count(s, "bark_hit"), _count(s, "parried")], [2, 0], "a bark is never parried")
	_ticks(s, 10)
	assert_true(Vector2(f.gx, f.gy).x > before[0].x + 0.2 and Vector2(b.gx, b.gy).x < before[1].x - 0.2, "both pushed away from him")
	assert_vec_near(Vector2(far.gx, far.gy), before[2], 0.05, "the far one did not move")
	InputService.trigger(&"bark")
	_ticks(s, 1)
	assert_eq(_count(s, "bark"), 1, "a second bark within BARK_COOLDOWN does nothing")
	_ticks(s, int(C.BARK_COOLDOWN / DT) + 2)
	InputService.trigger(&"bark")
	_ticks(s, 1)
	assert_eq(_count(s, "bark"), 2, "after the cooldown he barks again")


# --- COM-005–008: the sword -------------------------------------------------------------------------

## COM-005–008: a sword blow at a parrying foe who is not open is parried (no damage, both step
## back); during the foe's wind-up (the red ring filling) the blow lands, interrupts the swing and
## staggers him SWORD_STUN; the opening is consumed (the next blow is parried again); the sword
## cools down SWORD_COOLDOWN between swings.
func test_COM_005_008_sword_cooldown_hit_windup_ring_parry_and_opening() -> void:
	var s := _run(_scene_data([_spawn("f", Vector2(0.9, 0)), _fight(["f"], {"parry": true, "hp": 3.0, "speed": 1.0})]), ["knight"])
	if not assert_true(_at_objective(s), "at the fight"):
		return
	var f := _foe(s, "f")
	# Closed: neither staggered, nor swinging, nor just after a swing (cooldown <= COOLDOWN - RECOVER).
	f.foe.cooldown = 0.6
	assert_false(CombatRules.is_open(f.foe), "the foe is closed")
	InputService.trigger(&"strike")
	_ticks(s, 1)
	assert_eq([_count(s, "strike"), _count(s, "parried"), f.foe.hp], [1, 1, 3.0], "a closed foe parries")
	InputService.trigger(&"strike")
	_ticks(s, 1)
	assert_eq(_count(s, "strike"), 1, "no second swing within SWORD_COOLDOWN")
	_ticks(s, int(C.SWORD_COOLDOWN / DT) + 2)
	assert_true(_until(s, func() -> bool: return f.foe.windup > 0.0, 240), "the foe comes back and winds up (the ring fills)")
	InputService.trigger(&"strike")
	_ticks(s, 1)
	assert_eq([_count(s, "hit"), f.foe.hp, f.foe.windup], [1, 2.0, 0.0], "mid-swing the blow lands and interrupts the swing")
	assert_true(f.foe.stun > 0.0 and f.foe.stun <= C.SWORD_STUN, "staggered for SWORD_STUN")
	_ticks(s, int(maxf(C.SWORD_COOLDOWN, C.SWORD_STUN) / DT) + 2)
	f.foe.cooldown = maxf(f.foe.cooldown, 0.5)
	assert_false(CombatRules.is_open(f.foe), "the opening is consumed")
	InputService.trigger(&"strike")
	_ticks(s, 1)
	assert_eq([_count(s, "parried"), f.foe.hp], [2, 2.0], "the next blow is parried again: no chain")


# --- COM-009–012: the shield and the modes ----------------------------------------------------------

## COM-009–012: the raised shield turns to the nearest threat and takes a blow from its front arc
## (the attacker staggers SHIELD_BLOCK_STUN, no heart lost); a blow from behind still hurts; the
## action modes BARK/SWORD/SHIELD cycle with the switcher (each change plays the click cue) and the
## action button performs the selected one.
func test_COM_009_012_shield_front_arc_block_rear_hit_and_modes() -> void:
	var s := _run(_scene_data([_spawn("front", Vector2(0.9, 0)), _spawn("rear", Vector2(-1.0, 0.0)),
		_fight(["front", "rear"], {"hp": 2.0, "speed": 0.01, "health": 5})]), ["knight"])
	if not assert_true(_at_objective(s), "at the fight"):
		return
	var front := _foe(s, "front")
	var rear := _foe(s, "rear")
	var dog := s.world.player
	# Both stand their ground (idle fighters), the front one nearer: the shield turns to it.
	var place := func(a: StoryActor, dx: float) -> void:
		a.set_idle()
		a.knock(0.0, 0.0)
		a.set_grid_position(dog.gx + dx, dog.gy)
		a.foe.stun = 0.0
	place.call(front, 0.8)
	place.call(rear, -0.9)
	front.foe.cooldown = 99.0
	rear.foe.cooldown = 99.0
	InputService.guard_hold_injected = true
	_ticks(s, 1)
	assert_eq([s.ctx.combat.guarding, dog.guarding, _count(s, "shield_up")], [true, true, 1], "I held: the shield is up")
	assert_true(front.knock_x > 0.0, "raising it shoves the one in front (the bash)")
	_ticks(s, 30)
	place.call(front, 0.8)
	front.foe.cooldown = 0.0
	assert_true(_until(s, func() -> bool: return _count(s, "blocked") > 0, 240), "the front foe's blow lands on the shield")
	assert_eq([s.ctx.combat.health, front.foe.stun > C.SHIELD_BLOCK_STUN - 0.05, _count(s, "hurt")], [5, true, 0], "no heart lost; the attacker staggers")
	# The rear foe swings while the shield faces the (nearer) front one: the rear is open.
	_ticks(s, 30)
	place.call(front, 0.8)
	front.foe.cooldown = 99.0
	rear.foe.cooldown = 0.0
	assert_true(_until(s, func() -> bool: return _count(s, "hurt") > 0 or _count(s, "blocked") > 1, 240), "the rear foe strikes")
	assert_eq([_count(s, "hurt"), _count(s, "blocked"), s.ctx.combat.health], [1, 1, 4], "a blow from behind hurts: one heart lost")
	InputService.guard_hold_injected = false
	_ticks(s, 1)
	# The modes: BARK, SWORD, SHIELD; the switcher cycles them with the click cue.
	assert_eq([s.ctx.actions.modes, s.ctx.actions.mode], [PackedStringArray(["bark", "sword", "shield"]), "bark"], "a knight's modes")
	for want: String in ["sword", "shield", "bark"]:
		var clicks := int(AudioService.requested.get(&"click", 0))
		InputService.trigger(&"switch")
		_ticks(s, 1)
		assert_eq(s.ctx.actions.mode, want, "switch -> " + want)
		assert_eq(int(AudioService.requested.get(&"click", 0)), clicks + 1, "the click cue on the change to " + want)
		assert_eq(s.controls.action_label, s.ctx.actions.label(), "the button shows " + want)
	InputService.trigger(&"switch")
	_ticks(s, 1)
	var strikes := _count(s, "strike")
	InputService.trigger(&"action")
	_ticks(s, 1)
	assert_eq(_count(s, "strike"), strikes + 1, "the action button in SWORD mode swings")


# --- COM-013–014: routing and the knockdown ---------------------------------------------------------

## COM-013: routed foes run off (non-lethal: no longer hostile, fleeing) and the fight completes.
## COM-014: at no hearts he is knocked down: the KNOCKED DOWN card, then he and the foes are back
## where they started, hearts and HP full, the fight live again; nothing persistent is touched
## (the working copy equals the entry state; the save file's bytes do not change) and the retried
## fight can be won.
func test_COM_013_014_routing_and_knockdown_reset_without_death_or_leakage() -> void:
	SaveService.save_campaign(CampaignSchema.new_campaign(), 1000)
	var bytes := FileAccess.get_file_as_bytes(SaveService.base_dir + "save_v3.json")
	var s := _run(_scene_data([_spawn("a", Vector2(1.0, 0)), _fight(["a"], {"hp": 1.0, "health": 1, "speed": 1.6})]), ["knight"])
	var out := {}
	s.completed.connect(func(r: Dictionary) -> void: out["result"] = r)
	if not assert_true(_at_objective(s), "at the fight"):
		return
	var a := _foe(s, "a")
	var start := s.ctx.player_pos()
	var foe_start := Vector2(a.gx, a.gy)
	var entry := s.entry_state.duplicate(true)
	# He stands still: the foe winds up and hits; one heart: knocked down.
	assert_true(_until(s, func() -> bool: return s.runner.st.has("interrupt"), 600), "knocked down")
	assert_eq([s.hud.card_visible, s.hud.card_big, s.ctx.controls], [true, s.ctx.ui_text("story_knocked"), false], "the KNOCKED DOWN card, controls off")
	assert_eq(s.ctx.state, entry, "nothing applied to the working copy")
	assert_true(_until(s, func() -> bool: return not s.runner.st.has("interrupt"), 300), "he gets up")
	assert_vec_near(s.ctx.player_pos(), start, 0.01, "back where the fight started")
	assert_vec_near(Vector2(a.gx, a.gy), foe_start, 0.01, "the foe back where it stood")
	assert_eq([s.ctx.combat.health, a.foe.hp, a.foe.routed, a.hostile, s.ctx.combat.knocked], [1, 1.0, false, true, false], "hearts and HP full, the fight live again")
	assert_eq(s.ctx.metrics["knockdowns"], ["fight"], "one knockdown recorded")
	# Retry: catch him mid-swing (he does not parry here) and rout him.
	a.foe.cooldown = 0.0
	assert_true(_until(s, func() -> bool: return a.foe.windup > 0.0 or a.foe.routed, 240), "he winds up")
	InputService.trigger(&"strike")
	_ticks(s, 1)
	assert_eq([a.foe, a.hostile, a.behavior], [null, false, "flee"], "routed: he runs off, no longer hostile, no fighter state left (the fight is won)")
	assert_true(_until(s, func() -> bool: return out.has("result"), 120), "the fight is won and the scene completes")
	assert_eq((out["result"] as Dictionary)["state"], entry, "the completed working copy holds no fight residue")
	assert_eq(FileAccess.get_file_as_bytes(SaveService.base_dir + "save_v3.json"), bytes, "the scene itself writes nothing (the commit is Main's, once)")


## The knockdown's reset under a restart and a quit: restarting mid-fight starts from the entry state
## with fresh foes; nothing of the abandoned fight (hearts, HP, positions) remains.
func test_COM_014_restart_mid_fight_leaks_nothing() -> void:
	var s := _run(_scene_data([_spawn("a", Vector2(1.2, 0)), _fight(["a"], {"hp": 2.0, "health": 3, "speed": 0.01})]), ["knight"])
	if not assert_true(_at_objective(s), "at the fight"):
		return
	var a := _foe(s, "a")
	a.foe.cooldown = 0.0
	_until(s, func() -> bool: return a.foe.windup > 0.0, 240)
	InputService.trigger(&"strike")
	_ticks(s, 1)
	assert_eq(a.foe.hp, 1.0, "one blow landed")
	s.restart()
	_at_objective(s)
	var a2 := _foe(s, "a")
	assert_true(a2 != a, "a fresh foe")
	assert_eq([a2.foe.hp, s.ctx.combat.health, s.ctx.combat.events.size(), s.ctx.state], [2.0, 3, 0, s.entry_state], "full HP, full hearts, no events, the entry state")
	s.quit()
	assert_true(s.finished, "quit ends the scene")


# --- Real inputs: keys, touches, gestures ------------------------------------------------------------

## Combat inputs through the real paths: physical keys U (sword), I (shield; held, it stays up), B
## (bark), Q (switch) and J (the selected mode) parsed by Godot's Input; the round action button and
## the switcher button touched (InputService's pointer path, as StoryTouchControls feeds it); the
## default gestures over the buttons (swipe up: sword, swipe down: shield, double tap: bark).
func test_SLICE_combat_inputs_keyboard_touch_and_gestures() -> void:
	var s := _run(_scene_data([_spawn("a", Vector2(3.5, 0)), _fight(["a"], {"hp": 9.0, "speed": 0.01})]), ["knight"])
	if not assert_true(_at_objective(s), "at the fight"):
		return
	_foe(s, "a").foe.cooldown = 99.0
	await _press(s, KEY_U)
	assert_eq(_count(s, "strike"), 1, "U: the sword")
	await _press(s, KEY_B)
	assert_eq(_count(s, "bark"), 1, "B: a bark")
	_ticks(s, int(C.SHIELD_PULSE / DT) + 2)
	await _press(s, KEY_I)
	assert_eq(s.ctx.combat.guarding, true, "I: the shield (a pulse)")
	_ticks(s, int(C.SHIELD_PULSE / DT) + 2)
	assert_false(s.ctx.combat.guarding, "the pulse ends")
	await tree.process_frame
	_key(KEY_I, true)
	await tree.process_frame
	_ticks(s, int(C.SHIELD_PULSE / DT) + 5)
	assert_true(s.ctx.combat.guarding, "I held: still up after the pulse")
	_key(KEY_I, false)
	await tree.process_frame
	_ticks(s, int(C.SHIELD_PULSE / DT) + 2)
	assert_false(s.ctx.combat.guarding, "released: down")
	await _press(s, KEY_Q)
	assert_eq(s.ctx.actions.mode, "sword", "Q: the next mode")
	_ticks(s, int(C.SWORD_COOLDOWN / DT) + 2)
	await _press(s, KEY_J)
	assert_eq(_count(s, "strike"), 2, "J: the selected mode (SWORD)")
	# Touches: the switcher button, then the round button.
	var lay: Dictionary = s.controls._layout
	_tap_at(s, lay["switch"])
	assert_eq([s.ctx.actions.mode, s.controls.action_label], ["shield", s.ctx.ui_text("story_mode_shield")], "the switcher button: SHIELD")
	_ticks(s, int(C.SHIELD_PULSE / DT) + 2)
	_tap_at(s, lay["action"])
	assert_true(s.ctx.combat.guarding, "the round button in SHIELD mode raises the shield")
	_ticks(s, int(maxf(C.SHIELD_PULSE, C.SWORD_COOLDOWN) / DT) + 2)
	# Gestures over the buttons (default bindings).
	var g := _gesture_point(s)
	_swipe(s, g + Vector2(0, 40), Vector2(0, -32))
	assert_eq([InputService.last_gesture.get("kind", ""), _count(s, "strike")], ["swipeUp", 3], "swipe up: the sword")
	_ticks(s, int(C.SHIELD_PULSE / DT) + 2)
	_swipe(s, g, Vector2(0, 32))
	assert_eq([InputService.last_gesture.get("kind", ""), s.ctx.combat.guarding], ["swipeDown", true], "swipe down: the shield")
	_ticks(s, int(C.BARK_COOLDOWN / DT) + 2)
	var barks := _count(s, "bark")
	InputService.pointer_down(5, g)
	InputService.pointer_up(5, g)
	InputService.pointer_down(5, g + Vector2(2, 1))
	InputService.pointer_up(5, g + Vector2(2, 1))
	_ticks(s, 1)
	assert_eq([InputService.last_gesture.get("kind", ""), _count(s, "bark")], ["doubleTap", barks + 1], "double tap: a bark")


## No input leaks: edges pressed before a walk (during a line) or left over from a finished walk are
## not performed in the next walk; a scene that ends removes its fight state from the actors.
func test_SLICE_no_combat_input_leaks_between_steps_or_scenes() -> void:
	var line := DialogueStep.new()
	line.id = "line"
	line.speaker = "zampano"
	line.text = "ON GUARD."
	var s := _run(_scene_data([line, _spawn("a", Vector2(1.5, 0)), _fight(["a"], {"hp": 0.5, "speed": 0.01})]), ["knight"])
	assert_true(_until(s, func() -> bool: return s.runner.current is DialogueStep, 60), "at the line")
	InputService.trigger(&"confirm")
	_ticks(s, 15)
	assert_false(s.hud.typing, "the line is typed out")
	# Pressed on the line's last tick: the confirm ends it and the fight begins in the same tick.
	InputService.trigger(&"strike")
	InputService.trigger(&"bark")
	InputService.trigger(&"guard")
	InputService.trigger(&"switch")
	InputService.trigger(&"confirm")
	_ticks(s, 1)
	assert_true(s.runner.current is ObjectiveStep, "at the fight")
	_ticks(s, 2)
	assert_eq([s.ctx.combat.events, s.ctx.actions.mode, s.ctx.metrics["actions"]], [[], "bark", []], "nothing pressed during the line is performed in the fight")
	InputService.trigger(&"bark")
	_ticks(s, 1)
	var a := _foe(s, "a")
	assert_true(a.foe == null or a.foe.routed, "routed by the bark (or the fight already over)")
	assert_true(_until(s, func() -> bool: return s.finished, 120), "the scene completes")
	assert_eq([a.foe, a.hostile], [null, false], "the fight left nothing on the actor")


# --- NPC states for Levels 2–4 ------------------------------------------------------------------------

static func _act(handle: String, action: String, extra: Dictionary = {}) -> ActorStep:
	var a := ActorStep.new()
	a.id = "%s_%s" % [handle, action]
	a.actor = handle
	a.action = action
	for k: String in extra:
		a.set(k, extra[k])
	return a


## NPC-001–006 (the states Levels 2–4 use, M6): patrol between marker points with a pause (looking
## around while paused), chase within its radius and back home beyond it, flee while he is near, and
## wander within its radius (reproducible: the same handle draws the same path) — all on the shared
## grid solver, never inside a blocked tile.
func test_NPC_001_006_patrol_chase_flee_wander_on_the_grid() -> void:
	var wait := WaitStep.new()
	wait.id = "wait"
	wait.seconds = 60.0
	var steps := [
		_spawn("guard", Vector2(-3.0, 0.0), "knight"), _act("guard", "patrol", {"points": PackedStringArray(["2", "1"]), "speed": 2.0, "pause": 0.5}),
		_spawn("hound", Vector2(0.0, 2.0), "pilgrim"), _act("hound", "chase", {"speed": 1.5, "radius": 3.0}),
		_spawn("hare", Vector2(1.0, 0.0), "pilgrim"), _act("hare", "flee", {"speed": 2.0, "radius": 2.0}),
		_spawn("drifter", Vector2(-1.0, 7.0), "pilgrim"), _act("drifter", "wander", {"speed": 1.0, "radius": 1.5}),
		wait]
	var s := _run(_scene_data(steps))
	assert_true(_until(s, func() -> bool: return s.runner.current is WaitStep, 60), "the actors are placed")
	var m := s.world.map
	var guard := _foe(s, "guard")
	var hound := _foe(s, "hound")
	var hare := _foe(s, "hare")
	var drifter := _foe(s, "drifter")
	var drift_home := drifter.home
	var p2 := s.ctx.marker("2")
	var p1 := s.ctx.marker("1")
	var hound_home := hound.home
	var visited := {"2": false, "1": false}
	var looked := false
	var hare_d0 := Vector2(hare.gx, hare.gy).distance_to(s.ctx.player_pos())
	var drift_max := 0.0
	var hound_min := 99.0
	for k in 60 * 8:
		var f0 := guard.facing_vec
		_ticks(s, 1)
		for a: StoryActor in [guard, hound, hare, drifter]:
			if m.is_blocked_tile(int(floor(a.gx)), int(floor(a.gy))):
				fail("%s inside a blocked tile at %.2f, %.2f" % [a.handle, a.gx, a.gy])
				return
		if Vector2(guard.gx, guard.gy).distance_to(p2) < 0.2:
			visited["2"] = true
		if Vector2(guard.gx, guard.gy).distance_to(p1) < 0.2:
			visited["1"] = true
			if guard.facing_vec != f0:
				looked = true
		hound_min = minf(hound_min, Vector2(hound.gx, hound.gy).distance_to(s.ctx.player_pos()))
		drift_max = maxf(drift_max, Vector2(drifter.gx, drifter.gy).distance_to(drift_home))
	assert_eq(visited, {"2": true, "1": true}, "patrol: both points visited")
	assert_true(looked, "patrol: looks around while paused")
	assert_true(hound_min <= 0.35, "chase: reaches him (stop distance), %.2f" % hound_min)
	assert_true(Vector2(hare.gx, hare.gy).distance_to(s.ctx.player_pos()) > hare_d0 + 0.5, "flee: moved away from him")
	assert_true(drift_max <= 1.5 + 0.35 and drift_max > 0.3, "wander: moves, within its radius (%.2f)" % drift_max)
	# Beyond the chase radius the hound goes home (at 0.6 of its speed).
	s.world.player.set_grid_position(AT.x + 8.0, AT.y)
	_ticks(s, 60 * 6)
	assert_true(Vector2(hound.gx, hound.gy).distance_to(hound_home) < 0.3, "chase: back home once he is out of reach")
	# Reproducible wander: the same handle draws the same path.
	var s2 := _run(_scene_data(steps))
	_until(s2, func() -> bool: return s2.runner.current is WaitStep, 60)
	_ticks(s2, 120)
	var d2 := _foe(s2, "drifter")
	var s3 := _run(_scene_data(steps))
	_until(s3, func() -> bool: return s3.runner.current is WaitStep, 60)
	_ticks(s3, 120)
	assert_vec_near(Vector2(_foe(s3, "drifter").gx, _foe(s3, "drifter").gy), Vector2(d2.gx, d2.gy), 1e-9, "wander is reproducible")


## COM-011 (held SHIELD, M7 Phase 0): with SHIELD selected, the shield stays up while J/X is held or
## the round ACTION button is pressed, beyond SHIELD_PULSE, and drops on release; held so, it blocks a
## blow from the front and leaves the rear open. (I and the swipe keep their own behaviour.)
func test_COM_011_selected_shield_held_by_keys_and_touch() -> void:
	var s := _run(_scene_data([_spawn("front", Vector2(0.8, 0)), _spawn("rear", Vector2(-0.9, 0.0)),
		_fight(["front", "rear"], {"hp": 2.0, "speed": 0.01, "health": 5})]), ["knight"])
	if not assert_true(_at_objective(s), "at the fight"):
		return
	var front := _foe(s, "front")
	var rear := _foe(s, "rear")
	var dog := s.world.player
	for a: StoryActor in [front, rear]:
		a.set_idle()
		a.foe.cooldown = 5.0
	front.set_grid_position(dog.gx + 0.8, dog.gy)
	rear.set_grid_position(dog.gx - 0.9, dog.gy)
	InputService.trigger(&"switch")
	_ticks(s, 1)
	InputService.trigger(&"switch")
	_ticks(s, 1)
	assert_eq(s.ctx.actions.mode, "shield", "SHIELD selected")
	# J held through the real key path.
	await tree.process_frame
	_key(KEY_J, true)
	await tree.process_frame
	_ticks(s, int(C.SHIELD_PULSE / DT) + 20)
	assert_true(s.ctx.combat.guarding, "J held: still up after the pulse")
	front.set_grid_position(dog.gx + 0.8, dog.gy)
	front.knock(0.0, 0.0)
	front.foe.cooldown = 0.0
	assert_true(_until(s, func() -> bool: return _count(s, "blocked") > 0 or _count(s, "hurt") > 0, 240), "the front foe strikes")
	assert_eq([_count(s, "blocked"), _count(s, "hurt")], [1, 0], "held: the front blow is blocked")
	_ticks(s, 30)
	front.set_grid_position(dog.gx + 0.8, dog.gy)
	front.knock(0.0, 0.0)
	front.foe.stun = 0.0
	front.foe.cooldown = 5.0
	rear.set_grid_position(dog.gx - 0.9, dog.gy)
	rear.foe.cooldown = 0.0
	var b0 := _count(s, "blocked")
	assert_true(_until(s, func() -> bool: return _count(s, "hurt") > 0 or _count(s, "blocked") > b0, 240), "the rear foe strikes")
	assert_eq(_count(s, "hurt"), 1, "held: the rear stays open")
	_key(KEY_J, false)
	await tree.process_frame
	_ticks(s, int(C.SHIELD_PULSE / DT) + 2)
	assert_false(s.ctx.combat.guarding, "J released: down")
	# The touch ACTION button held.
	var lay: Dictionary = s.controls._layout
	front.foe.cooldown = 0.5
	rear.foe.cooldown = 0.5
	InputService.pointer_down(6, lay["action"])
	_ticks(s, int(C.SHIELD_PULSE / DT) + 20)
	assert_true(s.ctx.combat.guarding, "ACTION held on touch: still up after the pulse")
	InputService.pointer_up(6, lay["action"])
	_ticks(s, int(C.SHIELD_PULSE / DT) + 2)
	assert_false(s.ctx.combat.guarding, "released: down")
	# In SWORD mode a held J does not raise the shield.
	InputService.trigger(&"switch")
	_ticks(s, 1)
	InputService.trigger(&"switch")
	_ticks(s, 1)
	assert_eq(s.ctx.actions.mode, "sword", "SWORD selected")
	InputService.action_hold_injected = true
	_ticks(s, int(C.SHIELD_PULSE / DT) + 2)
	assert_false(s.ctx.combat.guarding, "a held action in SWORD mode is no shield")
	InputService.action_hold_injected = false
