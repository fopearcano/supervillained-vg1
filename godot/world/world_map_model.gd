class_name WorldMapModel
extends RefCounted
## Runtime map (port of src/world/map.ts GameMap): ground, props, collision queries, the per-tile
## pollution ("dirt") field that drives zone health, and BFS distance to the exit.
## Pure model: no Nodes; testable headless. Dirt is stored as float32 exactly like the source's
## Float32Array so thresholds and fixtures agree bit-for-bit.

const Ground := TileCatalog.Ground


class MapProp:
	extends RefCounted
	var id: int
	var kind: String
	var i: int
	var j: int
	## Grid-space centre of the tile.
	var x: float
	var y: float
	var solid: bool
	var radius: float
	var tall: bool
	var vertical: bool


var width: int
var height: int
var ground: PackedByteArray
var props: Array[MapProp] = []
## Tile index -> prop index, or -1.
var prop_index: PackedInt32Array
## Pollution per tile, 0 (clean) .. 1 (fully polluted).
var dirt: PackedFloat32Array
## 1 if the tile counts towards zone health.
var playable: PackedByteArray
var playable_count := 0
var clean_count := 0
## Tiles whose dirt or fresh highlight changed since the renderer last looked (index -> true).
var changed: Dictionary = {}
## Tiles showing the "re-greened" highlight: index -> remaining seconds.
var fresh: Dictionary = {}
## Steps (4-connected) from each tile to the exit; -1 if unreachable.
var exit_distance: PackedInt32Array
var start: Vector2
var exit: Vector2
var start_tile: Vector2i
var exit_tile: Vector2i
var markers: Dictionary = {}


func _init(level: Dictionary) -> void:
	width = level["width"]
	height = level["height"]
	ground = (level["ground"] as PackedByteArray).duplicate()
	var n := width * height
	prop_index = PackedInt32Array()
	prop_index.resize(n)
	prop_index.fill(-1)
	dirt = PackedFloat32Array()
	dirt.resize(n)
	playable = PackedByteArray()
	playable.resize(n)
	var id := 0
	for p: Dictionary in level["props"]:
		var mp := MapProp.new()
		mp.id = id
		mp.kind = p["kind"]
		mp.i = p["i"]
		mp.j = p["j"]
		mp.x = mp.i + 0.5
		mp.y = mp.j + 0.5
		mp.solid = TileCatalog.prop_solid(mp.kind)
		mp.radius = TileCatalog.prop_radius(mp.kind)
		mp.tall = TileCatalog.prop_tall(mp.kind)
		mp.vertical = TileCatalog.prop_vertical(mp.kind)
		props.append(mp)
		prop_index[mp.j * width + mp.i] = id
		id += 1
	for k in n:
		var g := ground[k]
		var pi := prop_index[k]
		var solid_prop := pi >= 0 and props[pi].solid
		if TileCatalog.is_ground_walkable(g) and g != Ground.WATER and not solid_prop:
			playable[k] = 1
			playable_count += 1
	clean_count = playable_count
	start_tile = level["start"]
	exit_tile = level["exit"]
	markers = level.get("markers", {})
	start = Vector2(start_tile.x + 0.5, start_tile.y + 0.5)
	exit = Vector2(exit_tile.x + 0.5, exit_tile.y + 0.5)
	exit_distance = bfs(exit_tile.x, exit_tile.y)


func in_bounds(i: int, j: int) -> bool:
	return i >= 0 and j >= 0 and i < width and j < height


func index(i: int, j: int) -> int:
	return j * width + i


func ground_at(i: int, j: int) -> int:
	if not in_bounds(i, j):
		return Ground.VOID
	return ground[j * width + i]


func prop_at(i: int, j: int) -> MapProp:
	if not in_bounds(i, j):
		return null
	var pi := prop_index[j * width + i]
	return props[pi] if pi >= 0 else null


## Ground blocks movement (forest border, void, outside the map).
func is_blocked_tile(i: int, j: int) -> bool:
	return not TileCatalog.is_ground_walkable(ground_at(i, j))


## A character can stand on the tile centre.
func is_walkable(i: int, j: int) -> bool:
	if is_blocked_tile(i, j):
		return false
	var p := prop_at(i, j)
	return not (p != null and p.solid)


