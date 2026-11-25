extends Node
## Unified input (port of src/core/input.ts): keyboard through the InputMap, multi-touch from the
## native touch Controls, and an injection interface for tests/automation.
##
## - Movement is a screen-space vector (x right, y down) with magnitude 0..1.
## - Discrete actions are queued with a timestamp and dropped after INPUT.ACTION_TTL unless consumed.
##   `action` (J/X, the round button) does the action button's mode; `pee` (Space) the scene's own
##   action; `bark` (B), `strike` (U) and `guard` (I) those directly; `switch` (Q/Tab, the small
##   switcher) the action button's next mode (story walks: StoryActionRouter).
## - RUN is held (Shift/K or the RUN button), or latched in toggle mode.
## - Gestures (story walks): on the right-hand side over the buttons, a swipe up, a swipe down and a
##   double tap do what OPTIONS > CONTROLS binds them to. A pointer is owned by what it first
##   touched: a button or the joystick never also becomes a gesture.
## Touch Controls live inside the pixel SubViewport and call pointer_* with logical coordinates;
## this service never converts coordinates again.

const InputCfg := GameConfig.InputCfg

## Discrete actions a physical key can queue (InputMap action -> queued actions).
const KEY_EDGES := {
	&"pee": [&"pee"],
	&"confirm": [&"confirm"],
	&"action": [&"action"],
	&"bark": [&"bark"],
	&"menu": [&"menu", &"back"],
	&"run": [&"run"],
	&"switch": [&"switch"],
	&"strike": [&"strike"],
	&"guard": [&"guard"],
}

## A gesture setting (OPTIONS > CONTROLS) -> the action it queues ("run": RUN on/off; "off": none).
const GESTURE_ACTIONS := {"off": &"", "action": &"action", "bark": &"bark", "sword": &"strike", "shield": &"guard", "switch": &"switch", "run": &"run_toggle"}

signal context_changed(context: StringName)

## Screen-space movement vector, refreshed once per logic tick by update(). move_x/move_y are the
## 64-bit components the rules read (Vector2 is 32-bit and only mirrors them for presentation).
var move := Vector2.ZERO
var move_x := 0.0
var move_y := 0.0
var joystick := {"active": false, "base": Vector2.ZERO, "knob": Vector2.ZERO}
var joystick_zone := Rect2()
var joystick_enabled := false
var using_touch := false
## id -> {action, center: Vector2, r, enabled, pressed}
var buttons: Dictionary = {}
var run_toggle := false
var left_handed := false
## Settings for the story's gestures and action switcher (OPTIONS > CONTROLS), applied at once by
## AppState and read by the gesture recognizer below.
var gesture_bindings := {"swipeUp": "sword", "swipeDown": "shield", "doubleTap": "bark"}
var switcher_enabled := true
## Where the right-hand gestures are read (logical px), while enabled (StoryTouchControls).
var gesture_zone := Rect2()
var gestures_enabled := false
## The last gesture {"kind", "at": Vector2, "seq": int} (its on-screen streak, tests), or {}.
var last_gesture: Dictionary = {}
var context: StringName = &"menu"
## When false, the owner calls update(dt) itself (deterministic tests).
var auto_update := true

var _pending: Dictionary = {}
var _now := 0.0
var _run_latched := false
var _pointers: Dictionary = {}
var _joystick_pointer := -1
var _taps: Array[Vector2] = []
## The last plain tap in the gesture zone {"p": Vector2, "at": float} (for the double tap), or null.
var _last_tap: Variant = null
var _gesture_seq := 0
## Injection (tests/automation): replaces keyboard/joystick movement and RUN when not null.
var _override: Variant = null


func _physics_process(delta: float) -> void:
	if auto_update:
		update(delta)


func _input(event: InputEvent) -> void:
	if event is InputEventKey and not event.echo:
		for action: StringName in KEY_EDGES:
			if event.is_action_pressed(action):
				for a: StringName in KEY_EDGES[action]:
					trigger(a)


