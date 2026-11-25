class_name ListenRule
extends ObjectiveRule
## 3.4: overhearing the council (port of the 3.4 walk's onUpdate): standing within `radius` of
## `point` fills the listening gauge; `seconds` of it complete the walk. While close, a fragment of
## what is said (rule_lines.fragments, in turn, one per `fragment_every` seconds) floats over the
## point. The gauge's label is rule_lines.close or rule_lines.far.

const FRAGMENT_COLOR := Color("#f0d8a0")
const GAUGE_COLOR := Color("#ffe23a")


func begin(ctx: StoryContext, step: ObjectiveStep, st: Dictionary) -> void:
	st["listen"] = 0.0
	st["frag_t"] = 0.0
	st["frag_k"] = 0
	ctx.hud.set_mode(String(step.rule_lines["far"]), 0.0, GAUGE_COLOR)


func _point(ctx: StoryContext, step: ObjectiveStep) -> Vector2:
	var p: Variant = step.rule_params["point"]
	return ctx.marker(p) if p is String else p as Vector2


func tick(ctx: StoryContext, step: ObjectiveStep, st: Dictionary, dt: float) -> bool:
	var at := _point(ctx, step)
	var close := ctx.player_pos().distance_to(at) < float(step.rule_params["radius"])
	if close:
		st["listen"] = float(st["listen"]) + dt
		st["frag_t"] = float(st["frag_t"]) - dt
		if float(st["frag_t"]) <= 0.0:
			st["frag_t"] = float(step.rule_params.get("fragment_every", 1.25))
			var frags: Array = step.rule_lines["fragments"]
			ctx.say_float(String(frags[int(st["frag_k"]) % frags.size()]), at, FRAGMENT_COLOR)
			st["frag_k"] = int(st["frag_k"]) + 1
	var seconds := float(step.rule_params["seconds"])
	ctx.hud.set_mode(String(step.rule_lines["close" if close else "far"]), float(st["listen"]) / seconds, GAUGE_COLOR)
	return float(st["listen"]) >= seconds


func end(ctx: StoryContext, _step: ObjectiveStep, _st: Dictionary) -> void:
	ctx.hud.clear_mode()