## True if a circle overlaps a blocked tile square or a solid prop.
func circle_blocked(x: float, y: float, r: float) -> bool:
	var i0 := int(floor(x - r - 1.0))
	var i1 := int(floor(x + r + 1.0))
	var j0 := int(floor(y - r - 1.0))
	var j1 := int(floor(y + r + 1.0))
	for j in range(j0, j1 + 1):
		for i in range(i0, i1 + 1):
			if is_blocked_tile(i, j):
				var cx := maxf(i, minf(x, i + 1))
				var cy := maxf(j, minf(y, j + 1))
				var dx := x - cx
				var dy := y - cy
				if dx * dx + dy * dy < r * r:
					return true
			else:
				var p := prop_at(i, j)
				if p != null and p.solid:
					var rr := r + p.radius
					var dx := x - p.x
					var dy := y - p.y
					if dx * dx + dy * dy < rr * rr:
						return true
	return false


## Moves a circle by (dx, dy) with sliding: solid props push the circle out radially, blocked tile
## squares stop the motion per axis. This grid-space solver is authoritative for static geometry.
## Returns [x, y, blocked].
func move_circle(x: float, y: float, dx: float, dy: float, r: float) -> Array:
	var blocked := false
	var nx := x + dx
	var ny := y + dy
	var pushed := _push_out_of_props(nx, ny, r)
	if not circle_blocked(pushed[0], pushed[1], r):
		return [pushed[0], pushed[1], pushed[2]]
	nx = x + dx
	if circle_blocked(nx, y, r):
		nx = x
		blocked = true
	ny = y + dy
	if circle_blocked(nx, ny, r):
		ny = y
		blocked = true
	return [nx, ny, blocked]


func _push_out_of_props(x: float, y: float, r: float) -> Array:
	var moved := false
	var i0 := int(floor(x - r - 1.0))
	var i1 := int(floor(x + r + 1.0))
	var j0 := int(floor(y - r - 1.0))
	var j1 := int(floor(y + r + 1.0))
	for j in range(j0, j1 + 1):
		for i in range(i0, i1 + 1):
			var p := prop_at(i, j)
			if p == null or not p.solid:
				continue
			var rr := r + p.radius
			var dx := x - p.x
			var dy := y - p.y
			var d2 := dx * dx + dy * dy
			if d2 < rr * rr:
				var d := sqrt(d2)
				if d == 0.0:
					d = 1e-4
				x = p.x + (dx / d) * (rr + 1e-4)
				y = p.y + (dy / d) * (rr + 1e-4)
				moved = true
	return [x, y, moved]


## How bad a poop is here: bushes/tall grass = low, path = heavy, grass = medium.
func poop_surface_at(x: float, y: float) -> String:
	var i := int(floor(x))
	var j := int(floor(y))
	var p := prop_at(i, j)
	if p != null and p.kind == "bush":
		return "low"
	var g := ground_at(i, j)
	if g == Ground.TALL_GRASS:
		return "low"
	if g == Ground.PATH:
		return "heavy"
	return "medium"


static func poop_footprint(surface: String) -> Dictionary:
	match surface:
		"low": return GameConfig.Poop.LOW
		"heavy": return GameConfig.Poop.HEAVY
	return GameConfig.Poop.MEDIUM


func is_water_at(x: float, y: float) -> bool:
	return ground_at(int(floor(x)), int(floor(y))) == Ground.WATER


## Nearest prop matching the predicate within max_dist (distance to its edge).
func nearest_prop(x: float, y: float, max_dist: float, pred: Callable) -> MapProp:
	var best: MapProp = null
	var best_d := max_dist
	var r := int(ceil(max_dist)) + 1
	var ci := int(floor(x))
	var cj := int(floor(y))
	for j in range(cj - r, cj + r + 1):
		for i in range(ci - r, ci + r + 1):
			var p := prop_at(i, j)
			if p == null or not pred.call(p):
				continue
			var d := JsMath.hypot(p.x - x, p.y - y) - p.radius
			if d <= best_d:
				best_d = d
				best = p
	return best


