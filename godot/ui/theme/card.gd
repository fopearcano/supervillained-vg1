class_name Card
extends RefCounted
## Paper cards of the title page (port of src/ui/card.ts): ink colours, faux-bold text, the
## floating paper card with its shadow and double frame, and the small framed CLOSE button.

const T := preload("res://ui/theme/pixel_text.gd")
const INK := Color("#1c1626")
const FADED := Color("#6a6478")
const PAPER := Color8(0xf3, 0xec, 0xd8)
const VIOLET := Color("#a77bff")


## Faux bold: the text twice, one pixel apart.
static func bold(ci: CanvasItem, pos: Vector2, text: String, color: Color, scale: int = 1) -> void:
	for dx in [0, 1]:
		T.draw(ci, pos + Vector2(dx, 0), text, color, scale, Color(0, 0, 0, 0), 3)


static func text_height(text: String, scale: int = 1, line_gap: int = 3) -> int:
	var lines := text.split("\n").size()
	return lines * T.CELL_H * scale + (lines - 1) * line_gap


static func paper(ci: CanvasItem, r: Rect2, accent: Color, accent_ink: Color) -> void:
	ci.draw_rect(Rect2(r.position + Vector2(3, 3), r.size), Color(0, 0, 0, 0.45))
	ci.draw_rect(r, PAPER)
	T._frame(ci, r, accent)
	T._frame(ci, Rect2(r.position + Vector2(2, 2), r.size - Vector2(4, 4)), Color(accent_ink, 0.6))


## A small framed text button; returns its rectangle.
static func button(ci: CanvasItem, x: float, y: float, label: String, accent: Color, accent_ink: Color) -> Rect2:
	var r := Rect2(x, y, T.width(label) + 16, 15)
	ci.draw_rect(r, Color(accent, 0.18))
	T._frame(ci, r, accent_ink)
	T.draw(ci, Vector2(x + 8, y + 4), label, accent_ink)
	return r
