class_name PlayableDog
extends CharacterBody2D
## The player's dog (port of src/entities/zampano.ts), generic over PlayableCharacterProfile.
##
## Authoritative state is grid space in 64-bit floats (gx, gy, vx, vy in tiles and tiles/s).
## Each logic tick (called by the owning scene from _physics_process, in source order):
## screen-space intent → inverse projection → walk/run/terrain/accel → GridKinematicSolver
## (WorldMapModel.move_circle) → node position = projection of the foot point. Native slide
## resolution is not used for static geometry (M2 collision decision, IMPLEMENTATION_LOG.md);
## the body stays a CharacterBody2D on the PlayerBody layer for Area2D interactions.

const P := GameConfig.Player

## Action states; "free" = controlled by the player.
const LOCKS_MOVEMENT := {
	"free": false, "bark": false, "eat": false,
	"pee": true, "poop": true, "fetch": true, "hurt": true, "drink": true, "exit": true,
}
const STATE_ANIM := {
	"pee": "pee", "poop": "poop", "bark": "bark", "eat": "eat", "fetch": "fetch", "hurt": "hurt", "drink": "eat",
}
const TERRAIN_SPEED := {TileCatalog.Ground.TALL_GRASS: 0.85, TileCatalog.Ground.WATER: 0.8}
const BUSH_SPEED := 0.7

@export var profile: PlayableCharacterProfile

var gx := 0.0
var gy := 0.0
var vx := 0.0
var vy := 0.0
var facing := "N"
var state := "free"
var state_time := 0.0
var state_duration := 0.0
var running := false
## Extra velocity applied by the world this step (ball magnet), tiles/s.
var push_x := 0.0
var push_y := 0.0
var knock_x := 0.0
var knock_y := 0.0
var invulnerable := 0.0
## Movement multiplier (lives-for-speed in the Green Zone; bogs and thirst in the story).
var speed_mul := 1.0
var no_run := false
var guarding := false
var energy := NeedsSystem.Energy.new()
## "empty" when he just got tired this step, "ready" when running is possible again.
var energy_event := ""
## Animation model (source CharacterAnimator): name, direction, playback speed, restart counter.
var anim := "idle"
var anim_dir := "S"
var anim_speed := 1.0
var iso := IsoRenderable.new()

## Physics-interpolation resets performed (spawn, teleport, camera snap): DOG-008 evidence.
var interpolation_resets := 0

## RUN wanted: false, true (held) or "scripted" (no energy cost).
var _run_wanted: Variant = false
var _intent_x := 0.0
var _intent_y := 0.0
var _squash := 0.0
var _squash_vel := 0.0
var _fetch_x := 0.0
var _fetch_y := 0.0
var _idle_time := 0.0
var _anim_restart := false

@onready var visual_root: Node2D = $VisualRoot
@onready var body_sprite: AnimatedSprite2D = $VisualRoot/Body
@onready var shadow: Sprite2D = $Shadow
@onready var interaction_probe: Area2D = $InteractionProbe
@onready var hurtbox: Area2D = $Hurtbox


func _ready() -> void:
	iso.node = self
	iso.bounds = Rect2(-15, -32, 30, 35)
	if profile:
		body_sprite.sprite_frames = profile.normal_frames
		body_sprite.centered = false
		body_sprite.offset = -Vector2(profile.foot_anchor)
	_build_contact_shapes()
	_sync_node()
	_apply_animation()
	reset_physics_interpolation()
	interpolation_resets += 1


## InteractionProbe and Hurtbox are projected grid circles on the foot point (GridShapes): broad
## phase only. Rules decide contacts with the exact grid distance, like the source.
func _build_contact_shapes() -> void:
	var radius := profile.collision_radius if profile else GameConfig.Player.RADIUS
	for pair: Array in [[interaction_probe, GridShapes.PROBE_RADIUS], [hurtbox, radius]]:
		var shape := ConvexPolygonShape2D.new()
		shape.points = GridShapes.ellipse_polygon(pair[1])
		var holder: CollisionShape2D = (pair[0] as Area2D).get_node("Shape")
		holder.shape = shape
		holder.position = Vector2.ZERO


