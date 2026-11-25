class_name StoryMarkup
extends Resource
## Colour markup of story text (port of src/story/names.ts): the names of the cast and of history
## are yellow in the story's cards (scene cards, the Professor's aside), and the period words the
## dream's characters speak are amber in the dialogue box, while typing and after. The lists are
## data (data/story/markup.tres, copied from the source's NAMES and OLD_WORDS).

@export var names: PackedStringArray = []
@export var old_words: PackedStringArray = []
@export var name_color := Color("#ffe23a")
@export var old_word_color := Color("#ffb45a")


static func _letter(ch: String) -> bool:
	return ch != "" and ((ch >= "A" and ch <= "Z") or (ch >= "0" and ch <= "9") or ch == "'")


## [start, end) of every period word in `text`, in order, never overlapping (longest first).
func old_word_ranges(text: String) -> Array:
	var found: Array = []
	var words := Array(old_words)
	words.sort_custom(func(a: String, b: String) -> bool: return a.length() > b.length())
	for w: String in words:
		var at := text.find(w)
		while at >= 0:
			var end := at + w.length()
			var before := text.substr(at - 1, 1) if at > 0 else ""
			var after := text.substr(end, 1) if end < text.length() else ""
			var clash := found.any(func(r: Array) -> bool: return at < int(r[1]) and end > int(r[0]))
			if not _letter(before) and not _letter(after) and not clash:
				found.append([at, end])
			at = text.find(w, at + 1)
	found.sort_custom(func(a: Array, b: Array) -> bool: return int(a[0]) < int(b[0]))
	return found


## One colour per character: `base`, with the period words in old_word_color.
func dialogue_colors(text: String, base: Color) -> Array:
	var out: Array = []
	out.resize(text.length())
	out.fill(base)
	for r: Array in old_word_ranges(text):
		for k in range(int(r[0]), int(r[1])):
			out[k] = old_word_color
	return out


## The text as spans [[text, Color], ...] with the names (whole words; a possessive counts) in
## name_color (source withNames).
func name_spans(text: String, base: Color) -> Array:
	var spans: Array = []
	var word := RegEx.create_from_string("[A-Z][A-Z'-]*")
	var at := 0
	for m in word.search_all(text):
		if m.get_start() > at:
			_push(spans, text.substr(at, m.get_start() - at), base)
		var part := m.get_string()
		var bare := part.trim_suffix("'S").trim_suffix("'")
		_push(spans, part, name_color if names.has(bare) else base)
		at = m.get_end()
	if at < text.length():
		_push(spans, text.substr(at), base)
	return spans


static func _push(spans: Array, t: String, c: Color) -> void:
	if not spans.is_empty() and (spans.back() as Array)[1] == c:
		(spans.back() as Array)[0] += t
	else:
		spans.append([t, c])
