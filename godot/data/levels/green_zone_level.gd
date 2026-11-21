class_name GreenZoneLevel
extends RefCounted
## Level 1 — the redesigned 96×96 Green Zone (deterministic port of src/levels/level1.ts):
## a chain of park districts with a fast gravel spine, garden loops, ponds, planting and
## landmarks, completed by a breadcrumb along the canonical shortest route.

const SIZE := 96

const MAIN_ROUTE: Array[Vector2] = [
	Vector2(90, 90), Vector2(84, 84), Vector2(76, 76), Vector2(69, 70), Vector2(63, 61), Vector2(57, 57),
	Vector2(51, 48), Vector2(43, 43), Vector2(36, 36), Vector2(29, 31), Vector2(22, 23), Vector2(15, 17),
	Vector2(8, 7), Vector2(4, 4),
]
const LOOPS := [
	[Vector2(90, 90), Vector2(92, 82), Vector2(86, 76), Vector2(78, 79), Vector2(80, 88), Vector2(90, 90)],
	[Vector2(76, 76), Vector2(78, 67), Vector2(72, 60), Vector2(63, 61), Vector2(61, 70), Vector2(68, 77), Vector2(76, 76)],
	[Vector2(58, 58), Vector2(52, 55), Vector2(47, 60), Vector2(51, 66), Vector2(58, 63), Vector2(58, 58)],
	[Vector2(50, 49), Vector2(53, 41), Vector2(48, 35), Vector2(40, 35), Vector2(35, 42), Vector2(41, 49), Vector2(50, 49)],
	[Vector2(50, 49), Vector2(60, 52), Vector2(69, 48), Vector2(72, 39), Vector2(67, 31), Vector2(57, 29), Vector2(48, 35)],
	[Vector2(58, 63), Vector2(47, 71), Vector2(36, 70), Vector2(31, 62), Vector2(39, 55), Vector2(47, 60), Vector2(58, 63)],
	[Vector2(30, 32), Vector2(23, 35), Vector2(17, 30), Vector2(18, 22), Vector2(25, 18), Vector2(32, 24), Vector2(30, 32)],
	[Vector2(16, 18), Vector2(9, 20), Vector2(5, 14), Vector2(4, 4), Vector2(12, 7), Vector2(16, 18)],
]
const HUBS: Array[Vector2] = [
	Vector2(87, 84), Vector2(72, 70), Vector2(55, 59), Vector2(38, 66), Vector2(44, 42), Vector2(68, 39),
	Vector2(24, 27), Vector2(10, 13),
]
## [cx, cy, rx, ry]
const PONDS := [[87, 83, 4.2, 2.8], [72, 68, 4.8, 3.3], [53, 60, 3.6, 2.5], [38, 66, 4.2, 2.6],
	[43, 40, 4.2, 2.8], [68, 39, 4.4, 3.0], [23, 27, 3.3, 4.4], [11, 13, 3.2, 2.2]]
const PLANTING := [[83, 88, 4.2, 2.2], [64, 73, 4.8, 2.4], [49, 57, 4.2, 2.4], [34, 64, 3.8, 2.2],
	[65, 34, 4.2, 2.4], [37, 46, 3.8, 2.6], [27, 20, 4.3, 2.1], [9, 18, 3.2, 2.1]]
const PLAZAS := [[57, 57, 3.8, 3.8], [44, 42, 4.2, 3.6], [24, 27, 3.5, 3.5]]
const LANDMARKS := [[89, 86, "F"], [82, 80, "P"], [75, 72, "F"], [66, 66, "P"], [38, 63, "F"],
	[56, 53, "F"], [63, 45, "P"], [68, 36, "F"], [50, 45, "P"], [39, 40, "F"],
	[31, 33, "P"], [20, 24, "F"], [14, 14, "P"], [8, 10, "F"]]

var _cells: Array = []


static func build_rows() -> PackedStringArray:
	return GreenZoneLevel.new()._build()


func _build() -> PackedStringArray:
	_cells = []
	for y in SIZE:
		var row: Array[String] = []
		row.resize(SIZE)
		row.fill("#")
		_cells.append(row)
	_paint_line(MAIN_ROUTE, 7.4, ".", {})
	for loop: Array in LOOPS:
		_paint_line(loop, 4.8, ".", {})
	for hub in HUBS:
		_paint_ellipse(hub.x, hub.y, 9.0, 8.0, ".", {})
	# Paths are painted after water, becoming bridges wherever a route crosses a pond.
	var lawn := {".": true}
	for p: Array in PONDS:
		_paint_ellipse(p[0], p[1], p[2], p[3], "W", lawn)
	for p: Array in PLANTING:
		_paint_ellipse(p[0], p[1], p[2], p[3], ",", lawn)
	var open := {".": true, ",": true, "W": true}
	_paint_line(MAIN_ROUTE, 1.55, "=", open)
	for loop: Array in LOOPS:
		_paint_line(loop, 1.05, "=", open)
	for p: Array in PLAZAS:
		_paint_ellipse(p[0], p[1], p[2], p[3], "=", open)
	# Deterministic detail pass. Trees stay off gravel, so every designed route remains viable.
	for y in range(2, SIZE - 2):
		for x in range(2, SIZE - 2):
			if _cells[y][x] != ".":
				continue
			var n := _noise(x, y)
			if n < 0.018:
				_cells[y][x] = "T"
			elif n < 0.046:
				_cells[y][x] = "B"
	for lm: Array in LANDMARKS:
		var c: String = _cells[lm[1]][lm[0]]
		if c == "." or c == "," or c == "W":
			_cells[lm[1]][lm[0]] = lm[2]
	_breadcrumb()
	_cells[90][90] = "S"
	_cells[4][4] = "E"
	var rows := PackedStringArray()
	for row: Array in _cells:
		rows.append("".join(row))
	return rows


