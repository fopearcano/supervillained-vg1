class_name DeterministicRng
extends RefCounted
## Port of src/core/rng.ts: mulberry32 with the source's seed handling, plus the per-tile hash2.
## All arithmetic is carried out modulo 2^32 on non-negative ints so outputs match the source
## bit-for-bit (RNG-001..003). Never use Godot's global RNG for gameplay decisions.

const MASK := 0xFFFFFFFF

var _s: int


func _init(seed_value: int) -> void:
	_s = seed_value & MASK
	if _s == 0:
		_s = 0x9e3779b9


## 32-bit multiply keeping the low 32 bits (JavaScript Math.imul on unsigned bit patterns).
static func imul(a: int, b: int) -> int:
	a &= MASK
	b &= MASK
	var lo := (a & 0xFFFF) * b
	var hi := ((a >> 16) * b) & MASK
	return (lo + (hi << 16)) & MASK


## Float in [0, 1).
func next_float() -> float:
	_s = (_s + 0x6d2b79f5) & MASK
	var t := _s
	t = imul(t ^ (t >> 15), t | 1)
	t = (t ^ ((t + imul(t ^ (t >> 7), t | 61)) & MASK)) & MASK
	return float((t ^ (t >> 14)) & MASK) / 4294967296.0


func range_float(min_value: float, max_value: float) -> float:
	return min_value + (max_value - min_value) * next_float()


## Integer in [min_value, max_inclusive].
func int_range(min_value: int, max_inclusive: int) -> int:
	return int(floor(range_float(float(min_value), float(max_inclusive + 1))))


func pick(items: Array) -> Variant:
	return items[int(floor(next_float() * items.size()))]


func chance(p: float) -> bool:
	return next_float() < p


## Stable hash of two integers (and a seed) to [0, 1), used for per-tile decoration choices.
static func hash2(i: int, j: int, seed_value: int = 0) -> float:
	var h := imul(i, 374761393) ^ imul(j, 668265263) ^ imul(seed_value, 2246822519)
	h = imul(h ^ (h >> 13), 1274126177)
	h ^= h >> 16
	return float(h & MASK) / 4294967296.0