## Places him (spawn, teleport, restart, stage change): no interpolation from the old position.
func set_grid_position(x: float, y: float) -> void:
	gx = x
	gy = y
	iso.gx = x
	iso.gy = y
	if is_inside_tree():
		_sync_node()
		reset_physics_interpolation()
		interpolation_resets += 1


## Screen-space intent (magnitude 0..1) and RUN (true, false or "scripted").
func set_intent(mx: float, my: float, run: Variant = false) -> void:
	_intent_x = mx
	_intent_y = my
	_run_wanted = run


var controllable: bool:
	get:
		return not LOCKS_MOVEMENT[state]


var moving: bool:
	get:
		return JsMath.hypot(vx, vy) > 0.25


var can_run: bool:
	get:
		return not no_run and energy.can_run()


func start_action(new_state: String, duration: float) -> void:
	state = new_state
	state_time = 0.0
	state_duration = duration
	if STATE_ANIM.has(new_state):
		_play(STATE_ANIM[new_state], facing, true)
	if new_state == "fetch":
		var g := IsoGrid.dir_to_grid_xy(facing)
		_fetch_x = g[0]
		_fetch_y = g[1]


## Damped-spring squash: amount > 0 stretches, < 0 squashes.
func bump(amount: float) -> void:
	_squash_vel += amount * 30.0


func knockback(dx: float, dy: float, speed: float) -> void:
	var length := JsMath.hypot(dx, dy)
	if length == 0.0:
		length = 1.0
	knock_x = dx / length * speed
	knock_y = dy / length * speed


func face(dir: String) -> void:
	facing = dir
	anim_dir = dir


## One logic tick (port of Zampano.updateMovement).
func update_movement(dt: float, map: WorldMapModel) -> void:
	state_time += dt
	if invulnerable > 0.0:
		invulnerable -= dt
	if state != "free" and state_time >= state_duration:
		state = "free"
	var tx := 0.0
	var ty := 0.0
	running = false
	if controllable:
		var mag := minf(1.0, JsMath.hypot(_intent_x, _intent_y))
		if mag > 0.01:
			var dir := IsoGrid.screen_dir_to_grid_xy(_intent_x, _intent_y)
			running = not guarding and (_run_wanted is String or (_run_wanted is bool and _run_wanted and can_run))
			var guard := GameConfig.Combat.SHIELD_SPEED if guarding else 1.0
			var speed := (P.RUN_SPEED if running else P.WALK_SPEED * minf(1.0, mag / 0.55)) * speed_mul * guard
			var terrain := _terrain_factor(map)
			tx = dir[0] * speed * terrain
			ty = dir[1] * speed * terrain
	elif state == "fetch":
		var half := 1.0 if state_time < state_duration * 0.5 else -1.0
		tx = _fetch_x * P.RUN_SPEED * 0.9 * half
		ty = _fetch_y * P.RUN_SPEED * 0.9 * half
		running = true
	var rate := P.ACCEL if JsMath.hypot(tx, ty) > JsMath.hypot(vx, vy) else P.DECEL
	var k := 1.0 - exp(-rate * dt)
	vx += (tx - vx) * k
	vy += (ty - vy) * k
	var kd := exp(-9.0 * dt)
	knock_x *= kd
	knock_y *= kd
	var mx := (vx + push_x + knock_x) * dt
	var my := (vy + push_y + knock_y) * dt
	push_x = 0.0
	push_y = 0.0
	if mx != 0.0 or my != 0.0:
		var r := map.move_circle(gx, gy, mx, my, P.RADIUS)
		gx = r[0]
		gy = r[1]
	# Energy: spent only by running the player asked for; recovers otherwise.
	var activity := "idle"
	if moving:
		activity = "run" if running and _run_wanted is bool and _run_wanted else "walk"
	energy_event = energy.update(dt, activity)
	# Facing follows the velocity (not while knocked back, nor behind a raised shield).
	if JsMath.hypot(vx, vy) > 0.3 and state != "hurt" and not guarding:
		var d := IsoGrid.dir_from_grid_vector(vx, vy, facing)
		if state == "fetch" or controllable:
			facing = d
	iso.gx = gx
	iso.gy = gy
	_update_animation(dt)
	if is_inside_tree():
		_sync_node()


