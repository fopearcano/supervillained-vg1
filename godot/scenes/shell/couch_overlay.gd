class_name CouchOverlay
extends OverlayPanel
## COUCH (source src/scenes/couchScene.ts): the saved story at a glance on a paper card — the next
## scene (or the finished story and its ending), scenes done per level, the four meters, the book
## counts, coins, costume, the Green Zone best, play time and the last campaign save. Read-only;
## closes with CLOSE, a tap outside the card, confirm or Back. Data: CampaignSummary over the saved
## campaign and StoryCatalog; story-dependent words from ShellText.

const K := GameConfig.Couch
const ORANGE_INK := Color("#b85a00")
const DONE := Color8(0x2e, 0x9e, 0x4a)
const PART := Color8(0xff, 0x9a, 0x1f)
const METERS := [["commozione", Color8(0x3a, 0x9e, 0xe0)], ["supervillain", Color8(0xe0, 0x20, 0x30)],
	["grace", Color8(0xe0, 0xa8, 0x00)], ["standing", Color8(0x2e, 0x9e, 0x4a)]]

var summary: Dictionary = {}
var best: Variant = null
var text: ShellText
var now_ms := 0
var offset_minutes := 0
var on_close: Callable
var card_rect := Rect2()
var close_rect := Rect2()
## Every text drawn, in order (structural tests read the card's content without pixels).
var drawn: Array = []
var _closed := false


func setup(state: Dictionary, catalog: StoryCatalog, p_best: Variant, p_text: ShellText, p_now_ms: int, p_offset_minutes: int, p_close: Callable) -> CouchOverlay:
	summary = CampaignSummary.progress(state, catalog)
	best = p_best
	text = p_text
	now_ms = p_now_ms
	offset_minutes = p_offset_minutes
	on_close = p_close
	back_action = close
	return self


func _ready() -> void:
	super._ready()
	dim = K.DIM


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


## The card's lines as plain text (the same strings draw_content draws).
func lines() -> PackedStringArray:
	var s := summary
	var out := PackedStringArray(["COUCH", "ZAMPANO'S SAVED STORY" if s["started"] else "NO STORY SAVED YET"])
	if s["next"] != null:
		out.append("NEXT" if s["started"] else "FIRST")
		out.append("LEVEL %d: %s %s" % [s["next"]["level"], s["next"]["id"], String(s["next"]["title"]).to_upper()])
	else:
		out.append("THE STORY IS FINISHED")
		out.append("ENDING: %s" % text.get_text("ending_" + String(s["ending"])))
	var pct := int(round(float(s["done"]) * 100.0 / float(s["total"]))) if int(s["total"]) > 0 else 0
	out.append("SCENES %d / %d  %d%%" % [s["done"], s["total"], pct])
	for m: Array in METERS:
		out.append("%s %d" % [text.get_text("meter_" + String(m[0])), int(round(float(s["meters"][m[0]])))])
	out.append("VALUES %d  MARVELS %d" % [s["values"], s["marvels"]])
	out.append("THINGS %d  SHARDS %d" % [s["items"], s["shards"]])
	out.append("COINS %d" % s["coins"])
	var costume := "costume_none" if s["costume"] == null else "costume_" + String(s["costume"])
	out.append("COSTUME %s" % text.get_text(costume))
	out.append("GREEN ZONE BEST")
	if best != null:
		out.append("SCORE %s  STARS %d" % [ScoringRules.format_score(best["score"]), int(round(float(best["stars"])))])
		out.append("TIME %s" % ScoringRules.format_time(best["time"]))
	else:
		out.append("NOT WALKED YET")
	out.append("PLAY TIME %s" % CampaignSummary.format_play_time(float(s["playTime"])))
	out.append("SAVED %s" % CampaignSummary.format_saved_at(s["savedAt"], now_ms, offset_minutes))
	out.append("CLOSE")
	return out


func draw_content() -> void:
	drawn.clear()
	var s := summary
	var w := size.x
	var h := size.y
	var cw := minf(w - 12, K.CARD_WIDTH)
	var pad := 10.0
	var inner := cw - pad * 2
	# Measure, then draw centred: the body is laid out from y = 0.
	var body_h := _body(null, Vector2.ZERO, cw, pad, inner)
	var card_h := body_h + pad * 2
	var cx := roundf((w - cw) / 2.0)
	var cy := maxf(4.0, roundf((h - card_h) / 2.0))
	card_rect = Rect2(cx, cy, cw, card_h)
	Card.paper(self, card_rect, T.ORANGE, ORANGE_INK)
	_body(self, Vector2(cx, cy + pad), cw, pad, inner)
	menu_top = size.y + 100


