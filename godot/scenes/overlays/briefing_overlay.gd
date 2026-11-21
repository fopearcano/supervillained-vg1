class_name BriefingOverlay
extends OverlayPanel
## The Green Zone briefing (src/scenes/overlays.ts BriefingScene): the five rules in their colours,
## at 2× when they fit, then TAP TO START / PRESS SPACE. Starts on a tap or confirm after 0.5 s.

signal go

const BRIEFING := [
	["MAKE A WALK.", PixelText.ORANGE],
	["COLLECT ENOUGH TREATS TO COMPENSATE THE HUNGER.", PixelText.GREEN],
	["PEE ENOUGH TO COMPENSATE THE POOPS AS TOO MANY POOPS CAN ENDANGER THE ENVIRONMENT OF THE ZONE YOU ARE PLAYING IN.", PixelText.RED],
	["CATS MEAN MONEY.", PixelText.CYAN],
	["DON'T GET DISTRACTED BY THE BALLS.", PixelText.YELLOW],
]

var touch := DisplayServer.is_touchscreen_available()
var _started := false


func _ready() -> void:
	super._ready()
	dim = 0.42


func _process(delta: float) -> void:
	super._process(delta)
	if not _started and time > 0.5 and InputService.consume(&"confirm"):
		_start()


func on_tap(_pos: Vector2) -> void:
	if time > 0.5:
		_start()


func _start() -> void:
	if _started:
		return
	_started = true
	go.emit()


func _layout_lines(scale: int, max_w: int) -> Array:
	var out: Array = []
	for para: Array in BRIEFING:
		for line in T.wrap(para[0], max_w, scale):
			out.append([line, para[1]])
	return out


func draw_content() -> void:
	var w := size.x
	var h := size.y
	var top := 58.0
	var bottom := h - 64.0
	var max_w := int(w - 16)
	var scale := 2
	var gap := 2
	var lines := _layout_lines(scale, max_w)
	var text_h := lines.size() * (8 * scale + gap)
	if text_h > bottom - top - 26:
		scale = 1
		gap = 5
		lines = _layout_lines(scale, max_w)
		text_h = lines.size() * (8 * scale + gap)
	var y := floorf(top + maxf(0.0, (bottom - top - 26 - text_h) / 2.0))
	for l: Array in lines:
		T.draw_centered(self, w / 2.0, y, l[0], l[1], scale, T.SHADOW)
		y += 8 * scale + gap
	if int(floor(time * 2.5)) % 2 == 0:
		T.draw_centered(self, w / 2.0, y + 12, "TAP TO START" if touch else "PRESS SPACE", T.WHITE, 1, Color.BLACK)
	var hint := "LEFT THUMB: MOVE\nBUTTONS: PEE / BARK / RUN" if touch else "WASD MOVE  SHIFT RUN\nSPACE PEE  J BARK  ESC MENU"
	if y + 24 + 20 < bottom + 20:
		T.draw_centered(self, w / 2.0, y + 24, hint, Color("#c8d0ff"), 1, Color.BLACK)