## Called once per logic tick.
func update(dt: float) -> void:
	_now += dt
	for a: StringName in _pending.keys():
		if _now - float(_pending[a]) > InputCfg.ACTION_TTL:
			_pending.erase(a)
	if _override != null:
		_set_move(_override["x"], _override["y"])
		return
	var k := Vector2.ZERO
	if Input.is_action_pressed(&"move_left"):
		k.x -= 1.0
	if Input.is_action_pressed(&"move_right"):
		k.x += 1.0
	if Input.is_action_pressed(&"move_up"):
		k.y -= 1.0
	if Input.is_action_pressed(&"move_down"):
		k.y += 1.0
	if k != Vector2.ZERO:
		var mag := 1.0 if Input.is_physical_key_pressed(KEY_SHIFT) else InputCfg.KEYBOARD_WALK_MAG
		var kl := JsMath.hypot(k.x, k.y)
		_set_move(k.x / kl * mag, k.y / kl * mag)
		return
	if joystick["active"]:
		var d: Vector2 = joystick["knob"] - joystick["base"]
		var length := JsMath.hypot(d.x, d.y)
		var mag := minf(1.0, length / InputCfg.JOYSTICK_RADIUS)
		mag = 0.0 if mag < InputCfg.JOYSTICK_DEADZONE else (mag - InputCfg.JOYSTICK_DEADZONE) / (1.0 - InputCfg.JOYSTICK_DEADZONE)
		if length > 0.0:
			_set_move(d.x / length * mag, d.y / length * mag)
		else:
			_set_move(0.0, 0.0)
		return
	_set_move(0.0, 0.0)


func _set_move(x: float, y: float) -> void:
	move_x = x
	move_y = y
	move = Vector2(x, y)


## True (once) if the action was queued recently.
func consume(action: StringName) -> bool:
	if not _pending.has(action):
		return false
	_pending.erase(action)
	return true


func consume_any(actions: Array[StringName]) -> bool:
	var hit := false
	for a in actions:
		if consume(a):
			hit = true
	return hit


func trigger(action: StringName) -> void:
	_pending[action] = _now


func consume_taps() -> Array[Vector2]:
	var t := _taps
	_taps = []
	return t


## Forget queued edges (scene/context change) so a confirm cannot leak into the next scene.
func set_context(new_context: StringName) -> void:
	context = new_context
	clear_pending()
	context_changed.emit(new_context)


func clear_pending() -> void:
	_pending.clear()
	_taps.clear()
	_last_tap = null


var run_held: bool:
	get:
		if _override != null:
			return bool(_override["run"])
		return _run_latched or Input.is_action_pressed(&"run") \
			or (not run_toggle and buttons.has(&"run") and bool(buttons[&"run"]["pressed"]))


## The shield held (I, or the injected hold of a test driver): it stays up while held.
var guard_hold_injected := false
var guard_held: bool:
	get:
		return guard_hold_injected or Input.is_action_pressed(&"guard")


var run_on: bool:
	get:
		return _run_latched


func clear_run_latch() -> void:
	_run_latched = false


# --- Injection (tests and automation drive the same InputService path as a player) ----------

func inject_move(x: float, y: float, run: bool = false) -> void:
	_override = {"x": x, "y": y, "run": run}


func clear_injection() -> void:
	_override = null


## Returns every piece of state to its start-up value (test isolation between cases).
func reset_for_tests() -> void:
	_override = null
	guard_hold_injected = false
	_pending.clear()
	_taps.clear()
	_pointers.clear()
	_joystick_pointer = -1
	joystick = {"active": false, "base": Vector2.ZERO, "knob": Vector2.ZERO}
	joystick_zone = Rect2()
	joystick_enabled = false
	using_touch = false
	buttons.clear()
	run_toggle = false
	left_handed = false
	gesture_bindings = {"swipeUp": "sword", "swipeDown": "shield", "doubleTap": "bark"}
	switcher_enabled = true
	gesture_zone = Rect2()
	gestures_enabled = false
	last_gesture = {}
	_last_tap = null
	_gesture_seq = 0
	context = &"menu"
	_run_latched = false
	_set_move(0.0, 0.0)
	_now = 0.0


# --- Virtual buttons and pointers (logical viewport coordinates) -----------------------------

func set_button(id: StringName, action: StringName, center: Vector2, r: float, enabled: bool) -> void:
	var pressed := false
	if buttons.has(id):
		pressed = buttons[id]["pressed"]
	buttons[id] = {"action": action, "center": center, "r": r, "enabled": enabled, "pressed": pressed}


func set_button_enabled(id: StringName, enabled: bool) -> void:
	if buttons.has(id):
		buttons[id]["enabled"] = enabled
		if not enabled:
			buttons[id]["pressed"] = false


func is_button_pressed(id: StringName) -> bool:
	return buttons.has(id) and bool(buttons[id]["pressed"])


## Forgets a button (its owner left: a scene's buttons must not catch the next scene's touches).
func remove_button(id: StringName) -> void:
	buttons.erase(id)
	for index: int in _pointers.keys():
		if _pointers[index]["kind"] == &"button" and _pointers[index]["id"] == id:
			_pointers.erase(index)


# --- Gestures (source classifySwipe / isDoubleTap / fireGesture) -----------------------------

