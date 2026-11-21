class_name GridShapes
extends RefCounted
## Grid-space circles in screen space, for Area2D shapes (ARCHITECTURE.md §7.2).
##
## The source decides every contact in grid tiles (Math.hypot on grid coordinates against a rule
## radius). A grid circle of radius r projects to an axis-aligned 2:1 ellipse with semi-axes
## 16·√2·r × 8·√2·r px, never to a screen circle. Area2D shapes built here are BROAD PHASE ONLY:
## they are circumscribed polygons of that ellipse (an overlap means "maybe", a contact the exact
## check accepts is never missed), and every rule then decides with `distance()` (the source's
## hypot, bit-exact) against its own source radius.

const SEGMENTS := 16
## Grid radius the InteractionProbe gates: the largest interaction distance it serves (marking
## 1.05, drinking 1.0, treats 0.55 in the Green Zone). Rules still compare their own radius.
const PROBE_RADIUS := maxf(GameConfig.Player.MARK_DISTANCE, maxf(GameConfig.Player.DRINK_DISTANCE, GameConfig.Treat.PICKUP_RADIUS))


## Circumscribed convex polygon (screen px, centred on the foot point) of the projected grid circle
## of radius `r` tiles: every point of the true ellipse lies inside it.
static func ellipse_polygon(r: float, segments: int = SEGMENTS) -> PackedVector2Array:
	var k := r / cos(PI / segments)
	var out := PackedVector2Array()
	for n in segments:
		var a := TAU * n / segments
		out.append(IsoGrid.grid_vec_to_screen(k * cos(a), k * sin(a)))
	return out


## The exact source contact distance in tiles (Math.hypot on grid deltas, V8-identical).
static func distance(ax: float, ay: float, bx: float, by: float) -> float:
	return JsMath.hypot(ax - bx, ay - by)
