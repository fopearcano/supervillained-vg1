class_name IsoDepthSorter
extends RefCounted
## Explicit painter sort of the VISIBLE object candidates (port of World.render in
## src/world/world.ts). Godot Y-sort is not used: the source tie-break (depth+bias, grid x,
## stable id) is reproduced and ranks are written as sequential z_index values inside the object
## band, so stationary objects never flicker. Also applies the player-only occlusion fade.

const CULL_MARGIN := Rect2(-24, -24, 48, 72)


static func sort(items: Array[IsoRenderable]) -> void:
	items.sort_custom(IsoRenderable.before)


## Culls, fades occluders and ranks visible objects. `view` is the camera's view rectangle in
## world screen space; `player` is the occlusion subject (may be null). Returns visible count.
static func apply(items: Array[IsoRenderable], view: Rect2, player: IsoRenderable, frame_dt: float) -> int:
	var cull := Rect2(view.position + CULL_MARGIN.position, view.size + CULL_MARGIN.size)
	var visible: Array[IsoRenderable] = []
	var player_rect := player.screen_rect() if player else Rect2()
	var k := minf(1.0, frame_dt * GameConfig.Occlusion.FADE_RATE)
	for r in items:
		var rect := r.screen_rect()
		var on := IsoRenderable.rects_overlap(rect, cull)
		if r.node.visible != on:
			r.node.visible = on
		if not on:
			continue
		visible.append(r)
		if r.fadeable and player:
			var target := GameConfig.Occlusion.FADED_ALPHA if IsoRenderable.occludes(r, rect, player, player_rect) else 1.0
			r.fade += (target - r.fade) * k
			r.node.modulate.a = r.fade
	sort(visible)
	for i in visible.size():
		if visible[i].node.z_index != i:
			visible[i].node.z_index = i
	return visible.size()
