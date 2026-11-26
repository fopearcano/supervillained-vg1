class_name StoryActor
extends CharacterBody2D
## A story character (port of src/entities/actor.ts): a cast role's SpriteFrames
## (idle/walk/run/bark/hurt × 8 directions), or the Professor's legs (the `legs` story sprite at the
## dog's eye level, RD-13). Authoritative position in grid space; explicit behaviours idle / goto /
## follow / patrol / chase / flee / wander move on the shared WorldMapModel grid solver (no
## pathfinding; authored straight paths). A fighter (CombatController) carries a CombatRules.Foe:
## staggered or swinging it stands its ground; blows push it back (a decaying knock). A watcher
## has a sight cone (range, half-angle) and an alert level the walk fills. A speaking gesture plays
## the "bark" clip once and returns to idle (src/story/dialogueGestures.ts). Randomness (wander, a
## cornered flee) comes from a generator seeded by the handle, so a run is reproducible.
## CharacterBody2D like PlayableDog, for Area2D interactions.

const RADIUS := 0.26
## A goto has arrived within this distance (tiles) of its target, and only then.
const ARRIVE_DISTANCE := 0.05
## Human roles whose "bark" slot is a speaking gesture (src/story/dialogueGestures.ts).
const GESTURE_ROLES := ["professor", "niketas", "fulk", "clerk", "abbot", "envoy", "bishop", "cook",
	"sailmaker", "prince", "householdWoman", "knight", "pilgrim", "venetian", "greek"]
const BEHAVIORS := ["idle", "goto", "follow", "patrol", "chase", "flee", "wander", "flail"]
const C := GameConfig.Combat

var role := ""
var handle := ""
var gx := 0.0
var gy := 0.0
var facing := "S"
## Grid-space facing (unit vector): sight cones; `facing` is its 8-way animation direction.
var facing_vec := Vector2(0, 1)
var behavior := "idle"
var target := Vector2.ZERO
var speed := 2.0
var running := false
var arrived := true
## follow: keeps this far behind the player and `follow_side` tiles to his side.
var follow_gap := 1.2
var follow_side := 0.0
## idle: keeps turning to the player.
var face_player_always := false
## patrol: the points (grid), the pause at each.
var patrol_points: Array = []
var patrol_pause := 0.8
var patrol_index := 0
var _pause_left := 0.0
## chase: radius, home (where it gives up to), leash from home (0 = none), stop distance.
var chase_radius := 5.0
var home := Vector2.ZERO
var leash := 0.0
var stop_at := 0.3
## flee (only while he is this close) / wander (around `home`).
var area_radius := 3.0
var _wander_target: Variant = null
var _think := 0.0
var _flee_dir := Vector2.ZERO
## A fighter's state (CombatController), or null.
var foe: CombatRules.Foe = null
## Touching Zampanò counts as being caught (stealth walks).
var hostile := false
## A sight cone (stealth walks): range in tiles (0 = none), half-angle in radians; alert 0..1.
var sight_range := 0.0
var sight_half_angle := 0.0
var alert := 0.0
var knock_x := 0.0
var knock_y := 0.0
var hit_flash := 0.0
var iso := IsoRenderable.new()
var anim := "idle"
## A one-shot clip in progress ("" = none) and its remaining time.
var action_anim := ""
var action_left := 0.0
var gestures := 0
var _sprite: AnimatedSprite2D
var _legs: Array[Texture2D] = []
var _legs_sprite: Sprite2D
var _walk_t := 0.0
var _time := 0.0
var _rng := RandomNumberGenerator.new()


func setup(p_handle: String, p_role: String, catalog: SpriteCatalog) -> StoryActor:
	handle = p_handle
	role = p_role
	name = "Actor_" + p_handle
	_rng.seed = hash(p_handle)
	if role == "legs":
		for v in 4:
			_legs.append(catalog.texture("legs_%d" % v))
		_legs_sprite = Sprite2D.new()
		_legs_sprite.texture = _legs[0]
		_legs_sprite.centered = false
		_legs_sprite.offset = -Vector2(catalog.anchor("legs_0"))
		add_child(_legs_sprite)
	else:
		var path := StoryCast.frames_path(role)
		assert(path != "", "StoryActor: no SpriteFrames for role '%s'" % role)
		_sprite = AnimatedSprite2D.new()
		_sprite.sprite_frames = load(path)
		_sprite.centered = false
		_sprite.offset = Vector2(-20, -36)
		add_child(_sprite)
	iso.node = self
	return self


func set_grid_position(x: float, y: float) -> void:
	gx = x
	gy = y
	_sync()
	reset_physics_interpolation()


func face(dir: String) -> void:
	facing = dir
	var g := IsoGrid.dir_to_grid_xy(dir)
	facing_vec = Vector2(g[0], g[1]).normalized()