func _paint_ellipse(cx: float, cy: float, rx: float, ry: float, ch: String, replace: Dictionary) -> void:
	var x0 := maxi(1, int(floor(cx - rx)))
	var x1 := mini(SIZE - 2, int(ceil(cx + rx)))
	var y0 := maxi(1, int(floor(cy - ry)))
	var y1 := mini(SIZE - 2, int(ceil(cy + ry)))
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			var dx := (x - cx) / rx
			var dy := (y - cy) / ry
			if dx * dx + dy * dy > 1.0:
				continue
			if replace.is_empty() or replace.has(_cells[y][x]):
				_cells[y][x] = ch


func _paint_line(points: Array, radius: float, ch: String, replace: Dictionary) -> void:
	for p in range(1, points.size()):
		var a: Vector2 = points[p - 1]
		var b: Vector2 = points[p]
		var steps := maxi(1, int(ceil(Vector2(b.x - a.x, b.y - a.y).length() * 2.0)))
		for k in range(steps + 1):
			var t := float(k) / steps
			_paint_ellipse(a.x + (b.x - a.x) * t, a.y + (b.y - a.y) * t, radius, radius, ch, replace)


static func _noise(x: int, y: int) -> float:
	var n := DeterministicRng.imul(x + 17, 0x45d9f3b) ^ DeterministicRng.imul(y + 31, 0x27d4eb2d)
	n ^= n >> 16
	return float(n & 0xFFFFFFFF) / 4294967295.0


## Completes the visual spine along the unweighted shortest route (S at 90,90 to E at 4,4).
func _breadcrumb() -> void:
	var distance := PackedInt32Array()
	distance.resize(SIZE * SIZE)
	distance.fill(-1)
	var queue: Array[int] = [4 * SIZE + 4]
	distance[queue[0]] = 0
	var head := 0
	while head < queue.size():
		var k := queue[head]
		head += 1
		var x := k % SIZE
		var y := k / SIZE
		for nb: Vector2i in [Vector2i(x + 1, y), Vector2i(x - 1, y), Vector2i(x, y + 1), Vector2i(x, y - 1)]:
			if nb.x < 0 or nb.y < 0 or nb.x >= SIZE or nb.y >= SIZE or _cells[nb.y][nb.x] == "#":
				continue
			var nk := nb.y * SIZE + nb.x
			if distance[nk] >= 0:
				continue
			distance[nk] = distance[k] + 1
			queue.append(nk)
	var x := 90
	var y := 90
	for guard in SIZE * SIZE:
		var d := distance[y * SIZE + x]
		if d <= 0:
			break
		var found := false
		for nb: Vector2i in [Vector2i(x + 1, y), Vector2i(x - 1, y), Vector2i(x, y + 1), Vector2i(x, y - 1)]:
			if nb.x >= 0 and nb.y >= 0 and nb.x < SIZE and nb.y < SIZE and distance[nb.y * SIZE + nb.x] == d - 1:
				x = nb.x
				y = nb.y
				found = true
				break
		if not found:
			break
		if (x != 4 or y != 4) and _cells[y][x] != "#":
			_cells[y][x] = "="


static func definition() -> LevelDefinition:
	var def := LevelDefinition.new()
	def.id = "level1"
	def.number = 1
	def.zone_name = "Green Zone"
	def.seed = 20240501
	def.par_time = 240.0
	def.environment = "ch01_greenzone"
	def.spawns = {
		"treats": {"count": 30, "maxOffset": 3, "minSpacing": 2.2},
		"cats": {"first": 16.0, "interval": [16.0, 27.0], "max": 2},
		"balls": {"first": 28.0, "interval": [22.0, 34.0], "max": 2},
	}
	def.events = {
		"underAttack": {"scriptedProgress": 0.56, "bagnaskizHits": 3},
		"pollutionWaves": [
			{"progress": 0.2, "count": 2, "radius": 2.4, "strength": 0.72, "distance": [3.0, 7.0]},
			{"progress": 0.43, "count": 2, "radius": 2.8, "strength": 0.82, "distance": [3.0, 8.0]},
			{"progress": 0.72, "count": 3, "radius": 3.0, "strength": 0.9, "distance": [2.0, 8.0]},
		],
	}
	def.rows = build_rows()
	return def


## Parses the definition's rows into a WorldMapModel (fails loudly on a malformed map).
static func load_model(def: LevelDefinition) -> WorldMapModel:
	var parsed := AsciiMapLoader.parse(def.rows, ".", def.require_exit)
	assert(parsed["ok"], "Green Zone map failed to parse: %s" % parsed.get("error"))
	return WorldMapModel.new(parsed["level"])
