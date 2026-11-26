class_name BranchStep
extends StoryStep
## A readback (STORY_REWRITE_SPEC.md §5.3, M7): the first case whose condition holds of the campaign
## working copy runs its steps (queued right after this one); when none holds, `otherwise` does. No
## text of its own: every line is in its cases' steps. Used where a later scene answers an earlier
## decision (5.5's board, 7.7's comradeship, 7.9's cloth, 8.2's telling, 8.4's ball, the endings).

@export var cases: Array = []
@export var otherwise: Array = []


func kind() -> String:
	return "branch"


func branches() -> Array:
	var out: Array = []
	for c: StoryBranchCase in cases:
		out.append(c.steps)
	out.append(otherwise)
	return out


func check(errors: PackedStringArray) -> void:
	_need(errors, not cases.is_empty(), "branch %s without cases" % id)
	for c: Variant in cases:
		if not c is StoryBranchCase:
			errors.append("branch %s: a case is not a StoryBranchCase" % id)
			continue
		var bc: StoryBranchCase = c
		var why := StoryConditions.check(bc.when)
		_need(errors, why == "", "branch %s case %s: %s" % [id, bc.id, why])


## The steps that run from `state`.
func chosen(state: Dictionary) -> Array:
	for c: StoryBranchCase in cases:
		if StoryConditions.holds(state, c.when):
			return c.steps
	return otherwise


func begin(ctx: StoryContext, st: Dictionary) -> void:
	var steps := chosen(ctx.state)
	st["case"] = "otherwise"
	for c: StoryBranchCase in cases:
		if c.steps == steps:
			st["case"] = c.id
			break
	(ctx.metrics.get_or_add("branches", []) as Array).append("%s:%s" % [id, st["case"]])
	if not steps.is_empty():
		ctx.insert(steps)
