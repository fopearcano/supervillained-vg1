class_name PollutionWaveDirector
extends RefCounted
## Turns route-progress milestones into one-shot outbreaks (port of src/systems/threatLogic.ts).
## A progress jump can cross several milestones; update() returns every due wave.

var _next := 0
var _waves: Array = []


func _init(waves: Array = []) -> void:
	var keyed: Array = []
	for k in waves.size():
		keyed.append([float(waves[k]["progress"]), k])
	# Stable sort by progress (JavaScript Array.sort is stable).
	keyed.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0] or (a[0] == b[0] and a[1] < b[1]))
	for e: Array in keyed:
		_waves.append(waves[e[1]])


func update(progress: float) -> Array:
	var due: Array = []
	while _next < _waves.size() and progress >= float(_waves[_next]["progress"]):
		due.append(_waves[_next])
		_next += 1
	return due


func remaining() -> int:
	return _waves.size() - _next