## Stamps pollution around (cx, cy); dirt never decreases here (max blend).
## Returns the number of tiles that went from clean to polluted.
func stamp_dirt(cx: float, cy: float, radius: float, strength: float) -> int:
	var newly := 0
	var i0 := maxi(0, int(floor(cx - radius)))
	var i1 := mini(width - 1, int(floor(cx + radius)))
	var j0 := maxi(0, int(floor(cy - radius)))
	var j1 := mini(height - 1, int(floor(cy + radius)))
	for j in range(j0, j1 + 1):
		for i in range(i0, i1 + 1):
			var d := JsMath.hypot(i + 0.5 - cx, j + 0.5 - cy)
			if d > radius:
				continue
			var k := j * width + i
			if playable[k] == 0:
				continue
			var t := d / radius
			var amount := strength * (1.0 - 0.55 * t * t)
			var old := dirt[k]
			if amount <= old:
				continue
			dirt[k] = amount
			changed[k] = true
			if old < GameConfig.Pollution.CLEAN_THRESHOLD and amount >= GameConfig.Pollution.CLEAN_THRESHOLD:
				clean_count -= 1
				newly += 1
	return newly


## Cleans and re-greens every tile within the radius. Returns tiles that went polluted -> clean.
func clean(cx: float, cy: float, radius: float) -> int:
	var cleaned := 0
	var i0 := maxi(0, int(floor(cx - radius)))
	var i1 := mini(width - 1, int(floor(cx + radius)))
	var j0 := maxi(0, int(floor(cy - radius)))
	var j1 := mini(height - 1, int(floor(cy + radius)))
	for j in range(j0, j1 + 1):
		for i in range(i0, i1 + 1):
			var d := JsMath.hypot(i + 0.5 - cx, j + 0.5 - cy)
			if d > radius:
				continue
			var k := j * width + i
			if playable[k] == 0:
				continue
			var old := dirt[k]
			if old > 0.0:
				if old >= GameConfig.Pollution.CLEAN_THRESHOLD:
					clean_count += 1
					cleaned += 1
				dirt[k] = 0.0
			fresh[k] = GameConfig.Pollution.FRESH_TIME
			changed[k] = true
	return cleaned


## Fraction of playable tiles that are clean (0..1).
func health() -> float:
	return float(clean_count) / playable_count if playable_count > 0 else 1.0


func dirt_at(x: float, y: float) -> float:
	var i := int(floor(x))
	var j := int(floor(y))
	return dirt[index(i, j)] if in_bounds(i, j) else 0.0


## Advances the fresh-highlight timers.
func update(dt: float) -> void:
	for k: int in fresh.keys():
		var nt: float = fresh[k] - dt
		if nt <= 0.0:
			fresh.erase(k)
		else:
			fresh[k] = nt
		changed[k] = true


## Level progress 0 (start) .. 1 (exit) by walking distance to the exit.
func progress_at(x: float, y: float) -> float:
	var i := int(floor(x))
	var j := int(floor(y))
	if not in_bounds(i, j):
		return 0.0
	var d := exit_distance[index(i, j)]
	var d0 := exit_distance[index(start_tile.x, start_tile.y)]
	if d < 0 or d0 <= 0:
		return 0.0
	return clampf(1.0 - float(d) / d0, 0.0, 1.0)


## 4-connected BFS distances over walkable tiles.
func bfs(si: int, sj: int) -> PackedInt32Array:
	var n := width * height
	var dist := PackedInt32Array()
	dist.resize(n)
	dist.fill(-1)
	var queue := PackedInt32Array()
	queue.resize(n)
	var head := 0
	var tail := 0
	var s := index(si, sj)
	dist[s] = 0
	queue[tail] = s
	tail += 1
	while head < tail:
		var k := queue[head]
		head += 1
		var i := k % width
		var j := (k - i) / width
		var nd := dist[k] + 1
		for nb: Vector2i in [Vector2i(i + 1, j), Vector2i(i - 1, j), Vector2i(i, j + 1), Vector2i(i, j - 1)]:
			if not is_walkable(nb.x, nb.y):
				continue
			var nk := index(nb.x, nb.y)
			if dist[nk] != -1:
				continue
			dist[nk] = nd
			queue[tail] = nk
			tail += 1
	return dist
