class_name StoryProp
extends Node2D
## A story prop on the stage (the bowl, the ball, a pickup's sprite): a sprite-catalogue frame at a
## grid point, depth-sorted with the characters.

var handle := ""
var key := ""
var gx := 0.0
var gy := 0.0
var iso := IsoRenderable.new()
var _sprite := Sprite2D.new()


func setup(p_handle: String, catalog: SpriteCatalog, p_key: String, tint: Color = Color.WHITE) -> StoryProp:
	handle = p_handle
	key = p_key
	name = "Prop_" + p_handle
	_sprite.texture = catalog.texture(p_key)
	_sprite.centered = false
	_sprite.offset = -Vector2(catalog.anchor(p_key))
	_sprite.modulate = tint
	add_child(_sprite)
	iso.node = self
	return self


## Another frame of the catalogue (the fire's flicker).
func set_key(catalog: SpriteCatalog, p_key: String) -> void:
	if p_key == key:
		return
	key = p_key
	_sprite.texture = catalog.texture(p_key)
	_sprite.offset = -Vector2(catalog.anchor(p_key))


func set_grid_position(x: float, y: float) -> void:
	gx = x
	gy = y
	iso.gx = x
	iso.gy = y
	var at := IsoGrid.grid_to_screen_xy(x, y)
	position = Vector2(JsMath.round(at[0]), JsMath.round(at[1]))