## Lays the card body out at `o`; draws when `ci` is set. Returns the body height.
func _body(ci: CanvasItem, o: Vector2, cw: float, pad: float, inner: float) -> float:
	_ci = ci
	_o = o
	_pad = pad
	_inner = inner
	_y = 0.0
	var s := summary
	_put("COUCH", roundf((inner - T.width("COUCH", 2) - 1) / 2.0), ORANGE_INK, true, 2)
	_y += 16 + 5
	var sub := "ZAMPANO'S SAVED STORY" if s["started"] else "NO STORY SAVED YET"
	_put(sub, roundf((inner - T.width(sub)) / 2.0), Card.FADED)
	_y += 8 + 2
	_rule(4, 6)
	if s["next"] != null:
		_put("NEXT" if s["started"] else "FIRST", 0, Card.INK, true)
		_y += 8 + 3
		var label := "LEVEL %d: %s %s" % [s["next"]["level"], s["next"]["id"], String(s["next"]["title"]).to_upper()]
		for l in T.wrap(label, int(inner - 8)):
			_put(l, 8, Card.INK)
			_y += 11
		_y += 3
	else:
		_put("THE STORY IS FINISHED", 0, Card.INK, true)
		_y += 8 + 3
		_put("ENDING: %s" % text.get_text("ending_" + String(s["ending"])), 8, Card.INK)
		_y += 8 + 6
	var pct := int(round(float(s["done"]) * 100.0 / float(s["total"]))) if int(s["total"]) > 0 else 0
	_put("SCENES", 0, Card.INK, true)
	_right("%d / %d  %d%%" % [s["done"], s["total"], pct], Card.INK)
	_y += 12
	var levels: Array = s["levels"]
	var gap := 2.0
	var cell_w := floorf((inner - gap * (levels.size() - 1)) / levels.size())
	var cell_h := 14.0
	var row_x := pad + floorf((inner - (cell_w * levels.size() + gap * (levels.size() - 1))) / 2.0)
	for k in levels.size():
		var l: Dictionary = levels[k]
		var x := row_x + k * (cell_w + gap)
		var f := float(l["done"]) / float(l["total"]) if int(l["total"]) > 0 else 0.0
		if ci:
			if f > 0.0:
				var fh := maxf(1.0, roundf((cell_h - 2) * f))
				ci.draw_rect(Rect2(o + Vector2(x + 1, _y + cell_h - 1 - fh), Vector2(cell_w - 2, fh)), Color(DONE if f >= 1.0 else PART, 0.85 if f >= 1.0 else 0.7))
			T._frame(ci, Rect2(o + Vector2(x, _y), Vector2(cell_w, cell_h)), Color(Card.INK, 0.8))
			var n := str(l["number"])
			T.draw(ci, o + Vector2(x + roundf((cell_w - T.width(n)) / 2.0), _y + 4), n, T.WHITE if f >= 1.0 else Card.INK)
	_y += cell_h
	_rule(7, 6)
	var value_w := 30.0
	var bar_w := maxf(16.0, minf(K.BAR_WIDTH, inner - (12 * 8 + 4) - value_w))
	for m: Array in METERS:
		var v := int(round(float(s["meters"][m[0]])))
		_put(text.get_text("meter_" + String(m[0])), 0, Card.INK)
		if ci:
			var bx := o.x + pad + inner - value_w - bar_w
			ci.draw_rect(Rect2(bx, o.y + _y + 1, bar_w, 6), Color(Card.INK, 0.15))
			ci.draw_rect(Rect2(bx, o.y + _y + 1, roundf(bar_w * clampi(v, 0, 100) / 100.0), 6), m[1])
			T._frame(ci, Rect2(bx, o.y + _y + 1, bar_w, 6), Color(Card.INK, 0.5))
		_right(str(v), Card.INK)
		_y += 11
	_rule(2, 6)
	_pair(["VALUES", str(s["values"])], ["MARVELS", str(s["marvels"])])
	_pair(["THINGS", str(s["items"])], ["SHARDS", str(s["shards"])])
	_pair(["COINS", str(s["coins"])], [])
	_put("COSTUME", 0, Card.FADED)
	_right(text.get_text("costume_none" if s["costume"] == null else "costume_" + String(s["costume"])), Card.INK)
	_y += 11 + 2
	_put("GREEN ZONE BEST", 0, Card.INK, true)
	_y += 8 + 4
	if best != null:
		_pair(["SCORE", ScoringRules.format_score(best["score"])], ["STARS", str(int(round(float(best["stars"]))))])
		_pair(["TIME", ScoringRules.format_time(best["time"])], [])
	else:
		_put("NOT WALKED YET", 8, Card.FADED)
		_y += 8 + 2
	_rule(3, 6)
	_put("PLAY TIME", 0, Card.FADED)
	_right(CampaignSummary.format_play_time(float(s["playTime"])), Card.INK)
	_y += 11
	_put("SAVED", 0, Card.FADED)
	_right(CampaignSummary.format_saved_at(s["savedAt"], now_ms, offset_minutes), Card.INK)
	_y += 11 + 3
	var bx := roundf((cw - T.width("CLOSE") - 16) / 2.0)
	if ci:
		drawn.append("CLOSE")
		close_rect = Card.button(ci, o.x + bx, o.y + _y, "CLOSE", T.ORANGE, ORANGE_INK)
	_y += 15
	return _y


var _ci: CanvasItem = null
var _o := Vector2.ZERO
var _pad := 0.0
var _inner := 0.0
var _y := 0.0


func _put(t: String, x: float, color: Color, is_bold: bool = false, scale: int = 1) -> void:
	if _ci == null:
		return
	drawn.append(t)
	if is_bold:
		Card.bold(_ci, _o + Vector2(_pad + x, _y), t, color, scale)
	else:
		T.draw(_ci, _o + Vector2(_pad + x, _y), t, color, scale, Color(0, 0, 0, 0), 3)


func _right(t: String, color: Color) -> void:
	if _ci == null:
		return
	drawn.append(t)
	T.draw(_ci, _o + Vector2(_pad + _inner - T.width(t), _y), t, color)


func _rule(before: float, after: float) -> void:
	_y += before
	if _ci:
		_ci.draw_rect(Rect2(_o + Vector2(_pad, _y), Vector2(_inner, 1)), Color(Card.INK, 0.6))
	_y += 1 + after


func _pair(a: Array, b: Array) -> void:
	var half := floorf(_inner / 2.0) + 4
	_put(a[0], 0, Card.FADED)
	if _ci:
		drawn.append(a[1])
		T.draw(_ci, _o + Vector2(_pad + half - 8 - T.width(a[1]), _y), a[1], Card.INK)
	if not b.is_empty():
		_put(b[0], half, Card.FADED)
		_right(b[1], Card.INK)
	_y += 11
