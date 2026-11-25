class_name NarrationStep
extends StoryStep
## A narrator's line in the dialogue box (no speaker, no portrait).

@export_multiline var text := ""


func kind() -> String:
	return "narration"


func texts() -> PackedStringArray:
	return PackedStringArray([text])


func check(errors: PackedStringArray) -> void:
	_need(errors, text.strip_edges() != "", "narration without text")


func begin(ctx: StoryContext, st: Dictionary) -> void:
	st["t"] = 0.0
	ctx.hud.show_line("", Color.WHITE, null, text)


func tick(ctx: StoryContext, st: Dictionary, dt: float) -> bool:
	st["t"] = float(st["t"]) + dt
	if not ctx.tapped(st, GameConfig.Story.LINE_GUARD):
		return false
	if ctx.hud.typing:
		ctx.hud.finish_typing()
		return false
	return true


func end(ctx: StoryContext, _st: Dictionary) -> void:
	ctx.hud.hide_line()
