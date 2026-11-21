class_name PixelViewportController
extends Node
## Port of src/core/display.ts computeViewport: a low logical resolution and an INTEGER device
## pixel scale so nearest-neighbour upscaling is exact. Wide windows are pillarboxed, tall ones
## letterboxed, inside the display safe area. The root window performs no second stretch; the
## SubViewportContainer is sized to logical × scale with stretch_shrink = scale.

signal viewport_changed(logical_size: Vector2i, scale: int)

@export var safe_area_root: Control
@export var container: SubViewportContainer

var logical_size := Vector2i(216, 432)
var scale := 1


## Pure port of computeViewport (css size and device pixel ratio). Returns the same fields.
static func compute_viewport(css_w: float, css_h: float, dpr: float) -> Dictionary:
	var dev_w := maxi(1, int(floor(css_w * dpr)))
	var dev_h := maxi(1, int(floor(css_h * dpr)))
	var area_w := dev_w
	var area_h := dev_h
	if float(area_w) / area_h > GameConfig.Display.MAX_ASPECT:
		area_w = int(floor(area_h * GameConfig.Display.MAX_ASPECT))
	if float(area_w) / area_h < GameConfig.Display.MIN_ASPECT:
		area_h = int(floor(area_w / GameConfig.Display.MIN_ASPECT))
	var s := maxi(1, int(IsoGrid._js_round(float(area_w) / GameConfig.Display.TARGET_WIDTH)))
	while s > 1 and int(floor(float(area_w) / s)) < GameConfig.Display.MIN_WIDTH:
		s -= 1
	while int(floor(float(area_w) / s)) > GameConfig.Display.MAX_WIDTH:
		s += 1
	var width := int(floor(float(area_w) / s))
	var height := int(floor(float(area_h) / s))
	var css_width := float(width * s) / dpr
	var css_height := float(height * s) / dpr
	return {
		"width": width, "height": height, "scale": s,
		"cssWidth": css_width, "cssHeight": css_height,
		"cssLeft": floor((css_w - css_width) / 2.0), "cssTop": floor((css_h - css_height) / 2.0),
	}


func _ready() -> void:
	get_tree().root.size_changed.connect(apply)
	apply()


## The usable rectangle of the window: the display safe area (cutouts, bars) clipped to it.
func safe_rect() -> Rect2i:
	var win := get_tree().root
	var win_rect := Rect2i(Vector2i.ZERO, win.size)
	if DisplayServer.get_name() == "headless":
		return win_rect
	var safe := DisplayServer.get_display_safe_area()
	var origin := DisplayServer.window_get_position()
	var safe_local := Rect2i(safe.position - origin, safe.size)
	var clipped := win_rect.intersection(safe_local)
	return clipped if clipped.has_area() else win_rect


func apply() -> void:
	var area := safe_rect()
	var vp := compute_viewport(area.size.x, area.size.y, 1.0)
	logical_size = Vector2i(vp["width"], vp["height"])
	scale = vp["scale"]
	safe_area_root.position = Vector2(area.position)
	safe_area_root.size = Vector2(area.size)
	container.stretch = true
	container.stretch_shrink = scale
	container.size = Vector2(logical_size * scale)
	container.position = Vector2(int(vp["cssLeft"]), int(vp["cssTop"]))
	viewport_changed.emit(logical_size, scale)
