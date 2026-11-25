class_name PropStep
extends StoryStep
## A story prop on the stage (the bowl, the ball, a horse, a bush): place it, move it, or remove
## it; optionally a floating line where it lands (the bowl's CLONG). `near_player`: `point` is an
## offset from Zampanò (place) or, for move, from where the prop stands. `hides`: the prop is a hiding
## spot for stealth walks (StorySight).

const ACTIONS := ["place", "move", "remove"]

@export var prop := ""
@export var sprite := ""
@export var action := "place"
@export var at := ""
@export var point := Vector2.ZERO
@export var tint := Color.WHITE
@export var float_text := ""
@export var float_color := Color.WHITE
@export var sound := ""
@export var near_player := false
@export var hides := false


func kind() -> String:
	return "prop"


func texts() -> PackedStringArray:
	return PackedStringArray([float_text]) if float_text != "" else PackedStringArray()


func marker_refs() -> PackedStringArray:
	return PackedStringArray([at]) if at != "" else PackedStringArray()


func sprites() -> PackedStringArray:
	return PackedStringArray([sprite]) if action == "place" else PackedStringArray()


func sounds() -> PackedStringArray:
	return PackedStringArray([sound]) if sound != "" else PackedStringArray()


func check(errors: PackedStringArray) -> void:
	_need(errors, prop != "", "prop step %s without a prop handle" % id)
	_need(errors, ACTIONS.has(action), "prop %s: bad action '%s'" % [prop, action])
	_need(errors, action != "place" or sprite != "", "prop %s: place without a sprite" % prop)


func begin(ctx: StoryContext, _st: Dictionary) -> void:
	var p := ctx.place(at, point)
	if ctx.error != "":
		return
	match action:
		"place":
			if near_player:
				p = ctx.player_pos() + point
			if ctx.scene.place_prop(prop, sprite, p, tint) and hides:
				ctx.hides.append(p)
		"move":
			var pr: StoryProp = ctx.scene.props.get(prop)
			if pr == null:
				ctx.fail("missing prop '%s'" % prop)
				return
			if near_player:
				p = Vector2(pr.gx, pr.gy) + point
			pr.set_grid_position(p.x, p.y)
		"remove":
			var pr: StoryProp = ctx.scene.props.get(prop)
			if pr:
				ctx.hides.erase(Vector2(pr.gx, pr.gy))
			ctx.scene.remove_prop(prop)
	ctx.play_sound(sound)
	if float_text != "":
		ctx.say_float(float_text, p, float_color)
