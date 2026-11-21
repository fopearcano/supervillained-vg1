class_name IsoGrid
extends RefCounted
## The single implementation of the 2:1 isometric projection (port of src/iso/projection.ts).
##
## Grid space: continuous (gx, gy); tile (i, j) covers [i, i+1) x [j, j+1). Map rows are gy,
## columns gx. Screen space: logical pixels, y down; grid (0,0) projects to the TOP vertex of
## tile (0,0). Direction names are screen-space names: N is up on the display.

const TW := 32.0
const TH := 16.0
const HALF_W := TW / 2.0
const HALF_H := TH / 2.0

## Clockwise from East, matching atan2 with y pointing down.
const DIRS_BY_ANGLE: Array[String] = ["E", "SE", "S", "SW", "W", "NW", "N", "NE"]
## Sheet row order and the canonical list of the eight facings.
const DIRS8: Array[String] = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]

## Offset that places a TileMapLayer (Godot cell centres) on the source tile centres. Measured on
## Godot 4.7.2 for TILE_SHAPE_ISOMETRIC + TILE_LAYOUT_DIAMOND_DOWN + horizontal offset axis:
## map_to_local(i, j) == grid_to_screen(i + 0.5, j + 0.5) + (16, 0). Proven by test MAP-003b.
const TILE_LAYER_OFFSET := Vector2(-16, 0)


static func grid_to_screen(gx: float, gy: float) -> Vector2:
	return Vector2((gx - gy) * HALF_W, (gx + gy) * HALF_H)


static func grid_to_screen_v(g: Vector2) -> Vector2:
	return Vector2((g.x - g.y) * HALF_W, (g.x + g.y) * HALF_H)


static func screen_to_grid(sx: float, sy: float) -> Vector2:
	return Vector2(sy / TH + sx / TW, sy / TH - sx / TW)


## Screen-space position of the centre of tile (i, j).
static func tile_center_screen(i: int, j: int) -> Vector2:
	return grid_to_screen(i + 0.5, j + 0.5)


## A screen-space direction (joystick: up = up on screen) as a unit grid-space direction.
static func screen_dir_to_grid(dx: float, dy: float) -> Vector2:
	var g := screen_dir_to_grid_xy(dx, dy)
	return Vector2(g[0], g[1])


# --- 64-bit variants: rule math (Godot's Vector2 is 32-bit; positions stay in doubles) ---------

static func grid_to_screen_xy(gx: float, gy: float) -> PackedFloat64Array:
	return PackedFloat64Array([(gx - gy) * HALF_W, (gx + gy) * HALF_H])


static func screen_to_grid_xy(sx: float, sy: float) -> PackedFloat64Array:
	return PackedFloat64Array([sy / TH + sx / TW, sy / TH - sx / TW])


static func screen_dir_to_grid_xy(dx: float, dy: float) -> PackedFloat64Array:
	var gx := dy + dx * (TH / TW)
	var gy := dy - dx * (TH / TW)
	var length := JsMath.hypot(gx, gy)
	if length < 1e-9:
		return PackedFloat64Array([0.0, 0.0])
	return PackedFloat64Array([gx / length, gy / length])


static func dir_to_grid_xy(d: String) -> PackedFloat64Array:
	var a := DIRS_BY_ANGLE.find(d) * PI / 4.0
	return screen_dir_to_grid_xy(cos(a), sin(a))


## A grid-space vector as the (unnormalized) screen-space vector it projects to.
static func grid_vec_to_screen(dgx: float, dgy: float) -> Vector2:
	return Vector2((dgx - dgy) * HALF_W, (dgx + dgy) * HALF_H)


## Nearest of the eight screen directions for a screen-space vector.
static func dir_from_screen_vector(dx: float, dy: float, fallback: String = "S") -> String:
	if absf(dx) < 1e-9 and absf(dy) < 1e-9:
		return fallback
	var a := atan2(dy, dx)
	var idx := ((int(_js_round(a / (PI / 4.0))) % 8) + 8) % 8
	return DIRS_BY_ANGLE[idx]


## Nearest of the eight screen directions for a grid-space vector (2:1 squash undone).
static func dir_from_grid_vector(dgx: float, dgy: float, fallback: String = "S") -> String:
	return dir_from_screen_vector((dgx - dgy) * HALF_W, (dgx + dgy) * HALF_H * 2.0, fallback)


static func dir_to_screen_vector(d: String) -> Vector2:
	var i := DIRS_BY_ANGLE.find(d)
	var a := i * PI / 4.0
	return Vector2(cos(a), sin(a))


## Unit grid-space vector of a facing (as seen on the ground plane).
static func dir_to_grid_vector(d: String) -> Vector2:
	var g := dir_to_grid_xy(d)
	return Vector2(g[0], g[1])


static func mirror_dir(d: String) -> String:
	match d:
		"E": return "W"
		"W": return "E"
		"NE": return "NW"
		"NW": return "NE"
		"SE": return "SW"
		"SW": return "SE"
	return d


static func depth_key(gx: float, gy: float) -> float:
	return gx + gy


## JavaScript Math.round (halves round toward +infinity), used where the source rounds.
static func _js_round(x: float) -> float:
	return JsMath.round(x)
