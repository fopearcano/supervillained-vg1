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
