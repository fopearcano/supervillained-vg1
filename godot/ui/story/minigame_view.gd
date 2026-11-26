class_name MiniGameView
extends Control
## Draws the running MiniGameStep (presentation only; port of the drawing in
## src/story/minigames/rhythm.ts and action.ts): a beat game's title, the lane with its hit line and
## box, the cues travelling down to it (each beat's word), the score and the feedback; the boat's two
## bars (distance, water) and its line. Over the stage, beneath the HUD. Every word comes from the
## step's `lines` or ShellText.

const T := preload("res://ui/theme/pixel_text.gd")
const S := GameConfig.Story

var step: MiniGameStep
var st: Dictionary
var ctx: StoryContext


func setup(p_step: MiniGameStep, p_st: Dictionary, p_ctx: StoryContext) -> MiniGameView:
	step = p_step
	st = p_st
	ctx = p_ctx
	name = "MiniGameView"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	return self


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if st.is_empty() or not st.has("game"):
		return
	var w := size.x
	var h := size.y
	var result := String(st.get("result", ""))
	if step.game == "ladders":
		_draw_ladders(w, h, st["game"] as LaddersGame)
		_draw_result(w, h, result)
		return
	if step.game == "letter":
		_draw_letter(w, h, st["game"] as LetterGame)
		_draw_result(w, h, result)
		return
	if step.game == "rumour":
		_draw_rumour(w, h, st["game"] as RumourGame)
		_draw_result(w, h, result)
		return
	if step.game == "tug":
		_draw_tug(w, h, st["game"] as TugGame)
		_draw_result(w, h, result)
		return
	draw_rect(Rect2(0, 0, w, h), Color(0, 0, 0, 0.35))
	T.retro_box(self, Rect2(6, h - 120, w - 12, 100), T.RED, T.YELLOW, 0.6)
	T.draw_centered(self, w / 2.0, 74, String(step.lines.get("title", "")), T.YELLOW, 1, T.SHADOW)
	if step.game == "boat":
		_draw_boat(w, h, st["game"] as BoatGame)
	else:
		_draw_rhythm(w, h, st["game"] as RhythmGame)
	_draw_result(w, h, result)


func _draw_result(w: float, h: float, result: String) -> void:
	if result != "":
		var line := String(step.lines.get(result, ""))
		if line == "":
			line = ctx.ui_text("story_mini_won" if result == "won" else "story_mini_lost")
		T.draw_centered(self, w / 2.0, h - 150, line, T.GREEN if result == "won" else T.ORANGE, 1, T.SHADOW)


func _draw_rhythm(w: float, h: float, g: RhythmGame) -> void:
	var line_y := h - 70.0
	draw_rect(Rect2(10, line_y - 1, w - 20, 2), T.YELLOW)
	var near: Array = g.nearest()
	var pulse := 3.0 if absf(float(near[1])) < 0.08 else 0.0
	draw_rect(Rect2(w / 2.0 - 12 - pulse, line_y - 12 - pulse, 24 + pulse * 2, 24 + pulse * 2), T.RED, false, 1.0)
	var cue := String(step.lines.get("cue", ""))
	for k in g.beats:
		if g.judged.has(k):
			continue
		var y := line_y - (g.beat_at(k) - g.time) * S.RHYTHM_CUE_SPEED
		if y > 90.0 and y < h:
			T.draw_centered(self, w / 2.0, roundf(y) - 4, cue, T.WHITE, 1, T.SHADOW)
	T.draw_centered(self, w / 2.0, h - 114, ctx.ui_text("story_mini_score") % [g.hits, g.beats], T.YELLOW, 1, T.SHADOW)
	var fb := ""
	if g.feedback_t > 0.0:
		match g.feedback:
			"hit":
				fb = String(step.lines.get("hit", ""))
			"miss":
				fb = String(step.lines.get("miss", ""))
			"early":
				fb = ctx.ui_text("story_mini_too_early")
	T.draw_centered(self, w / 2.0, h - 140, fb, T.WHITE, 1, T.SHADOW)
	T.draw(self, Vector2(roundf(w * 0.28) - 30, h - 44), ctx.ui_text("story_mini_on_beat"), T.CYAN, 1, T.SHADOW)


func _draw_boat(w: float, h: float, b: BoatGame) -> void:
	var bw := w - 60.0
	for row: Array in [[h - 118.0, b.progress, Color("#5ac8ff"), "story_boat_distance"], [h - 100.0, b.water, Color("#2a6aff"), "story_boat_water"]]:
		var y: float = row[0]
		draw_rect(Rect2(30, y, bw, 8), Color(0, 0, 0, 0.6))
		draw_rect(Rect2(31, y + 1, roundf((bw - 2) * clampf(float(row[1]), 0.0, 1.0)), 6), row[2])
		draw_rect(Rect2(30, y, bw, 8), T.YELLOW, false, 1.0)
		T.draw(self, Vector2(30, y + 10), ctx.ui_text(String(row[3])), T.CYAN, 1, T.SHADOW)
	var label := String(step.lines.get("objective", ""))
	if b.swamped_t > 0.0:
		label = ctx.ui_text("story_boat_swamped")
	elif b.progress > 0.75:
		label = ctx.ui_text("story_boat_almost")
	for k in T.wrap(label, int(w - 20)).size():
		T.draw_centered(self, w / 2.0, h - 150 + k * 10, T.wrap(label, int(w - 20))[k], T.CYAN, 1, T.SHADOW)


