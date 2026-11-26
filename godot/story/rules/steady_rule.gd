class_name SteadyRule
extends ObjectiveRule
## 5.2: steady the ladder — a survive walk whose clock (st.t) starts again whenever he moves (port of
## the 5.2 walk's onUpdate): rule_lines.wobble is shown the first time; the gauge (rule_lines.label)
## fills as he stands still. The objective (kind "survive") completes at `survive` seconds.

const GAUGE := Color("#5ac8ff")


func begin(ctx: StoryContext, step: ObjectiveStep, st: Dictionary) -> void:
	st["warned"] = false
	ctx.hud.set_mode(String(step.rule_lines["label"]), 0.0, GAUGE)


func tick(ctx: StoryContext, step: ObjectiveStep, st: Dictionary, _dt: float) -> bool:
	var dog := ctx.player
	if Vector2(dog.vx, dog.vy).length() > 0.3:
		st["t"] = 0.0
		if not st["warned"]:
			st["warned"] = true
			ctx.notice(String(step.rule_lines["wobble"]), Color("#ff9a1f"))
	ctx.hud.set_mode(String(step.rule_lines["label"]), minf(1.0, float(st["t"]) / maxf(0.001, step.survive)), GAUGE)
	return false


func end(ctx: StoryContext, _step: ObjectiveStep, _st: Dictionary) -> void:
	ctx.hud.clear_mode()
