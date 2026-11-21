extends Node
## Unified input (port of src/core/input.ts): keyboard through the InputMap, multi-touch from the
## native touch Controls, and an injection interface for tests/automation.
##
## - Movement is a screen-space vector (x right, y down) with magnitude 0..1.
## - Discrete actions are queued with a timestamp and dropped after INPUT.ACTION_TTL unless consumed.
## - RUN is held (Shift/K or the RUN button), or latched in toggle mode.
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
}

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
var context: StringName = &"menu"
## When false, the owner calls update(dt) itself (deterministic tests).
var auto_update := true

var _pending: Dictionary = {}
var _now := 0.0
var _run_latched := false
var _pointers: Dictionary = {}
var _joystick_pointer := -1
var _taps: Array[Vector2] = []
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


var run_held: bool:
	get:
		if _override != null:
			return bool(_override["run"])
		return _run_latched or Input.is_action_pressed(&"run") \
			or (not run_toggle and buttons.has(&"run") and bool(buttons[&"run"]["pressed"]))


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


func reset_for_tests() -> void:
	_override = null
	_pending.clear()
	_taps.clear()
	_pointers.clear()
	_joystick_pointer = -1
	joystick["active"] = false
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
		_:
			if not cancelled and (p - t["start"]).length() <= InputCfg.TAP_SLOP:
				_taps.append(p)


func release_all() -> void:
	_pointers.clear()
	_joystick_pointer = -1
	joystick["active"] = false
	for id: StringName in buttons:
		buttons[id]["pressed"] = false


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		release_all()
