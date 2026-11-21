class_name GreenZoneHud
extends Control
## The retro neon Green Zone HUD (port of src/ui/hud.ts layout and behaviour) as a native
## custom-draw Control: stats box + half stars, lives + face, HUNGER bar, MENU, radar, SCORE,
## zone name, TIME and Level boxes. Values that change flash white for 0.35 s.

const M := 3.0
const RADAR_R := 17.0
const RADAR_RANGE := 230.0
const T := preload("res://ui/theme/pixel_text.gd")

var catalog: SpriteCatalog
var state: Dictionary = {
	"pees": 0, "poops": 0, "treats": 0, "stars": 5.0, "lives": 2, "hunger": 1.0, "score": 0,
	"time": 0.0, "zone_name": "", "level": 1, "radar": [], "exit": Vector2.ZERO, "poop_warning": -1.0,
}
var menu_enabled := true
var _clock := 0.0
var _flash := {"pees": 0.0, "poops": 0.0, "treats": 0.0, "lives": 0.0, "score": 0.0}
var _last := {"pees": -1, "poops": -1, "treats": -1, "lives": -1, "score": -1}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func layout(view: Vector2i) -> void:
	size = Vector2(view)
	var my := M + 39.0
	InputService.set_button(&"menu", &"menu", Vector2(view.x - M - 16.0, my + 8.0), 16.0, menu_enabled)
	queue_redraw()


func set_menu_enabled(on: bool) -> void:
	menu_enabled = on
	InputService.set_button_enabled(&"menu", on)


func update_state(s: Dictionary, dt: float) -> void:
	_clock += dt
	for k: String in _flash:
		if _last[k] != -1 and _last[k] != s[k]:
			_flash[k] = 0.35
		_last[k] = s[k]
		_flash[k] = maxf(0.0, _flash[k] - dt)
	state = s
	queue_redraw()


func _hot(key: String, color: Color) -> Color:
	var f: float = _flash[key]
	return T.WHITE if f > 0.0 and int(floor(f * 16.0)) % 2 == 0 else color


func _draw() -> void:
	var w := size.x
	var h := size.y
	var s := state
	# Stats box and stars.
	T.retro_box(self, Rect2(M, M, 92, 33))
	T.draw_spans(self, Vector2(M + 4, M + 4), [["PEES: ", T.YELLOW], [str(s["pees"]), _hot("pees", T.CYAN)]], 1, T.SHADOW)
	T.draw_spans(self, Vector2(M + 4, M + 14), [["POOPS: ", T.ORANGE], [str(s["poops"]), _hot("poops", T.CYAN)]], 1, T.SHADOW)
	T.draw_spans(self, Vector2(M + 4, M + 24), [["TREATS: ", T.PINK], [str(s["treats"]), _hot("treats", T.MAGENTA)]], 1, T.SHADOW)
	for k in 5:
		var v := 0 if s["stars"] >= k + 1 else (1 if s["stars"] >= k + 0.5 else 2)
		draw_texture(catalog.texture("star_%d" % v), Vector2(M + 2 + k * 13, M + 37))
	# Lives and face.
	var face_x := w - M - 17
	draw_texture(catalog.texture("dogFace_0"), Vector2(face_x, M))
	T.retro_box(self, Rect2(face_x - 28, M + 1, 26, 13), T.RED, Color("#a01020"), 0.45)
	var lf: float = _flash["lives"]
	if lf <= 0.0 or int(floor(lf * 16.0)) % 2 == 0:
		T.draw(self, Vector2(face_x - 24, M + 4), "%dx" % s["lives"], T.PALE_ROSE)
	# Hunger.
	var hunger_w := minf(88.0, floor(w * 0.42))
	T.draw(self, Vector2(w - M - T.width("HUNGER"), M + 18), "HUNGER", T.YELLOW, 1, T.SHADOW)
	_draw_hunger(Vector2(w - M - hunger_w, M + 28), hunger_w, s["hunger"])
	# Menu.
	var mx := w - M - 14
	var my := M + 39
	var menu_alpha := 0.5 if InputService.is_button_pressed(&"menu") else 1.0
	if menu_enabled:
		for k in 3:
			draw_rect(Rect2(mx, my + k * 3, 14, 1), Color(T.YELLOW, menu_alpha))
		T.draw(self, Vector2(w - M - T.width("MENU"), my + 10), "MENU", Color(T.YELLOW, menu_alpha), 1, T.SHADOW)
	# Bottom boxes.
	var time_y := h - M - 15
	T.retro_box(self, Rect2(M, time_y, 98, 15))
	T.draw_spans(self, Vector2(M + 5, time_y + 4), [["TIME: ", T.GREEN], [ScoringRules.format_time(s["time"]), T.PALE_ROSE]], 1, T.SHADOW)
	var lvl_w := 70.0
	T.retro_box(self, Rect2(w - M - lvl_w, time_y, lvl_w, 15), T.YELLOW, T.RED)
	T.draw_centered(self, w - M - lvl_w / 2.0, time_y + 4, "Level %d" % s["level"], T.HOT_PINK)
	T.draw_spans(self, Vector2(M + 2, time_y - 12), [["SCORE: ", T.CYAN], [ScoringRules.format_score(s["score"]), _hot("score", T.CYAN)]], 1, T.SHADOW)
	var zone: String = s["zone_name"]
	T.draw(self, Vector2(w - M - 1 - T.width(zone), time_y - 12), zone, T.GREEN, 1, T.SHADOW)
	_draw_radar(Vector2(M + RADAR_R + 2, time_y - 16 - RADAR_R), s)