func face_point(p: Vector2) -> void:
	var d := p - Vector2(gx, gy)
	if d.length() > 1e-6:
		facing = IsoGrid.dir_from_grid_vector(d.x, d.y, facing)
		facing_vec = d.normalized()


func set_idle(p_face_player: bool = false) -> void:
	behavior = "idle"
	arrived = true
	face_player_always = p_face_player


func go_to(p: Vector2, p_speed: float, run: bool = false) -> void:
	behavior = "goto"
	target = p
	speed = p_speed
	running = run
	arrived = Vector2(gx, gy).distance_to(p) < ARRIVE_DISTANCE


func follow(p_speed: float, side: float = 0.0) -> void:
	behavior = "follow"
	speed = p_speed
	follow_side = side
	arrived = false


func patrol(points: Array, p_speed: float, pause: float) -> void:
	behavior = "patrol"
	patrol_points = points.duplicate()
	speed = p_speed
	patrol_pause = pause
	patrol_index = 0
	_pause_left = 0.0


func chase(p_speed: float, radius: float, p_home: Vector2, p_leash: float = 0.0, p_stop_at: float = 0.3) -> void:
	behavior = "chase"
	speed = p_speed
	chase_radius = radius
	home = p_home
	leash = p_leash
	stop_at = p_stop_at


func flee(p_speed: float, radius: float) -> void:
	behavior = "flee"
	speed = p_speed
	area_radius = radius
	_think = 0.0


## flail: a brawl within its radius — a new target often (seeded), always moving, running.
func flail(center: Vector2, radius: float, p_speed: float) -> void:
	behavior = "flail"
	home = center
	area_radius = radius
	speed = p_speed
	_wander_target = null


func wander(center: Vector2, radius: float, p_speed: float) -> void:
	behavior = "wander"
	home = center
	area_radius = radius
	speed = p_speed
	_wander_target = null


## A blow or a bark pushes it back (tiles/s, decaying).
func knock(vx: float, vy: float) -> void:
	knock_x = vx
	knock_y = vy


func flash_hit() -> void:
	hit_flash = 0.15


## One speaking gesture (only an idle human, only from idle).
func gesture() -> bool:
	if not GESTURE_ROLES.has(role) or behavior != "idle" or action_anim != "":
		return false
	play_action("bark", 0.6)
	gestures += 1
	return true


## A one-shot clip (a bark, a gesture, a hurt), then back to the behaviour's own clip.
func play_action(clip: String, seconds: float) -> void:
	action_anim = clip
	action_left = seconds


