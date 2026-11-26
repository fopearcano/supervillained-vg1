class_name NoRunningRule
extends ObjectiveRule
## 7.6: envoys do not run (port of the 7.6 runCheck). Running is possible (the walk does not take it
## away), but the moment he runs the walk stops: the card (rule_lines out_big, out_small), then he is
## back at the walk's start with the `escorts` beside him, and walks it again. Nothing is applied.


func tick(ctx: StoryContext, step: ObjectiveStep, st: Dictionary, _dt: float) -> bool:
	if ctx.player.running:
		st["rule_restart"] = {"big": String(step.rule_lines["out_big"]), "small": String(step.rule_lines["out_small"])}
		(ctx.metrics.get_or_add("ran", []) as Array).append(step.id)
	return false


func restart(ctx: StoryContext, step: ObjectiveStep, _st: Dictionary) -> void:
	var p := ctx.player_pos()
	var side := -0.8
	for h: String in step.rule_params.get("escorts", []):
		var a := ctx.actor(h)
		if a:
			a.set_grid_position(p.x + side, p.y)
		side = -side
