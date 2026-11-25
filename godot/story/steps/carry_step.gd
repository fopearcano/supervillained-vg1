class_name CarryStep
extends StoryStep
## Zampanò carries something (shown on his back with its label), or drops it (empty label).

@export var label := ""
@export var sprite := ""


func kind() -> String:
	return "carry"


func texts() -> PackedStringArray:
	return PackedStringArray([label]) if label != "" else PackedStringArray()


func sprites() -> PackedStringArray:
	return PackedStringArray([sprite]) if sprite != "" else PackedStringArray()


func begin(ctx: StoryContext, _st: Dictionary) -> void:
	ctx.carry(label, sprite)
