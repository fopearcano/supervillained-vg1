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