## A swipe? Mostly vertical, long enough and quick enough: "swipeUp", "swipeDown" or "".
static func classify_swipe(dx: float, dy: float, seconds: float) -> String:
	if seconds > InputCfg.SWIPE_MAX_TIME or absf(dy) < InputCfg.SWIPE_MIN or absf(dy) < absf(dx) * InputCfg.SWIPE_RATIO:
		return ""
	return "swipeUp" if dy < 0.0 else "swipeDown"


## Is a press at `p` (logic clock `at`) the second tap of a double tap after `prev`?
static func is_double_tap(prev: Variant, p: Vector2, at: float) -> bool:
	if prev == null:
		return false
	var dt := at - float(prev["at"])
	return dt >= 0.0 and dt <= InputCfg.DOUBLE_TAP_TIME and p.distance_to(prev["p"]) <= InputCfg.DOUBLE_TAP_DIST


## A gesture was made: queue what it is bound to, remember it.
func _fire_gesture(kind: String, p: Vector2) -> void:
	var a: StringName = GESTURE_ACTIONS.get(String(gesture_bindings.get(kind, "off")), &"")
	if a == &"run_toggle":
		_run_latched = not _run_latched
	elif a != &"":
		trigger(a)
	_gesture_seq += 1
	last_gesture = {"kind": kind, "at": p, "seq": _gesture_seq}


func pointer_down(index: int, p: Vector2) -> void:
	using_touch = true
	for id: StringName in buttons:
		var b: Dictionary = buttons[id]
		if not b["enabled"]:
			continue
		if p.distance_to(b["center"]) <= float(b["r"]):
			b["pressed"] = true
			if b["action"] == &"run":
				_run_latched = (not _run_latched) if run_toggle else false
			trigger(b["action"])
			_pointers[index] = {"kind": &"button", "id": id, "start": p, "pos": p}
			return
	# Right-hand side, over the buttons: gestures (the second tap of a double tap fires on press).
	if gestures_enabled and gesture_zone.has_point(p):
		var second := is_double_tap(_last_tap, p, _now)
		if second:
			_last_tap = null
			_fire_gesture("doubleTap", p)
		_pointers[index] = {"kind": &"gesture", "start": p, "pos": p, "start_at": _now, "fired": second}
		return
	if joystick_enabled and _joystick_pointer == -1 and joystick_zone.has_point(p):
		_joystick_pointer = index
		joystick["active"] = true
		joystick["base"] = p
		joystick["knob"] = p
		_pointers[index] = {"kind": &"joystick", "start": p, "pos": p}
		return
	_pointers[index] = {"kind": &"tap", "start": p, "pos": p}


func pointer_move(index: int, p: Vector2) -> void:
	if not _pointers.has(index):
		return
	var t: Dictionary = _pointers[index]
	t["pos"] = p
	if t["kind"] == &"gesture":
		# A swipe fires as soon as it is one (no waiting for the finger to lift).
		if not t["fired"]:
			var from: Vector2 = t["start"]
			var swipe := classify_swipe(p.x - from.x, p.y - from.y, _now - float(t["start_at"]))
			if swipe != "":
				t["fired"] = true
				_last_tap = null
				_fire_gesture(swipe, from)
		return
	if t["kind"] == &"joystick":
		joystick["knob"] = p
		# The base follows the thumb when dragged beyond the radius.
		var d: Vector2 = p - joystick["base"]
		var length := d.length()
		if length > InputCfg.JOYSTICK_RADIUS:
			joystick["base"] = p - d / length * InputCfg.JOYSTICK_RADIUS


func pointer_up(index: int, p: Vector2, cancelled: bool = false) -> void:
	if not _pointers.has(index):
		return
	var t: Dictionary = _pointers[index]
	_pointers.erase(index)
	t["pos"] = p
	match t["kind"]:
		&"button":
			if buttons.has(t["id"]):
				buttons[t["id"]]["pressed"] = false
		&"joystick":
			_joystick_pointer = -1
			joystick["active"] = false
		&"gesture":
			if cancelled or t["fired"]:
				return
			var from: Vector2 = t["start"]
			if (p - from).length() <= InputCfg.TAP_SLOP:
				# A plain tap: still a tap (dialogue, choices), and maybe the first of a double tap.
				_taps.append(p)
				_last_tap = {"p": p, "at": _now} if _now - float(t["start_at"]) <= InputCfg.TAP_MAX_TIME else null
		_:
			if not cancelled and (p - t["start"]).length() <= InputCfg.TAP_SLOP:
				_taps.append(p)


func release_all() -> void:
	_pointers.clear()
	guard_hold_injected = false
	_last_tap = null
	_joystick_pointer = -1
	joystick["active"] = false
	for id: StringName in buttons:
		buttons[id]["pressed"] = false


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		release_all()
