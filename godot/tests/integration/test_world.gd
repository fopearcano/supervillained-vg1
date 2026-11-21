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


func _make(rows: PackedStringArray, forest: bool = true, extra: Dictionary = {}) -> IsoWorld:
	var parsed := AsciiMapLoader.parse(rows, ".", false)
	assert_true(parsed["ok"], "map parses")
	if world and is_instance_valid(world):
		world.get_parent().remove_child(world)
		world.free()
	world = WORLD.instantiate()
	tree.root.add_child(world)
	var options := {"forest": forest}
	options.merge(extra)
	world.setup(WorldMapModel.new(parsed["level"]), options)
	return world


## Diagnostic map: deep water (~), walls (%), shallow water (W), tall grass (,), a bush (B), forest
## (#), void ( ) and every story ground, around an open room with the start in the middle.
const DIAG := [
	"#############",
	"#~~~~~%%%%%%#",
	"#~.........%#",
	"#~.,,_::-*.%#",
	"#~.WW^^++B.%#",
	"#~.....S...%#",
	"#~.WW.....T%#",
	"#~.........%#",
	"#~~~~~%%%%%%#",
	"#############",
	"             ",
]


func test_P_ARCH_001_dummy_story_map_reuses_iso_world() -> void:
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


func test_P_MAP_003_tile_layer_matches_isogrid() -> void:
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


func test_CAM_002_camera_clamps_small_and_large_maps() -> void:
	# Small map: narrower than the view on both axes -> the camera is centred on the bounds.
	var small := _make(PackedStringArray(DIAG), false)
	small.camera_rig.set_view_size(Vector2(216, 432))
	var sb := small.camera_rig.model.bounds
	small.snap_camera()
	for k in 120:
		small.player.set_intent(1.0, 0.0, true)
		small.player.update_movement(DT, small.map)
		small.end_step(DT)
	# Each axis is either centred (bounds + margin narrower than the view) or kept inside them.
	var mdl := small.camera_rig.model
	var centred := 0
	for axis in [[mdl.x, sb.position.x, sb.end.x, 216.0], [mdl.y, sb.position.y, sb.end.y, 432.0]]:
		var lo: float = axis[1] - 8.0
		var hi: float = axis[2] + 8.0
		if hi - lo <= axis[3]:
			centred += 1
			assert_near(axis[0], lo + (hi - lo) / 2.0, 1e-9, "small map: centred on a narrow axis")
		else:
			assert_true(axis[0] - axis[3] / 2.0 >= lo - 1e-9 and axis[0] + axis[3] / 2.0 <= hi + 1e-9, "small map: view inside the bounds")
	assert_true(centred >= 1, "the small map is narrower than the view on at least one axis")
	# Large map: the view never leaves the bounds plus the margin.
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
	assert_true(view.position.x >= b.position.x - 8 - 1 and view.end.x <= b.end.x + 8 + 1, "x inside bounds + margin")
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


