class_name ActorStep
extends StoryStep
## Commands one actor: spawn (a role at a marker, a point or near the player), despawn, goto,
## follow the player, idle, face, a speaking gesture, or place (teleport).

const ACTIONS := ["spawn", "despawn", "goto", "follow", "idle", "face", "gesture", "place"]

@export var actor := ""
@export var action := "idle"
## spawn: the cast role.
@export var role := ""
## Where (spawn, goto, place): a marker id, or "" for `point`.
@export var at := ""
@export var point := Vector2.ZERO
## spawn/goto/place relative to the player: `point` is an offset from his position.
@export var near_player := false
@export var face := ""
@export var face_player := false
@export var speed := 2.0
@export var run := false
## goto: the step waits until the actor arrives.
@export var wait_arrival := false


func kind() -> String:
	return "actor"


func marker_refs() -> PackedStringArray:
	return PackedStringArray([at]) if at != "" else PackedStringArray()


func roles() -> PackedStringArray:
	return PackedStringArray([role]) if action == "spawn" else PackedStringArray()


func actor_defs() -> PackedStringArray:
	return PackedStringArray([actor]) if action == "spawn" else PackedStringArray()


func actor_refs() -> PackedStringArray:
	return PackedStringArray([actor]) if action != "spawn" else PackedStringArray()


func check(errors: PackedStringArray) -> void:
	_need(errors, actor != "", "actor step without an actor")
	_need(errors, ACTIONS.has(action), "actor %s: bad action '%s'" % [actor, action])
	_need(errors, action != "spawn" or role != "", "actor %s: spawn without a role" % actor)
	_need(errors, face == "" or StoryDirs.ALL.has(face), "actor %s: bad facing '%s'" % [actor, face])
	_need(errors, speed > 0.0, "actor %s: speed must be positive" % actor)
