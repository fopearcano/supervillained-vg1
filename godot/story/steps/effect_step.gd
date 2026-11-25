class_name EffectStep
extends StoryStep
## Persistent campaign effects (meters, flags, book, unlocks, coins), applied to the scene's
## working copy with their notices; saved with the scene's completion (RD-05).

@export var effects: Dictionary = {}


func kind() -> String:
	return "effect"


func effect_sets() -> Array:
	return [effects]


func check(errors: PackedStringArray) -> void:
	_need(errors, not effects.is_empty(), "effect step %s without effects" % id)