func test_COLL_004_blocked_and_walkable_grounds_including_deep_water_and_walls() -> void:
	var w := _make(PackedStringArray(DIAG), false)
	var m := w.map
	var G := TileCatalog.Ground
	for c: Vector2i in [Vector2i(1, 3), Vector2i(3, 1)]:
		assert_eq(m.ground_at(c.x, c.y), G.DEEP, "deep water at %s" % c)
		assert_true(m.is_blocked_tile(c.x, c.y), "deep water blocks")
	assert_eq(m.ground_at(11, 3), G.WALL, "wall")
	assert_true(m.is_blocked_tile(11, 3), "wall blocks")
	assert_true(m.is_blocked_tile(0, 10), "void blocks")
	for c: Vector2i in [Vector2i(3, 4), Vector2i(3, 3), Vector2i(9, 4)]:
		assert_true(m.is_walkable(c.x, c.y), "%s walkable (water / tall grass / bush)" % c)
	# Run into every border (deep water west/north, walls east/south-east) from 8 directions.
	var dirs := [[0, -1], [0.7071, -0.7071], [1, 0], [0.7071, 0.7071], [0, 1], [-0.7071, 0.7071], [-1, 0], [-0.7071, -0.7071]]
	for d: Array in dirs:
		w.player.set_grid_position(m.start.x, m.start.y)
		w.player.vx = 0.0
		w.player.vy = 0.0
		w.player.energy = NeedsSystem.Energy.new()
		for k in 150:
			w.player.set_intent(d[0], d[1], true)
			w.player.update_movement(DT, m)
			var i := int(floor(w.player.gx))
			var j := int(floor(w.player.gy))
			if m.is_blocked_tile(i, j) or m.circle_blocked(w.player.gx, w.player.gy, GameConfig.Player.RADIUS):
				fail("dir %s entered blocked ground at %s,%s" % [d, w.player.gx, w.player.gy])
				return
	# Walking across shallow water and tall grass is allowed (and slowed, MOVE-004).
	w.player.set_grid_position(2.5, 4.5)
	var east := IsoGrid.grid_vec_to_screen(1.0, 0.0).normalized()
	var wet := false
	for k in 60:
		w.player.set_intent(east.x * 0.8, east.y * 0.8, false)
		w.player.update_movement(DT, m)
		wet = wet or m.is_water_at(w.player.gx, w.player.gy)
	assert_true(wet and w.player.gx > 5.0, "walked through the shallow water along +gx (%s)" % w.player.gx)


func test_SLICE_deep_water_and_wall_diagnostic_rendering() -> void:
	var w := _make(PackedStringArray(DIAG), false)
	var coords: Dictionary = w.tileset.get_meta(&"tile_coords")
	var deep := w.ground_layer.get_cell_atlas_coords(Vector2i(1, 3))
	assert_true(deep == coords["deep_phase0"] or deep == coords["deep_phase1"], "deep water uses a phase tile")
	var want := "deep_phase%d" % int(floor(DeterministicRng.hash2(1, 3, 74) * 2))
	assert_eq(deep, coords[want], "deep phase from hash2(i, j, 74)")
	var src := w.tileset.get_source(0) as TileSetAtlasSource
	assert_eq(src.get_tile_animation_frames_count(coords["deep_phase0"]), 2, "deep water animates")
	assert_near(src.get_tile_animation_frame_duration(coords["deep_phase0"], 0), 0.72, 1e-6, "deep step 0.72 s")
	assert_eq(w.ground_layer.get_cell_atlas_coords(Vector2i(11, 3)), coords["wallBase_0"], "wall base tile")
	for c: Vector2i in [Vector2i(5, 3), Vector2i(6, 3), Vector2i(7, 3), Vector2i(8, 3), Vector2i(5, 4), Vector2i(7, 4)]:
		var tile := w.ground_layer.get_cell_atlas_coords(c)
		assert_true(tile != Vector2i(-1, -1), "story ground %s drawn" % c)
	var blocks := 0
	for n in w.object_layer.get_children():
		if n is IsoProp and n.kind == "wallBlock":
			blocks += 1
			var i := int(floor(n.iso.gx))
			var j := int(floor(n.iso.gy))
			assert_eq(w.map.ground_at(i, j), TileCatalog.Ground.WALL, "wall block stands on a wall tile")
			assert_true(n.iso.fadeable, "wall blocks fade over the dog")
	var walls := 0
	for j in w.map.height:
		for i in w.map.width:
			if w.map.ground_at(i, j) == TileCatalog.Ground.WALL:
				walls += 1
	assert_eq(blocks, walls, "every wall tile near walkable ground gets a block (all are, here)")


