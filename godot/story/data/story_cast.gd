class_name StoryCast
extends Resource
## The story's speakers (port of src/story/ui.ts SPEAKERS for the speakers in use): display name,
## name colour, the cast role whose sprite is the dialogue portrait ("" = a voice without a face),
## and whether an idle actor of that role makes a speaking gesture (src/story/dialogueGestures.ts).

## id -> {"name": String, "color": Color, "portrait": String role, "gesture": bool}
@export var speakers: Dictionary = {}


func has_speaker(id: String) -> bool:
	return speakers.has(id)


func display_name(id: String) -> String:
	return String((speakers.get(id, {}) as Dictionary).get("name", id.to_upper()))


func color(id: String) -> Color:
	return (speakers.get(id, {}) as Dictionary).get("color", Color.WHITE)


func portrait(id: String) -> String:
	return String((speakers.get(id, {}) as Dictionary).get("portrait", ""))


func gestures(id: String) -> bool:
	return bool((speakers.get(id, {}) as Dictionary).get("gesture", false))


## SpriteFrames of a cast role: a playable skin (data/characters/<skin>_frames.tres) or a cast
## sheet (data/characters/cast/<role>_frames.tres). "" when the role has no sheet.
static func frames_path(role: String) -> String:
	var playable := "res://data/characters/%s_frames.tres" % role
	if ResourceLoader.exists(playable):
		return playable
	var cast := "res://data/characters/cast/%s_frames.tres" % role
	return cast if ResourceLoader.exists(cast) else ""
