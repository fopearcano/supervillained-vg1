class_name DialogueStep
extends StoryStep
## A speaker's line in the dialogue box (name, portrait, typewriter). `remembered`: the scene's one
## remembered line, collected in the book. Optional effects apply when the line starts.

@export var speaker := ""
@export_multiline var text := ""
@export var remembered := false
@export var effects: Dictionary = {}


func kind() -> String:
	return "dialogue"


func texts() -> PackedStringArray:
	return PackedStringArray([text])


func speakers() -> PackedStringArray:
	return PackedStringArray([speaker])


func effect_sets() -> Array:
	var out: Array = []
	if remembered:
		out.append({"remembered": text})
	if not effects.is_empty():
		out.append(effects)
	return out


func check(errors: PackedStringArray) -> void:
	_need(errors, speaker != "", "dialogue without a speaker")
	_need(errors, text.strip_edges() != "", "dialogue (%s) without text" % speaker)


func begin(ctx: StoryContext, st: Dictionary) -> void:
	st["t"] = 0.0
	ctx.hud.show_line(ctx.cast.display_name(speaker), ctx.cast.color(speaker), ctx.portrait_of(speaker), text)
	ctx.speaking_gesture(speaker)
	if remembered:
		ctx.apply({"remembered": text})
	if not effects.is_empty():
		ctx.apply(effects)


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
