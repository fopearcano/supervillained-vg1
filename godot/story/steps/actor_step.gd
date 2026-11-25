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
## goto + wait_arrival: seconds to arrive before the scene stops with an explicit error (validated
## positive; never a silent continue while the actor is far from its target).
@export var arrival_timeout := 0.0


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
	if action == "goto" and wait_arrival:
		_need(errors, arrival_timeout > 0.0, "actor step %s: wait_arrival needs a positive arrival_timeout" % id)
	_need(errors, actor != "", "actor step without an actor")
	_need(errors, ACTIONS.has(action), "actor %s: bad action '%s'" % [actor, action])
	_need(errors, action != "spawn" or role != "", "actor %s: spawn without a role" % actor)
	_need(errors, face == "" or StoryDirs.ALL.has(face), "actor %s: bad facing '%s'" % [actor, face])
	_need(errors, speed > 0.0, "actor %s: speed must be positive" % actor)


func begin(ctx: StoryContext, st: Dictionary) -> void:
	st["t"] = 0.0
	var p := Vector2.ZERO
	if ["spawn", "goto", "place"].has(action):
		p = ctx.player_pos() + point if near_player else ctx.place(at, point)
		if ctx.error != "":
			return
	if action == "spawn":
		var s := ctx.scene.spawn_actor(actor, role, p, face if face != "" else "S")
		if s != null and face_player:
			s.face_point(ctx.player_pos())
		return
	if action == "despawn":
		ctx.scene.despawn_actor(actor)
		return
	var a := ctx.actor(actor)
	if a == null:
		return
	match action:
		"goto":
			a.go_to(p, speed, run)
		"follow":
			a.follow(speed)
		"idle":
			a.set_idle()
		"gesture":
			if not a.gesture():
				a.play_action("bark", 0.5)
		"place":
			a.set_grid_position(p.x, p.y)
	if face_player:
		a.face_point(ctx.player_pos())
	elif face != "":
		a.face(face)


func tick(ctx: StoryContext, st: Dictionary, dt: float) -> bool:
	if action == "goto" and wait_arrival:
		var a := ctx.actor(actor)
		if a == null:
			return true
		st["t"] = float(st["t"]) + dt
		if a.arrived:
			return true
		if float(st["t"]) > arrival_timeout:
			ctx.fail("actor '%s' did not reach (%.2f, %.2f) within %.1f s (stopped at %.2f, %.2f)" % [actor, a.target.x, a.target.y, arrival_timeout, a.gx, a.gy])
			return true
		return false
	return true
