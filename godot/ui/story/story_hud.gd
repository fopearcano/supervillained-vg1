class_name StoryHud
extends Control
## The story HUD (port of the parts of src/story/ui.ts and storyScene.ts Level 1 uses), drawn in
## the pixel font: the dialogue box (portrait, speaker name in its colour, typewriter at the text
## speed setting, the box growing upward for long lines, a blinking ">" when done), the choice
## list above it (locked options greyed with their reason, the selected one highlighted), the
## big centred cards, notices, lines floating above characters, the objective and carry lines,
## the visor (1.1's bucket over his eyes) and a flash. All text it shows comes from the story
## Resources through the steps; this script holds none.

const T := preload("res://ui/theme/pixel_text.gd")
const S := GameConfig.Story
const MARKUP: StoryMarkup = preload("res://data/story/markup.tres")

var world: IsoWorld
var cps: float = S.TEXT_CPS["normal"]
# Dialogue.
var line_visible := false
var speaker_name := ""
var name_color := Color.WHITE
var portrait: Texture2D = null
var full_text := ""
var shown := 0.0
var choices: Array = []
var selected := 0
var choice_rects: Array[Rect2] = []
# Card.
var card_visible := false
var card_big := ""
var card_small := ""
var card_color := Color.WHITE
var card_dim := 0.55
var card_tap := false
# Notices, floating lines, objective, carry, visor, flash.
var notices: Array = []
var floats: Array = []
var objective := ""
var carry_label := ""
var visor := 0.0
## A walk's gauge under the objective (a fight's hearts, a lull, listening, a beat game): its label,
## fill 0..1 and colour; hidden when the label is "".
var mode_label := ""
var mode_value := 0.0
var mode_color := Color.WHITE
var flash_alpha := 0.0
var time := 0.0
## Every line, card, notice and floating text shown, in order (tests, the completion reports).
var shown_texts: PackedStringArray = []

var typing: bool:
	get:
		return int(shown) < full_text.length()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func layout(view: Vector2i) -> void:
	size = Vector2(view)
	queue_redraw()


func show_line(p_name: String, p_color: Color, p_portrait: Texture2D, text: String) -> void:
	line_visible = true
	speaker_name = p_name
	name_color = p_color
	portrait = p_portrait
	full_text = T.sanitize(text)
	shown = 0.0
	shown_texts.append(full_text)
	choices = []
	choice_rects.clear()
	queue_redraw()


func finish_typing() -> void:
	shown = full_text.length()


func hide_line() -> void:
	line_visible = false
	choices = []
	choice_rects.clear()


## [{"label": String, "locked": String ("" = open)}]
func set_choices(views: Array) -> void:
	choices = views
	selected = 0
	for k in views.size():
		if String((views[k] as Dictionary).get("locked", "")) == "":
			selected = k
			break
	_layout_choices()


## Reads the player's pick: UP/DOWN and confirm, or a tap on a row. Returns the index or -1.
func read_choice() -> int:
	if choices.is_empty():
		return -1
	if Input.is_action_just_pressed(&"move_up"):
		selected = (selected + choices.size() - 1) % choices.size()
	elif Input.is_action_just_pressed(&"move_down"):
		selected = (selected + 1) % choices.size()
	for p: Vector2 in InputService.consume_taps():
		for k in choice_rects.size():
			if choice_rects[k].grow(2).has_point(p):
				selected = k
				return k
	if InputService.consume_any([&"confirm", &"action"] as Array[StringName]):
		return selected
	return -1


func show_card(big: String, small: String, color: Color, dim: float, tap: bool) -> void:
	card_visible = true
	card_big = T.sanitize(big)
	card_small = T.sanitize(small)
	shown_texts.append_array(PackedStringArray([card_big, card_small]))
	card_color = color
	card_dim = dim
	card_tap = tap


func hide_card() -> void:
	card_visible = false


func set_mode(label: String, value: float, color: Color) -> void:
	mode_label = label
	mode_value = clampf(value, 0.0, 1.0)
	mode_color = color
	queue_redraw()


func clear_mode() -> void:
	mode_label = ""
	queue_redraw()


func notice(text: String, color: Color, delay: float = 0.0) -> void:
	notices.append({"text": T.sanitize(text), "color": color, "t": -delay})
	shown_texts.append(T.sanitize(text))


