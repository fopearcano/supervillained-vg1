class_name MoveStep
extends StoryStep
## A scripted walk of the player to a point (controls off), then an optional facing.

@export var to_marker := ""
@export var to_point := Vector2.ZERO
@export var speed := 2.0
@export var face := ""


func kind() -> String:
	return "move"


func marker_refs() -> PackedStringArray:
	return PackedStringArray([to_marker]) if to_marker != "" else PackedStringArray()


func check(errors: PackedStringArray) -> void:
	_need(errors, speed > 0.0, "move: speed must be positive")
	_need(errors, face == "" or StoryDirs.ALL.has(face), "move: bad facing '%s'" % face)
