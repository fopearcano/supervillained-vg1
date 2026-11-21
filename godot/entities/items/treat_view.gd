class_name TreatView
extends Node2D
## A bone floating above the ground (presentation of a GreenZoneRules treat).

var iso := IsoRenderable.new()
var index := -1
var _t := 0.0
var _sprite := Sprite2D.new()


func setup(catalog: SpriteCatalog, p_index: int, gx: float, gy: float) -> TreatView:
	index = p_index
	var shadow := Sprite2D.new()
	shadow.texture = catalog.texture("shadowSmall_0")
	shadow.centered = false
	shadow.offset = -Vector2(catalog.anchor("shadowSmall_0"))
	add_child(shadow)
	_sprite.texture = catalog.texture("treat_0")
	_sprite.centered = false
	_sprite.offset = -Vector2(catalog.anchor("treat_0"))
	add_child(_sprite)
	# Deterministic bob phase per treat (the source used Math.random for this cosmetic offset).
	_t = DeterministicRng.hash2(p_index, 7, 11) * 6.0
	iso.node = self
	iso.gx = gx
	iso.gy = gy
	iso.bounds = Rect2(-7, -14, 14, 16)
	position = IsoGrid.grid_to_screen(gx, gy)
	visible = false
	return self


func step(dt: float) -> void:
	_t += dt
	_sprite.position.y = -4 - JsMath.round((sin(_t * 3.2) + 1.0) * 1.5)
