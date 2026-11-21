class_name PoopPileModel
extends RefCounted
## A poop pile (port of PoopPile in src/entities/items.ts, rule half). Its stain slowly spreads
## until a pee neutralises it; then it fades out over 0.4 s and is removed.

var gx: float
var gy: float
var surface: String
var base_radius: float
var strength: float
var age := 0.0
var radius: float
var cleaned := false
var fade_out := 0.0
var _tick := 0.0


func _init(x: float, y: float, p_surface: String, footprint: Dictionary) -> void:
	gx = x
	gy = y
	surface = p_surface
	base_radius = footprint["radius"]
	strength = footprint["strength"]
	radius = base_radius


## Spreads pollution over time. Returns true while the pile should stay.
func step(dt: float, map: WorldMapModel) -> bool:
	if cleaned:
		fade_out += dt
		return fade_out < 0.4
	age += dt
	_tick += dt
	if _tick >= GameConfig.Poop.GROW_TICK:
		_tick = 0.0
		var g := minf(1.0, age / GameConfig.Poop.GROW_TIME)
		radius = base_radius * (1.0 + (GameConfig.Poop.GROW_FACTOR - 1.0) * g)
		map.stamp_dirt(gx, gy, radius, strength)
	return true
