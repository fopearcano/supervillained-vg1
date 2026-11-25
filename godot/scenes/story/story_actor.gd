class_name StoryActor
extends CharacterBody2D
## A story character (port of the parts of src/entities/actor.ts Level 1 uses): a cast role's
## SpriteFrames (idle/walk/run/bark/hurt × 8 directions), or the Professor's legs (the `legs`
## story sprite at the dog's eye level, RD-13). Authoritative position in grid space; explicit
## behaviours idle / goto / follow move on the shared WorldMapModel grid solver (no pathfinding;
## authored straight paths). A speaking gesture plays the "bark" clip once and returns to idle
## (src/story/dialogueGestures.ts). CharacterBody2D like PlayableDog, for Area2D interactions.

const RADIUS := 0.26
## Human roles whose "bark" slot is a speaking gesture (src/story/dialogueGestures.ts).
const GESTURE_ROLES := ["professor", "niketas", "fulk", "clerk", "abbot", "envoy", "bishop", "cook",
	"sailmaker", "prince", "householdWoman", "knight", "pilgrim", "venetian", "greek"]

var role := ""
var handle := ""
var gx := 0.0
var gy := 0.0
var facing := "S"
var behavior := "idle"
var target := Vector2.ZERO
var speed := 2.0
var running := false
var arrived := true
## follow: keeps this far behind the player.
var follow_gap := 1.2
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


func setup(p_handle: String, p_role: String, catalog: SpriteCatalog) -> StoryActor:
	handle = p_handle
	role = p_role
	name = "Actor_" + p_handle
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


func face_point(p: Vector2) -> void:
	if p.distance_to(Vector2(gx, gy)) > 1e-6:
		facing = IsoGrid.dir_from_grid_vector(p.x - gx, p.y - gy, facing)


func set_idle() -> void:
	behavior = "idle"
	arrived = true


func go_to(p: Vector2, p_speed: float, run: bool = false) -> void:
	behavior = "goto"
	target = p
	speed = p_speed
	running = run
	arrived = Vector2(gx, gy).distance_to(p) < 0.05


func follow(p_speed: float) -> void:
	behavior = "follow"
	speed = p_speed
	arrived = false


## One speaking gesture (only an idle human, only from idle).
func gesture() -> bool:
	if not GESTURE_ROLES.has(role) or behavior != "idle" or action_anim != "":
		return false
	play_action("bark", 0.6)
	gestures += 1
	return true


## A one-shot clip (a bark, a gesture), then back to the behaviour's own clip.
func play_action(clip: String, seconds: float) -> void:
	action_anim = clip
	action_left = seconds


## One logic tick on the stage's map; `player` is followed when the behaviour is follow.
func tick(dt: float, map: WorldMapModel, player: Vector2) -> void:
	var moving := false
	match behavior:
		"goto":
			var d := target - Vector2(gx, gy)
			var length := d.length()
			if length < 0.05:
				arrived = true
			else:
				var step := minf(length, speed * dt)
				var r := map.move_circle(gx, gy, d.x / length * step, d.y / length * step, RADIUS)
				var moved := Vector2(float(r[0]) - gx, float(r[1]) - gy).length() > 1e-9
				gx = r[0]
				gy = r[1]
				face_point(target)
				moving = moved
				arrived = Vector2(gx, gy).distance_to(target) < 0.05 or not moved
		"follow":
			var d := player - Vector2(gx, gy)
			var length := d.length()
			if length > follow_gap:
				var step := minf(length - follow_gap, speed * dt)
				var r := map.move_circle(gx, gy, d.x / length * step, d.y / length * step, RADIUS)
				gx = r[0]
				gy = r[1]
				moving = true
			face_point(player)
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
