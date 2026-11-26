class_name CompanionsRule
extends ObjectiveRule
## 8.3: his friends beside him on the direct path (port of the 8.3 beside/flinch walk). Each of
## `companions` ([actor, side] pairs) follows him at that side. A flinch (standing nearly still, or
## stepping back: grid vx below -0.3) for more than 0.6 s and they stop and wait for him, turned to
## him (rule_lines.wait, metrics "flinch"); when he walks on they fall in beside him again
## (metrics "rejoined"). Past x = `fall_in_x` the line rule_lines.fall_in shows once.

const FOLLOW_SPEED := 3.6


func begin(ctx: StoryContext, step: ObjectiveStep, st: Dictionary) -> void:
	st["flinch_t"] = 0.0
	st["waiting"] = false
	st["fell_in"] = false
	_beside(ctx, step, false)


func _beside(ctx: StoryContext, step: ObjectiveStep, wait_up: bool) -> void:
	for pair: Array in step.rule_params["companions"]:
		var a := ctx.actor(String(pair[0]))
		if a == null:
			continue
		if wait_up:
			a.set_idle(true)
		elif a.behavior != "follow":
			a.follow_actor = null
			a.follow_gap = 1.0
			a.follow(FOLLOW_SPEED, float(pair[1]))


func tick(ctx: StoryContext, step: ObjectiveStep, st: Dictionary, dt: float) -> bool:
	var dog := ctx.player
	var flinch := Vector2(dog.vx, dog.vy).length() < 0.25 or dog.vx < -0.3
	st["flinch_t"] = float(st["flinch_t"]) + dt if flinch else 0.0
	if float(st["flinch_t"]) > 0.6 and not st["waiting"]:
		st["waiting"] = true
		_beside(ctx, step, true)
		ctx.notice(String(step.rule_lines["wait"]), Color("#ff9a1f"))
		(ctx.metrics.get_or_add("flinch", []) as Array).append(step.id)
	elif not flinch and st["waiting"]:
		st["waiting"] = false
		_beside(ctx, step, false)
		(ctx.metrics.get_or_add("rejoined", []) as Array).append(step.id)
	if not st["fell_in"] and dog.gx > float(step.rule_params["fall_in_x"]):
		st["fell_in"] = true
		ctx.notice(String(step.rule_lines["fall_in"]), PixelText.GREEN)
	return false