func _draw_hunger(origin: Vector2, bar_w: float, f: float) -> void:
	var inner := bar_w - 2.0
	var px := int(JsMath.round(clampf(f, 0.0, 1.0) * inner))
	var blink := f < 0.25 and int(floor(_clock * 4.0)) % 2 == 0
	draw_rect(Rect2(origin, Vector2(bar_w, 7)), Color(0, 0, 0, 0.4))
	for x in px:
		draw_rect(Rect2(origin + Vector2(1 + x, 1), Vector2(1, 5)), T.hunger_color(x / inner))
	if px > 0:
		draw_rect(Rect2(origin + Vector2(1, 1), Vector2(px, 1)), Color(1, 1, 1, 0.35))
	var border := T.WHITE if blink else T.RED
	draw_rect(Rect2(origin, Vector2(bar_w, 1)), border)
	draw_rect(Rect2(origin + Vector2(0, 6), Vector2(bar_w, 1)), border)
	draw_rect(Rect2(origin, Vector2(1, 7)), border)
	draw_rect(Rect2(origin + Vector2(bar_w - 1, 0), Vector2(1, 7)), border)


func _draw_radar(c: Vector2, s: Dictionary) -> void:
	draw_circle(c, RADAR_R, Color(Color("#2bd12b"), 0.45))
	draw_arc(c, RADAR_R, 0, TAU, 48, Color(T.YELLOW, 0.95), 1.0)
	draw_arc(c, RADAR_R * 0.5, 0, TAU, 32, Color(Color("#9dff7a"), 0.35), 1.0)
	var a := _clock * 2.4
	draw_line(c, c + Vector2(cos(a), sin(a)) * (RADAR_R - 1), Color(Color("#d8ffb0"), 0.5), 1.0)
	var k := RADAR_R / RADAR_RANGE
	for d: Dictionary in s["radar"]:
		if d.get("blink", false) and int(floor(_clock * 6.0)) % 2 == 0:
			continue
		var p: Vector2 = d["d"] * k
		if p.length() > RADAR_R - 2:
			continue
		var sz: int = d.get("size", 2)
		var q := (c + p).round()
		draw_rect(Rect2(q.x - (sz >> 1), q.y - (sz >> 1), sz, sz), d["color"])
	var e: Vector2 = s["exit"] * k
	if e.length() > RADAR_R - 2:
		e = e / e.length() * (RADAR_R - 2)
	if int(floor(_clock * 3.0)) % 3 != 0:
		var q := (c + e).round()
		draw_rect(Rect2(q.x - 1, q.y - 1, 3, 3), Color.WHITE)
	draw_rect(Rect2(c.x - 1, c.y - 1, 2, 2), Color.WHITE)
