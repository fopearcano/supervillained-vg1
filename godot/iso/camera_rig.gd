class_name CameraRig
extends Node2D
## Owns the native Camera2D and drives it from CameraModel in the physics tick. Built-in Camera2D
## smoothing stays disabled (one source of truth); the camera sits on a whole-pixel view origin.

var model := CameraModel.new()
@onready var camera: Camera2D = $Camera2D


func set_view_size(size: Vector2) -> void:
	model.view_w = size.x
	model.view_h = size.y


func snap(tx: float, ty: float) -> void:
	model.snap_to(tx, ty)
	_apply()
	reset_physics_interpolation()
	if camera:
		camera.reset_physics_interpolation()


func step(dt: float, tx: float, ty: float, vx: float, vy: float) -> void:
	model.update(dt, tx, ty, vx, vy)
	_apply()


func _apply() -> void:
	position = model.view_origin() + Vector2(model.view_w, model.view_h) / 2.0


func view_rect() -> Rect2:
	return Rect2(model.view_origin(), Vector2(model.view_w, model.view_h))
