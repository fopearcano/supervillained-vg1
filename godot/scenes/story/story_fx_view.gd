class_name StoryFxView
extends Node2D
## The story's world-space effects (port of the drawing in src/story/combat.ts and the sight cones of
## src/story/walk.ts), redrawn every frame from the scene's state; presentation only, never rule
## state. `under` (the world's decal layer): the rings under the foes (a swing's wind-up filling red,
## a stagger in yellow) and the watchers' sight cones (yellow, red as alert fills). `over` (the fx
## layer): the sword's arc, the bark's ring, the raised shield and the foes' HP pips.

const C := GameConfig.Combat

var scene: StoryScene
var under := true


func setup(p_scene: StoryScene, p_under: bool) -> StoryFxView:
	scene = p_scene
	under = p_under
	name = "StoryFxUnder" if under else "StoryFxOver"
	return self


func _process(_delta: float) -> void:
	queue_redraw()


func _at(x: float, y: float) -> Vector2:
	return IsoGrid.grid_to_screen(x, y)


func _ellipse(c: Vector2, rx: float, ry: float, color: Color, filled: bool) -> void:
	var pts := PackedVector2Array()
	for k in 25:
		var a := TAU * k / 24.0
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	if filled:
		draw_colored_polygon(pts, color)
	else:
		draw_polyline(pts, color, 1.0)


func _draw() -> void:
	if scene == null or scene.ctx == null or scene.world == null:
		return
	var combat := scene.ctx.combat
	if under:
		for a: StoryActor in scene.actors.values():
			if a.sight_range > 0.0:
				_cone(a)
			var f := a.foe
			if f == null or f.routed:
				continue
			var s := _at(a.gx, a.gy)
			if f.windup > 0.0:
				var k := 1.0 - f.windup / C.FOE_WINDUP
				_ellipse(s, 13.0, 6.5, Color("#ff3b3b", 0.9), false)
				_ellipse(s, maxf(0.5, 13.0 * k), maxf(0.25, 6.5 * k), Color("#ff3b3b", 0.45), true)
			elif f.stun > 0.0:
				_ellipse(s, 11.0, 5.5, Color("#ffe23a", 0.7), false)
		return
	if combat == null:
		return
	var p := scene.world.player
	var ps := _at(p.gx, p.gy)
	if combat.swing > 0.0:
		# A crescent sweeping across the front, fading.
		var a0 := atan2(combat.swing_dir.y, combat.swing_dir.x) - 1.1
		var sweep := 2.2 * minf(1.0, (1.0 - combat.swing) * 2.2 + 0.25)
		var c := ps + Vector2(0, -10)
		var pts := PackedVector2Array()
		for k in 11:
			var a := a0 + sweep * k / 10.0
			var r := 14.0 + 11.0 * sin(PI * k / 10.0)
			pts.append(c + Vector2(cos(a) * r, sin(a) * r * 0.75))
		for k in range(10, -1, -1):
			var a := a0 + sweep * k / 10.0
			pts.append(c + Vector2(cos(a) * 13.0, sin(a) * 13.0 * 0.75))
		draw_colored_polygon(pts, Color(1, 1, 1, 0.75 * combat.swing))
	if combat.bark_ring > 0.0:
		var r := (1.0 - combat.bark_ring) * C.BARK_RADIUS * 22.0
		_ellipse(ps, maxf(0.5, r), maxf(0.25, r * 0.5), Color("#3ff0ff", combat.bark_ring), false)
	if combat.guarding:
		var g := IsoGrid.dir_to_grid_xy(p.facing)
		var s := _at(p.gx + g[0] * 0.42, p.gy + g[1] * 0.42) + Vector2(0, -14)
		var kite := PackedVector2Array([s + Vector2(-6, -8), s + Vector2(6, -8), s + Vector2(6, 1), s + Vector2(0, 8), s + Vector2(-6, 1)])
		draw_colored_polygon(kite, Color("#3050c0", 0.85))
		kite.append(kite[0])
		draw_polyline(kite, Color("#ffc23a"), 1.0)
		draw_rect(Rect2(s.x - 0.5, s.y - 7, 1.5, 12), Color.WHITE)
		draw_rect(Rect2(s.x - 4, s.y - 4, 8, 1.5), Color.WHITE)
	for a: StoryActor in combat.foes:
		if not is_instance_valid(a) or a.foe == null or a.foe.routed:
			continue
		var s := _at(a.gx, a.gy)
		var pips := int(ceil(a.foe.max_hp))
		for k in pips:
			var left := a.foe.hp - k
			var color := Color("#ff4a4a") if left >= 1.0 else (Color("#ff9a6a") if left > 0.0 else Color("#3a2a2a"))
			draw_rect(Rect2(roundf(s.x - pips * 2.5 + k * 5), roundf(s.y - 40), 4, 2), color)


## A watcher's sight cone: yellow, filling red as the alert rises.
func _cone(a: StoryActor) -> void:
	var base := atan2(a.facing_vec.y, a.facing_vec.x)
	var pts := PackedVector2Array([_at(a.gx, a.gy)])
	for k in 11:
		var ang := base - a.sight_half_angle + 2.0 * a.sight_half_angle * k / 10.0
		pts.append(_at(a.gx + cos(ang) * a.sight_range, a.gy + sin(ang) * a.sight_range))
	var color := Color("#ff3030") if a.alert > 0.05 else Color("#fff060")
	draw_colored_polygon(pts, Color(color, 0.12 + a.alert * 0.25))