func _terrain_factor(map: WorldMapModel) -> float:
	var i := int(floor(gx))
	var j := int(floor(gy))
	var prop := map.prop_at(i, j)
	if prop != null and prop.kind == "bush":
		return BUSH_SPEED
	return TERRAIN_SPEED.get(map.ground_at(i, j), 1.0)


func _play(new_anim: String, dir: String, restart: bool = false) -> void:
	if new_anim != anim or restart:
		_anim_restart = true
	anim = new_anim
	anim_dir = dir


func _update_animation(dt: float) -> void:
	var speed := JsMath.hypot(vx, vy)
	var has_seated_idle := profile == null or profile.has_seated_idle
	var next := "idle"
	var state_anim: String = STATE_ANIM.get(state, "")
	if state_anim != "" and state != "free":
		next = state_anim
		# Eating/barking while walking keeps the legs moving.
		if (state == "eat" or state == "bark") and speed > 0.4 and state_time > 0.2:
			next = "run" if running else "walk"
	elif speed > P.WALK_SPEED * 1.15:
		next = "run"
	elif speed > 0.25:
		next = "walk"
	elif energy.exhausted:
		next = "tired"
	else:
		var phase := int(floor(_idle_time / P.IDLE_PHASE_TIME))
		if has_seated_idle:
			next = "idle" if phase == 0 else ("sit" if phase % 2 == 1 else "sniff")
		else:
			next = "sniff" if phase % 2 == 1 else "idle"
	# Rest counts from the end of an action too: he stands, then sits.
	_idle_time = 0.0 if speed > 0.25 or state != "free" else _idle_time + dt
	_play(next, facing)
	# Fit the authored holds to the action timer, including the final standing pose.
	var timed := profile != null and profile.timed_actions.has(next)
	if next == state_anim and timed and state_duration > 0.0:
		anim_speed = float(profile.action_durations[next]) / state_duration
	else:
		anim_speed = maxf(0.6, speed / P.WALK_SPEED) if next == "walk" else 1.0
	# Squash & stretch spring (presentation, advanced on the logic tick like the source).
	var stiffness := 240.0
	var damping := 14.0
	_squash_vel += (-stiffness * _squash - damping * _squash_vel) * dt
	_squash += _squash_vel * dt
	if is_inside_tree():
		_apply_animation()


func _apply_animation() -> void:
	if body_sprite == null or body_sprite.sprite_frames == null:
		return
	var name := StringName("%s_%s" % [anim, anim_dir.to_lower()])
	if body_sprite.animation != name or _anim_restart:
		if _anim_restart or not body_sprite.animation.begins_with(anim + "_"):
			body_sprite.play(name)
			body_sprite.set_frame_and_progress(0, 0.0)
		else:
			# Same action, new facing: keep the cycle's phase (the source keeps its clock).
			var f := body_sprite.frame
			var p := body_sprite.frame_progress
			body_sprite.play(name)
			body_sprite.set_frame_and_progress(f, p)
		_anim_restart = false
	body_sprite.speed_scale = anim_speed
	var s := clampf(_squash, -0.35, 0.35)
	visual_root.scale = Vector2(1.0 - s * 0.6, 1.0 + s)
	var blink := invulnerable > 0.0 and int(floor(invulnerable * 12.0)) % 2 == 0
	body_sprite.modulate = Color(1, 0.5, 0.5) if state == "hurt" else Color.WHITE
	body_sprite.modulate.a = 0.35 if blink else 1.0


## Whole-pixel world position, like the source's Math.round in Entity.sync: every world object
## sits on integer coordinates so the camera's snapping moves them all alike (no relative shimmer).
func _sync_node() -> void:
	var s := IsoGrid.grid_to_screen_xy(gx, gy)
	position = Vector2(JsMath.round(s[0]), JsMath.round(s[1]))


## Screen-space velocity (for the camera look-ahead).
func screen_velocity() -> Vector2:
	return IsoGrid.grid_vec_to_screen(vx, vy)
