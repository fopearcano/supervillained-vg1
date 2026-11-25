class_name CutOffRule
extends ObjectiveRule
## 1.3: on the way home Jack cuts Zampanò off at the next opening on the direct path
## (`rule_params.gap`): he is pushed back, Jack jumps into the gap (`block_point`) with
## `rule_lines.cut`, and the first time a notice says the hedge is always open
## (`rule_lines.notice`). From the lower lane (south of `lane_y`) he hears Jack telling the same
## joke on the other side, every `joke_every` seconds (`rule_lines.jokes`). The direct path stays
## denied in reality until 8.3 (RD-08).

const S := GameConfig.Story


func begin(_ctx: StoryContext, _step: ObjectiveStep, st: Dictionary) -> void:
	st["cuts"] = 0
	st["cool"] = 0.0
	st["joke_t"] = 0.0
	st["joke"] = 0


func tick(ctx: StoryContext, step: ObjectiveStep, st: Dictionary, dt: float) -> bool:
	var p := step.rule_params
	st["cool"] = maxf(0.0, float(st["cool"]) - dt)
	if keep_out(ctx, p["gap"]) and float(st["cool"]) <= 0.0:
		st["cool"] = S.BUMP_EVERY
		var block: Vector2 = p["block_point"]
		var jack := ctx.actor(String(p["blocker"]))
		if jack:
			jack.set_grid_position(block.x, block.y)
			jack.play_action("bark", 0.4)
		ctx.say_float(String(step.rule_lines["cut"]), block, JACK_COLOR)
		if int(st["cuts"]) == 0:
			ctx.notice(String(step.rule_lines["notice"]), PixelText.ORANGE)
		st["cuts"] = int(st["cuts"]) + 1
		ctx.metrics["cuts"] = st["cuts"]
	if ctx.player.gy > float(p["lane_y"]):
		st["joke_t"] = float(st["joke_t"]) - dt
		if float(st["joke_t"]) <= 0.0:
			st["joke_t"] = float(p["joke_every"])
			var jokes: Array = step.rule_lines["jokes"]
			ctx.say_float(String(jokes[int(st["joke"]) % jokes.size()]), Vector2(ctx.player.gx - 0.5, float(p["joke_y"])), JACK_COLOR)
			st["joke"] = int(st["joke"]) + 1
	return false
