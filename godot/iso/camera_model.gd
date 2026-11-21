class_name CameraModel
extends RefCounted
## Port of src/iso/camera.ts: exponential follow with movement look-ahead, a constant vertical
## bias, handheld sway, decaying shake and map clamping, in world screen space. Pure (CAM-001..4).
## State is kept in 64-bit floats. The shake noise uses a seeded DeterministicRng instead of
## Math.random (CAM-003 determinism).

const C := GameConfig.Camera

var x := 0.0
var y := 0.0
var view_w := 216.0
var view_h := 400.0
var bounds := Rect2()
var has_bounds := false
var shake_x := 0.0
var shake_y := 0.0
var _look_x := 0.0
var _look_y := 0.0
var _time := 0.0
var _shake_amp := 0.0
var _rng := DeterministicRng.new(0x5eed)


func set_bounds(rect: Rect2) -> void:
	bounds = rect
	has_bounds = true


func snap_to(tx: float, ty: float) -> void:
	x = _clamp_x(tx)
	y = _clamp_y(ty + C.BIAS_Y)
	_look_x = 0.0
	_look_y = 0.0


func shake(amount: float) -> void:
	_shake_amp = maxf(_shake_amp, amount)


## (tx, ty): follow point; (vx, vy): movement direction in screen space (any length).
func update(dt: float, tx: float, ty: float, vx: float, vy: float) -> void:
	_time += dt
	var length := JsMath.hypot(vx, vy)
	var lx := vx / length * C.LOOK_AHEAD if length > 1e-6 else 0.0
	var ly := vy / length * C.LOOK_AHEAD * 0.75 if length > 1e-6 else 0.0
	var lk := 1.0 - exp(-C.LOOK_AHEAD_RATE * dt)
	_look_x += (lx - _look_x) * lk
	_look_y += (ly - _look_y) * lk
	var sway_x := sin(_time * C.SWAY_SPEED * 2.1) * C.SWAY_AMPLITUDE
	var sway_y := sin(_time * C.SWAY_SPEED * 1.3 + 1.7) * C.SWAY_AMPLITUDE
	var goal_x := tx + _look_x + sway_x
	var goal_y := ty + _look_y + C.BIAS_Y + sway_y
	var k := 1.0 - exp(-C.FOLLOW_RATE * dt)
	x = _clamp_x(x + (goal_x - x) * k)
	y = _clamp_y(y + (goal_y - y) * k)
	_shake_amp *= exp(-dt * GameConfig.Fx.SHAKE_DECAY)
	if _shake_amp < 0.05:
		_shake_amp = 0.0
	shake_x = (_rng.next_float() * 2.0 - 1.0) * _shake_amp
	shake_y = (_rng.next_float() * 2.0 - 1.0) * _shake_amp


func _clamp_x(v: float) -> float:
	if not has_bounds:
		return v
	return clamp_axis(v, bounds.position.x - C.BOUNDS_MARGIN, bounds.end.x + C.BOUNDS_MARGIN, view_w)


func _clamp_y(v: float) -> float:
	if not has_bounds:
		return v
	return clamp_axis(v, bounds.position.y - C.BOUNDS_MARGIN, bounds.end.y + C.BOUNDS_MARGIN, view_h)


## Whole-pixel top-left corner of the view (shake included).
func view_origin() -> Vector2:
	return Vector2(JsMath.round(x + shake_x - view_w / 2.0), JsMath.round(y + shake_y - view_h / 2.0))


static func clamp_axis(c: float, min_v: float, max_v: float, view_size: float) -> float:
	var span := max_v - min_v
	if span <= view_size:
		return min_v + span / 2.0
	return minf(max_v - view_size / 2.0, maxf(min_v + view_size / 2.0, c))
