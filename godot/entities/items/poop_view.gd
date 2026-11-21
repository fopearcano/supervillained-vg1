class_name PoopView
extends Node2D
## Presentation of a PoopPileModel: half-hidden in bushes/tall grass, fades and swells when a pee
## cleans it (src/entities/items.ts).

var iso := IsoRenderable.new()
var model: PoopPileModel
var _sprite := Sprite2D.new()


func setup(catalog: SpriteCatalog, p_model: PoopPileModel) -> PoopView:
	model = p_model
	_sprite.texture = catalog.texture("poop_0")
	_sprite.centered = false
	_sprite.offset = -Vector2(catalog.anchor("poop_0"))
	add_child(_sprite)
	if model.surface == "low":
		_sprite.modulate.a = 0.75
	iso.node = self
	iso.gx = model.gx
	iso.gy = model.gy
	iso.depth_bias = -0.3
	iso.bounds = Rect2(-5, -9, 10, 10)
	position = IsoGrid.grid_to_screen(model.gx, model.gy)
	visible = false
	return self


func step(_dt: float) -> void:
	if model.cleaned:
		_sprite.modulate.a = maxf(0.0, 1.0 - model.fade_out * 2.5)
		scale = Vector2.ONE * (1.0 + model.fade_out * 0.6)
