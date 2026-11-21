class_name IsoRenderable
extends RefCounted
## Depth-sorted presence of a world object (port of the Sortable/Entity contract in
## src/entities/entity.ts). Composition: every object in the IsoWorld's ObjectLayer owns one.
## Positions are the contact point (feet/base) in grid space; `z_lift` raises the sprite.

static var _next_id := 1

var id: int
var node: CanvasItem
var gx := 0.0
var gy := 0.0
var z_lift := 0.0
## Small bias added to the depth (flat things < 0 < things on top).
var depth_bias := 0.0
## Approximate sprite box relative to the contact point (culling and occlusion), in pixels.
var bounds := Rect2(-16, -32, 32, 32)
## Tall objects fade when they hide the playable dog.
var fadeable := false
var fade := 1.0


func _init() -> void:
	id = _next_id
	_next_id += 1


func screen_rect() -> Rect2:
	var s := IsoGrid.grid_to_screen(gx, gy)
	return Rect2(s.x + bounds.position.x, s.y - z_lift + bounds.position.y, bounds.size.x, bounds.size.y)


## Painter's order (port of compareDepth): depth + bias, then grid x, then stable id.
static func before(a: IsoRenderable, b: IsoRenderable) -> bool:
	var da := a.gx + a.gy + a.depth_bias
	var db := b.gx + b.gy + b.depth_bias
	if absf(da - db) > 1e-6:
		return da < db
	if absf(a.gx - b.gx) > 1e-6:
		return a.gx < b.gx
	return a.id < b.id


static func rects_overlap(a: Rect2, b: Rect2) -> bool:
	return a.position.x < b.position.x + b.size.x and a.position.x + a.size.x > b.position.x \
		and a.position.y < b.position.y + b.size.y and a.position.y + a.size.y > b.position.y


## True when `front` (a tall object) hides `subject`: drawn after it and their rectangles overlap.
static func occludes(front: IsoRenderable, front_rect: Rect2, subject: IsoRenderable, subject_rect: Rect2) -> bool:
	return before(subject, front) and rects_overlap(front_rect, subject_rect)
