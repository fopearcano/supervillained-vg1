class_name GreenZoneHud
extends Control
## Compact prototype HUD: body counters, hunger, digestion, Green Zone health and score.

const M := 3.0
const T := preload("res://ui/theme/pixel_text.gd")

var state := {
	"pees": 0,
	"poops": 0,
	"treats": 0,
	"hunger": 1.0,
	"digestion": 0.0,
	"poop_warning": -1.0,
	"health": 1.0,
	"score": 0,
}
var menu_enabled := true
var _clock := 0.0
var _flash := {"pees": 0.0, "poops": 0.0, "treats": 0.0, "score": 0.0}
var _last := {"pees": -1, "poops": -1, "treats": -1, "score": -1}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func layout(view: Vector2i) -> void:
	size = Vector2(view)
	var menu_y := M + 36.0
	InputService.set_button(&"menu", &"menu", Vector2(view.x - M - 15.0, menu_y + 8.0), 16.0, menu_enabled)
	queue_redraw()


func set_menu_enabled(on: bool) -> void:
	menu_enabled = on
	InputService.set_button_enabled(&"menu", on)


func update_state(next: Dictionary, dt: float) -> void:
	_clock += dt
	for key: String in _flash:
		if _last[key] != -1 and _last[key] != next[key]:
			_flash[key] = 0.35
		_last[key] = next[key]
		_flash[key] = maxf(0.0, _flash[key] - dt)
	state = next
	queue_redraw()


func _hot(key: String, color: Color) -> Color:
	var flash: float = _flash[key]
	return T.WHITE if flash > 0.0 and int(floor(flash * 16.0)) % 2 == 0 else color


func _draw() -> void:
	var width := size.x
	var s := state
	T.retro_box(self, Rect2(M, M, 92, 33))
	T.draw_spans(self, Vector2(M + 4, M + 4), [["PEES: ", T.YELLOW], [str(s["pees"]), _hot("pees", T.CYAN)]], 1, T.SHADOW)
	T.draw_spans(self, Vector2(M + 4, M + 14), [["POOPS: ", T.ORANGE], [str(s["poops"]), _hot("poops", T.CYAN)]], 1, T.SHADOW)
	T.draw_spans(self, Vector2(M + 4, M + 24), [["TREATS: ", T.PINK], [str(s["treats"]), _hot("treats", T.MAGENTA)]], 1, T.SHADOW)

	var bar_width := minf(82.0, floor(width * 0.40))
	var right := width - M
	T.draw(self, Vector2(right - T.width("HUNGER"), M + 1), "HUNGER", T.YELLOW, 1, T.SHADOW)
	_draw_bar(Vector2(right - bar_width, M + 12), bar_width, s["hunger"], T.RED, T.GREEN)

	var menu_x := right - 14.0
	var menu_y := M + 36.0
	var menu_alpha := 0.5 if InputService.is_button_pressed(&"menu") else 1.0
	if menu_enabled:
		for k in 3:
			draw_rect(Rect2(menu_x, menu_y + k * 3, 14, 1), Color(T.YELLOW, menu_alpha))
		T.draw(self, Vector2(right - T.width("MENU"), menu_y + 10), "MENU", Color(T.YELLOW, menu_alpha), 1, T.SHADOW)

	var status_y := 53.0
	T.draw(self, Vector2(M, status_y), "DIGEST", T.ORANGE, 1, T.SHADOW)
	_draw_bar(Vector2(M, status_y + 11), 78.0, s["digestion"], T.ORANGE, T.PINK)
	T.draw(self, Vector2(right - T.width("CLEAN"), status_y), "CLEAN", T.GREEN, 1, T.SHADOW)
	_draw_bar(Vector2(right - 78.0, status_y + 11), 78.0, s["health"], T.RED, T.GREEN)

	var score_text := "SCORE %s" % ScoringRules.format_score(s["score"])
	T.draw_centered(self, width / 2.0, status_y + 24.0, score_text, _hot("score", T.CYAN), 1, T.SHADOW)
	var warning: float = s["poop_warning"]
	if warning >= 0.0:
		var text := "POOP NOW!" if warning <= 0.0 else "POOP IN %.1f" % warning
		var color := T.WHITE if int(floor(_clock * 6.0)) % 2 == 0 else T.ORANGE
		T.draw_centered(self, width / 2.0, status_y + 36.0, text, color, 1, T.SHADOW)


func _draw_bar(origin: Vector2, width: float, fraction: float, low: Color, high: Color) -> void:
	var inner := width - 2.0
	var amount := clampf(fraction, 0.0, 1.0)
	var pixels := int(JsMath.round(amount * inner))
	draw_rect(Rect2(origin, Vector2(width, 7)), Color(0, 0, 0, 0.55))
	if pixels > 0:
		draw_rect(Rect2(origin + Vector2.ONE, Vector2(pixels, 5)), low.lerp(high, amount))
		draw_rect(Rect2(origin + Vector2.ONE, Vector2(pixels, 1)), Color(1, 1, 1, 0.35))
	draw_rect(Rect2(origin, Vector2(width, 1)), T.WHITE)
	draw_rect(Rect2(origin + Vector2(0, 6), Vector2(width, 1)), T.WHITE)
	draw_rect(Rect2(origin, Vector2(1, 7)), T.WHITE)
	draw_rect(Rect2(origin + Vector2(width - 1, 0), Vector2(1, 7)), T.WHITE)