func test_MAP_006_floor_designs_change_visuals_only() -> void:
	var rows := GreenZoneLevel.definition().rows
	var design: Dictionary = fixture("floor_design_1_arcade")
	var plain := _make(rows, false)
	var base_cells := {}
	for c: Vector2i in plain.ground_layer.get_used_cells():
		base_cells[c] = [plain.ground_layer.get_cell_source_id(c), plain.ground_layer.get_cell_atlas_coords(c)]
	var m0 := plain.map
	var model0 := [Array(m0.ground), Array(m0.playable), Array(m0.exit_distance), m0.markers, m0.start_tile, m0.exit_tile, m0.playable_count]
	var designed := _make(rows, false, {"floor_design": design})
	assert_eq(designed.floor_design_rejection, "", "1:arcade validates for this exact map")
	var m := designed.map
	assert_eq([Array(m.ground), Array(m.playable), Array(m.exit_distance), m.markers, m.start_tile, m.exit_tile, m.playable_count], model0, "model untouched")
	var r := DeterministicRng.new(3)
	for k in 200:
		var x := r.range_float(1.0, 95.0)
		var y := r.range_float(1.0, 95.0)
		if m.circle_blocked(x, y, 0.26) != m0.circle_blocked(x, y, 0.26):
			fail("collision differs at %s,%s" % [x, y])
			return
	var authored := 0
	for c: Vector2i in designed.ground_layer.get_used_cells():
		if designed.ground_layer.get_cell_source_id(c) == 1:
			authored += 1
			assert_true(IsoWorld.floor_design_applies(m.ground_at(c.x, c.y)), "authored frame only on flat ground at %s" % c)
		else:
			assert_eq([0, designed.ground_layer.get_cell_atlas_coords(c)], base_cells[c], "native tile kept at %s" % c)
	assert_true(authored > 50, "the design changed visuals (%d cells)" % authored)
	# A design for other dimensions or another bank is refused and changes nothing.
	var wrong := design.duplicate()
	wrong["width"] = 95
	var refused := _make(rows, false, {"floor_design": wrong})
	assert_eq(refused.floor_design_rejection, "dimensions", "wrong size refused")
	for c: Vector2i in refused.ground_layer.get_used_cells():
		if refused.ground_layer.get_cell_source_id(c) == 1:
			fail("refused design still drew %s" % c)
			return


func test_COLL_003_round_props_push_out_without_tunnelling() -> void:
	var w := _make(GreenZoneLevel.definition().rows, false)
	var m := w.map
	var seen := {}
	for p in m.props:
		if not p.solid or seen.has(p.kind):
			continue
		seen[p.kind] = true
		for a in 16:
			var ang := TAU * a / 16.0
			var sx := p.x + cos(ang) * 2.0
			var sy := p.y + sin(ang) * 2.0
			if m.circle_blocked(sx, sy, GameConfig.Player.RADIUS):
				continue
			w.player.set_grid_position(sx, sy)
			w.player.vx = 0.0
			w.player.vy = 0.0
			w.player.energy = NeedsSystem.Energy.new()
			w.player.knockback(-cos(ang), -sin(ang), GameConfig.Player.RUN_SPEED * GameConfig.Player.BOUNCE)
			var s := IsoGrid.grid_vec_to_screen(-cos(ang), -sin(ang))
			var length := JsMath.hypot(s.x, s.y)
			var px := sx
			var py := sy
			for k in 90:
				# Maximum speed into the prop: run + the strongest knockback, at the fixed 1/60 step.
				w.player.set_intent(s.x / length, s.y / length, true)
				w.player.update_movement(DT, m)
				var nx := w.player.gx
				var ny := w.player.gy
				var reach := GameConfig.Player.RADIUS + p.radius - 1e-6
				if JsMath.hypot(nx - p.x, ny - p.y) < reach:
					fail("%s: overlapping at angle %d tick %d" % [p.kind, a, k])
					return
				# Tunnelling = the step's segment passes through the trunk (sliding around is fine).
				var seg := Vector2(nx - px, ny - py)
				var t := 0.0
				if seg.length_squared() > 0.0:
					t = clampf(((p.x - px) * seg.x + (p.y - py) * seg.y) / seg.length_squared(), 0.0, 1.0)
				if JsMath.hypot(px + seg.x * t - p.x, py + seg.y * t - p.y) < reach - 0.02:
					fail("%s: step through the obstacle at angle %d tick %d" % [p.kind, a, k])
					return
				px = nx
				py = ny
	assert_true(seen.has("tree") and seen.has("pole") and seen.has("fountain"), "every solid Green Zone prop kind tested (%s)" % str(seen.keys()))


