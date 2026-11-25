extends TestCase
## Correction 31: the story's action inputs through the real input paths, through Main — physical
## key events (J, X, Space, B, Q) parsed by Godot's Input into the InputMap, and screen touches
## through the window, the pixel SubViewport and the story touch controls. Nothing here calls
## InputService.trigger(): J/X perform the action button's mode, Space always the walk's own action,
## B a plain bark the scene rules hear (RD-28), the touch ACTION button the displayed action, the
## switcher (Q or its button) the next mode, the double tap what CONTROLS binds it to; a button or
## joystick touch never also becomes a gesture; swipes are routed, but no sword or shield is offered
## before M6.

const MAIN := preload("res://main/main.tscn")
const DT := 1.0 / 60.0
const NOW := 1795608000000

var main: Node
var settings_before: Dictionary = {}


func before_each() -> void:
	AppState.clock = func() -> int: return NOW
	InputService.auto_update = false
	settings_before = AppState.settings.duplicate(true)


func after_each() -> void:
	if main and is_instance_valid(main):
		main.get_parent().remove_child(main)
		main.free()
	InputService.clear_injection()
	InputService.release_all()
	InputService.auto_update = true
	AppState.update_settings(settings_before)
	AppState.clock = func() -> int: return int(Time.get_unix_time_from_system() * 1000.0)


# --- Helpers ------------------------------------------------------------------------------------

## The campaign entering `id`: 1.0 and every earlier Level 1 scene completed.
static func _entry(id: String) -> Dictionary:
	var st := CampaignSchema.new_campaign()
	st["completed"] = ["1.0"]
	for k in ["1.1", "1.2", "1.3", "1.4", "1.5"]:
		if k == id:
			break
		st["completed"].append(k)
	return st


func _until(cond: Callable, limit: int = 6000) -> bool:
	for k in limit:
		if cond.call():
			return true
		await tree.process_frame
	return cond.call()


## Main from a saved campaign, CONTINUE, the scene card, then the scene ticked by hand up to the
## start of objective `step_id` (the scripted driver gets there); queued input is cleared.
func _to_objective(id: String, step_id: String) -> StoryScene:
	SaveService.save_campaign(_entry(id), NOW - 1000)
	tree.root.size = Vector2i(432, 864)
	main = MAIN.instantiate()
	main.open_url = func(_url: String) -> void: pass
	main.quit_app = func() -> void: pass
	tree.root.add_child(main)
	await tree.process_frame
	await _until(func() -> bool: return not main.transition.running)
	(main.current_scene as TitleScreen).time = 1.0
	(main.current_scene as TitleScreen).activate(1)
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
	var d := StoryDriver.new(s, {}, "bark", true)
	for k in 60 * 120:
		if s.runner.current != null and s.runner.current.id == step_id:
			break
		d.drive(DT)
		InputService.update(DT)
		s.tick(DT)
	if not assert_true(s.runner.current != null and s.runner.current.id == step_id, "%s reached objective %s" % [id, step_id]):
		return null
	InputService.clear_injection()
	InputService.clear_pending()
	(s.ctx.metrics["actions"] as Array).clear()
	return s


func _ticks(s: StoryScene, n: int) -> void:
	for k in n:
		InputService.update(DT)
		s.tick(DT)


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


func _physical(logical: Vector2) -> Vector2:
	var vc: PixelViewportController = main.viewport_controller
	return vc.container.get_global_rect().position + logical * vc.scale


func _touch(index: int, logical: Vector2, pressed: bool) -> void:
	var e := InputEventScreenTouch.new()
	e.index = index
	e.position = _physical(logical)
	e.pressed = pressed
	Input.parse_input_event(e)
	await tree.process_frame


func _drag(index: int, logical: Vector2) -> void:
	var e := InputEventScreenDrag.new()
	e.index = index
	e.position = _physical(logical)
	Input.parse_input_event(e)
	await tree.process_frame


## A screen tap (press, release), then one logic tick.
func _tap(s: StoryScene, logical: Vector2) -> void:
	await _touch(0, logical, true)
	await _touch(0, logical, false)
	_ticks(s, 1)


func _performed(s: StoryScene) -> Array:
	return (s.ctx.metrics["actions"] as Array).duplicate()


func _floats(s: StoryScene) -> Array:
	return s.hud.floats.map(func(f: Dictionary) -> String: return String(f["text"]))


## A point in the gesture zone, away from every button.
func _gesture_point(s: StoryScene) -> Vector2:
	return Vector2(s._view.x - 30, s._view.y * 0.4)


# --- Keys ---------------------------------------------------------------------------------------