## The ladder: the wall (stone courses), its parapet near the top, three ladders, the stones (a red
## warning first), and Zampanò climbing in his costume's authored walk frames (north), one walk cycle
## per LADDER_RUNGS_PER_CYCLE rungs; blinking while hit.
func _draw_ladders(w: float, h: float, g: LaddersGame) -> void:
	var lane_x := func(l: int) -> float: return roundf(w * (0.25 + l * 0.25))
	draw_rect(Rect2(0, 0, w, h), Color("#4b3630"))
	var scroll := maxf(0.0, g.rung - 6.0) * S.LADDER_RUNG_PX
	var off := fmod(scroll, 10.0)
	for row in range(-2, int(h / 10.0) + 2):
		var y := roundf(row * 10 + off)
		var shift := 10.0 if (row - int(scroll / 10.0)) % 2 != 0 else 0.0
		var x := -shift
		while x < w:
			draw_rect(Rect2(x, y, 19, 9), Color("#8a7660"))
			draw_rect(Rect2(x + 1, y, 17, 1), Color("#c8ad88"))
			x += 20.0
	var top := g.rung_y(g.rungs)
	if top > -10.0:
		draw_rect(Rect2(0, top - 30, w, 26), Color("#8a7660"))
		draw_rect(Rect2(0, top - 30, w, 2), Color("#c8ad88"))
	for l in 3:
		var x: float = lane_x.call(l)
		draw_rect(Rect2(x - 10, maxf(top - 6, 0), 2, h), Color("#5a3a1c"))
		draw_rect(Rect2(x + 8, maxf(top - 6, 0), 2, h), Color("#5a3a1c"))
		for r in g.rungs + 1:
			var y := g.rung_y(r)
			if y > -5.0 and y < h + 5.0:
				draw_rect(Rect2(x - 10, y, 20, 2), Color("#7a5430"))
	for f: Dictionary in g.falling:
		var x: float = lane_x.call(int(f["lane"]))
		if float(f["warn"]) > 0.0:
			if int(floor(float(f["warn"]) * 10.0)) % 2 == 1:
				draw_rect(Rect2(x - 6, 2, 12, 3), Color("#ff3030"))
			continue
		draw_circle(Vector2(x, float(f["y"])), 6.0, Color("#9a9a9a"))
	var tex := hero_frame(g)
	if tex and not (g.hit_t > 0.0 and int(floor(g.hit_t * 12.0)) % 2 == 1):
		var at := Vector2(lane_x.call(g.lane), g.hero_y())
		draw_texture(tex, at - Vector2(tex.get_width() * 0.5, tex.get_height() * 0.9))
	draw_rect(Rect2(4, h - 32, w - 8, 22), T.YELLOW, false, 1.0)
	T.draw_centered(self, w / 2.0, h - 27, "%d/%d" % [mini(g.rungs, int(floor(g.rung))), g.rungs], T.WHITE, 1, T.SHADOW)
	T.draw_centered(self, w / 2.0, h - 18, String(step.lines.get("help", "")), T.WHITE, 1, T.SHADOW)
	T.draw_centered(self, w / 2.0, 40, String(step.lines.get("title", "")), T.YELLOW, 1, T.SHADOW)


## The hero's frame: the player's own SpriteFrames (his costume, his profile), "walk_n", frame
## floor(rung × frames / LADDER_RUNGS_PER_CYCLE) mod frames (the source's cycleFrame).
func hero_frame(g: LaddersGame) -> Texture2D:
	var dog := ctx.player if ctx.scene.world else null
	if dog == null:
		return null
	var frames: SpriteFrames = dog.body_sprite.sprite_frames
	if not frames.has_animation(&"walk_n"):
		return null
	var n := frames.get_frame_count(&"walk_n")
	return frames.get_frame_texture(&"walk_n", int(floor(g.rung * n / S.LADDER_RUNGS_PER_CYCLE)) % n)


