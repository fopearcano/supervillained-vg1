class_name CritterView
extends Node2D
## Presentation of a Green Zone critter controller (src/entities/critters.ts views): a cat or
## Bagnaskiz as an animated sheet with its shadow, or a bouncing ball. Reads the controller after
## each logic tick; never changes rule state.

const CAT_FRAMES: SpriteFrames = preload("res://data/characters/cast/cat_frames.tres")
## CHARACTERS.cat foot anchor (src/assets/manifest.ts).
const CAT_ANCHOR := Vector2i(14, 25)
const BAGNASKIZ_PROFILE := "res://data/characters/bagnaskiz_profile.tres"

var iso := IsoRenderable.new()
## CatController, BallController or BagnaskizController.
var model: RefCounted
var _body: Node2D
var _sprite: AnimatedSprite2D = null
var _ball: Sprite2D = null
var _restarts := -1


func setup_cat(catalog: SpriteCatalog, cat: CritterControllers.CatController) -> CritterView:
	model = cat
	_shadow(catalog, "shadowSmall_0")
	_animated(CAT_FRAMES, CAT_ANCHOR)
	_sprite.modulate = cat.tint
	iso.bounds = Rect2(-12, -24, 24, 26)
	return _finish(cat.gx, cat.gy)


func setup_ball(catalog: SpriteCatalog, ball: CritterControllers.BallController) -> CritterView:
	model = ball
	_shadow(catalog, "shadowSmall_0")
	_body = Node2D.new()
	add_child(_body)
	_ball = Sprite2D.new()
	_ball.texture = catalog.texture("ball_0")
	_ball.centered = false
	_ball.offset = -Vector2(catalog.anchor("ball_0"))
	_body.add_child(_ball)
	iso.bounds = Rect2(-5, -14, 10, 16)
	return _finish(ball.gx, ball.gy)


func setup_bagnaskiz(catalog: SpriteCatalog, pug: CritterControllers.BagnaskizController) -> CritterView:
	model = pug
	var profile: PlayableCharacterProfile = load(BAGNASKIZ_PROFILE)
	_shadow(catalog, "shadow_0")
	_animated(profile.normal_frames, profile.foot_anchor)
	iso.bounds = Rect2(-15, -32, 30, 35)
	return _finish(pug.gx, pug.gy)


func _shadow(catalog: SpriteCatalog, key: String) -> void:
	var s := Sprite2D.new()
	s.texture = catalog.texture(key)
	s.centered = false
	s.offset = -Vector2(catalog.anchor(key))
	add_child(s)


func _animated(frames: SpriteFrames, anchor: Vector2i) -> void:
	_body = Node2D.new()
	add_child(_body)
	_sprite = AnimatedSprite2D.new()
	_sprite.sprite_frames = frames
	_sprite.centered = false
	_sprite.offset = -Vector2(anchor)
	_body.add_child(_sprite)


func _finish(gx: float, gy: float) -> CritterView:
	iso.node = self
	sync()
	visible = false
	return self


## Mirrors the controller (called after every logic tick).
func sync() -> void:
	var gx: float = model.get("gx")
	var gy: float = model.get("gy")
	iso.gx = gx
	iso.gy = gy
	var at := IsoGrid.grid_to_screen_xy(gx, gy)
	position = Vector2(JsMath.round(at[0]), JsMath.round(at[1]))
	if model is CritterControllers.BallController:
		var b := model as CritterControllers.BallController
		_ball.position.y = -JsMath.round(absf(sin(b.t * 4.0)) * 6.0)
		modulate.a = b.fade
		return
	var a: CritterControllers.Anim = model.get("anim")
	var anim_name := StringName("%s_%s" % [a.anim, a.dir.to_lower()])
	if a.restarts != _restarts or not _sprite.animation.begins_with(a.anim + "_"):
		_restarts = a.restarts
		_sprite.play(anim_name)
		_sprite.set_frame_and_progress(0, 0.0)
	elif _sprite.animation != anim_name:
		var f := _sprite.frame
		var p := _sprite.frame_progress
		_sprite.play(anim_name)
		_sprite.set_frame_and_progress(f, p)
	modulate.a = float(model.get("fade"))
	if model is CritterControllers.CatController:
		var cat := model as CritterControllers.CatController
		_body.position.y = -JsMath.round(cat.z)
		iso.z_lift = cat.z
	elif model is CritterControllers.BagnaskizController:
		var pug := model as CritterControllers.BagnaskizController
		var blink := pug.state == "stunned" and int(floor(pug.state_time * 16.0)) % 2 == 0
		_sprite.modulate = Color8(0xff, 0x90, 0x90) if blink else Color.WHITE