## J and X perform the displayed action: SNIFF in 1.2's scrap walk, the bucket's own BARK in 1.1.
func test_SLICE_keys_J_and_X_perform_the_displayed_action() -> void:
	var s := await _to_objective("1.2", "s05")
	if s == null:
		return
	assert_eq([s.controls.action_label, s.ctx.actions.modes], ["SNIFF", PackedStringArray(["scene", "bark"])], "the walk shows SNIFF, its own action first")
	await _press(s, KEY_J)
	assert_eq(_performed(s), ["scene"], "J: the selected mode (SNIFF)")
	assert_true(_floats(s).has("SNIFF..."), "SNIFF... above him")
	await _press(s, KEY_X)
	assert_eq(_performed(s), ["scene", "scene"], "X: the same")
	main.free()
	var s11 := await _to_objective("1.1", "s06")
	if s11 == null:
		return
	assert_eq(s11.controls.action_label, "BARK", "1.1 shows its own BARK")
	await _press(s11, KEY_J)
	assert_eq(_performed(s11), ["scene"], "J: the bucket's own bark")
	assert_true(_floats(s11).has("WOOF! (IT ECHOES INSIDE THE BUCKET.)"), "with its own line")
	assert_true(float(s11.runner.st["bow"]) > 0.0, "and the bucket's rule heard it (his head goes down)")


## Space always performs the walk's own action, whatever mode the action button is in; Q switches
## the button's mode (a notice says what J now does when no touch is in use).
func test_SLICE_space_performs_the_scene_action_and_Q_switches_the_mode() -> void:
	var s := await _to_objective("1.2", "s05")
	if s == null:
		return
	await _press(s, KEY_Q)
	assert_eq([s.ctx.actions.mode, s.controls.action_label, s.controls.mode_index], ["bark", "BARK", 1], "Q: the action button now barks")
	assert_true((s.ctx.metrics["notices"] as Array).has("J: BARK"), "the notice says what J does")
	await _press(s, KEY_J)
	assert_eq(_performed(s), ["bark"], "J: a plain bark now")
	assert_true(_floats(s).has("WOOF!"), "WOOF! above him")
	await _press(s, KEY_SPACE)
	assert_eq(_performed(s), ["bark", "scene"], "Space: still the walk's own action")
	assert_eq(_floats(s).count("SNIFF..."), 1, "SNIFF...")
	await _press(s, KEY_TAB)
	assert_eq(s.ctx.actions.mode, "scene", "Tab switches back")


## B barks directly, in any walk; the scene rules that react to barking hear it (RD-28): the 1.1
## bucket slides down; at the 1.2 gate Jack echoes each bark and the third opens the gap.
func test_SLICE_B_barks_directly_and_the_bark_rules_hear_it() -> void:
	var s := await _to_objective("1.2", "s05")
	if s == null:
		return
	await _press(s, KEY_B)
	assert_eq(_performed(s), ["bark"], "B in the scrap walk: a plain bark, not SNIFF")
	assert_false(_floats(s).has("SNIFF..."), "no sniff")
	main.free()
	var s11 := await _to_objective("1.1", "s06")
	if s11 == null:
		return
	# The bucket up and his head up: it stays up for a moment (standing still lowers it only after
	# VISOR_STILL_AFTER); a bark lowers it at once.
	s11.ctx.visor = 0.0
	s11.runner.st["still_t"] = 0.0
	_ticks(s11, 10)
	assert_eq(s11.ctx.visor, 0.0, "control: no bark, the bucket stays up")
	await _press(s11, KEY_B)
	assert_eq(_performed(s11), ["bark"], "B in 1.1: a plain bark")
	assert_true(float(s11.runner.st["bow"]) > 0.0, "the bucket's rule heard it")
	_ticks(s11, 10)
	assert_true(s11.ctx.visor > 0.0 and float(s11.runner.st["still_t"]) < GameConfig.Story.VISOR_STILL_AFTER, "the bucket slid down because of the bark (visor %.2f)" % s11.ctx.visor)
	main.free()
	var g := await _to_objective("1.2", "s17")
	if g == null:
		return
	g.world.player.set_grid_position(6.0, 3.5)
	for k in 3:
		await _press(g, KEY_B)
	assert_eq([_performed(g), g.ctx.metrics["echoes"]], [["bark", "bark", "bark"], 3], "three B barks, three echoes")
	_ticks(g, 2)
	assert_true(g.runner.current == null or g.runner.current.id != "s17", "the third opened the gap: the gate objective is over")


# --- Touch --------------------------------------------------------------------------------------

