class_name RecedingRule
extends VisorRule
## 2.1: the city gate is always one step away. Each time he comes within `within` of the goal it
## steps back by `step` (grid offset), `steps` times, with a `recede` notice; then it lets him reach
## it. The helmet (the bucket of 1.1) slides down whenever he stops or barks (VisorRule), with a
## one-time `slip` notice; every `door_every` seconds a voice behind a door says `door` at
## `door_offset` from him. The goal ring moves with the goal.

const DOOR_COLOR := Color("#9aa4c0")


func begin(ctx: StoryContext, step: ObjectiveStep, st: Dictionary) -> void:
	super.begin(ctx, step, st)
	st["receded"] = 0
	st["door_t"] = 0.0
	st["slip_told"] = false


func tick(ctx: StoryContext, step: ObjectiveStep, st: Dictionary, dt: float) -> bool:
	super.tick(ctx, step, st, dt)
	if ctx.visor > 0.05 and not st["slip_told"]:
		st["slip_told"] = true
		ctx.notice(String(step.rule_lines["slip"]), PixelText.CYAN)
	st["door_t"] = float(st["door_t"]) + dt
	if float(st["door_t"]) > float(step.rule_params["door_every"]):
		st["door_t"] = 0.0
		ctx.say_float(String(step.rule_lines["door"]), ctx.player_pos() + (step.rule_params["door_offset"] as Vector2), DOOR_COLOR)
	if int(st["receded"]) < int(step.rule_params["steps"]) and st["goal"] != null:
		var goal: Vector2 = st["goal"]
		if ctx.player_pos().distance_to(goal) <= float(step.rule_params["within"]):
			st["receded"] = int(st["receded"]) + 1
			goal += step.rule_params["step"] as Vector2
			st["goal"] = goal
			ctx.scene.remove_marker(st.get("goal_node"))
			st["goal_node"] = ctx.scene.add_marker(goal, st["radius"], ObjectiveStep.GOAL_COLOR)
			ctx.notice(String(step.rule_lines["recede"]), Color("#f6c8e0"))
			ctx.play_sound("glitch")
	return false


func end(ctx: StoryContext, _step: ObjectiveStep, _st: Dictionary) -> void:
	ctx.visor = 0.0