## One logic tick on the stage's map; `player` is followed, chased or fled from.
func tick(dt: float, map: WorldMapModel, player: Vector2) -> void:
	_time += dt
	if knock_x != 0.0 or knock_y != 0.0:
		var r := map.move_circle(gx, gy, knock_x * dt, knock_y * dt, RADIUS)
		gx = r[0]
		gy = r[1]
		var k := exp(-C.FOE_KNOCK_DECAY * dt)
		knock_x *= k
		knock_y *= k
		if absf(knock_x) < 1e-3 and absf(knock_y) < 1e-3:
			knock_x = 0.0
			knock_y = 0.0
	if hit_flash > 0.0:
		hit_flash = maxf(0.0, hit_flash - dt)
	modulate = Color(1.0, 0.5, 0.5) if hit_flash > 0.0 else Color.WHITE
	# A fighter staggered or swinging stands its ground, turned to him.
	if foe != null and not foe.routed and (foe.stun > 0.0 or foe.windup > 0.0):
		if foe.windup > 0.0:
			face_point(player)
		_finish_tick(dt, false, false)
		return
	var moving := false
	var run := false
	var dp := player.distance_to(Vector2(gx, gy))
	match behavior:
		"idle":
			if face_player_always:
				face_point(player)
		"goto":
			var d := target - Vector2(gx, gy)
			var length := d.length()
			if length < ARRIVE_DISTANCE:
				arrived = true
			else:
				var step := minf(length, speed * dt)
				var r := map.move_circle(gx, gy, d.x / length * step, d.y / length * step, RADIUS)
				var moved := Vector2(float(r[0]) - gx, float(r[1]) - gy).length() > 1e-9
				gx = r[0]
				gy = r[1]
				face_point(target)
				moving = moved
				# Arrival is distance only (the retained actor contract): a blocked actor has not
				# arrived (ActorStep's timeout reports it).
				arrived = Vector2(gx, gy).distance_to(target) < ARRIVE_DISTANCE
			run = running
		"follow":
			var d := player - Vector2(gx, gy)
			var length := d.length()
			if length > follow_gap:
				var goal := player - d / length * follow_gap
				if follow_side != 0.0:
					goal = player + Vector2(-d.y, d.x) / length * follow_side - d / length * follow_gap * 0.5
				var to := goal - Vector2(gx, gy)
				if to.length() > 0.05:
					var step := minf(to.length(), speed * dt)
					var r := map.move_circle(gx, gy, to.x / to.length() * step, to.y / to.length() * step, RADIUS)
					gx = r[0]
					gy = r[1]
					moving = true
				run = length > follow_gap * 2.0
			face_point(player)
		"patrol":
			if _pause_left > 0.0:
				_pause_left -= dt
				# Looks around while pausing.
				var a := atan2(facing_vec.y, facing_vec.x) + sin(_time * 2.0) * dt * 1.5
				facing_vec = Vector2(cos(a), sin(a))
				facing = IsoGrid.dir_from_grid_vector(facing_vec.x, facing_vec.y, facing)
			elif not patrol_points.is_empty():
				var p: Vector2 = patrol_points[patrol_index % patrol_points.size()]
				if _toward(p, speed, 0.15, dt, map):
					patrol_index += 1
					_pause_left = patrol_pause
				else:
					moving = true
		"chase":
			var from_home := player.distance_to(home)
			if dp < chase_radius and (leash <= 0.0 or from_home < leash):
				moving = not _toward(player, speed, stop_at, dt, map)
				run = true
			else:
				moving = not _toward(home, speed * 0.6, 0.15, dt, map)
		"flee":
			if dp < area_radius:
				_think -= dt
				if _think <= 0.0:
					_think = 0.2
					_flee_dir = _flee_direction(map, player)
				var r := map.move_circle(gx, gy, _flee_dir.x * speed * dt, _flee_dir.y * speed * dt, RADIUS)
				moving = Vector2(float(r[0]) - gx, float(r[1]) - gy).length() > 1e-9
				gx = r[0]
				gy = r[1]
				if _flee_dir != Vector2.ZERO:
					facing_vec = _flee_dir
					facing = IsoGrid.dir_from_grid_vector(_flee_dir.x, _flee_dir.y, facing)
				run = true
		"wander", "flail":
			var fast := behavior == "flail"
			if _wander_target == null or (_wander_target as Vector2).distance_to(Vector2(gx, gy)) < 0.3 or (fast and _rng.randf() < dt * 1.5):
				var a := _rng.randf() * TAU
				var rr := sqrt(_rng.randf()) * area_radius
				_wander_target = home + Vector2(cos(a), sin(a)) * rr
			moving = not _toward(_wander_target, speed, 0.15, dt, map)
			run = fast
	_finish_tick(dt, moving, run)


## Steps toward `p` at `spd` (stops within `stop`): true when there.
func _toward(p: Vector2, spd: float, stop: float, dt: float, map: WorldMapModel) -> bool:
	var d := p - Vector2(gx, gy)
	var length := d.length()
	if length <= stop:
		return true
	var step := minf(length, spd * dt)
	var r := map.move_circle(gx, gy, d.x / length * step, d.y / length * step, RADIUS)
	gx = r[0]
	gy = r[1]
	facing_vec = d / length
	facing = IsoGrid.dir_from_grid_vector(d.x, d.y, facing)
	return false


## Away from the player; when that way is blocked, the nearest open way around it (±45°, ±90°, …).
func _flee_direction(map: WorldMapModel, player: Vector2) -> Vector2:
	var away := Vector2(gx, gy) - player
	if away.length() < 1e-6:
		away = Vector2(_rng.randf() - 0.5, _rng.randf() - 0.5)
	var base := away.normalized()
	for k: int in [0, 1, -1, 2, -2, 3, -3]:
		var dir := base.rotated(k * PI / 4.0)
		var r := map.move_circle(gx, gy, dir.x * 0.4, dir.y * 0.4, RADIUS)
		if Vector2(float(r[0]) - gx, float(r[1]) - gy).length() > 0.3:
			return dir
	return Vector2.ZERO


func _finish_tick(dt: float, moving: bool, run: bool) -> void:
	if behavior != "goto":
		running = run
	if action_anim != "":
		action_left -= dt
		if action_left <= 0.0:
			action_anim = ""
	anim = action_anim if action_anim != "" else ("run" if moving and running else ("walk" if moving else "idle"))
	_walk_t = _walk_t + dt if moving else 0.0
	_sync()


func _sync() -> void:
	iso.gx = gx
	iso.gy = gy
	var at := IsoGrid.grid_to_screen_xy(gx, gy)
	position = Vector2(JsMath.round(at[0]), JsMath.round(at[1]))
	if _sprite:
		var clip := "%s_%s" % [anim, facing.to_lower()]
		if _sprite.sprite_frames.has_animation(clip) and _sprite.animation != StringName(clip):
			_sprite.play(StringName(clip))
	elif _legs_sprite:
		_legs_sprite.texture = _legs[int(floor(_walk_t * 6.0)) % _legs.size()] if anim == "walk" or anim == "run" else _legs[0]
		_legs_sprite.flip_h = facing.contains("W")
