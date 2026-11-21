extends TestCase
## IsoWorld contracts: reuse by a non-Green-Zone map, TileMapLayer/IsoGrid alignment, animated
## phase alternatives, camera clamping and blocked-tile collision in every direction.

const WORLD := preload("res://world/world_2d.tscn")
const DT := 1.0 / 60.0

var world: IsoWorld


func after_each() -> void:
	if world and is_instance_valid(world):
		world.get_parent().remove_child(world)
		world.free()


func _make(rows: PackedStringArray, forest: bool = true) -> IsoWorld:
	var parsed := AsciiMapLoader.parse(rows, ".", false)
	assert_true(parsed["ok"], "map parses")
	world = WORLD.instantiate()
	tree.root.add_child(world)
	world.setup(WorldMapModel.new(parsed["level"]), {"forest": forest})
	return world


func test_ARCH_001b_dummy_story_map_reuses_iso_world() -> void:
	# A small story-style map without an exit, markers and a water pond (no Green Zone rules).
	var w := _make(PackedStringArray([
		"#########",
		"#..T..1.#",
		"#.,,,...#",
		"#..WW.B.#",
		"#S.WW..2#",
		"#########",
	]))
	assert_eq(w.map.exit_tile, w.map.start_tile, "story map without exit uses start")
	assert_eq(w.map.markers["1"], Vector2i(6, 1), "marker 1")
	assert_true(w.player is PlayableDog, "same PlayableDog")
	w.player.set_intent(0.8, 0.0, false)
	for k in 30:
		w.player.update_movement(DT, w.map)
		w.end_step(DT)
	w.render(DT)
	assert_true(w.player.gx > w.map.start.x, "moved with the shared controller")
	assert_true(w.visible_count >= 3, "objects depth-sorted (%d)" % w.visible_count)


func test_MAP_003b_tile_layer_matches_isogrid() -> void:
	var w := _make(GreenZoneLevel.definition().rows, false)
	for c: Vector2i in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(17, 42), Vector2i(95, 95), Vector2i(90, 90)]:
		var drawn := w.ground_layer.map_to_local(c) + w.ground_layer.position
		assert_vec_near(drawn, IsoGrid.tile_center_screen(c.x, c.y), 1e-4, "cell %s centre" % c)
	assert_eq(w.ground_layer.position, IsoGrid.TILE_LAYER_OFFSET, "layer offset")
	assert_eq(w.ground_layer.tile_set.tile_size, Vector2i(32, 16), "tile size")
	assert_eq(w.ground_layer.tile_set.tile_layout, TileSet.TILE_LAYOUT_DIAMOND_DOWN, "layout")


func test_WORLD_004_phase_rotated_animated_alternatives() -> void:
	var w := _make(GreenZoneLevel.definition().rows, false)
	var coords: Dictionary = w.tileset.get_meta(&"tile_coords")
	var src := w.tileset.get_source(0) as TileSetAtlasSource
	var phases := {}
	var water_phases := {}
	for j in w.map.height:
		for i in w.map.width:
			var g := w.map.ground_at(i, j)
			if g == TileCatalog.Ground.TALL_GRASS:
				var want := "tallGrass_phase%d" % int(floor(DeterministicRng.hash2(i, j, 72) * 4))
				if w.ground_layer.get_cell_atlas_coords(Vector2i(i, j)) != coords[want]:
					fail("tall grass %d,%d not on %s" % [i, j, want])
					return
				phases[want] = true
			elif g == TileCatalog.Ground.WATER:
				var want := "water_phase%d" % int(floor(DeterministicRng.hash2(i, j, 73) * 2))
				assert_eq(w.ground_layer.get_cell_atlas_coords(Vector2i(i, j)), coords[want], "water %d,%d" % [i, j])
				water_phases[want] = true
	assert_eq(phases.size(), 4, "all four wind phases in use (not lockstep)")
	assert_eq(water_phases.size(), 2, "both water phases in use")
	assert_eq(src.get_tile_animation_frames_count(coords["tallGrass_phase0"]), 4, "wind cycle frames")
	assert_near(src.get_tile_animation_frame_duration(coords["tallGrass_phase0"], 0), 0.24, 1e-6, "wind step 0.24 s")
	assert_eq(src.get_tile_animation_frames_count(coords["water_phase1"]), 2, "water frames")
	assert_near(src.get_tile_animation_frame_duration(coords["water_phase1"], 0), 0.55, 1e-6, "water step 0.55 s")


func test_CAM_002_camera_clamps_to_map() -> void:
	var w := _make(GreenZoneLevel.definition().rows)
	w.camera_rig.set_view_size(Vector2(216, 432))
	var b := w.camera_rig.model.bounds
	assert_true(b.has_area(), "walkable bounds set")
	w.player.set_grid_position(w.map.exit.x, w.map.exit.y)
	w.snap_camera()
	for k in 240:
		w.end_step(DT)
	var view := w.camera_rig.view_rect()
	assert_true(view.position.y >= b.position.y - 8 - 1, "top clamped (%s vs %s)" % [view.position.y, b.position.y])
	assert_eq(view.position, view.position.round(), "CAM-004 whole-pixel origin")


func test_COLL_001_blocked_tiles_stop_all_eight_directions() -> void:
	var w := _make(PackedStringArray([
		"#####",
		"#...#",
		"#.S.#",
		"#...#",
		"#####",
	]), false)
	var dirs := [[0, -1], [0.7071, -0.7071], [1, 0], [0.7071, 0.7071], [0, 1], [-0.7071, 0.7071], [-1, 0], [-0.7071, -0.7071]]
	for d: Array in dirs:
		w.player.set_grid_position(w.map.start.x, w.map.start.y)
		w.player.vx = 0.0
		w.player.vy = 0.0
		for k in 120:
			w.player.set_intent(d[0], d[1], true)
			w.player.update_movement(DT, w.map)
		var x := w.player.gx
		var y := w.player.gy
		assert_false(w.map.circle_blocked(x, y, GameConfig.Player.RADIUS), "dir %s ends inside a wall" % [d])
		assert_true(x >= 1.0 + 0.25 and x <= 4.0 - 0.25 and y >= 1.0 + 0.25 and y <= 4.0 - 0.25, "dir %s stayed in the room (%s,%s)" % [d, x, y])


func test_COLL_006_repeated_collision_is_deterministic() -> void:
	var w := _make(GreenZoneLevel.definition().rows, false)
	var runs: Array = []
	for r in 3:
		w.player.set_grid_position(82.3, 79.9)
		w.player.vx = 0.0
		w.player.vy = 0.0
		w.player.energy = NeedsSystem.Energy.new()
		w.player.state = "free"
		for k in 300:
			w.player.set_intent(0.6, -0.6, k % 50 < 25)
			w.player.update_movement(DT, w.map)
		runs.append([w.player.gx, w.player.gy])
	assert_eq(runs[0], runs[1], "run 1 == run 2")
	assert_eq(runs[1], runs[2], "run 2 == run 3")
