class_name StageStep
extends StoryStep
## Loads a story stage: the map, the player's place and facing, and the actors standing there.
## In a reality scene the player always wears his plain skin (no armour in reality).

@export var map := ""
## A map marker id ("S" = the map's start), or "" to use `player_point`.
@export var player_at := "S"
@export var player_point := Vector2.ZERO
@export var player_face := "S"
## StoryActorSpec Resources.
@export var actors: Array = []


func kind() -> String:
	return "stage"


func stage_map() -> String:
	return map


func marker_refs() -> PackedStringArray:
	var out := PackedStringArray()
	if player_at != "":
		out.append(player_at)
	for a: StoryActorSpec in actors:
		if a.at != "":
			out.append(a.at)
		if a.behavior == "goto" and a.target != "":
			out.append(a.target)
	return out


func roles() -> PackedStringArray:
	var out := PackedStringArray()
	for a: StoryActorSpec in actors:
		out.append(a.role)
	return out


func actor_defs() -> PackedStringArray:
	var out := PackedStringArray()
	for a: StoryActorSpec in actors:
		out.append(a.name)
	return out


func check(errors: PackedStringArray) -> void:
	_need(errors, map != "", "stage without a map")
	_need(errors, StoryDirs.ALL.has(player_face), "bad player facing '%s'" % player_face)
	for a: Variant in actors:
		if not a is StoryActorSpec:
			errors.append("stage actor is not a StoryActorSpec")
			continue
		var s: StoryActorSpec = a
		_need(errors, s.name != "" and s.role != "", "stage actor without name or role")
		_need(errors, ["idle", "goto", "follow"].has(s.behavior), "actor %s: bad behavior '%s'" % [s.name, s.behavior])
		_need(errors, StoryDirs.ALL.has(s.face), "actor %s: bad facing '%s'" % [s.name, s.face])
