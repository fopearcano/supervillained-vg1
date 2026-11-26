class_name ActorStep
extends StoryStep
## Commands one actor: spawn (a role at a marker, a point or near the player), despawn, goto,
## follow the player, idle, face, a speaking gesture, place (teleport), patrol (between marker
## `points`, pausing), chase (the player, within `radius` of where it stands), flee (from the
## player while within `radius`), wander (within `radius` of where it stands), emote (a one-shot
## clip: hurt, bark). Any action may also set a sight cone (`sight_range` > 0) and `hostile`.

const ACTIONS := ["spawn", "despawn", "goto", "follow", "idle", "face", "gesture", "place", "patrol", "chase", "flee", "wander", "flail", "emote"]

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
## patrol: marker ids in order, the pause at each.
@export var points: PackedStringArray = []
@export var pause := 0.8
## chase / flee / wander: the radius.
@export var radius := 0.0
## follow: tiles to the player's side.
@export var side := 0.0
## emote: the clip and its length.
@export var clip := ""
@export var seconds := 0.0
## A sight cone (stealth): range in tiles (0 = unchanged), half-angle in radians.
@export var sight_range := 0.0
@export var sight_half_angle := 0.0
## Touching him catches him (stealth walks).
@export var hostile := false


func kind() -> String:
	return "actor"


func marker_refs() -> PackedStringArray:
	var out := PackedStringArray([at]) if at != "" else PackedStringArray()
	out.append_array(points)
	return out


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
	_need(errors, action != "patrol" or points.size() >= 2, "actor %s: patrol needs at least two points" % actor)
	_need(errors, not ["chase", "flee", "wander", "flail"].has(action) or radius > 0.0, "actor %s: %s needs a positive radius" % [actor, action])
	_need(errors, action != "emote" or (clip != "" and seconds > 0.0), "actor %s: emote needs a clip and seconds" % actor)
	_need(errors, sight_range >= 0.0 and (sight_range == 0.0 or sight_half_angle > 0.0), "actor %s: a sight cone needs a half-angle" % actor)


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
		if s != null:
			_watch(s)
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
			a.follow(speed, side)
		"idle":
			a.set_idle(face_player)
		"patrol":
			var pts: Array = []
			for m in points:
				pts.append(ctx.marker(m))
			if ctx.error != "":
				return
			a.patrol(pts, speed, pause)
		"chase":
			a.chase(speed, radius, Vector2(a.gx, a.gy))
		"flee":
			a.flee(speed, radius)
		"wander":
			a.wander(Vector2(a.gx, a.gy), radius, speed)
		"flail":
			a.flail(Vector2(a.gx, a.gy), radius, speed)
		"emote":
			a.play_action(clip, seconds)
		"gesture":
			if not a.gesture():
				a.play_action("bark", 0.5)
		"place":
			a.set_grid_position(p.x, p.y)
	if face_player:
		a.face_point(ctx.player_pos())
	elif face != "":
		a.face(face)
	_watch(a)


## Sight and hostility, when the step sets them.
func _watch(a: StoryActor) -> void:
	if sight_range > 0.0:
		a.sight_range = sight_range
		a.sight_half_angle = sight_half_angle
	if hostile:
		a.hostile = true


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
