class_name StoryShade
extends Control
## The story's screen shades, drawn under the touch controls, the HUD, the dialogue and the cards
## (source StoryScene.overlayG): the 1.1 bucket's visor bars (the helmet from the top, the
## cheek-pieces from the bottom, a slit left) and the white flash. Reads them from the StoryHud.

const VISOR_COLOR := Color("#14161c")
const VISOR_EDGE := Color("#8a94a8")

var hud: StoryHud


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if hud == null:
		return
	var w := size.x
	var h := size.y
	if hud.visor > 0.01:
		var top := roundf(h / 2.0 * hud.visor)
		var bottom := roundf(h / 2.0 * hud.visor * 0.82)
		draw_rect(Rect2(0, 0, w, top), VISOR_COLOR)
		draw_rect(Rect2(0, h - bottom, w, bottom), VISOR_COLOR)
		draw_rect(Rect2(0, top - 2, w, 2), VISOR_EDGE)
	if hud.flash_alpha > 0.0:
		draw_rect(Rect2(0, 0, w, h), Color(1, 1, 1, hud.flash_alpha))
