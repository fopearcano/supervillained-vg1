class_name TouchControls
extends Control
## Floating virtual joystick with only the prototype's two action buttons: PEE and RUN.

const INPUT := GameConfig.InputCfg

var catalog: SpriteCatalog
var charges := 3
var max_charges := 3
var regen_fraction := 0.0
var energy := 1.0
var can_run := true
var enabled := true
var _given := {}
var _layout := {}
var _view := Vector2i(216, 432)
var _top := 104


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP


func layout(view: Vector2i, top: int = 104) -> void:
	_view = view
	_top = top
	size = Vector2(view)
	var width := float(view.x)
	var height := float(view.y)
	_given = {
		"pee": Vector2(width - 28.0, height - 48.0),
		"pee_r": 16.0,
		"run": Vector2(width - 28.0, height - 92.0),
		"run_r": 15.0,
	}
	_apply_layout()


func _apply_layout() -> void:
	var mirrored := InputService.left_handed
	var width := float(_view.x)
	var mirror := func(point: Vector2) -> Vector2: return Vector2(width - point.x, point.y) if mirrored else point
	_layout = _given.duplicate()
	for key in ["pee", "run"]:
		_layout[key] = mirror.call(_given[key])
	var thumb_width := roundf(width * INPUT.JOYSTICK_ZONE)
	InputService.joystick_zone = Rect2(width - thumb_width, _top, thumb_width, _view.y - _top) if mirrored else Rect2(0, _top, thumb_width, _view.y - _top)
	InputService.set_button(&"pee", &"pee", _layout["pee"], _layout["pee_r"] + 4.0, enabled)
	InputService.set_button(&"run", &"run", _layout["run"], _layout["run_r"] + 4.0, enabled)
	queue_redraw()


func set_enabled(on: bool) -> void:
	enabled = on
	visible = on
	for id in [&"pee", &"run"]:
		InputService.set_button_enabled(id, on)
	InputService.joystick_enabled = on
	if not on:
		InputService.clear_run_latch()
		InputService.release_all()


func _gui_input(event: InputEvent) -> void:
	if not enabled:
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			InputService.pointer_down(event.index, event.position)
		else:
			InputService.pointer_up(event.index, event.position, event.canceled)
		accept_event()
	elif event is InputEventScreenDrag:
		InputService.pointer_move(event.index, event.position)
		accept_event()


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if not enabled or _layout.is_empty():
		return
	var joystick: Dictionary = InputService.joystick
	if joystick["active"]:
		var base: Vector2 = (joystick["base"] as Vector2).round()
		var radius := INPUT.JOYSTICK_RADIUS
		draw_circle(base, radius, Color(0, 0, 0, 0.18))
		draw_arc(base, radius, 0, TAU, 40, Color(PixelText.YELLOW, 0.8), 1.0)
		draw_arc(base, radius - 3, 0, TAU, 40, Color(Color("#ff3b3b"), 0.5), 1.0)
		var delta: Vector2 = joystick["knob"] - joystick["base"]
		var length := delta.length()
		var scale := radius / length if length > radius else 1.0
		var knob := (base + delta * scale).round()
		draw_circle(knob, 8, Color(PixelText.CYAN, 0.55))
		draw_arc(knob, 8, 0, TAU, 24, Color(1, 1, 1, 0.9), 1.0)
	_draw_pee()
	_draw_run()


func _button(center: Vector2, radius: float, ring: Color, ring2: Color, pressed: bool, alpha: float) -> void:
	draw_circle(center, radius, Color(ring, 0.45) if pressed else Color(0, 0, 0, 0.28))
	draw_arc(center, radius, 0, TAU, 40, Color(ring, alpha), 1.0)
	draw_arc(center + Vector2.ONE, radius - 2, 0, TAU, 40, Color(ring2, alpha * 0.8), 1.0)


func _label(center: Vector2, y: float, text: String, color: Color) -> void:
	PixelText.draw_centered(self, center.x, center.y + y, text, color, 1, Color.BLACK)


func _icon(key: String, pos: Vector2) -> void:
	var texture := catalog.texture(key)
	draw_texture(texture, pos - Vector2(catalog.anchor(key)))


func _draw_pee() -> void:
	var center: Vector2 = _layout["pee"]
	var radius: float = _layout["pee_r"]
	_button(center, radius, PixelText.YELLOW, Color("#ff3b3b"), InputService.is_button_pressed(&"pee"), 1.0 if charges > 0 else 0.35)
	_icon("peeIcon_0", center + Vector2(0, -3))
	_label(center, 7, "PEE", PixelText.YELLOW)
	var mirrored := InputService.left_handed
	for k in max_charges:
		var angle := PI * (1.05 + k * 0.22)
		var x := JsMath.round(cos(angle) * (radius + 6))
		var p := center + Vector2(-x if mirrored else x, JsMath.round(sin(angle) * (radius + 6)))
		_icon("drop_%d" % (0 if k < charges else 1), p)
	if charges < max_charges and regen_fraction > 0.0:
		draw_arc(center, radius + 2, -PI / 2, -PI / 2 + TAU * regen_fraction, 32, Color(PixelText.YELLOW, 0.9), 1.0)


func _draw_run() -> void:
	var center: Vector2 = _layout["run"]
	var radius: float = _layout["run_r"]
	var pressed := (InputService.is_button_pressed(&"run") or InputService.run_on) and can_run
	var alpha := 1.0 if can_run else 0.6
	_button(center, radius, PixelText.GREEN, PixelText.CYAN, pressed, (1.0 if can_run else 0.35) * alpha)
	var icon := catalog.texture("runIcon_0")
	draw_texture(icon, center + Vector2(-floor(icon.get_width() / 2.0), -12), Color(1, 1, 1, alpha))
	_label(center, 5, "RUN", Color(PixelText.GREEN, alpha))
	if energy > 0.005:
		draw_arc(center, radius + 2, -PI / 2, -PI / 2 + TAU * minf(1.0, energy), 40, Color(PixelText.GREEN if can_run else PixelText.ORANGE, 0.9), 2.0)
