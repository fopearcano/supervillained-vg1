class_name WaitStep
extends StoryStep
## A pause of `seconds` (the stage keeps running).

@export var seconds := 0.5


func kind() -> String:
	return "wait"


func check(errors: PackedStringArray) -> void:
	_need(errors, seconds > 0.0, "wait %s: seconds must be positive" % id)


func begin(_ctx: StoryContext, st: Dictionary) -> void:
	st["t"] = 0.0


func tick(_ctx: StoryContext, st: Dictionary, dt: float) -> bool:
	st["t"] = float(st["t"]) + dt
	return float(st["t"]) >= seconds
