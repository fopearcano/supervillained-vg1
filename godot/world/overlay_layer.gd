class_name OverlayLayer
extends TileMapLayer
## Sparse overlay cells whose alpha follows the pollution model: the blotchy dirt overlay
## (alpha = 0.3 + 0.65·dirt above VISIBLE) or the fresh re-greened highlight
## (alpha = 0.85·(fresh/FRESH_TIME)^1.5). Only active cells exist in the layer; their alpha is
## applied through runtime tile-data updates, one notify per non-empty change set.

enum Kind { DIRT, FRESH }

@export var kind := Kind.DIRT
var source_id := 0
## For DIRT, the 4 dirt tile variants; for FRESH, the single fresh tile.
var tiles: Array[Vector2i] = []
var alpha_by_cell: Dictionary = {}
var notifications := 0


func apply_changes(model: WorldMapModel, changed: Array) -> bool:
	var any := false
	for k: int in changed:
		var i := k % model.width
		var j := k / model.width
		var c := Vector2i(i, j)
		var a := -1.0
		if kind == Kind.DIRT:
			var d := model.dirt[k]
			if d > GameConfig.Pollution.VISIBLE:
				a = GameConfig.Pollution.OVERLAY_MIN_ALPHA + (GameConfig.Pollution.OVERLAY_MAX_ALPHA - GameConfig.Pollution.OVERLAY_MIN_ALPHA) * d
		else:
			var f: float = model.fresh.get(k, 0.0)
			if f > 0.0:
				a = 0.85 * pow(minf(1.0, f / GameConfig.Pollution.FRESH_TIME), 1.5)
		if a < 0.0:
			if alpha_by_cell.has(c):
				alpha_by_cell.erase(c)
				erase_cell(c)
				any = true
			continue
		if not alpha_by_cell.has(c):
			var tile := tiles[0]
			if kind == Kind.DIRT:
				tile = tiles[int(floor(DeterministicRng.hash2(i, j, 9) * tiles.size()))]
			set_cell(c, source_id, tile)
		if alpha_by_cell.get(c, -2.0) != a:
			alpha_by_cell[c] = a
			any = true
	if any:
		notify_runtime_tile_data_update()
		notifications += 1
	return any


func _use_tile_data_runtime_update(coords: Vector2i) -> bool:
	return alpha_by_cell.has(coords)


func _tile_data_runtime_update(coords: Vector2i, tile_data: TileData) -> void:
	tile_data.modulate = Color(1, 1, 1, alpha_by_cell.get(coords, 1.0))
