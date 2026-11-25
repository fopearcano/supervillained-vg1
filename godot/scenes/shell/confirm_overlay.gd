class_name ConfirmOverlay
extends OverlayPanel
## A yes/no question (source ConfirmScene: NEW GAME over a saved story). NO is preselected; Back
## answers NO.

var heading := ""
var body := ""


func setup(p_heading: String, p_body: String, yes: Callable, no: Callable, yes_label: String = "YES", no_label: String = "NO") -> ConfirmOverlay:
	heading = p_heading
	body = p_body
	items = [
		{"label": yes_label, "color": T.GREEN, "action": yes},
		{"label": no_label, "color": T.PINK, "action": no},
	]
	selected = 1
	back_action = no
	return self


func _ready() -> void:
	super._ready()
	dim = 0.92
	menu_item_width = 140.0
	menu_item_height = 18.0
	menu_gap = 6.0


func draw_content() -> void:
	var y := roundf(size.y * 0.32)
	T.draw_centered(self, size.x / 2.0, y - 4, heading, T.YELLOW, 1, T.SHADOW)
	var lines := T.wrap(body, 180)
	T.draw_centered(self, size.x / 2.0, y + 16, "\n".join(lines), T.WHITE, 1, Color.BLACK)
	menu_top = y + 30 + lines.size() * 11
