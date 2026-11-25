class_name StorySight
extends RefCounted
## Sight for stealth walks (port of src/story/walk.ts lineOfSight and canSee), pure over the
## stage's WorldMapModel: range, the cone around the watcher's facing, line of sight (walls and tall
## props block it; a bush blocks it unless it is the last step), and hiding (in a bush, or within
## HIDE_PROP_RADIUS of a hiding spot the scene placed, he is seen only from within BUSH_HIDE).

const S := GameConfig.Story


## Line of sight between two grid points.
static func line_of_sight(map: WorldMapModel, ax: float, ay: float, bx: float, by: float) -> bool:
	var d := JsMath.hypot(bx - ax, by - ay)
	var n := int(ceil(d / 0.25))
	for k in range(1, n):
		var x := ax + (bx - ax) * k / n
		var y := ay + (by - ay) * k / n
		var i := int(floor(x))
		var j := int(floor(y))
		if map.is_blocked_tile(i, j):
			return false
		var p := map.prop_at(i, j)
		if p != null and p.tall and (k < n - 2 or p.kind != "bush"):
			return false
	return true


## Whether the point is hidden from a watcher `d` tiles away: in a map bush or by a hiding spot.
static func hidden(map: WorldMapModel, x: float, y: float, d: float, hides: Array) -> bool:
	if d <= S.BUSH_HIDE:
		return false
	var here := map.prop_at(int(floor(x)), int(floor(y)))
	if here != null and here.kind == "bush":
		return true
	for h: Vector2 in hides:
		if h.distance_to(Vector2(x, y)) <= S.HIDE_PROP_RADIUS:
			return true
	return false


## Can the actor see the point? (range, cone, hiding, line of sight.)
static func can_see(map: WorldMapModel, a: StoryActor, x: float, y: float, hides: Array = []) -> bool:
	if a.sight_range <= 0.0:
		return false
	var dx := x - a.gx
	var dy := y - a.gy
	var d := JsMath.hypot(dx, dy)
	if d > a.sight_range:
		return false
	var c := (dx * a.facing_vec.x + dy * a.facing_vec.y) / (d if d > 0.0 else 1.0)
	if d > 0.8 and c < cos(a.sight_half_angle):
		return false
	if hidden(map, x, y, d, hides):
		return false
	return line_of_sight(map, a.gx, a.gy, x, y)
