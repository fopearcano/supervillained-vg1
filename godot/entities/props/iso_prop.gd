class_name IsoProp
extends Node2D
## Static scenery: trees, bushes, poles, fountains, forest trees, the exit flag (port of
## src/entities/prop.ts). One Sprite2D anchored at the contact point; tall props fade when they
## hide the playable dog.

var iso := IsoRenderable.new()
var kind: String
var map_prop: WorldMapModel.MapProp
var sprite := Sprite2D.new()


func setup(catalog: SpriteCatalog, sprite_key: String, gx: float, gy: float, p_map_prop: WorldMapModel.MapProp, fadeable: bool) -> IsoProp:
	kind = sprite_key.get_slice("_", 0)
	map_prop = p_map_prop
	sprite.texture = catalog.texture(sprite_key)
	sprite.centered = false
	var anchor := catalog.anchor(sprite_key)
	var size := catalog.size_of(sprite_key)
	sprite.offset = -Vector2(anchor)
	add_child(sprite)
	iso.node = self
	iso.gx = gx
	iso.gy = gy
	iso.fadeable = fadeable
	iso.bounds = Rect2(-anchor.x, -anchor.y, size.x, size.y)
	position = IsoGrid.grid_to_screen(gx, gy)
	visible = false
	return self
