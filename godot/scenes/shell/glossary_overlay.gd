class_name GlossaryOverlay
extends OverlayPanel
## GLOSSARY (source src/scenes/glossaryScene.ts): the dictionary entry of "supervillain,
## supervillained" on a paper card; the b) verb is circled in red by a ring that draws itself after
## RING_DELAY in RING_TIME. Closes with CLOSE, a tap outside the card, confirm or Back.

const G := GameConfig.Glossary
const RING := Color8(0xd4, 0x20, 0x30)
const VIOLET_INK := Color("#5b2bc4")
const HEADWORD := "SUPERVILLAIN,\nSUPERVILLAINED"
const IPA := "/ˈsuːpərvilən/"
const NOUN_LABEL := "A) NOUN,"
const NOUN := "A FICTIONAL VILLAIN HAVING EXTRAORDINARY OR SUPERHUMAN POWERS"
const VERB_LABEL := "B) VERB,"
const VERB := "TO GROW UP STRONG;\nTO GET CHARACTER"

var on_close: Callable
var card_rect := Rect2()
var close_rect := Rect2()
## The ring's points (64 steps + overshoot) and how many are drawn now.
var ring_points: PackedVector2Array = []
var _closed := false


func setup(p_close: Callable) -> GlossaryOverlay:
	on_close = p_close
	back_action = close
	return self


func _ready() -> void:
	super._ready()
	dim = G.DIM


func _process(delta: float) -> void:
	super._process(delta)
	if is_top() and time > 0.25 and InputService.consume(&"confirm"):
		close()


func on_tap(pos: Vector2) -> void:
	if time < 0.25:
		return
	if not card_rect.has_point(pos) or close_rect.grow(6).has_point(pos):
		close()


func close() -> void:
	if _closed:
		return
	_closed = true
	AudioService.play(&"click")
	on_close.call()


## Share of the ring drawn at this time (0..1).
func ring_progress() -> float:
	return clampf((time - G.RING_DELAY) / G.RING_TIME, 0.0, 1.0)


func draw_content() -> void:
	var w := size.x
	var h := size.y
	var cw := minf(w - 16, G.CARD_WIDTH)
	var pad := 10.0
	var inner := cw - pad * 2
	var noun_lines := T.wrap(NOUN, int(inner - 8))
	# Heights: heading 16+12, headword 2 lines, rule, ipa, labels, noun, verb, button.
	var body_h := 16 + 12 + Card.text_height(HEADWORD) + 3 + 5 + 8 + 10 + 8 + 4 + Card.text_height("\n".join(noun_lines)) + 11 + 8 + 10 + Card.text_height(VERB, 1, 4) + 14 + 15
	var card_h := body_h + pad * 2
	var cx := roundf((w - cw) / 2.0)
	var cy := maxf(8.0, roundf((h - card_h) / 2.0))
	card_rect = Rect2(cx, cy, cw, card_h)
	Card.paper(self, card_rect, Card.VIOLET, VIOLET_INK)
	var o := Vector2(cx + pad, cy + pad)
	var y := 0.0
	Card.bold(self, o + Vector2(roundf((inner - T.width("GLOSSARY", 2)) / 2.0), y), "GLOSSARY", VIOLET_INK, 2)
	y += 16 + 12
	Card.bold(self, o + Vector2(0, y), HEADWORD, Card.INK)
	y += Card.text_height(HEADWORD) + 3
	draw_rect(Rect2(o + Vector2(0, y), Vector2(inner, 1)), Card.INK)
	y += 5
	T.draw(self, o + Vector2(0, y), IPA, Card.INK)
	y += 8 + 10
	Card.bold(self, o + Vector2(0, y), NOUN_LABEL, Card.FADED)
	y += 8 + 4
	T.draw(self, o + Vector2(8, y), "\n".join(noun_lines), Card.FADED, 1, Color(0, 0, 0, 0), 3)
	y += Card.text_height("\n".join(noun_lines)) + 11
	Card.bold(self, o + Vector2(0, y), VERB_LABEL, Card.INK)
	y += 8 + 10
	var vw := maxf(T.width("TO GROW UP STRONG;"), T.width("TO GET CHARACTER"))
	var vx := roundf((inner - vw) / 2.0)
	var vh := Card.text_height(VERB, 1, 4)
	for k in 2:
		var l := VERB.split("\n")[k]
		T.draw(self, o + Vector2(vx, y + k * 12), l, Card.INK)
	# The ring: a slightly wobbly ellipse whose end overshoots its start (source drawRing).
	var ex := o.x + vx + vw / 2.0
	var ey := o.y + y + vh / 2.0
	var rx := vw / 2.0 + G.RING_PAD_X
	var ry := vh / 2.0 + G.RING_PAD_Y
	ring_points.clear()
	var steps := 64
	for k in range(steps + G.RING_OVERSHOOT + 1):
		var a := -PI * 0.9 + (float(k) / steps) * PI * 2.0
		var wob := 1.0 + 0.035 * sin(a * 3.0 + 0.6) + (float(k) / steps) * 0.05
		ring_points.append(Vector2(ex + cos(a) * rx * wob, ey + sin(a) * ry * wob - (float(k) / steps) * 2.0))
	var n := int(floor(ring_progress() * (ring_points.size() - 1))) + 1
	if ring_progress() > 0.0 and n >= 2:
		draw_polyline(ring_points.slice(0, n), RING, 1.5)
	y += vh + 14
	close_rect = Card.button(self, cx + roundf((cw - T.width("CLOSE") - 16) / 2.0), o.y + y, "CLOSE", Card.VIOLET, VIOLET_INK)
	menu_top = size.y + 100