func test_P_COLL_005_start_exit_and_treats_reachable_under_the_solver() -> void:
	var w := _make(GreenZoneLevel.definition().rows, false)
	var m := w.map
	# Follow the BFS gradient tile by tile with the grid solver: start -> exit.
	w.player.set_grid_position(m.start.x, m.start.y)
	for t in 60 * 120:
		var i := int(floor(w.player.gx))
		var j := int(floor(w.player.gy))
		var here := m.exit_distance[m.index(i, j)]
		if JsMath.hypot(w.player.gx - m.exit.x, w.player.gy - m.exit.y) < 0.8:
			break
		var next := Vector2i(i, j)
		for nb: Vector2i in [Vector2i(i + 1, j), Vector2i(i - 1, j), Vector2i(i, j + 1), Vector2i(i, j - 1)]:
			if m.is_walkable(nb.x, nb.y) and m.exit_distance[m.index(nb.x, nb.y)] == here - 1:
				next = nb
				break
		var s := IsoGrid.grid_vec_to_screen(next.x + 0.5 - w.player.gx, next.y + 0.5 - w.player.gy)
		var length := JsMath.hypot(s.x, s.y)
		w.player.set_intent(s.x / length * 0.8 if length > 0 else 0.0, s.y / length * 0.8 if length > 0 else 0.0, false)
		w.player.update_movement(DT, m)
	assert_true(JsMath.hypot(w.player.gx - m.exit.x, w.player.gy - m.exit.y) < 0.8, "solver reached the exit from the start")
	var def := GreenZoneLevel.definition()
	for tr: Array in TreatPlacement.place_treats(m, def.spawns["treats"], def.seed):
		assert_true(m.exit_distance[m.index(int(floor(tr[0])), int(floor(tr[1])))] >= 0, "treat %s on the connected area" % [tr])


func test_DEPTH_003_only_visible_candidates_ranked_and_bands_separate() -> void:
	var w := _make(GreenZoneLevel.definition().rows)
	w.camera_rig.set_view_size(Vector2(216, 432))
	w.snap_camera()
	for n in w.object_layer.get_children():
		n.z_index = -999
	w.render(DT)
	var visible: Array[int] = []
	var hidden := 0
	for n in w.object_layer.get_children():
		if n.visible:
			visible.append(n.z_index)
		else:
			hidden += 1
			assert_eq(n.z_index, -999, "hidden object not re-ranked")
	visible.sort()
	var want: Array[int] = []
	for k in visible.size():
		want.append(k)
	assert_eq(visible, want, "visible objects ranked 0..n-1")
	assert_eq(visible.size(), w.visible_count, "count")
	assert_true(hidden > visible.size() * 3, "most objects culled (%d hidden, %d visible)" % [hidden, visible.size()])
	# Bands: ground 0 < pollution 1 < fresh 2 < decals 3 < objects 10+rank < FX.
	assert_eq([w.ground_layer.z_index, w.pollution_layer.z_index, w.fresh_layer.z_index, w.decal_layer.z_index], [0, 1, 2, 3], "ground bands")
	assert_true(w.object_layer.z_index > w.decal_layer.z_index, "objects above decals")
	assert_true(w.object_layer.z_index + w.visible_count < w.fx_layer.z_index, "object ranks never reach the FX band")
	assert_true(w.fx_layer.z_index <= RenderingServer.CANVAS_ITEM_Z_MAX, "FX band valid")
