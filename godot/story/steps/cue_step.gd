class_name CueStep
extends StoryStep
## Presentation cues in one step: a sound, a camera shake, a flash, the visor (1.1's bucket over
## his eyes; -1 leaves it), and a floating line above a marker, a point, an actor or the player.

@export var sound := ""
@export var shake := 0.0
@export var flash := false
@export var visor := -1.0
@export var float_text := ""
## Where the floating line appears: an actor handle, a marker id, "player", or "" for `float_point`.
@export var float_at := ""
@export var float_point := Vector2.ZERO
@export var float_color := Color.WHITE


func kind() -> String:
	return "cue"


func texts() -> PackedStringArray:
	return PackedStringArray([float_text]) if float_text != "" else PackedStringArray()


func sounds() -> PackedStringArray:
	return PackedStringArray([sound]) if sound != "" else PackedStringArray()


func check(errors: PackedStringArray) -> void:
	_need(errors, sound != "" or shake > 0.0 or flash or visor >= 0.0 or float_text != "", "cue %s does nothing" % id)
	_need(errors, visor <= 1.0, "cue %s: visor above 1" % id)


func begin(ctx: StoryContext, _st: Dictionary) -> void:
	ctx.play_sound(sound)
	if shake > 0.0:
		ctx.shake(shake)
	if flash:
		ctx.flash()
	if visor >= 0.0:
		ctx.visor = visor
	if float_text != "":
		var at := float_point
		if float_at == "player":
			at = ctx.player_pos()
		elif ctx.has_actor(float_at):
			var a := ctx.actor(float_at)
			at = Vector2(a.gx, a.gy)
		elif float_at != "":
			at = ctx.marker(float_at)
		ctx.say_float(float_text, at, float_color)
