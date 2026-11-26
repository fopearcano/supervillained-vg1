class_name MeravigliaOverlay
extends OverlayPanel
## The Meraviglia book (port of src/story/screens.ts BookScene): the four meters, then the things
## brought home, the marvels seen, the values learned, the scraps of the lecture and the remembered
## lines, read from the committed campaign. Rows are split into pages by their wrapped height (a
## heading is never left alone at a page's foot); PREV / NEXT / BACK, a tap on the page (next), the
## arrow keys, confirm, and Back/Esc to close. Every label comes from ShellText.

const BG := Color("#1a0e06")
const PAGE := Color("#f0dcb0")
const RULE := Color("#c8a060")
const HEAD_INK := Color("#8a2a10")
const INK := Color("#3a2410")
const FOOT_INK := Color("#6a4a20")
const TOP := 40.0
const FOOT := 70.0

var text: ShellText
var campaign: Dictionary = {}
var on_close: Callable
## [{"text": String, "head": bool}] and the pages (arrays of rows).
var rows: Array = []
var pages: Array = []
var page := 0
var _closed := false
var _laid_for := Vector2.ZERO


func setup(p_campaign: Dictionary, p_text: ShellText, p_close: Callable) -> MeravigliaOverlay:
	campaign = p_campaign.duplicate(true)
	text = p_text
	on_close = p_close
	back_action = close
	_build()
	return self


func _ready() -> void:
	super._ready()
	dim = 1.0
	menu_item_width = 70.0
	menu_item_height = 16.0
	menu_gap = 3.0


## The book's rows (source BookScene.build).
func _build() -> void:
	rows = []
	var meters: Dictionary = campaign.get("meters", {})
	rows.append({"text": text.get_text("book_title"), "head": true})
	for key: String in CampaignSchema.METER_KEYS:
		var full: String = text.get_text("book_full") if key == "supervillain" and CampaignRules.unshakeable(campaign) else ""
		rows.append({"text": "%s %s%s" % [CampaignRules.METER_LABEL[key], CampaignSchema.clean_number(float(meters.get(key, 0.0))), full], "head": false})
	rows.append({"text": "", "head": false})
	var book: Dictionary = campaign.get("book", {})
	for sec: Array in [["book_section_items", "items"], ["book_section_marvels", "marvels"], ["book_section_values", "values"], ["book_section_shards", "shards"], ["book_section_remembered", "remembered"]]:
		rows.append({"text": text.get_text(sec[0]), "head": true})
		var list: Array = book.get(sec[1], [])
		if list.is_empty():
			rows.append({"text": text.get_text("book_empty"), "head": false})
		for v: Variant in list:
			var s := String(v).to_upper()
			rows.append({"text": "\"%s\"" % s if sec[1] == "remembered" else s, "head": false})
		rows.append({"text": "", "head": false})


func _row_height(r: Dictionary, width: float) -> float:
	if String(r["text"]) == "":
		return 6.0
	return float(T.wrap(String(r["text"]), int(width)).size() * (T.CELL_H + 2)) + 4.0


## Splits the rows into pages by their wrapped height (source BookScene.paginate).
func paginate(view: Vector2) -> void:
	pages = []
	var width := view.x - 32.0
	var avail := view.y - TOP - FOOT
	var cur: Array = []
	var used := 0.0
	for r: Dictionary in rows:
		var hgt := _row_height(r, width)
		if used + hgt > avail and not cur.is_empty():
			var carry: Array = []
			if bool((cur.back() as Dictionary)["head"]):
				carry.append(cur.pop_back())
			pages.append(cur)
			cur = carry
			used = 0.0
			for c: Dictionary in carry:
				used += _row_height(c, width)
			if String(r["text"]) == "":
				continue
		cur.append(r)
		used += hgt
	if not cur.is_empty():
		pages.append(cur)
	page = clampi(page, 0, maxi(0, pages.size() - 1))
	_laid_for = view
	_menu()


func _menu() -> void:
	items = []
	if page > 0:
		items.append({"label": text.get_text("book_prev"), "color": PixelText.WHITE, "action": prev_page})
	if page < pages.size() - 1:
		items.append({"label": text.get_text("book_next"), "color": PixelText.YELLOW, "action": next_page})
	items.append({"label": text.get_text("book_back"), "color": PixelText.PINK, "action": close})
	selected = clampi(selected, 0, items.size() - 1)


func next_page() -> void:
	if page < pages.size() - 1:
		page += 1
		AudioService.play(&"click")
		selected = 0
		_menu()


func prev_page() -> void:
	if page > 0:
		page -= 1
		AudioService.play(&"click")
		_menu()


func close() -> void:
	if _closed:
		return
	_closed = true
	AudioService.play(&"click")
	on_close.call()


func _process(delta: float) -> void:
	if size != _laid_for and size.x > 0.0:
		paginate(size)
	if is_top() and time > 0.25:
		if Input.is_action_just_pressed(&"move_right"):
			next_page()
		elif Input.is_action_just_pressed(&"move_left"):
			prev_page()
	super._process(delta)


## A tap on the page turns it (on the last page, nothing: BACK closes).
func on_tap(pos: Vector2) -> void:
	if time < 0.3:
		return
	if pos.y < size.y - FOOT:
		next_page()


func draw_content() -> void:
	var w := size.x
	var h := size.y
	draw_rect(Rect2(0, 0, w, h), BG)
	draw_rect(Rect2(4, 4, w - 8, h - 8), PAGE)
	draw_rect(Rect2(4, 4, w - 8, 2), RULE)
	var y := TOP
	if not pages.is_empty():
		for r: Dictionary in pages[page]:
			if String(r["text"]) == "":
				y += 6.0
				continue
			var lines := T.wrap(String(r["text"]), int(w - 32.0))
			for line in lines:
				T.draw(self, Vector2(14, y), line, HEAD_INK if r["head"] else INK)
				y += T.CELL_H + 2
			y += 4.0
	T.draw_centered(self, w / 2.0, h - FOOT + 6.0, text.get_text("book_page") % [page + 1, maxi(1, pages.size())], FOOT_INK)
	menu_top = h - FOOT + 18.0
