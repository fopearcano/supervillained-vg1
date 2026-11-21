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
## Largest grid radius of an interaction target: the widest TileCatalog prop (house, gate 0.5).
## Prop rules measure to the prop's EDGE like the source (WorldMapModel.nearest_prop:
## hypot - radius <= distance), so an accepted prop's centre can be distance + radius away.
const MAX_TARGET_RADIUS := 0.5
## Probe and target nodes sit on whole pixels (Entity.sync rounding): each is up to the grid length
## of a half-pixel diagonal (0.0494 tiles) off its exact grid point. Covers both, rounded up.
const SNAP_MARGIN := 0.1
## Grid radius the InteractionProbe gates around the foot point, for targets registered at their
## grid centre: the largest prop rule distance (marking 1.05, drinking 1.0) plus the largest target
## radius plus the snap margin (1.65 tiles), or the treat pickup radius (0.55, centre to centre) if
## larger. Conservative only: every rule still decides with its own exact source distance.
const PROBE_RADIUS := maxf(maxf(GameConfig.Player.MARK_DISTANCE, GameConfig.Player.DRINK_DISTANCE) + MAX_TARGET_RADIUS + SNAP_MARGIN, GameConfig.Treat.PICKUP_RADIUS)


## Centre distance (tiles) up to which an edge-distance rule of `rule_distance` accepts a target of
## grid radius `target_radius`: the reach the broad phase must cover (plus SNAP_MARGIN).
static func reach(rule_distance: float, target_radius: float) -> float:
	return rule_distance + target_radius


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