## The touch ACTION button performs the displayed action; the switcher button changes the mode and
## the button's label; a walk with one mode shows no switcher.
func test_SLICE_touch_action_button_and_switcher() -> void:
	var s := await _to_objective("1.2", "s05")
	if s == null:
		return
	var action: Vector2 = s.controls._layout["action"]
	var switcher: Vector2 = s.controls._layout["switch"]
	assert_true(InputService.buttons[&"story_switch"]["enabled"], "two modes: the switcher is there")
	await _tap(s, action)
	assert_eq(_performed(s), ["scene"], "ACTION: SNIFF (the displayed action)")
	await _tap(s, switcher)
	assert_eq([s.ctx.actions.mode, s.controls.action_label], ["bark", "BARK"], "the switcher: BARK")
	assert_false((s.ctx.metrics["notices"] as Array).has("J: BARK"), "no keyboard notice while touch is in use")
	await _tap(s, action)
	assert_eq(_performed(s), ["scene", "bark"], "ACTION: now a bark")
	assert_eq(InputService.last_gesture, {}, "button taps are never gestures")
	main.free()
	var g := await _to_objective("1.2", "s17")
	if g == null:
		return
	g.world.player.set_grid_position(6.0, 3.5)
	await _tap(g, g.controls._layout["action"])
	assert_eq([_performed(g), g.ctx.metrics["echoes"]], [["scene"], 1], "the gate's ACTION: his bark, echoed")
	main.free()
	var w := await _to_objective("1.2", "s20")
	if w == null:
		return
	assert_eq([w.controls.action_label, w.ctx.actions.modes, InputService.buttons[&"story_switch"]["enabled"]], ["BARK", PackedStringArray(["bark"]), false], "a walk without its own action: BARK only, no switcher")


## The double tap (default binding: BARK) barks at the gate and Jack echoes; a slow second tap is no
## double tap; bound to OFF it does nothing; bound to ACTION it performs the selected mode.
func test_SLICE_double_tap_performs_its_configured_action() -> void:
	var g := await _to_objective("1.2", "s17")
	if g == null:
		return
	g.world.player.set_grid_position(6.0, 3.5)
	var p := _gesture_point(g)
	assert_true(InputService.gestures_enabled and InputService.gesture_zone.has_point(p), "the gesture zone is on during the walk")
	await _tap(g, p)
	await _tap(g, p + Vector2(3, 2))
	assert_eq([InputService.last_gesture.get("kind", ""), _performed(g), g.ctx.metrics["echoes"]], ["doubleTap", ["bark"], 1], "double tap: a bark, echoed")
	# Slow: the second tap comes after DOUBLE_TAP_TIME of logic time.
	await _tap(g, p)
	_ticks(g, int(GameConfig.InputCfg.DOUBLE_TAP_TIME / DT) + 4)
	await _tap(g, p)
	assert_eq([_performed(g), g.ctx.metrics["echoes"]], [["bark"], 1], "a slow second tap is no double tap")
	AppState.set_control("doubleTap", "off")
	_ticks(g, 30)
	var seq := int(InputService.last_gesture["seq"])
	await _tap(g, p)
	await _tap(g, p)
	assert_eq([int(InputService.last_gesture["seq"]), _performed(g)], [seq + 1, ["bark"]], "bound to OFF: seen, but nothing done")
	AppState.set_control("doubleTap", "action")
	_ticks(g, 30)
	await _tap(g, p)
	await _tap(g, p)
	assert_eq([_performed(g), g.ctx.metrics["echoes"]], [["bark", "scene"], 2], "bound to ACTION: the selected mode (the gate's own bark)")


## Pointer ownership: a joystick drag that ends over the gesture zone is never a swipe; a swipe in
## the zone is routed (SWORD by default: not offered before M6, nothing happens; bound to SWITCH
## it switches the mode).
func test_SLICE_pointer_ownership_and_swipe_routing() -> void:
	var s := await _to_objective("1.2", "s05")
	if s == null:
		return
	var zone: Rect2 = InputService.joystick_zone
	var thumb := zone.position + Vector2(30, zone.size.y * 0.6)
	await _touch(1, thumb, true)
	await _drag(1, thumb + Vector2(10, -40))
	await _drag(1, _gesture_point(s) + Vector2(0, 40))
	await _drag(1, _gesture_point(s))
	assert_true(InputService.joystick["active"], "the joystick owns the pointer")
	await _touch(1, _gesture_point(s), false)
	assert_eq(InputService.last_gesture, {}, "a joystick drag into the gesture zone is not a swipe")
	var p := _gesture_point(s) + Vector2(0, 40)
	await _touch(0, p, true)
	await _drag(0, p + Vector2(2, -30))
	await _touch(0, p + Vector2(2, -30), false)
	_ticks(s, 1)
	assert_eq([InputService.last_gesture.get("kind", ""), _performed(s), s.ctx.actions.mode], ["swipeUp", [], "scene"], "swipe up (SWORD): routed, no sword before M6")
	AppState.set_control("swipeUp", "switch")
	await _touch(0, p, true)
	await _drag(0, p + Vector2(0, -30))
	await _touch(0, p + Vector2(0, -30), false)
	_ticks(s, 1)
	assert_eq([s.ctx.actions.mode, s.controls.action_label], ["bark", "BARK"], "swipe up bound to SWITCH: the next mode")
