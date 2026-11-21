class_name JsMath
extends RefCounted
## Bit-exact counterparts of the JavaScript Math functions the source's rules depend on.
## Gameplay math in this port uses 64-bit GDScript floats; Godot's Vector2 is 32-bit and is used
## for presentation only.


## V8's Math.hypot for two arguments (normalised Kahan summation, src/builtins/math.tq), so
## distances and pollution stamps agree with the source to the last bit.
static func hypot(a: float, b: float) -> float:
	a = absf(a)
	b = absf(b)
	if is_nan(a) or is_nan(b):
		return INF if (is_inf(a) or is_inf(b)) else NAN
	var m := maxf(a, b)
	if m == INF:
		return INF
	if m == 0.0:
		return 0.0
	var sum := 0.0
	var compensation := 0.0
	var n := a / m
	var summand := n * n - compensation
	var preliminary := sum + summand
	compensation = (preliminary - sum) - summand
	sum = preliminary
	n = b / m
	summand = n * n - compensation
	preliminary = sum + summand
	compensation = (preliminary - sum) - summand
	sum = preliminary
	return sqrt(sum) * m


## Math.round: halves round toward +infinity.
static func round(x: float) -> float:
	return floor(x + 0.5)


## Math.sign
static func sign(x: float) -> float:
	if x > 0.0:
		return 1.0
	if x < 0.0:
		return -1.0
	return x
