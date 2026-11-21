class_name GreenZoneDriver
extends RefCounted
## Real-input Green Zone driver (slice run and captures). It only sets InputService movement and
## presses PEE — never teleports or calls rules. It follows the BFS distance field toward the exit,
## detours to treats ahead, and pees on its own poops once the squat ends.

var pee_cooldown := 0
var best_distance := 1 << 30
var ticks := 0
var last_progress_tick := 0


func step(scene: GreenZoneScene) -> void:
	ticks += 1
	var m := scene.world.map
	var dog := scene.world.player
	var i := int(floor(dog.gx))
	var j := int(floor(dog.gy))
	var here := m.exit_distance[m.index(i, j)]
	if here < best_distance:
		best_distance = here
		last_progress_tick = ticks
	if pee_cooldown > 0:
		pee_cooldown -= 1
	for p in scene.rules.poops:
		if not p.cleaned and dog.state == "free" and JsMath.hypot(p.gx - dog.gx, p.gy - dog.gy) < 1.0 and pee_cooldown == 0 and scene.rules.bladder.charges > 0:
			InputService.trigger(&"pee")
			pee_cooldown = 60
	var goal_x := -1.0
	var goal_y := -1.0
	var best_d := 4.0
	for tr: Array in scene.rules.treats:
		var td := m.exit_distance[m.index(int(floor(tr[0])), int(floor(tr[1])))]
		var d := JsMath.hypot(tr[0] - dog.gx, tr[1] - dog.gy)
		if td >= 0 and td <= here + 1 and d < best_d:
			best_d = d
			goal_x = tr[0]
			goal_y = tr[1]
	if goal_x < 0.0:
		var next := Vector2i(i, j)
		for nb: Vector2i in [Vector2i(i + 1, j), Vector2i(i - 1, j), Vector2i(i, j + 1), Vector2i(i, j - 1)]:
			if m.in_bounds(nb.x, nb.y) and m.is_walkable(nb.x, nb.y) and m.exit_distance[m.index(nb.x, nb.y)] == here - 1:
				next = nb
				break
		goal_x = next.x + 0.5
		goal_y = next.y + 0.5
	var s := IsoGrid.grid_vec_to_screen(goal_x - dog.gx, goal_y - dog.gy)
	var length := JsMath.hypot(s.x, s.y)
	if length > 1e-6:
		InputService.inject_move(s.x / length * 0.8, s.y / length * 0.8, false)
	else:
		InputService.inject_move(0.0, 0.0, false)


func stalled(limit_ticks: int) -> bool:
	return ticks - last_progress_tick > limit_ticks
