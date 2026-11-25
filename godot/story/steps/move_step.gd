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


## A scripted walk that cannot arrive within this many seconds fails explicitly.
const TIMEOUT := 12.0


func begin(ctx: StoryContext, st: Dictionary) -> void:
	ctx.move_target = ctx.place(to_marker, to_point)
	st["t"] = 0.0


func tick(ctx: StoryContext, st: Dictionary, dt: float) -> bool:
	st["t"] = float(st["t"]) + dt
	var target: Vector2 = ctx.move_target
	var d := target - ctx.player_pos()
	if d.length() < 0.15:
		return true
	if float(st["t"]) > TIMEOUT:
		ctx.fail("scripted move %s did not reach %s" % [id, target])
		return true
	var s := IsoGrid.grid_vec_to_screen(d.x, d.y).normalized()
	var mag := clampf(speed / GameConfig.Player.WALK_SPEED, 0.2, 1.0)
	ctx.player.set_intent(s.x * mag, s.y * mag, false)
	return false


func end(ctx: StoryContext, _st: Dictionary) -> void:
	ctx.move_target = null
	if ctx.scene.world:
		ctx.player.set_intent(0.0, 0.0)
		if face != "":
			ctx.player.face(face)