func float_text(text: String, at: Vector2, color: Color) -> void:
	floats.append({"text": T.sanitize(text), "at": at, "color": color, "t": 0.0})
	shown_texts.append(T.sanitize(text))


func flash() -> void:
	flash_alpha = 0.85


## One logic tick: the typewriter, timers.
func tick(dt: float) -> void:
	time += dt
	if line_visible and typing:
		shown = minf(float(full_text.length()), shown + cps * dt)
	for n: Dictionary in notices:
		n["t"] = float(n["t"]) + dt
	notices = notices.filter(func(n: Dictionary) -> bool: return float(n["t"]) < S.NOTICE_TIME)
	for f: Dictionary in floats:
		f["t"] = float(f["t"]) + dt
	floats = floats.filter(func(f: Dictionary) -> bool: return float(f["t"]) < S.FLOAT_TIME)
	flash_alpha = maxf(0.0, flash_alpha - dt * 3.0)
	queue_redraw()


func _box_height(w: float) -> float:
	var lines := T.wrap(full_text, int(w - 62.0))
	var text_h := lines.size() * (T.CELL_H + 3)
	return maxf(float(S.DIALOGUE_MIN_H), text_h + S.DIALOGUE_PAD)


func _draw() -> void:
	var w := size.x
	var h := size.y
	# (The visor bars and the flash are drawn beneath the touch controls by StoryShade.)
	# Floating lines above characters (kept inside the view).
	if world:
		var origin := world.camera_rig.view_rect().position
		for f: Dictionary in floats:
			var at: Vector2 = f["at"]
			var s := IsoGrid.grid_to_screen(at.x, at.y) - origin
			var lines := T.wrap(f["text"], int(minf(150.0, w - 2.0 * S.SAY_INSET_SIDE)))
			var y := maxf(s.y - 46.0 - float(f["t"]) * 6.0 - (lines.size() - 1) * (T.CELL_H + 2), S.SAY_INSET_TOP - 30.0)
			for line in lines:
				var tw := T.width(line)
				var x := clampf(s.x - tw / 2.0, S.SAY_INSET_SIDE, w - S.SAY_INSET_SIDE - tw)
				T.draw(self, Vector2(roundf(x), roundf(y)), line, f["color"], 1, Color.BLACK)
				y += T.CELL_H + 2
	# Objective and carry lines, notices.
	var y0 := 22.0
	if objective != "":
		for line in T.wrap(objective, int(w - 40)):
			T.draw(self, Vector2(6, y0), line, T.YELLOW, 1, Color.BLACK)
			y0 += T.CELL_H + 3
	if carry_label != "":
		T.draw(self, Vector2(6, y0), carry_label, T.CYAN, 1, Color.BLACK)
		y0 += T.CELL_H + 3
	if mode_label != "":
		T.draw(self, Vector2(6, y0), mode_label, mode_color, 1, Color.BLACK)
		y0 += T.CELL_H + 2
		var bw := minf(120.0, w - 12.0)
		draw_rect(Rect2(6, y0, bw, 5), Color(0, 0, 0, 0.6))
		draw_rect(Rect2(7, y0 + 1, roundf((bw - 2.0) * mode_value), 3), mode_color)
		draw_rect(Rect2(6, y0, bw, 5), T.YELLOW, false, 1.0)
		y0 += 8
	var ny := y0 + 4
	for n: Dictionary in notices:
		if float(n["t"]) < 0.0:
			continue
		var a := clampf((S.NOTICE_TIME - float(n["t"])) / 0.5, 0.0, 1.0)
		for line in T.wrap(n["text"], int(w - 16)):
			T.draw_centered(self, w / 2.0, ny, line, Color(n["color"], a), 1, Color(0, 0, 0, a))
			ny += T.CELL_H + 3
	if line_visible:
		_draw_dialogue(w, h)
	if card_visible:
		draw_rect(Rect2(0, 0, w, h), Color(0, 0, 0, card_dim))
		var cy := roundf(h * 0.42)
		if card_big != "":
			# Double size when it fits the view, else the normal size (no clipping).
			var scale := 2 if T.width(card_big, 2) <= w - 8 else 1
			T.draw_centered(self, w / 2.0, cy - 20, card_big, card_color, scale, T.SHADOW)
		var yy := cy + 4
		for line in T.wrap(card_small, int(minf(w - 24, 196))):
			T.draw_centered(self, w / 2.0, yy, line, T.WHITE, 1, Color.BLACK)
			yy += T.CELL_H + 3
		if card_tap and int(floor(time * 3.0)) % 2 == 0:
			T.draw(self, Vector2(w - 16, h - 18), ">", T.YELLOW, 1, Color.BLACK)


