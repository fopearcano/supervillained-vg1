class_name ActAtRule
extends ObjectiveRule
## An action that must be done at a spot (5.5: chalk the balance on the board): reaching the goal is
## not enough; the walk's own action within rule_params.radius of the goal completes it. Away from it
## the action does nothing (the walk's own text still floats).


func begin(_ctx: StoryContext, _step: ObjectiveStep, st: Dictionary) -> void:
	st["acted"] = false


func on_action(ctx: StoryContext, step: ObjectiveStep, st: Dictionary) -> void:
	if st.get("goal") != null and ctx.player_pos().distance_to(st["goal"]) <= float(step.rule_params["radius"]):
		st["acted"] = true


func tick(_ctx: StoryContext, _step: ObjectiveStep, st: Dictionary, _dt: float) -> bool:
	return bool(st["acted"])
