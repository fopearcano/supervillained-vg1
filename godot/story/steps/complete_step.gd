class_name CompleteStep
extends StoryStep
## The scene's completion boundary: the last step of every scene. The scene Resource's
## `completion` says what must be true here; the runner then commits the scene (RD-05).


func kind() -> String:
	return "complete"


## The boundary: the scene's required state must be in the working copy (else an explicit failure;
## the validator proves every branch produces it).
func begin(ctx: StoryContext, _st: Dictionary) -> void:
	var c: Dictionary = ctx.data.completion
	for f: String in c.get("requires_flags", []):
		if not (ctx.state["flags"] as Dictionary).has(f):
			ctx.fail("completion boundary reached without flag '%s'" % f)
			return
	for a: String in c.get("requires_abilities", []):
		if not (ctx.state["abilities"] as Array).has(a):
			ctx.fail("completion boundary reached without ability '%s'" % a)
			return
