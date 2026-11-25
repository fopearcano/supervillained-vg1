class_name StoryContext
extends RefCounted
## The only API story steps use (ARCHITECTURE.md §13): the stage (map, markers, actors, props),
## the player, the story HUD, the campaign working copy and its effects, cues and input. One
## context per scene run; a restart builds a fresh one from the scene's entry state.

var scene: StoryScene
var data: StorySceneData
var cast: StoryCast
## The campaign working copy: effects apply here at once and are committed with the scene's
## completion (RD-05). A replay's copy is never committed.
var state: Dictionary = {}
var persist := true
var runner: StoryRunner
var hud: StoryHud
## The first explicit failure (a missing marker, actor or resource); the scene stops.
var error := ""
## 1.1: how far the bucket is over his eyes (0..1).
var visor := 0.0
## The player walks with the joystick (an objective runs) or stands (lines, cards, cues).
var controls := false
var no_run := false
## The current objective's action button ("" = none) and the carried thing ("" = none).
## What J/X, Space, B, the touch buttons and the gestures do in a walk (the objective configures it).
var actions := StoryActionRouter.new()
var carrying := ""
var map_id := ""
## A scripted walk of the player in progress (MoveStep): its target grid point, or null.
var move_target: Variant = null
## choice id -> option ids taken in this run (once_each choices offer the rest).
var choices_taken: Dictionary = {}
## Run metrics: choices taken, bumps and echoes at a gate, notices shown.
var metrics: Dictionary = {"choices": [], "bumps": 0, "echoes": 0, "notices": [], "actions": []}

var world: IsoWorld:
	get:
		return scene.world

var player: PlayableDog:
	get:
		return scene.world.player


## Stops the scene with an explicit message (never a silent fallback).
func fail(message: String) -> void:
	if error != "":
		return
	error = "story %s: %s" % [data.id if data else "?", message]
	push_error(error)
	scene.on_failed(error)


## Grid centre of a marker of the current map ("S" = the start).
func marker(id: String) -> Vector2:
	var m := world.map
	if id == "S":
		return Vector2(m.start_tile.x + 0.5, m.start_tile.y + 0.5)
	if not m.markers.has(id):
		fail("missing marker '%s' on map '%s'" % [id, map_id])
		return Vector2.ZERO
	var t: Vector2i = m.markers[id]
	return Vector2(t.x + 0.5, t.y + 0.5)


## A marker if given, else the literal grid point.
func place(at: String, point: Vector2) -> Vector2:
	return marker(at) if at != "" else point


func player_pos() -> Vector2:
	return Vector2(player.gx, player.gy)


func actor(handle: String) -> StoryActor:
	var a: StoryActor = scene.actors.get(handle)
	if a == null:
		fail("missing actor '%s'" % handle)
	return a


func has_actor(handle: String) -> bool:
	return scene.actors.has(handle)


## Applies campaign effects to the working copy; each change shows as a notice (source labels).
func apply(fx: Dictionary) -> Array:
	var changes: Array = CampaignRules.apply_effects(state, fx)
	for k in changes.size():
		var c: Dictionary = changes[k]
		notice(String(c["label"]), PixelText.GREEN if c["positive"] else PixelText.RED, k * 0.25)
	return changes


func notice(text: String, color: Color = PixelText.YELLOW, delay: float = 0.0) -> void:
	(metrics["notices"] as Array).append(text)
	hud.notice(text, color, delay)


## A short line floating above a grid point (speech above a character, a CLONG).
func say_float(text: String, at: Vector2, color: Color = PixelText.WHITE) -> void:
	hud.float_text(text, at, color)


func insert(steps: Array) -> void:
	runner.insert(steps)


func set_controls(on: bool) -> void:
	controls = on
	scene.set_controls(on)


func play_sound(cue: String) -> void:
	if cue != "":
		AudioService.play(StringName(cue))


func shake(amount: float) -> void:
	world.camera_rig.model.shake(amount)


func flash() -> void:
	hud.flash()


func carry(label: String, sprite: String = "") -> void:
	carrying = label
	scene.set_carried(label, sprite)


## Interface chrome (a lock reason template, a cost suffix) from data/shell/shell_text.tres.
func ui_text(key: String) -> String:
	return StoryScene.TEXT.get_text(key)


## A speaker's dialogue portrait: the first idle frame of its cast role (none for a voice).
func portrait_of(speaker: String) -> Texture2D:
	var path := StoryCast.frames_path(cast.portrait(speaker))
	if path == "":
		return null
	var frames: SpriteFrames = load(path)
	for clip in [&"idle_s", &"idle_se", &"idle"]:
		if frames.has_animation(clip):
			return frames.get_frame_texture(clip, 0)
	return null


## An idle on-stage actor of the speaker's role makes one speaking gesture (humans only).
func speaking_gesture(speaker: String) -> bool:
	if not cast.gestures(speaker):
		return false
	var role := cast.portrait(speaker)
	for a: StoryActor in scene.actors.values():
		if a.role == role and a.gesture():
			return true
	return false


## A confirm or a tap after `guard` seconds of the step (`st.t`); a held key never skips.
func tapped(st: Dictionary, guard: float) -> bool:
	var taps := InputService.consume_taps().size() > 0
	var key := InputService.consume_any([&"confirm", &"action", &"pee"] as Array[StringName])
	return float(st.get("t", 0.0)) > guard and (taps or key)
