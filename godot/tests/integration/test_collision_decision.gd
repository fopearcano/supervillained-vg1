extends TestCase
## M2 collision-solver decision (ARCHITECTURE.md §7.2, COLL-002). The 48 reference trajectories
## recorded from the source's GameMap.moveCircle (6 starts × 8 directions, run speed, 90 ticks) are
## replayed through (a) native CharacterBody2D.move_and_slide() against projected blocked-tile
## diamonds and prop ellipses with the pinned PhysicsConfig values, and (b) the ported grid solver.
## Tolerance: 0.10 tile at every checkpoint. The measured numbers are printed for the log.

const TOL := 0.10
const DT := 1.0 / 60.0


class Driver:
	extends Node
	var bodies: Array[CharacterBody2D] = []
	var velocities: Array[Vector2] = []
	var ticks := 0
	var samples: Array = []

	func _physics_process(_delta: float) -> void:
		if ticks >= 90:
			return
		for k in bodies.size():
			bodies[k].velocity = velocities[k]
			bodies[k].move_and_slide()
		ticks += 1
		if ticks % 10 == 0:
			var row: Array = []
			for b in bodies:
				var g := IsoGrid.screen_to_grid_xy(b.position.x, b.position.y)
				row.append([g[0], g[1]])
			samples.append(row)


static func _ellipse(r: float, cx: float, cy: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for k in 16:
		var t := TAU * k / 16.0
		var x := cx + r * cos(t)
		var y := cy + r * sin(t)
		pts.append(IsoGrid.grid_to_screen(x, y))
	return pts


func test_SLICE_collision_solver_decision_native_vs_grid() -> void:
	var map := GreenZoneLevel.load_model(GreenZoneLevel.definition())
	var traces: Array = fixture()["move_circle"]
	var root := Node2D.new()
	tree.root.add_child(root)
	var world := StaticBody2D.new()
	world.collision_layer = 1
	world.collision_mask = 0
	root.add_child(world)
	var tiles := {}
	for tr: Dictionary in traces:
		var si := int(floor(tr["start"][0]))
		var sj := int(floor(tr["start"][1]))
		for j in range(sj - 13, sj + 14):
			for i in range(si - 13, si + 14):
				tiles[Vector2i(i, j)] = true
	var shapes := 0
	for c: Vector2i in tiles:
		if map.is_blocked_tile(c.x, c.y):
			var poly := CollisionPolygon2D.new()
			var top := IsoGrid.grid_to_screen(c.x, c.y)
			poly.polygon = PackedVector2Array([top, top + Vector2(16, 8), top + Vector2(0, 16), top + Vector2(-16, 8)])
			world.add_child(poly)
			shapes += 1
		else:
			var p := map.prop_at(c.x, c.y)
			if p != null and p.solid:
				var poly := CollisionPolygon2D.new()
				poly.polygon = _ellipse(p.radius, p.x, p.y)
				world.add_child(poly)
				shapes += 1
	var driver := Driver.new()
	root.add_child(driver)
	for tr: Dictionary in traces:
		var b := CharacterBody2D.new()
		b.motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
		b.safe_margin = 0.08
		b.max_slides = 4
		b.wall_min_slide_angle = 0.261799
		b.collision_layer = 2
		b.collision_mask = 1
		var shape := CollisionPolygon2D.new()
		shape.polygon = _ellipse(GameConfig.Player.RADIUS, 0.0, 0.0)
		b.add_child(shape)
		b.position = IsoGrid.grid_to_screen(tr["start"][0], tr["start"][1])
		root.add_child(b)
		driver.bodies.append(b)
		var dx: float = tr["dir"][0]
		var dy: float = tr["dir"][1]
		var length := JsMath.hypot(dx, dy)
		var speed := float(tr["step"]) / DT
		driver.velocities.append(IsoGrid.grid_vec_to_screen(dx / length * speed, dy / length * speed))
	while driver.ticks < 90:
		await tree.physics_frame
	var native_max := 0.0
	var native_bad := 0
	var worst_case := ""
	var clear_max := 0.0
	var clear_bad := 0
	var clear_count := 0
	for k in traces.size():
		var tr: Dictionary = traces[k]
		var clear_start := not map.circle_blocked(tr["start"][0], tr["start"][1], GameConfig.Player.RADIUS)
		var dev := 0.0
		for s in 9:
			var got: Array = driver.samples[s][k]
			var want: Array = tr["trace"][s]
			dev = maxf(dev, JsMath.hypot(got[0] - want[0], got[1] - want[1]))
		if dev > TOL:
			native_bad += 1
		if clear_start:
			clear_count += 1
			clear_max = maxf(clear_max, dev)
			if dev > TOL:
				clear_bad += 1
		if dev > native_max:
			native_max = dev
			worst_case = "start %s dir %s" % [tr["start"], tr["dir"]]
	# The ported solver on the same traces (exactness is also covered by unit COLL-002).
	var grid_max := 0.0
	for tr: Dictionary in traces:
		var x: float = tr["start"][0]
		var y: float = tr["start"][1]
		var dx: float = tr["dir"][0]
		var dy: float = tr["dir"][1]
		var length := JsMath.hypot(dx, dy)
		for t in 90:
			var r := map.move_circle(x, y, dx / length * float(tr["step"]), dy / length * float(tr["step"]), GameConfig.Player.RADIUS)
			x = r[0]
			y = r[1]
			if t % 10 == 9:
				var want: Array = tr["trace"][t / 10]
				grid_max = maxf(grid_max, JsMath.hypot(x - want[0], y - want[1]))
	print("       COLL-002 native move_and_slide: %d/%d trajectories exceed %.2f tile, max deviation %.3f tile (%s); %d static shapes" % [native_bad, traces.size(), TOL, native_max, worst_case, shapes])
	print("       COLL-002 native, starts clear of obstacles only: %d/%d exceed, max deviation %.3f tile" % [clear_bad, clear_count, clear_max])
	print("       COLL-002 grid solver: max deviation %.12f tile" % grid_max)
	assert_true(grid_max <= TOL, "selected grid solver within tolerance")
	# Decision record: native slide resolution is outside tolerance on this geometry, so the
	# approved GridKinematicSolver is selected. If this ever flips, the decision must be revisited.
	assert_true(native_max > TOL and clear_max > TOL, "native slide unexpectedly within tolerance: revisit the M2 decision")
	root.queue_free()
	await tree.process_frame
