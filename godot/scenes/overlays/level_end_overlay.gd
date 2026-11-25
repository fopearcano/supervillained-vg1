class_name LevelEndOverlay
extends OverlayPanel
## "GOOD BOY!" result card, with the source geometry and reveal timing of src/scenes/overlays.ts
## LevelEndScene: one centred box, rows appearing every 0.15 s, stars popping in from 1.2 s every
## 0.35 s (3× → 2×), then the bonuses, the total, NEW BEST and the menu; a tap/confirm skips the
## reveal. When the walk is played as the story's 1.0 (`result["has_next"]`) the menu is CONTINUE
## (the campaign handoff) and RETRY, otherwise RETRY and TITLE (the title arrives with M4; until
## then TITLE returns to the briefing). Each revealed full or half star plays 'star', its rate
## rising 0.12 per star (source Flow.levelComplete onStar).

signal continue_requested
signal retry_requested
signal title_requested

const STAR_START := 1.2
const STAR_STEP := 0.35

var result: Dictionary = {}
var catalog: SpriteCatalog
var skip := false
var _stars_shown := 0
var _star_scale: Array[float] = [2.0, 2.0, 2.0, 2.0, 2.0]


func _ready() -> void:
	super._ready()
	dim = 0.6
	menu_item_width = 120.0
	menu_item_height = 16.0
	menu_gap = 5.0
	items = []
	if result.get("has_next", false):
		items.append({"label": String(result.get("next_label", "CONTINUE")), "color": T.GREEN, "action": func() -> void: continue_requested.emit()})
	items.append({"label": "RETRY", "color": T.YELLOW, "action": func() -> void: retry_requested.emit()})
	if not result.get("has_next", false):
		items.append({"label": "TITLE", "color": T.PINK, "action": func() -> void: title_requested.emit()})


func _reveal_time() -> float:
	return 99.0 if skip else time


func menu_visible() -> bool:
	return _reveal_time() > STAR_START + 5 * STAR_STEP + 0.6


func _process(delta: float) -> void:
	var t := _reveal_time()
	var want := mini(5, maxi(0, int(floor((t - STAR_START) / STAR_STEP)) + 1))
	while _stars_shown < want:
		var k := _stars_shown
		_stars_shown += 1
		_star_scale[k] = 2.0 if _star_variant(k) == 2 else 3.0
		if _star_variant(k) != 2:
			AudioService.play(&"star", 1.0, 1.0 + k * 0.12)
	for k in 5:
		if _star_scale[k] > 2.0:
			_star_scale[k] = maxf(2.0, _star_scale[k] - delta * 8.0)
	if not menu_visible():
		time += delta
		if InputService.consume(&"confirm"):
			skip = true
		queue_redraw()
		return
	super._process(delta)


func on_tap(_pos: Vector2) -> void:
	skip = true


func _star_variant(k: int) -> int:
	var s: float = result["stars"]
	return 0 if s >= k + 1 else (1 if s >= k + 0.5 else 2)


func draw_content() -> void:
	var w := size.x
	var h := size.y
	var r := result
	var st: Dictionary = r["stats"]
	var t := _reveal_time()
	var bw := minf(w - 8, 196)
	var bh := 222 + (2 * menu_item_height + menu_gap) + 9
	var top := maxf(4, JsMath.round(h / 2.0 - bh / 2.0))
	var left := JsMath.round(w / 2.0 - bw / 2.0)
	T.retro_box(self, Rect2(left, top, bw, bh), T.YELLOW, T.RED, 0.65)
	T.draw_centered(self, w / 2.0, top + 16, "GOOD BOY!", T.YELLOW, 2, T.SHADOW)
	T.draw_centered(self, w / 2.0, top + 34, "LEVEL %d COMPLETE" % r["level"], T.CYAN, 1, T.SHADOW)
	var tx := JsMath.round(w / 2.0 - 23 * 8 / 2.0)
	var rows := [
		["TIME", ScoringRules.format_time(st["time"]), T.GREEN],
		["TREATS", str(st["treats"]), T.PINK],
		["PEES / POOPS", "%d / %d" % [st["pees"], st["poops"]], T.YELLOW],
		["COINS", "%d  (%d)" % [st["coins"], r["coins_total"]], T.ORANGE],
		["ZONE HEALTH", "%d%%" % int(JsMath.round(r["health"] * 100.0)), T.GREEN],
	]
	for k in rows.size():
		if t > 0.3 + k * 0.15:
			var row: Array = rows[k]
			T.draw_spans(self, Vector2(tx, top + 48 + k * 13), [[String(row[0]).rpad(14), row[2]], [String(row[1]).lpad(9), T.WHITE]], 1, Color.BLACK)
	for k in 5:
		var v := _star_variant(k) if k < _stars_shown else 2
		var tex := catalog.texture("star_%d" % v)
		var sc := _star_scale[k]
		var pos := Vector2(JsMath.round(w / 2.0 + (k - 2) * 26), top + 130)
		draw_texture_rect(tex, Rect2(pos, Vector2(tex.get_width(), tex.get_height()) * sc), false)
	var after := STAR_START + 5 * STAR_STEP
	if t > after:
		T.draw_spans(self, Vector2(tx, top + 156), [["TIME BONUS".rpad(14), T.CYAN], [("+%d" % r["time_bonus"]).lpad(9), T.WHITE]], 1, Color.BLACK)
		T.draw_spans(self, Vector2(tx, top + 168), [["STAR BONUS".rpad(14), T.CYAN], [("+%d" % r["star_bonus"]).lpad(9), T.WHITE]], 1, Color.BLACK)
	if t > after + 0.3:
		T.draw_spans(self, Vector2(tx, top + 186), [["SCORE".rpad(14), T.YELLOW], [ScoringRules.format_score(r["total"]).lpad(9), T.YELLOW]], 1, Color.BLACK)
	if r.get("replay", false) and t > after + 0.5:
		T.draw_centered(self, w / 2.0, top + 206, "REPLAY: NOTHING SAVED", T.CYAN, 1, T.SHADOW)
	elif not r.get("record_saved", true) and t > after + 0.5:
		# The record could not be written (blocked or failed save): say so instead of NEW BEST.
		T.draw_centered(self, w / 2.0, top + 206, "RECORD NOT SAVED", T.RED, 1, T.SHADOW)
	elif r["new_best"] and t > after + 0.5 and int(floor(time * 3.0)) % 2 == 0:
		T.draw_centered(self, w / 2.0, top + 206, "NEW BEST!", T.GREEN, 1, T.SHADOW)
	menu_top = top + 222
	menu_hidden = not menu_visible()
