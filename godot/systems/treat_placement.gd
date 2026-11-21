class_name TreatPlacement
extends RefCounted
## Deterministic treat placement and random spots (port of src/systems/placement.ts).


## Walks the canonical shortest route from start to exit and drops treats at regular progress
## intervals, offset sideways onto free tiles. Returns [[x, y], ...] in grid space (64-bit floats).
static func place_treats(map: WorldMapModel, settings: Dictionary, seed_value: int) -> Array:
	var rng := DeterministicRng.new(seed_value)
	var start_dist := map.exit_distance[map.index(map.start_tile.x, map.start_tile.y)]
	var path: Array = []  # [i, j, d]
	var ci := map.start_tile.x
	var cj := map.start_tile.y
	for guard in map.width * map.height + 1:
		var d := map.exit_distance[map.index(ci, cj)]
		if d < 0:
			break
		if map.ground_at(ci, cj) != TileCatalog.Ground.WATER:
			path.append([ci, cj, d])
		if d == 0:
			break
		var found := false
		for nb: Vector2i in [Vector2i(ci + 1, cj), Vector2i(ci - 1, cj), Vector2i(ci, cj + 1), Vector2i(ci, cj - 1)]:
			if map.is_walkable(nb.x, nb.y) and map.exit_distance[map.index(nb.x, nb.y)] == d - 1:
				ci = nb.x
				cj = nb.y
				found = true
				break
		if not found:
			break
	var out: Array = []
	var count: int = settings["count"]
	if path.is_empty() or count <= 0:
		return out
	var max_offset: int = settings["maxOffset"]
	var min_spacing: float = settings["minSpacing"]
	var step := maxf(1.0, (start_dist - 4.0) / count)
	var next_d := start_dist - 3.0
	while out.size() < count and next_d > 1.0:
		var candidates := _closest(path, next_d, 28)
		var placed := false
		for t: Array in candidates:
			for attempt in 8:
				var oi: int = t[0] + (0 if attempt == 0 else rng.int_range(-max_offset, max_offset))
				var oj: int = t[1] + (0 if attempt == 0 else rng.int_range(-max_offset, max_offset))
				if not map.is_walkable(oi, oj) or map.ground_at(oi, oj) == TileCatalog.Ground.WATER:
					continue
				var x := oi + rng.range_float(0.35, 0.65)
				var y := oj + rng.range_float(0.35, 0.65)
				var too_close := false
				for p: Array in out:
					if JsMath.hypot(p[0] - x, p[1] - y) < min_spacing:
						too_close = true
						break
				if too_close:
					continue
				if JsMath.hypot(map.start.x - x, map.start.y - y) < 2.0:
					continue
				out.append([x, y])
				placed = true
				break
			if placed:
				break
		next_d -= step
	return out


## The `limit` path entries closest to distance `target`, in a STABLE order (JavaScript's
## Array.prototype.sort is stable; ties keep route order).
static func _closest(path: Array, target: float, limit: int) -> Array:
	var keyed: Array = []
	for k in path.size():
		keyed.append([absf(path[k][2] - target), k])
	keyed.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0] or (a[0] == b[0] and a[1] < b[1]))
	var out: Array = []
	for k in mini(limit, keyed.size()):
		out.append(path[keyed[k][1]])
	return out


## Random walkable non-water spot [x, y] at distance [min_d, max_d] from (x, y), or null.
static func random_spot_near(map: WorldMapModel, x: float, y: float, min_d: float, max_d: float, rng: DeterministicRng, accept: Callable = Callable()) -> Variant:
	for attempt in 40:
		var a := rng.range_float(0.0, PI * 2.0)
		var d := rng.range_float(min_d, max_d)
		var px := x + cos(a) * d
		var py := y + sin(a) * d
		var i := int(floor(px))
		var j := int(floor(py))
		if not map.is_walkable(i, j) or (accept.is_valid() and not accept.call(i, j)):
			continue
		if map.ground_at(i, j) == TileCatalog.Ground.WATER:
			continue
		return [i + 0.5, j + 0.5]
	return null
