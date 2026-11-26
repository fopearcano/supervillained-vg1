class_name SounderRule
extends ObjectiveRule
## A sound popping up at a place every `every` seconds (port of src/campaign/chapters/helpers.ts
## sounder): the harbour bell over the quay (3.1), and a goal found by ear (3.4: with `hidden` the
## goal has no ring; he follows the sound). The place is rule_params.at (a marker or a point), or the
## walk's goal when absent; the line is rule_lines.sound.

const SOUND_COLOR := Color("#c8d0ff")


func begin(ctx: StoryContext, step: ObjectiveStep, st: Dictionary) -> void:
	st["sound_t"] = 0.0
	if bool(step.rule_params.get("hidden", false)) and st.has("goal_node"):
		ctx.scene.remove_marker(st["goal_node"])
		st.erase("goal_node")


## The place: rule_params.actor (an actor, followed), rule_params.at (a marker or a point), the goal.
func _at(ctx: StoryContext, step: ObjectiveStep, st: Dictionary) -> Vector2:
	if step.rule_params.has("actor") and ctx.has_actor(String(step.rule_params["actor"])):
		var a := ctx.actor(String(step.rule_params["actor"]))
		return Vector2(a.gx, a.gy)
	var p: Variant = step.rule_params.get("at")
	if p is String:
		return ctx.marker(p)
	if p is Vector2:
		return p
	return st["goal"] if st.get("goal") != null else ctx.player_pos()


func tick(ctx: StoryContext, step: ObjectiveStep, st: Dictionary, dt: float) -> bool:
	st["sound_t"] = float(st["sound_t"]) - dt
	if float(st["sound_t"]) <= 0.0:
		st["sound_t"] = float(step.rule_params["every"])
		ctx.say_float(String(step.rule_lines["sound"]), _at(ctx, step, st), SOUND_COLOR)
		(ctx.metrics.get_or_add("sounds", []) as Array).append(step.id)
	return false
