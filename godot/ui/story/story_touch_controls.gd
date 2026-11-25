class_name StoryTouchControls
extends Control
## The story's touch controls (the story half of src/ui/touchControls.ts, as Level 1 uses it): the
## floating joystick on the movement side, the round action button labelled by the current
## objective (BARK, SNIFF...), RUN (hidden on no-run objectives) and MENU at the top. Feeds
## InputService.pointer_*; outside a walk the joystick and buttons are off and every touch is a
## tap (dialogue, cards, choices). Mirrors for the left hand. The label text comes from the
## objective Resource.

const INPUT := GameConfig.InputCfg
const T := preload("res://ui/theme/pixel_text.gd")

var walking := false
var action_label := ""
var can_run := true
var _view := Vector2i(216, 432)
var _top := 60
var _layout := {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP


func layout(view: Vector2i, top: int = 60) -> void:
	_view = view
	_top = top
	size = Vector2(view)
	_apply()


## Walk controls on or off; the action button's label ("" = none); whether RUN is offered.
func configure(p_walking: bool, p_action: String, p_run: bool) -> void:
	walking = p_walking
	action_label = p_action
	can_run = p_run
	_apply()
	if not walking:
		InputService.clear_run_latch()
		InputService.release_all()


func _apply() -> void:
	var w := float(_view.x)
	var h := float(_view.y)
	var mirrored := InputService.left_handed
	var mx := func(p: Vector2) -> Vector2: return Vector2(w - p.x, p.y) if mirrored else p
	_layout = {"action": mx.call(Vector2(w - 23, h - 60)), "action_r": 17.0, "run": mx.call(Vector2(w - 42, h - 98)), "run_r": 15.0, "menu": Vector2(w - 22, 12), "menu_r": 12.0}
	var thumb_w := roundf(w * INPUT.JOYSTICK_ZONE)
	InputService.joystick_zone = Rect2(w - thumb_w, _top, thumb_w, h - _top) if mirrored else Rect2(0, _top, thumb_w, h - _top)
	InputService.joystick_enabled = walking
	InputService.set_button(&"story_action", &"action", _layout["action"], _layout["action_r"] + 4.0, walking and action_label != "")
	InputService.set_button(&"story_run", &"run", _layout["run"], _layout["run_r"] + 4.0, walking and can_run)
	InputService.set_button(&"story_menu", &"menu", _layout["menu"], _layout["menu_r"], true)
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
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
	if _layout.is_empty():
		return
	var m: Vector2 = _layout["menu"]
	T.retro_box(self, Rect2(m.x - 18, m.y - 7, 36, 14), T.CYAN, T.RED, 0.5)
	T.draw_centered(self, m.x, m.y - 3, "MENU", T.WHITE, 1, Color.BLACK)
	if not walking:
		return
	var j: Dictionary = InputService.joystick
	if j["active"]:
		var base: Vector2 = (j["base"] as Vector2).round()
		var r := INPUT.JOYSTICK_RADIUS
		draw_circle(base, r, Color(0, 0, 0, 0.18))
		draw_arc(base, r, 0, TAU, 40, Color(T.YELLOW, 0.8), 1.0)
		var d: Vector2 = j["knob"] - j["base"]
		var length := d.length()
		var k := r / length if length > r else 1.0
		draw_circle((base + d * k).round(), 8, Color(T.CYAN, 0.55))
	if action_label != "":
		var c: Vector2 = _layout["action"]
		draw_circle(c, _layout["action_r"], Color(0, 0, 0, 0.35))
		draw_arc(c, _layout["action_r"], 0, TAU, 32, T.YELLOW, 1.0)
		T.draw_centered(self, c.x, c.y - 3, action_label, T.WHITE, 1, Color.BLACK)
	if can_run:
		var c: Vector2 = _layout["run"]
		draw_circle(c, _layout["run_r"], Color(0, 0, 0, 0.3))
		draw_arc(c, _layout["run_r"], 0, TAU, 32, T.CYAN if InputService.run_held else Color(T.CYAN, 0.6), 1.0)
		T.draw_centered(self, c.x, c.y - 3, "RUN", T.WHITE, 1, Color.BLACK)