func _draw_dialogue(w: float, h: float) -> void:
	var box_h := _box_height(w)
	var top := h - S.DIALOGUE_BOTTOM - box_h
	T.retro_box(self, Rect2(3, top, w - 6, box_h), T.YELLOW, T.RED, 0.78)
	var text_x := 8.0
	if portrait:
		draw_texture(portrait, Vector2(8, top + 6))
		text_x = 52.0
	if speaker_name != "":
		T.draw(self, Vector2(text_x, top + 6), speaker_name, name_color, 1, Color.BLACK)
	var ty := top + (18.0 if speaker_name != "" else 8.0)
	for spans: Array in dialogue_spans(w):
		if not spans.is_empty():
			T.draw_spans(self, Vector2(text_x, ty), spans, 1, Color.BLACK)
		ty += T.CELL_H + 3
	if not typing and choices.is_empty() and int(floor(time * 3.0)) % 2 == 0:
		T.draw(self, Vector2(w - 14, top + box_h - 12), ">", T.YELLOW, 1, Color.BLACK)
	# The options, above the box (a row grows for a long label).
	var wrapped := _layout_choices()
	for k in choices.size():
		var c: Dictionary = choices[k]
		var locked := String(c.get("locked", "")) != ""
		var r := choice_rects[k]
		var border := T.YELLOW if k == selected else Color(T.CYAN, 0.6)
		T.retro_box(self, r, Color(0.3, 0.3, 0.36) if locked else border, Color(0.2, 0.2, 0.24) if locked else T.RED, 0.8)
		var ly := r.position.y + 4.0
		for line: String in wrapped[k]:
			T.draw(self, Vector2(r.position.x + 4, ly), line, Color(0.55, 0.55, 0.6) if locked else (T.YELLOW if k == selected else T.WHITE), 1, Color.BLACK)
			ly += T.CELL_H + 3


## The dialogue line as typed so far, one span list per wrapped line: the whole line is wrapped
## once (no reflow while typing) and the period words are amber while typing and after (source
## withOldWords).
func dialogue_spans(w: float = -1.0) -> Array:
	var width := (size.x if w < 0.0 else w) - (52.0 if portrait else 8.0) - 10.0
	var colors := MARKUP.dialogue_colors(full_text, T.WHITE)
	var out: Array = []
	var cursor := 0
	for line in T.wrap(full_text, int(width)):
		var start := full_text.find(line, cursor)
		if start < 0:
			start = cursor
		cursor = start + line.length()
		var visible := clampi(int(shown) - start, 0, line.length())
		out.append(_runs(line.substr(0, visible), colors, start) if visible > 0 else [])
	return out


## Consecutive characters of the same colour as spans [[text, Color], ...].
static func _runs(text: String, colors: Array, offset: int) -> Array:
	var spans: Array = []
	for k in text.length():
		var c: Color = colors[offset + k] if offset + k < colors.size() else Color.WHITE
		if not spans.is_empty() and (spans.back() as Array)[1] == c:
			(spans.back() as Array)[0] += text[k]
		else:
			spans.append([text[k], c])
	return spans


## The option rows' rectangles (filled in choice_rects) and their wrapped lines, from the current
## size and text: the same before the first draw (taps, tests) as on screen.
func _layout_choices() -> Array:
	var w := size.x
	var top := size.y - S.DIALOGUE_BOTTOM - _box_height(w)
	choice_rects.clear()
	var wrapped: Array = []
	var total := 0.0
	for c: Dictionary in choices:
		var locked := String(c.get("locked", "")) != ""
		var label := String(c["label"]) if not locked else "%s (%s)" % [c["label"], c["locked"]]
		var lines := T.wrap(T.sanitize(label), int(w - 24))
		wrapped.append(lines)
		total += maxf(16.0, lines.size() * (T.CELL_H + 3) + 5.0) + 3.0
	var cy := top - 4.0 - total
	for lines: PackedStringArray in wrapped:
		var row_h := maxf(16.0, lines.size() * (T.CELL_H + 3) + 5.0)
		choice_rects.append(Rect2(8, cy, w - 16, row_h))
		cy += row_h + 3.0
	return wrapped
