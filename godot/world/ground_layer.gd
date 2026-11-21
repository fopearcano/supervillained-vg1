class_name GroundLayer
extends TileMapLayer
## Ground cells with the dead-grass tint driven by the pollution model (port of the base-tile part
## of src/world/mapRenderer.ts). Runtime tile-data updates (ARCHITECTURE.md §7): `runtime_coords`
## holds every currently tinted cell, `reset_pending` cells that just returned to white; one
## layer-wide notify per non-empty change set; a reset cell stays eligible until its callback
## applied white, and is dropped on the next process tick.

const DEAD_GRASS := Color8(0xb0, 0x78, 0x4a)

var runtime_coords: Dictionary = {}
var reset_pending: Dictionary = {}
var notifications := 0


## Dead-grass tint for a dirt amount: lerp(white, 0xb0784a, min(1, dirt*1.3)) with per-channel
## JavaScript rounding, exactly like lerpColor in the source.
static func tint_for(dirt: float) -> Color:
	var t := minf(1.0, dirt * 1.3)
	var r := int(JsMath.round(255.0 + (0xb0 - 255.0) * t))
	var g := int(JsMath.round(255.0 + (0x78 - 255.0) * t))
	var b := int(JsMath.round(255.0 + (0x4a - 255.0) * t))
	return Color8(r, g, b)


## Applies the model's changed tiles. Returns true when a notification was issued.
func apply_changes(model: WorldMapModel, changed: Array) -> bool:
	var any := false
	for k: int in changed:
		var c := Vector2i(k % model.width, k / model.width)
		var tint := tint_for(model.dirt[k])
		if tint != Color.WHITE:
			if runtime_coords.get(c) != tint:
				runtime_coords[c] = tint
				reset_pending.erase(c)
				any = true
		elif runtime_coords.has(c):
			runtime_coords.erase(c)
			reset_pending[c] = false
			any = true
	if any:
		notify_runtime_tile_data_update()
		notifications += 1
	return any


func _process(_delta: float) -> void:
	for c: Vector2i in reset_pending.keys():
		if reset_pending[c]:
			reset_pending.erase(c)


func _use_tile_data_runtime_update(coords: Vector2i) -> bool:
	return runtime_coords.has(coords) or reset_pending.has(coords)


func _tile_data_runtime_update(coords: Vector2i, tile_data: TileData) -> void:
	if runtime_coords.has(coords):
		tile_data.modulate = runtime_coords[coords]
	else:
		tile_data.modulate = Color.WHITE
		if reset_pending.has(coords):
			reset_pending[coords] = true
