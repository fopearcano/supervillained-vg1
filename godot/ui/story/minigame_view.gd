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
	draw_rect(Rect2(0, 0, w, h), Color(0, 0, 0, 0.35))
	T.retro_box(self, Rect2(6, h - 120, w - 12, 100), T.RED, T.YELLOW, 0.6)
	T.draw_centered(self, w / 2.0, 74, String(step.lines.get("title", "")), T.YELLOW, 1, T.SHADOW)
	var result := String(st.get("result", ""))
	if step.game == "boat":
		_draw_boat(w, h, st["game"] as BoatGame)
	else:
		_draw_rhythm(w, h, st["game"] as RhythmGame)
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
