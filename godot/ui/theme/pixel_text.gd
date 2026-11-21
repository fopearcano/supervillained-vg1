class_name PixelText
extends RefCounted
## Draws text with the generated Press Start 2P bitmap font (assets/fonts/pixel_font.fnt, built
## from src/ui/pixelFont.ts): 8 px monospace advance, 8 px cell, integer scales only, unknown
## characters shown as '?' like the source. Positions are the text box's top-left.

const FONT: FontFile = preload("res://assets/fonts/pixel_font.fnt")
const ADVANCE := 8
const CELL_H := 8
const EXTRA := "əˈː"

## Source HUD colours (src/ui/retro.ts).
const YELLOW := Color("#ffe23a")
const ORANGE := Color("#ff9a1f")
const RED := Color("#ff2a3a")
const PINK := Color("#ff4fa8")
const MAGENTA := Color("#e040ff")
const CYAN := Color("#3ff0ff")
const GREEN := Color("#4dff5a")
const WHITE := Color("#ffffff")
const PALE_ROSE := Color("#ffd6f0")
const HOT_PINK := Color("#ff5ad6")
const SHADOW := Color("#120818")


static func sanitize(text: String) -> String:
	var out := ""
	for ch in text:
		var c := ch.unicode_at(0)
		out += ch if (c >= 32 and c <= 126) or ch == "\n" or EXTRA.contains(ch) else "?"
	return out


static func width(text: String, scale: int = 1) -> int:
	var w := 0
	for line in text.split("\n"):
		w = maxi(w, line.length())
	return w * ADVANCE * scale


## Draws one or more lines (\n) at `pos` (top-left). `shadow` with alpha 0 draws no shadow.
static func draw(ci: CanvasItem, pos: Vector2, text: String, color: Color, scale: int = 1, shadow := Color(0, 0, 0, 0), line_gap: int = 2) -> void:
	var lines := sanitize(text).split("\n")
	for k in lines.size():
		var p := pos + Vector2(0, k * (CELL_H * scale + line_gap))
		if shadow.a > 0.0:
			ci.draw_string(FONT, p + Vector2(scale, scale + CELL_H * scale), lines[k], HORIZONTAL_ALIGNMENT_LEFT, -1, ADVANCE * scale, shadow)
		ci.draw_string(FONT, p + Vector2(0, CELL_H * scale), lines[k], HORIZONTAL_ALIGNMENT_LEFT, -1, ADVANCE * scale, color)


## Draws coloured spans [[text, color], ...] on one line.
static func draw_spans(ci: CanvasItem, pos: Vector2, spans: Array, scale: int = 1, shadow := Color(0, 0, 0, 0)) -> void:
	var x := pos.x
	for s: Array in spans:
		draw(ci, Vector2(x, pos.y), s[0], s[1], scale, shadow)
		x += String(s[0]).length() * ADVANCE * scale


## Text centred horizontally on `cx`.
static func draw_centered(ci: CanvasItem, cx: float, y: float, text: String, color: Color, scale: int = 1, shadow := Color(0, 0, 0, 0)) -> void:
	for k in text.split("\n").size():
		var line := text.split("\n")[k]
		draw(ci, Vector2(floor(cx - width(line, scale) / 2.0), y + k * (CELL_H * scale + 3)), line, color, scale, shadow)


## Greedy word wrap to a pixel width (monospace), src/ui/pixelText.ts layoutLines(): runs of
## spaces separate words, a word longer than the line stays whole, 0 = no wrap.
static func wrap(text: String, max_width: int, scale: int = 1) -> PackedStringArray:
	if max_width <= 0:
		return text.split("\n")
	var out := PackedStringArray()
	var cols := maxi(1, max_width / (ADVANCE * scale))
	for para in text.split("\n"):
		var line := ""
		for word in para.split(" ", false):
			var candidate := word if line == "" else line + " " + word
			if candidate.length() > cols and line != "":
				out.append(line)
				line = word
			else:
				line = candidate
		out.append(line)
	return out


## Source retroBox: dark translucent fill, an outer border and a second inner border.
static func retro_box(ci: CanvasItem, r: Rect2, outer: Color = RED, inner: Color = YELLOW, fill_alpha: float = 0.28) -> void:
	ci.draw_rect(r, Color(0, 0, 0, fill_alpha))
	_frame(ci, r, outer)
	_frame(ci, Rect2(r.position + Vector2.ONE, r.size - Vector2.ONE), Color(inner, 0.9))


static func _frame(ci: CanvasItem, r: Rect2, c: Color) -> void:
	var x := r.position.x
	var y := r.position.y
	var w := r.size.x
	var h := r.size.y
	ci.draw_rect(Rect2(x, y, w, 1), c)
	ci.draw_rect(Rect2(x, y + h - 1, w, 1), c)
	ci.draw_rect(Rect2(x, y + 1, 1, h - 2), c)
	ci.draw_rect(Rect2(x + w - 1, y + 1, 1, h - 2), c)


## Hunger gradient: cyan -> yellow -> orange -> red (src/ui/retro.ts hungerColor).
static func hunger_color(t: float) -> Color:
	var stops := [[0.0, 0x3f, 0xf0, 0xff], [0.45, 0xff, 0xe2, 0x3a], [0.75, 0xff, 0x8a, 0x1f], [1.0, 0xff, 0x2a, 0x3a]]
	for k in range(1, stops.size()):
		var a: Array = stops[k - 1]
		var b: Array = stops[k]
		if t <= b[0]:
			var u: float = (t - a[0]) / (b[0] - a[0])
			return Color8(int(JsMath.round(a[1] + (b[1] - a[1]) * u)), int(JsMath.round(a[2] + (b[2] - a[2]) * u)), int(JsMath.round(a[3] + (b[3] - a[3]) * u)))
	return Color("#ff2a3a")
