class_name MessageOverlay
extends OverlayPanel
## A card of text with optional buttons: the Goodbye card (source GoodbyeScene: tap, confirm or
## Back returns), the one-time save-migration notice (source showNotice), save-recovery notices,
## and this build's honest boundary where a story scene would start (M5).

var heading := ""
var heading_color := T.YELLOW
## [[text, Color], ...]
var paragraphs: Array = []
## With no buttons, a tap, confirm or Back after 0.5 s calls this.
var dismiss: Callable = Callable()
## Story cards: the names in yellow (StoryMarkup; null = plain paragraphs).
var markup: StoryMarkup = null


func setup(p_heading: String, p_paragraphs: Array, buttons: Array = [], p_dismiss: Callable = Callable(), p_dim: float = 0.88) -> MessageOverlay:
	heading = p_heading
	paragraphs = p_paragraphs
	items = buttons
	dismiss = p_dismiss
	dim = p_dim
	if not buttons.is_empty():
		back_action = (buttons[buttons.size() - 1] as Dictionary)["action"]
	elif dismiss.is_valid():
		back_action = dismiss
	return self


func _ready() -> void:
	var keep_dim := dim
	super._ready()
	dim = keep_dim
	menu_item_width = 150.0
	menu_item_height = 18.0
	menu_gap = 6.0


func _process(delta: float) -> void:
	super._process(delta)
	if is_top() and items.is_empty() and dismiss.is_valid() and time > 0.5 and InputService.consume(&"confirm"):
		_dismiss()


func on_tap(_pos: Vector2) -> void:
	if items.is_empty() and dismiss.is_valid() and time > 0.5:
		_dismiss()


func _dismiss() -> void:
	var d := dismiss
	dismiss = Callable()
	d.call()


func draw_content() -> void:
	var w := size.x
	var lines: Array = []
	for p: Array in paragraphs:
		for l in T.wrap(String(p[0]), int(minf(w - 24, 196))):
			lines.append([l, p[1]])
		lines.append(["", T.WHITE])
	var block := 16 + lines.size() * 11
	var y := floorf(maxf(16.0, size.y * 0.42 - block / 2.0))
	T.draw_centered(self, w / 2.0, y, heading, heading_color, 1, T.SHADOW)
	y += 18
	for l: Array in lines:
		if String(l[0]) != "" and markup:
			var spans := markup.name_spans(String(l[0]), l[1])
			T.draw_spans(self, Vector2(roundf(w / 2.0 - T.width(String(l[0])) / 2.0), y), spans, 1, Color.BLACK)
		elif String(l[0]) != "":
			T.draw_centered(self, w / 2.0, y, l[0], l[1], 1, Color.BLACK)
		y += 11
	menu_top = y + 6
