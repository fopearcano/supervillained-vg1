class_name OverlayPanel
extends Control
## Base for native overlays (port of the Overlay/Menu pattern in src/scenes/overlays.ts): a dim
## layer, pixel-font drawing and a vertical menu operated by touch/mouse (taps), arrow keys and
## Space/Enter (InputService "confirm"). Runs while the gameplay below is paused.

const T := preload("res://ui/theme/pixel_text.gd")

var dim := 0.5
var time := 0.0
## [{"label": String, "color": Color, "action": Callable}]
var items: Array = []
var selected := 0
var menu_top := 0.0
## Source Menu geometry (item width/height, gap); width 0 = fit the label.
var menu_item_width := 0.0
var menu_item_height := 17.0
var menu_gap := 5.0
var menu_hidden := false
var _item_rects: Array[Rect2] = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS
	InputService.clear_pending()


func _process(delta: float) -> void:
	time += delta
	if not items.is_empty():
		if Input.is_action_just_pressed(&"move_up"):
			selected = (selected + items.size() - 1) % items.size()
		elif Input.is_action_just_pressed(&"move_down"):
			selected = (selected + 1) % items.size()
		elif time > 0.25 and InputService.consume(&"confirm"):
			activate(selected)
			return
	queue_redraw()


func activate(index: int) -> void:
	if index >= 0 and index < items.size():
		(items[index]["action"] as Callable).call()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and not event.pressed and time > 0.25:
		for k in _item_rects.size():
			if _item_rects[k].grow(3).has_point(event.position):
				selected = k
				activate(k)
				accept_event()
				return
		on_tap(event.position)
		accept_event()


## Taps outside the menu (subclasses may react).
func on_tap(_pos: Vector2) -> void:
	pass


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, dim))
	draw_content()
	_draw_menu()


func draw_content() -> void:
	pass


func _draw_menu() -> void:
	_item_rects.clear()
	if menu_hidden:
		return
	var y := menu_top
	for k in items.size():
		var label: String = items[k]["label"]
		var w := menu_item_width if menu_item_width > 0.0 else maxf(T.width(label) + 16.0, 96.0)
		var r := Rect2(floor(size.x / 2.0 - w / 2.0), y, w, menu_item_height)
		_item_rects.append(r)
		var col: Color = items[k]["color"]
		T.retro_box(self, r, col, T.YELLOW if k == selected else Color(col, 0.6), 0.55 if k == selected else 0.35)
		T.draw_centered(self, size.x / 2.0, y + floorf((menu_item_height - 8.0) / 2.0) + 1, label, T.WHITE if k == selected else col, 1, Color.BLACK)
		y += menu_item_height + menu_gap