## The letter: the parchment with the assembled account (or, after sending, the two accounts of the
## reply), and the buttons of the current phase.
func _draw_letter(w: float, h: float, g: LetterGame) -> void:
	draw_rect(Rect2(0, 0, w, h), Color("#1a0e06"))
	T.draw_centered(self, w / 2.0, 56, String(step.lines.get("title", "")), T.YELLOW, 1, T.SHADOW)
	draw_rect(Rect2(8, 76, w - 16, 116), Color("#f0dcb0"))
	var y := 84.0
	for line in T.wrap(g.letter(), int(w - 32)):
		T.draw(self, Vector2(16, y), line, Color("#3a2410"))
		y += T.CELL_H + 4
	if g.phase == "answer":
		var ay := 200.0
		for line in T.wrap(String(step.lines.get("answer", "")), int(w - 32)):
			T.draw(self, Vector2(16, ay), line, Color("#ff9a6a"), 1, T.SHADOW)
			ay += T.CELL_H + 4
	for b: Dictionary in g.layout(w):
		var r: Rect2 = b["rect"]
		draw_rect(r, Color(0, 0, 0, 0.65))
		draw_rect(r, T.RED, false, 1.0)
		var id := String(b["id"])
		var label := ""
		if id.begins_with("slot"):
			var k := int(id.substr(4))
			label = "< %s >" % String((g.slots[k]["options"] as Array)[g.picks[k]])
		else:
			label = String(step.lines.get(id, ""))
		T.draw_centered(self, r.get_center().x, r.position.y + 4, label, T.CYAN if id.begins_with("slot") else T.YELLOW, 1, T.SHADOW)


## The garbled news: the account so far (the placed pieces, numbered, in full) on the parchment, and
## the arrived pieces still to place as garbled buttons.
func _draw_rumour(w: float, h: float, g: RumourGame) -> void:
	draw_rect(Rect2(0, 0, w, h), Color("#0e1420"))
	T.draw_centered(self, w / 2.0, 64, String(step.lines.get("title", "")), T.YELLOW, 1, T.SHADOW)
	draw_rect(Rect2(8, 76, w - 16, 136), Color("#f0dcb0"))
	var y := 84.0
	if g.placed.is_empty():
		for line in T.wrap(String(step.lines.get("start", "")), int(w - 32)):
			T.draw(self, Vector2(16, y), line, Color("#3a2410"))
			y += T.CELL_H + 4
	for n in g.placed.size():
		for line in T.wrap("%d. %s" % [n + 1, String((g.pieces[g.placed[n]] as Dictionary)["text"])], int(w - 32)):
			T.draw(self, Vector2(16, y), line, Color("#3a2410"))
			y += T.CELL_H + 3
	for b: Dictionary in g.layout(w):
		var r: Rect2 = b["rect"]
		draw_rect(r, Color(0, 0, 0, 0.6))
		draw_rect(r, T.RED, false, 1.0)
		T.draw_centered(self, r.get_center().x, r.position.y + 4, String((g.pieces[int(b["id"])] as Dictionary)["garble"]), T.CYAN, 1, T.SHADOW)


## The tug: the dark band, the friend pulled toward the hole (or the boat pushed back), Zampano behind
## him holding on, the rope's red bar; run frames (east) by time.
func _draw_tug(w: float, h: float, g: TugGame) -> void:
	draw_rect(Rect2(0, h * 0.5 - 40, w, 80), Color(0, 0, 0, 0.5))
	var hole_x := w - 20.0
	draw_rect(Rect2(hole_x - 6, h * 0.5 - 30, 26, 50), Color("#0a0606"))
	var fx := roundf(w * 0.5 + g.pos * (hole_x - w * 0.5 - 10))
	var friend := _frames(String(step.params.get("friend", "")))
	if friend and friend.has_animation(&"run_e"):
		var ft := friend.get_frame_texture(&"run_e", int(floor(g.time * 10.0)) % friend.get_frame_count(&"run_e"))
		draw_texture(ft, Vector2(fx, h * 0.5 + 10) - Vector2(ft.get_width() * 0.5, ft.get_height() * 0.9))
	var hero: SpriteFrames = ctx.player.body_sprite.sprite_frames if ctx.scene.world else null
	if hero and hero.has_animation(&"run_e"):
		var ht := hero.get_frame_texture(&"run_e", int(floor(g.time * 10.0)) % hero.get_frame_count(&"run_e"))
		draw_texture(ht, Vector2(fx - 34, h * 0.5 + 12) - Vector2(ht.get_width() * 0.5, ht.get_height() * 0.9))
	draw_rect(Rect2(fx - 30, h * 0.5 + 2, 24, 2), Color("#d8c8a0"))
	var bw := w - 40.0
	draw_rect(Rect2(20, h * 0.5 + 40, bw, 6), Color("#220808"))
	draw_rect(Rect2(20, h * 0.5 + 41, roundf(bw * maxf(0.0, g.pos)), 4), Color("#ff3030"))
	draw_rect(Rect2(20, h * 0.5 + 40, bw, 6), T.YELLOW, false, 1.0)
	T.draw_centered(self, w / 2.0, roundf(h * 0.5 - 56), String(step.lines.get("help", "")), T.YELLOW, 1, T.SHADOW)
	T.draw_centered(self, w / 2.0, 64, String(step.lines.get("title", "")), T.YELLOW, 1, T.SHADOW)


## A cast role's frames, kept for the view's life: a texture loaded inside _draw() alone would be
## freed before the frame is rendered (it drew as a white box).
var _frames_cache := {}


func _frames(role: String) -> SpriteFrames:
	if not _frames_cache.has(role):
		var path := StoryCast.frames_path(role)
		_frames_cache[role] = load(path) if path != "" else null
	return _frames_cache[role]
