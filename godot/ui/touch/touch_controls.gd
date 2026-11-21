class_name TouchControls
extends Control
## Floating virtual joystick + PEE / BARK / RUN buttons (port of the Green Zone half of
## src/ui/touchControls.ts): pee-charge droplets and regeneration arc, the energy ring around RUN
## (orange while tired), bark readiness. Receives touch in logical viewport coordinates and feeds
## InputService.pointer_*; layout mirrors for the left hand. Story gestures/switcher arrive in M5.

const INPUT := GameConfig.InputCfg

var catalog: SpriteCatalog
var charges := 3
var max_charges := 3
var regen_fraction := 0.0
var bark_ready := 1.0
var energy := 1.0
var can_run := true
var enabled := true
## Right-hand layout as given by the scene, and the effective (possibly mirrored) one.
var _given := {}
var _layout := {}
var _view := Vector2i(216, 432)
var _top := 60


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP


## Source GameScene.resize: PEE (w-60, h-50, r15), BARK (w-23, h-60, r17), RUN (w-42, h-98, r15).
func layout(view: Vector2i, top: int = 60) -> void:
	_view = view
	_top = top
	size = Vector2(view)
	var w := float(view.x)
	var h := float(view.y)
	_given = {"pee": Vector2(w - 60, h - 50), "pee_r": 15.0, "bark": Vector2(w - 23, h - 60), "bark_r": 17.0, "run": Vector2(w - 42, h - 98), "run_r": 15.0}
	_apply_layout()


func _apply_layout() -> void:
	var mirrored := InputService.left_handed
	var w := float(_view.x)
	var mx := func(p: Vector2) -> Vector2: return Vector2(w - p.x, p.y) if mirrored else p
	_layout = _given.duplicate()
	for k in ["pee", "bark", "run"]:
		_layout[k] = mx.call(_given[k])
	var thumb_w := roundf(w * INPUT.JOYSTICK_ZONE)
	InputService.joystick_zone = Rect2(w - thumb_w, _top, thumb_w, _view.y - _top) if mirrored else Rect2(0, _top, thumb_w, _view.y - _top)
	InputService.set_button(&"pee", &"pee", _layout["pee"], _layout["pee_r"] + 4.0, enabled)
	InputService.set_button(&"bark", &"action", _layout["bark"], _layout["bark_r"] + 4.0, enabled)
	InputService.set_button(&"run", &"run", _layout["run"], _layout["run_r"] + 4.0, enabled)
	queue_redraw()


func set_enabled(on: bool) -> void:
	enabled = on
	visible = on
	for id in [&"pee", &"bark", &"run"]:
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
	var j: Dictionary = InputService.joystick
	if j["active"]:
		var base: Vector2 = (j["base"] as Vector2).round()
		var r := INPUT.JOYSTICK_RADIUS
		draw_circle(base, r, Color(0, 0, 0, 0.18))
		draw_arc(base, r, 0, TAU, 40, Color(PixelText.YELLOW, 0.8), 1.0)
		draw_arc(base, r - 3, 0, TAU, 40, Color(Color("#ff3b3b"), 0.5), 1.0)
		var d: Vector2 = j["knob"] - j["base"]
		var length := d.length()
		var k := r / length if length > r else 1.0
		var knob := (base + d * k).round()
		draw_circle(knob, 8, Color(PixelText.CYAN, 0.55))
		draw_arc(knob, 8, 0, TAU, 24, Color(1, 1, 1, 0.9), 1.0)
	_draw_pee()
	_draw_bark()
	_draw_run()


func _button(c: Vector2, r: float, ring: Color, ring2: Color, pressed: bool, alpha: float) -> void:
	draw_circle(c, r, Color(ring, 0.45) if pressed else Color(0, 0, 0, 0.28))
	draw_arc(c, r, 0, TAU, 40, Color(ring, alpha), 1.0)
	draw_arc(c + Vector2.ONE, r - 2, 0, TAU, 40, Color(ring2, alpha * 0.8), 1.0)


func _label(c: Vector2, y: float, text: String, color: Color) -> void:
	PixelText.draw_centered(self, c.x, c.y + y, text, color, 1, Color.BLACK)


func _icon(key: String, pos: Vector2) -> void:
	var tex := catalog.texture(key)
	draw_texture(tex, pos - Vector2(catalog.anchor(key)))


func _draw_pee() -> void:
	var c: Vector2 = _layout["pee"]
	var r: float = _layout["pee_r"]
	_button(c, r, PixelText.YELLOW, Color("#ff3b3b"), InputService.is_button_pressed(&"pee"), 1.0 if charges > 0 else 0.35)
	_icon("peeIcon_0", c + Vector2(0, -3))
	_label(c, 6, "PEE", PixelText.YELLOW)
	var mirrored := InputService.left_handed
	for k in max_charges:
		var a := PI * (1.05 + k * 0.22)
		var x := JsMath.round(cos(a) * (r + 6))
		var p := c + Vector2(-x if mirrored else x, JsMath.round(sin(a) * (r + 6)))
		_icon("drop_%d" % (0 if k < charges else 1), p)
	if charges < max_charges and regen_fraction > 0.0:
		draw_arc(c, r + 2, -PI / 2, -PI / 2 + TAU * regen_fraction, 32, Color(PixelText.YELLOW, 0.9), 1.0)


func _draw_bark() -> void:
	var c: Vector2 = _layout["bark"]
	_button(c, _layout["bark_r"], PixelText.CYAN, Color("#b040ff"), InputService.is_button_pressed(&"bark"), 0.4 + 0.6 * bark_ready)
	_icon("barkIcon_0", c + Vector2(0, -4))
	_label(c, 7, "BARK", PixelText.CYAN)


func _draw_run() -> void:
	var c: Vector2 = _layout["run"]
	var r: float = _layout["run_r"]
	var pressed := (InputService.is_button_pressed(&"run") or InputService.run_on) and can_run
	var alpha := 1.0 if can_run else 0.6
	_button(c, r, PixelText.GREEN, PixelText.CYAN, pressed, (1.0 if can_run else 0.35) * alpha)
	var icon := catalog.texture("runIcon_0")
	draw_texture(icon, c + Vector2(-floor(icon.get_width() / 2.0), -12), Color(1, 1, 1, alpha))
	_label(c, 5, "RUN", Color(PixelText.GREEN, alpha))
	if energy > 0.005:
		draw_arc(c, r + 2, -PI / 2, -PI / 2 + TAU * minf(1.0, energy), 40, Color(PixelText.GREEN if can_run else PixelText.ORANGE, 0.9), 2.0)
