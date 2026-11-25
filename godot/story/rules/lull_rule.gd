class_name LullRule
extends ObjectiveRule
## Acting in a lull (port of src/campaign/chapters/helpers.ts lullWalk; 2.2 the preacher, 3.3 the
## square): a voice (`source`, an actor) talks, then pauses. Only what he does in a pause, standing
## within `range` of `stand`, is heard; one act counts per pause; `need` acts complete the walk.
## Talk and quiet lengths are drawn from the scene's seeded generator (ctx.rng), so a run and its
## restart are the same. Per heard act: `good_effects` are applied, the `responders` group of that
## count turns to him, says `response` and steps aside by `responder_shift`, and `good_notices`
## shows its line; from the first act the `spread` actors answer with `spread` lines (one every
## half second, in turn). Every line is in rule_lines: noise (the voice's phrases), noise_label,
## drowned (acting under the noise), act_text (said with each act).

const S := GameConfig.Story
const NOISE_COLOR := Color("#ff9a1f")
const RESPONSE_COLOR := Color("#ffe23a")
const SPREAD_COLOR := Color("#3ff0ff")


func begin(ctx: StoryContext, step: ObjectiveStep, st: Dictionary) -> void:
	st["talking"] = true
	st["phase_t"] = _draw(ctx, S.LULL_TALK) * 0.6
	st["phrase_t"] = 0.0
	st["phrase_k"] = 0
	st["good"] = 0
	st["used"] = false
	st["spread_t"] = 0.0
	st["spread_k"] = 0
	_hud(ctx, step, st)


static func _draw(ctx: StoryContext, r: Array) -> float:
	return float(r[0]) + ctx.rng.randf() * (float(r[1]) - float(r[0]))


func _source_at(ctx: StoryContext, step: ObjectiveStep) -> Vector2:
	var a := ctx.actor(String(step.rule_params["source"]))
	return Vector2(a.gx, a.gy) if a else ctx.player_pos()


func _stand_at(ctx: StoryContext, step: ObjectiveStep) -> Vector2:
	var s: Variant = step.rule_params["stand"]
	return ctx.marker(s) if s is String else s as Vector2


## True while the voice pauses (what a player sees on the gauge).
static func in_lull(st: Dictionary) -> bool:
	return not bool(st.get("talking", true))


func on_action(ctx: StoryContext, step: ObjectiveStep, st: Dictionary) -> void:
	var p := ctx.player_pos()
	ctx.player.start_action("bark", S.BARK_ANIM)
	if p.distance_to(_stand_at(ctx, step)) > float(step.rule_params["range"]):
		ctx.say_float(ctx.ui_text("story_too_far_bark"), p, Color.WHITE)
		ctx.notice(ctx.ui_text("story_too_far"), NOISE_COLOR)
		return
	ctx.say_float(String(step.rule_lines["act_text"]), p, Color.WHITE)
	if st["talking"]:
		ctx.notice(String(step.rule_lines["drowned"]), NOISE_COLOR)
		return
	if st["used"]:
		return
	st["used"] = true
	st["good"] = int(st["good"]) + 1
	var n := int(st["good"])
	(ctx.metrics.get_or_add("lull_acts", []) as Array).append(step.id)
	var fx: Dictionary = step.rule_params.get("good_effects", {})
	if not fx.is_empty():
		ctx.apply(fx)
	var groups: Array = step.rule_params.get("responders", [])
	if n - 1 < groups.size():
		var shift := float(step.rule_params.get("responder_shift", 0.0))
		var k := 0
		for h: String in groups[n - 1]:
			var a := ctx.actor(h)
			if a == null:
				return
			a.face_point(p)
			if step.rule_lines.has("response"):
				ctx.say_float(String(step.rule_lines["response"]), Vector2(a.gx, a.gy), RESPONSE_COLOR)
			if shift != 0.0:
				a.go_to(Vector2(a.gx + (shift if k % 2 == 1 else -shift), a.gy), 1.6)
			k += 1
	var notices: Array = step.rule_lines.get("good_notices", [])
	if n - 1 < notices.size() and String(notices[n - 1]) != "":
		ctx.notice(String(notices[n - 1]), SPREAD_COLOR)
	_hud(ctx, step, st)


func tick(ctx: StoryContext, step: ObjectiveStep, st: Dictionary, dt: float) -> bool:
	st["phase_t"] = float(st["phase_t"]) - dt
	if float(st["phase_t"]) <= 0.0:
		st["talking"] = not st["talking"]
		st["used"] = false
		st["phase_t"] = _draw(ctx, S.LULL_TALK if st["talking"] else S.LULL_QUIET)
		st["phrase_t"] = 0.0
	if st["talking"]:
		st["phrase_t"] = float(st["phrase_t"]) - dt
		if float(st["phrase_t"]) <= 0.0:
			st["phrase_t"] = S.LULL_PHRASE_EVERY
			var noise: Array = step.rule_lines["noise"]
			ctx.say_float(String(noise[int(st["phrase_k"]) % noise.size()]), _source_at(ctx, step), NOISE_COLOR)
			st["phrase_k"] = int(st["phrase_k"]) + 1
	var spread: Array = step.rule_params.get("spread", [])
	if int(st["good"]) >= 1 and not spread.is_empty() and step.rule_lines.has("spread"):
		st["spread_t"] = float(st["spread_t"]) - dt
		if float(st["spread_t"]) <= 0.0:
			st["spread_t"] = 0.5
			var lines: Array = step.rule_lines["spread"]
			var k := int(st["spread_k"])
			var a := ctx.actor(String(spread[k % spread.size()]))
			if a:
				ctx.say_float(String(lines[k % lines.size()]), Vector2(a.gx, a.gy), SPREAD_COLOR)
			st["spread_k"] = k + 1
	_hud(ctx, step, st)
	return int(st["good"]) >= int(step.rule_params["need"])


func _hud(ctx: StoryContext, step: ObjectiveStep, st: Dictionary) -> void:
	if st["talking"]:
		ctx.hud.set_mode(String(step.rule_lines["noise_label"]), minf(1.0, float(st["phase_t"]) / float(S.LULL_TALK[1])), Color("#ff7a1f"))
	else:
		ctx.hud.set_mode(ctx.ui_text("story_lull_now"), minf(1.0, float(st["phase_t"]) / float(S.LULL_QUIET[1])), Color("#5ac8ff"))
	ctx.hud.objective = ctx.ui_text("story_lull_count") % [step.objective, int(st["good"]), int(step.rule_params["need"])]


func end(ctx: StoryContext, _step: ObjectiveStep, _st: Dictionary) -> void:
	ctx.hud.clear_mode()
