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


func _story_maps() -> Dictionary:
	return fixture("source_story_maps")["maps"]


func _story_model(src: Dictionary) -> WorldMapModel:
	var parsed := AsciiMapLoader.parse(PackedStringArray(src["rows"]), src["base"], false)
	if not parsed["ok"]:
		fail("story map does not parse: " + String(parsed.get("error", "")))
		return null
	return WorldMapModel.new(parsed["level"])


static func _sha_text(text: String) -> String:
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(text.to_utf8_buffer())
	return ctx.finish().hex_encode()


static func _join(values: Variant) -> String:
	var parts := PackedStringArray()
	for v: Variant in values:
		parts.append(str(int(v)))
	return ",".join(parts)


## MAP-003: every current map parses like the source (storyScene parseAsciiMap(rows, { base,
## requireExit: false }) for the twenty story maps; the Green Zone and diagnostic maps are MAP-007
## and the parser cases): dimensions, ground per cell, props, markers, start/exit and playable tiles
## match the source fixtures, and map_to_local(cell) + IsoGrid.TILE_LAYER_OFFSET is the source tile
## centre over every map's extent.
func test_MAP_003_every_map_parses_and_aligns_with_isogrid() -> void:
	var maps := _story_maps()
	assert_eq(maps.size(), 20, "twenty story maps")
	var w := _make(GreenZoneLevel.definition().rows, false)
	assert_eq(w.ground_layer.position, IsoGrid.TILE_LAYER_OFFSET, "layer offset")
	assert_eq(w.ground_layer.tile_set.tile_size, Vector2i(32, 16), "tile size")
	assert_eq(w.ground_layer.tile_set.tile_layout, TileSet.TILE_LAYOUT_DIAMOND_DOWN, "layout")
	for c: Vector2i in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(17, 42), Vector2i(95, 95), Vector2i(90, 90)]:
		assert_vec_near(w.ground_layer.map_to_local(c) + w.ground_layer.position, IsoGrid.tile_center_screen(c.x, c.y), 1e-4, "Green Zone cell %s centre" % c)
	for key: String in maps:
		var src: Dictionary = maps[key]
		var m := _story_model(src)
		if m == null:
			continue
		assert_eq([m.width, m.height], [int(src["width"]), int(src["height"])], key + " size")
		assert_eq(_sha_text(_join(m.ground)), src["ground_sha256"], key + " ground per cell")
		var counts := {}
		for g in m.ground:
			counts[str(g)] = int(counts.get(str(g), 0)) + 1
		assert_eq(counts, src["ground_counts"], key + " ground counts")
		assert_eq(m.props.map(func(p: WorldMapModel.MapProp) -> Array: return [p.kind, p.i, p.j]), src["props"], key + " props")
		var markers := {}
		for name: String in m.markers:
			var t: Vector2i = m.markers[name]
			markers[name] = [t.x, t.y]
		assert_eq(markers, src["markers"], key + " markers")
		assert_eq([[m.start_tile.x, m.start_tile.y], [m.exit_tile.x, m.exit_tile.y], m.playable_count], [src["start"], src["exit"], int(src["playable_count"])], key + " start/exit/playable")
		for c: Vector2i in [Vector2i(0, 0), Vector2i(m.width - 1, 0), Vector2i(0, m.height - 1), Vector2i(m.width - 1, m.height - 1), m.start_tile]:
			assert_vec_near(w.ground_layer.map_to_local(c) + w.ground_layer.position, IsoGrid.tile_center_screen(c.x, c.y), 1e-4, "%s cell %s centre" % [key, c])


## Drives the selected grid solver (WorldMapModel.move_circle, walking speed, player radius) from
## `from` along the source BFS gradient to tile `target`; true when it arrives.
static func _solver_reaches(m: WorldMapModel, from: Vector2, target: Vector2i) -> bool:
	var dist := m.bfs(target.x, target.y)
	var x := from.x
	var y := from.y
	var step := GameConfig.Player.WALK_SPEED / 60.0
	for t in 60 * 60:
		if JsMath.hypot(x - (target.x + 0.5), y - (target.y + 0.5)) < 0.5:
			return true
		var i := int(floor(x))
		var j := int(floor(y))
		var here := dist[m.index(i, j)]
		var next := Vector2i(i, j)
		for nb: Vector2i in [Vector2i(i + 1, j), Vector2i(i - 1, j), Vector2i(i, j + 1), Vector2i(i, j - 1)]:
			if m.is_walkable(nb.x, nb.y) and dist[m.index(nb.x, nb.y)] == here - 1:
				next = nb
				break
		var dx := next.x + 0.5 - x
		var dy := next.y + 0.5 - y
		var len := JsMath.hypot(dx, dy)
		if len < 1e-9:
			dx = target.x + 0.5 - x
			dy = target.y + 0.5 - y
			len = maxf(JsMath.hypot(dx, dy), 1e-9)
		var r: Array = m.move_circle(x, y, dx / len * step, dy / len * step, GameConfig.Player.RADIUS)
		x = r[0]
		y = r[1]
	return false


## The world's decor as [[sprite key, gx, gy] of every static prop (sorted), per-cell ground tile name].
func _decor(w: IsoWorld) -> Array:
	var key_of := {}
	for key: String in w.catalog.entries:
		key_of[w.catalog.entries[key]["texture"]] = key
	var statics: Array = []
	for n in w.object_layer.get_children():
		if n is IsoProp:
			statics.append([key_of.get((n as IsoProp).sprite.texture, "?"), (n as IsoProp).iso.gx, (n as IsoProp).iso.gy])
	statics.sort_custom(func(a: Array, b: Array) -> bool:
		if a[1] != b[1]:
			return a[1] < b[1]
		if a[2] != b[2]:
			return a[2] < b[2]
		return String(a[0]) < String(b[0]))
	var name_of := {}
	var coords: Dictionary = w.tileset.get_meta(&"tile_coords")
	for name: String in coords:
		name_of[coords[name]] = name
	var rows: Array = []
	for j in w.map.height:
		var row := PackedStringArray()
		for i in w.map.width:
			var c := w.ground_layer.get_cell_atlas_coords(Vector2i(i, j))
			row.append(name_of.get(c, "-") if c != Vector2i(-1, -1) else "-")
		rows.append(row)
	return [statics, rows]


## RNG-002: the same seed reproduces the treat, decor and spawn choices byte for byte: the treat
## route and random spawn spots equal the source (MAP-007, GZ-001 data), every static prop (map
## props, forest trees, wall blocks) has the source World's sprite and position, every ground cell
## has the source mapRenderer.makeTile() choice (animated cells: their phased tile), and a second
## build with the same seed is identical.
func test_RNG_002_same_seed_reproduces_treat_decor_spawn_choices() -> void:
	var fx: Dictionary = fixture("source_green_zone_decor")
	var gz: Dictionary = fixture()["green_zone"]
	var def := GreenZoneLevel.definition()
	var w := _make(def.rows, true)
	var m := w.map
	# Treats and spawns.
	var treats := TreatPlacement.place_treats(m, def.spawns["treats"], def.seed)
	assert_eq(treats.map(func(t: Array) -> Array: return [t[0], t[1]]), (gz["treats"] as Array).map(func(t: Dictionary) -> Array: return [t["x"], t["y"]]), "treat route equals the source")
	var r := DeterministicRng.new(5)
	for k in (gz["random_spot"] as Array).size():
		var got: Variant = TreatPlacement.random_spot_near(m, 60.5, 60.5, 3, 8, r)
		var want: Variant = gz["random_spot"][k]
		assert_eq(got, [want["x"], want["y"]] if want != null else null, "spawn spot %d equals the source" % k)
	# Decor.
	var first := _decor(w)
	var statics: Array = first[0]
	var want_statics: Array = fx["statics"]
	assert_eq(statics.size(), want_statics.size(), "static prop count")
	for k in mini(statics.size(), want_statics.size()):
		if not values_equal(statics[k], want_statics[k]):
			fail("static %d: %s, source %s" % [k, statics[k], want_statics[k]])
			break
	var rows: Array = first[1]
	var mismatches := 0
	for j in m.height:
		var want_row := String(fx["ground_rows"][j]).split(" ")
		for i in m.width:
			var got: String = rows[j][i]
			var want: String = want_row[i]
			var ok := got == want
			for animated in ["tallGrass", "water", "deep"]:
				if want.begins_with(animated + "_"):
					ok = got.begins_with(animated + "_phase")
			if not ok:
				mismatches += 1
				if mismatches <= 3:
					fail("cell %d,%d: %s, source %s" % [i, j, got, want])
	assert_eq(mismatches, 0, "ground tiles equal the source choices")
	# Same seed, second build: identical.
	var w2 := _make(def.rows, true)
	assert_true(values_equal(_decor(w2), first), "a second build with the same seed is identical")
	assert_eq(TreatPlacement.place_treats(w2.map, def.spawns["treats"], def.seed), treats, "same treats")


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
	# The twenty story maps: the BFS from the start equals the source's, and every marker and exit the
	# source can reach is reached by the grid solver from the start. The only markers the source
	# cannot reach are actor spawn points (ship 5/6: Watson below deck; neighborhood 0/9: Santina and
	# her friend behind the gate), never player goals. Partial: pickups, spots and marvels at literal
	# coordinates are placed by the story scripts (M5).
	const ACTOR_ONLY := {"ship": ["5", "6"], "neighborhood": ["0", "9"]}
	var maps := _story_maps()
	for key: String in maps:
		var src: Dictionary = maps[key]
		var sm := _story_model(src)
		if sm == null:
			continue
		var from_start := sm.bfs(sm.start_tile.x, sm.start_tile.y)
		assert_eq(_sha_text(_join(from_start)), src["bfs_sha256"], key + " BFS from the start equals the source")
		var reach: Dictionary = src["reach_from_start"]
		for name: String in reach:
			var tile: Vector2i = sm.exit_tile if name == "E" else sm.markers[name]
			if int(reach[name]) < 0:
				assert_true((ACTOR_ONLY.get(key, []) as Array).has(name), "%s marker %s unreachable only as an actor spawn point" % [key, name])
				continue
			assert_true(_solver_reaches(sm, sm.start, tile), "%s: solver reaches %s from the start" % [key, name])


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


## InteractionProbe/Hurtbox (before M3 contact work): both are projected GRID circles on the foot
## point, never screen circles; they are broad phase only (conservative, circumscribed) and the
## decision is the exact grid distance, as in the source. Checked geometrically and through a real
## Area2D overlap in the physics server.
func test_SLICE_probe_and_hurtbox_are_projected_grid_ellipses_broad_phase_only() -> void:
	var holder := Node2D.new()
	tree.root.add_child(holder)
	var dog: PlayableDog = preload("res://entities/playable_dog/playable_dog.tscn").instantiate()
	holder.add_child(dog)
	dog.set_grid_position(20.0, 20.0)
	var radii := {"InteractionProbe": GridShapes.PROBE_RADIUS, "Hurtbox": GameConfig.Player.RADIUS}
	var widest_reach := GridShapes.reach(maxf(GameConfig.Player.MARK_DISTANCE, GameConfig.Player.DRINK_DISTANCE), GridShapes.MAX_TARGET_RADIUS)
	assert_true(GridShapes.PROBE_RADIUS >= maxf(widest_reach + GridShapes.SNAP_MARGIN, GameConfig.Treat.PICKUP_RADIUS), "probe gates every Green Zone interaction reach (rule distance + target radius)")
	var rng := DeterministicRng.new(17)
	for area_name: String in radii:
		var r: float = radii[area_name]
		var cs: CollisionShape2D = dog.get_node(area_name + "/Shape")
		assert_true(cs.shape is ConvexPolygonShape2D, area_name + ": polygon shape")
		assert_eq(cs.position, Vector2.ZERO, area_name + ": on the foot point")
		var poly: PackedVector2Array = (cs.shape as ConvexPolygonShape2D).points
		var vertex_r := r / cos(PI / GridShapes.SEGMENTS)
		for v in poly:
			var g := IsoGrid.screen_to_grid(v.x, v.y)
			assert_near(g.length(), vertex_r, 1e-5, area_name + ": vertex on the projected grid circle")
		# Conservative: every grid point within r (and on it) projects inside the polygon.
		for k in 2000:
			var a := rng.range_float(0.0, TAU)
			var d := r * (1.0 if k % 4 == 0 else sqrt(rng.range_float(0.0, 1.0)))
			var s := IsoGrid.grid_vec_to_screen(d * cos(a), d * sin(a))
			if not Geometry2D.is_point_in_polygon(s * 0.9999, poly):
				fail("%s: grid point at %.4f tiles outside the broad-phase shape" % [area_name, d])
				break
		# Broad phase only: a point near a polygon corner is inside the shape but farther than r.
		var corner := vertex_r * 0.999
		assert_true(Geometry2D.is_point_in_polygon(IsoGrid.grid_vec_to_screen(corner, 0.0), poly) and GridShapes.distance(0.0, 0.0, corner, 0.0) > r, area_name + ": the shape alone over-reports; the exact grid check decides")
	# The exact decision is the source arithmetic.
	assert_eq(GridShapes.distance(1.5, 2.0, 0.25, -1.0), JsMath.hypot(1.25, 3.0), "exact grid distance (V8 hypot)")
	# Real physics overlap: a point-like Interaction area at the probe radius (east) overlaps the
	# probe, one just beyond the polygon's vertex does not; the hurtbox is monitored by attack
	# areas, not monitoring itself.
	var targets: Array[Area2D] = []
	for d in [GridShapes.PROBE_RADIUS, GridShapes.PROBE_RADIUS / cos(PI / GridShapes.SEGMENTS) + 0.05]:
		var t := Area2D.new()
		t.collision_layer = 8
		t.collision_mask = 0
		t.monitoring = false
		var c := CollisionShape2D.new()
		var circle := CircleShape2D.new()
		circle.radius = 0.5
		c.shape = circle
		t.add_child(c)
		t.position = IsoGrid.grid_to_screen(20.0 + d, 20.0)
		holder.add_child(t)
		targets.append(t)
	for k in 4:
		await tree.physics_frame
	var hits := dog.interaction_probe.get_overlapping_areas()
	assert_eq([hits.has(targets[0]), hits.has(targets[1])], [true, false], "Area2D overlap follows the projected grid ellipse")
	assert_false(dog.hurtbox.monitoring, "hurtbox does not monitor")
	tree.root.remove_child(holder)
	holder.free()


## Interaction broad phase before M3 consumers. Prop rules measure to the prop's EDGE like the source
## (WorldMapModel.nearest_prop: hypot - radius <= distance), so the InteractionProbe must reach a
## target registered at its grid centre at rule distance + prop radius. Tree, pole and fountain at
## +-1e-9 tiles around each boundary, in 16 grid directions (the 8 compass points and 8 edge
## midpoints of the probe polygon, its tightest directions): the exact decision accepts inside and
## rejects outside, and the physics-server overlap with a point-like target on the whole-pixel prop
## centre reports every case, so an accepted contact is never missed. A probe of the bare rule
## distance (the previous contract) misses every accepted case.
func test_SLICE_interaction_broad_phase_covers_prop_edge_reach() -> void:
	const EPS := 1e-9
	const P := GameConfig.Player
	# Contract: every catalog prop at either prop rule distance, with both nodes on whole pixels.
	var widest := 0.0
	for kind: String in TileCatalog.PROP_INFO:
		widest = maxf(widest, TileCatalog.prop_radius(kind))
	assert_eq(GridShapes.MAX_TARGET_RADIUS, widest, "largest target radius = widest catalog prop")
	var half_px := maxf(IsoGrid.screen_to_grid(0.5, 0.5).length(), IsoGrid.screen_to_grid(0.5, -0.5).length())
	assert_true(GridShapes.SNAP_MARGIN >= 2.0 * half_px, "snap margin covers whole-pixel probe and target nodes")
	assert_true(GridShapes.reach(maxf(P.MARK_DISTANCE, P.DRINK_DISTANCE), widest) + GridShapes.SNAP_MARGIN <= GridShapes.PROBE_RADIUS, "every catalog prop's edge reach is inside the probe")
	# Isolated props on open grass, 10 tiles apart (beyond nearest_prop's search window).
	var parsed := AsciiMapLoader.parse(PackedStringArray([
		"##################################",
		"#................................#",
		"#................................#",
		"#................................#",
		"#....T.........P.........F.....S.#",
		"#................................#",
		"#................................#",
		"#................................#",
		"##################################",
	]), ".", false)
	assert_true(parsed["ok"], "map parses")
	var map := WorldMapModel.new(parsed["level"])
	var props := {}
	for p in map.props:
		props[p.kind] = p
	assert_eq(props.keys(), ["tree", "pole", "fountain"], "one tree, pole and fountain")
	# The rules' own queries (green_zone_rules.gd try_pee and _check_drink).
	var vertical := func(p: WorldMapModel.MapProp) -> bool: return p.vertical
	var is_fountain := func(p: WorldMapModel.MapProp) -> bool: return p.kind == "fountain"
	var cases := [
		["mark tree", props["tree"], P.MARK_DISTANCE, vertical],
		["mark pole", props["pole"], P.MARK_DISTANCE, vertical],
		["mark fountain", props["fountain"], P.MARK_DISTANCE, vertical],
		["drink fountain", props["fountain"], P.DRINK_DISTANCE, is_fountain],
	]
	var holder := Node2D.new()
	tree.root.add_child(holder)
	var targets := {}
	for kind: String in props:
		var p: WorldMapModel.MapProp = props[kind]
		var t := Area2D.new()
		t.collision_layer = 8
		t.collision_mask = 0
		t.monitoring = false
		var cs := CollisionShape2D.new()
		var point := CircleShape2D.new()
		point.radius = 0.5
		cs.shape = point
		t.add_child(cs)
		var s := IsoGrid.grid_to_screen(p.x, p.y)
		t.position = Vector2(JsMath.round(s.x), JsMath.round(s.y))
		holder.add_child(t)
		targets[kind] = t
	var placed: Array = []
	for c: Array in cases:
		var p: WorldMapModel.MapProp = c[1]
		var rule: float = c[2]
		var reach := GridShapes.reach(rule, p.radius)
		var bare := GridShapes.ellipse_polygon(rule)
		for n in 8:
			for offset: float in [0.0, 11.25]:
				var a := deg_to_rad(45.0 * n + offset)
				for side: float in [-1.0, 1.0]:
					var x := p.x + (reach + side * EPS) * cos(a)
					var y := p.y + (reach + side * EPS) * sin(a)
					var label := "%s at %.2f deg, %s" % [c[0], rad_to_deg(a), "inside" if side < 0.0 else "outside"]
					assert_eq(map.nearest_prop(x, y, rule, c[3]) == p, side < 0.0, label + ": exact edge-distance decision")
					if side < 0.0:
						assert_false(Geometry2D.is_point_in_polygon(IsoGrid.grid_vec_to_screen(p.x - x, p.y - y), bare), label + ": a probe without the prop radius would miss it")
					var dog: PlayableDog = preload("res://entities/playable_dog/playable_dog.tscn").instantiate()
					holder.add_child(dog)
					dog.set_grid_position(x, y)
					placed.append([label, dog, targets[p.kind]])
	assert_eq(placed.size(), 128, "4 cases x 16 directions x inside/outside")
	for k in 4:
		await tree.physics_frame
	for e: Array in placed:
		var dog: PlayableDog = e[1]
		assert_true(dog.interaction_probe.get_overlapping_areas().has(e[2]), e[0] + ": broad phase reports the target")
	tree.root.remove_child(holder)
	holder.free()


## The dog scene references no profile; the world injects the selected one before add_child()
## (`--as` for all three PLAY_AS dogs, or an explicit option); only a directly instantiated,
## unconfigured dog falls back, lazily, to Zampanò.
func test_SLICE_playable_profile_injected_before_add_child() -> void:
	var scene_path := "res://entities/playable_dog/playable_dog.tscn"
	var deps := ResourceLoader.get_dependencies(scene_path)
	for d in deps:
		assert_false(d.contains("zampano"), "playable_dog.tscn has no Zampanò dependency: " + d)
	assert_false(FileAccess.get_file_as_string(scene_path).contains("zampano"), "scene text names no Zampanò resource")
	assert_false(FileAccess.get_file_as_string("res://entities/playable_dog/playable_dog.gd").contains("preload(\"res://data/characters"), "no preloaded profile in the script")
	var app: Node = tree.root.get_node("AppState")
	var saved: StringName = app.selected_profile
	for id: StringName in [&"zampano", &"sbrimbrulon", &"bagnaskiz"]:
		assert_eq(app.resolve_profile(PackedStringArray(["--as=" + String(id)])), {"profile": id, "rejected": ""}, "--as=%s accepted" % id)
		app.selected_profile = id
		var w := _make(PackedStringArray(DIAG), false)
		var dog := w.player
		assert_eq([dog.profile.id, dog.used_fallback_profile], [id, false], "%s injected before add_child (no fallback)" % id)
		assert_eq((dog.get_node("VisualRoot/Body") as AnimatedSprite2D).sprite_frames, dog.profile.normal_frames, id + " frames on the body")
		var other: StringName = &"bagnaskiz" if id != &"bagnaskiz" else &"sbrimbrulon"
		var w2 := _make(PackedStringArray(DIAG), false, {"profile": other})
		assert_eq([w2.player.profile.id, w2.player.used_fallback_profile], [other, false], "explicit option %s overrides --as %s" % [other, id])
	app.selected_profile = saved
	# Direct instantiation without a profile: the lazy Zampanò fallback, only then.
	var bare: PlayableDog = load(scene_path).instantiate()
	assert_eq([bare.profile, bare.used_fallback_profile], [null, false], "an instantiated scene carries no profile")
	tree.root.add_child(bare)
	assert_eq([bare.profile.id, bare.used_fallback_profile], [&"zampano", true], "unconfigured dog falls back to Zampanò lazily")
	bare.free()

## A script's public interface: public method names with their argument counts and public script
## variables, sorted.
static func _public_interface(script: Script) -> Array:
	var out: Array = []
	for m: Dictionary in script.get_script_method_list():
		if not String(m["name"]).begins_with("_"):
			out.append("%s(%d)" % [m["name"], (m["args"] as Array).size()])
	for p: Dictionary in script.get_script_property_list():
		if not String(p["name"]).begins_with("_") and int(p["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE:
			out.append("var " + String(p["name"]))
	out.sort()
	return out


## ARCH-001a static review gate, scoped to duplicate playable/input movement controllers: flags a
## script other than PlayableDog that defines the playable controller API (update_movement,
## set_intent), or that reads player movement input (move_x / move_y / run_held) and moves a body
## itself. Actor controllers (ActorBody, cats, Bagnaskiz, companions) may move through the shared
## WorldMapModel solver with their approved behaviour controllers and are not flagged.
static func _duplicate_player_controllers(sources: Dictionary) -> PackedStringArray:
	var out := PackedStringArray()
	for path: String in sources:
		if path == "res://entities/playable_dog/playable_dog.gd":
			continue
		var src: String = sources[path]
		var defines_controller := src.contains("func update_movement(") or src.contains("func set_intent(")
		var reads_input := src.contains("move_x") or src.contains("move_y") or src.contains("run_held")
		var moves_body := src.contains(".move_circle(") or src.contains(".circle_blocked(") or src.contains("move_and_slide(") or src.contains("move_and_collide(")
		if defines_controller or (reads_input and moves_body):
			out.append(path)
	return out


## ARCH-001a (M2 dummy-story-scene contract, TEST_PLAN §5): a real dummy Story host scene
## (tests/support/dummy_story_scene.tscn) instantiates the shared IsoWorld as its child, supplies its
## own chapter-specific environment resources (tile set, sprite catalogue, bank id) through the
## world's public properties, configures a story-style map through IsoWorld.setup(), and runs its
## lifecycle (ready, ticks driven by the shared InputService, rendered frames, cleanup). Its
## IsoWorld, PlayableDog, CameraRig classes and public interfaces are GreenZoneScene's, IsoGrid and
## IsoDepthSorter place and rank both worlds, its movement is the shared controller and grid solver
## tick for tick, and the static gate finds no duplicate playable/input controller (actor
## controllers may use the shared solver). The production story scene is ARCH-001b (M5).
func test_ARCH_001a_dummy_story_host_shares_the_green_zone_world() -> void:
	var gz: GreenZoneScene = load("res://scenes/green_zone/green_zone_scene.tscn").instantiate()
	gz.show_briefing = false
	gz.manual_ticks = true
	tree.root.add_child(gz)
	var gw: IsoWorld = gz.world
	# The story stage's own environment resources (stand-ins for a chapter's bank: distinct instances).
	var env_tiles: TileSet = gw.tileset.duplicate()
	var env_catalog: SpriteCatalog = gw.catalog.duplicate()
	var host: Node2D = load("res://tests/support/dummy_story_scene.tscn").instantiate()
	host.manual_ticks = true
	host.environment_tileset = env_tiles
	host.environment_catalog = env_catalog
	host.environment_id = "story_stage_test"
	tree.root.add_child(host)
	var sw: IsoWorld = host.world
	# Lifecycle: the world is the host's child, built through the public setup() on the story map.
	assert_eq([sw.get_parent(), gw.get_parent()], [host, gz], "each host owns its world as a child")
	assert_eq(sw.map.exit_tile, sw.map.start_tile, "story map without exit uses the start")
	assert_eq(sw.map.markers.keys().size(), 2, "named markers")
	assert_true(sw.map.ground.has(TileCatalog.Ground.WATER), "water on the story map")
	# Identical classes and public interfaces.
	for pair: Array in [["IsoWorld", sw, gw], ["PlayableDog", sw.player, gw.player], ["CameraRig", sw.camera_rig, gw.camera_rig]]:
		var a: Script = (pair[1] as Node).get_script()
		var b: Script = (pair[2] as Node).get_script()
		assert_eq(a, b, "same %s class as GreenZoneScene" % pair[0])
		assert_eq(_public_interface(a), _public_interface(b), "same %s public interface" % pair[0])
		assert_true(_public_interface(a).size() > 3, "%s has a public interface" % pair[0])
	assert_eq([sw.scene_file_path, sw.player.scene_file_path], [gw.scene_file_path, gw.player.scene_file_path], "same IsoWorld and PlayableDog scenes")
	assert_eq(sw.player.profile, gw.player.profile, "same injected profile (AppState selection)")
	assert_false(sw.player.used_fallback_profile, "the profile was injected by the world")
	# Chapter-specific environment resources: the host's, not the Green Zone's.
	assert_eq([sw.tileset, sw.ground_layer.tile_set, sw.catalog, sw.environment], [env_tiles, env_tiles, env_catalog, "story_stage_test"], "the story stage's own environment resources are used")
	assert_true(sw.tileset != gw.tileset and sw.catalog != gw.catalog, "distinct from GreenZoneScene's resources")
	assert_eq([gw.tileset.resource_path, gw.environment], ["res://data/environment/ch01_greenzone_tileset.tres", "ch01_greenzone"], "the Green Zone keeps its own")
	# Movement through the host's tick: InputService -> shared controller -> grid solver; camera follows.
	var start_view := sw.camera_rig.view_rect().position
	var intents: Array = []
	var trace: Array = []
	for k in 200:
		InputService.inject_move(1.0, 0.0, k >= 120)
		InputService.update(DT)
		intents.append([InputService.move_x, InputService.move_y, InputService.run_held])
		host.tick(DT)
		trace.append([sw.player.gx, sw.player.gy])
		if k % 4 == 3:
			host._process(DT)
	InputService.clear_injection()
	gz._process(DT)
	assert_eq(host.ticks, 200, "host ticked")
	var right_wall := float(sw.map.width - 1)
	assert_true(sw.player.gx > host.marker("S").x + 3.0, "moved east (%.3f)" % sw.player.gx)
	assert_true(sw.player.gx <= right_wall - GameConfig.Player.RADIUS + 1e-9, "stopped by the wall through the grid solver (%.4f)" % sw.player.gx)
	assert_true(sw.camera_rig.view_rect().position != start_view, "camera followed")
	assert_eq(sw.camera_rig.view_rect().position, sw.camera_rig.view_rect().position.round(), "whole-pixel camera origin")
	# IsoGrid places and IsoDepthSorter ranks both worlds.
	for pair: Array in [["story", sw], ["Green Zone", gw]]:
		var w: IsoWorld = pair[1]
		assert_eq(w.player.position, IsoGrid.grid_to_screen(w.player.gx, w.player.gy).round(), pair[0] + ": IsoGrid foot point")
		var ranks: Array = []
		for n in w.object_layer.get_children():
			if n.visible:
				ranks.append(n.z_index)
		ranks.sort()
		assert_true(w.visible_count >= 3 and ranks == range(ranks.size()), "%s: visible set ranked 0..n-1 by IsoDepthSorter (%d)" % [pair[0], w.visible_count])
	# The same intents through a bare PlayableDog on the same map: identical, tick for tick.
	var parsed := AsciiMapLoader.parse(host.rows, host.base, false)
	var m := WorldMapModel.new(parsed["level"])
	var bare: PlayableDog = load("res://entities/playable_dog/playable_dog.tscn").instantiate()
	bare.set_grid_position(m.start.x, m.start.y)
	bare.face("N")
	var diverged := -1
	for k in intents.size():
		bare.set_intent(intents[k][0], intents[k][1], intents[k][2])
		bare.update_movement(DT, m)
		if diverged < 0 and (bare.gx != trace[k][0] or bare.gy != trace[k][1]):
			diverged = k
	bare.free()
	assert_eq(diverged, -1, "host movement equals the shared controller and solver tick for tick")
	# Static review gate (scope checked first): duplicate playable/input controllers are flagged,
	# actor behaviour controllers on the shared solver are not.
	var samples := {
		"res://entities/actor/actor_body.gd": "func behave(dt):\n\tvar r := map.move_circle(gx, gy, dx, dy, radius)\n",
		"res://entities/critters/cat.gd": "func flee(dt):\n\tvar r = map.move_circle(gx, gy, -dx, -dy, 0.2)\n",
		"res://entities/actor/second_dog.gd": "func set_intent(x, y, run):\n\tpass\n",
		"res://scenes/story/walk_hack.gd": "func tick(dt):\n\tvar r = map.move_circle(gx, gy, InputService.move_x, InputService.move_y, 0.26)\n",
	}
	assert_eq(_duplicate_player_controllers(samples), PackedStringArray(["res://entities/actor/second_dog.gd", "res://scenes/story/walk_hack.gd"]), "gate scope: duplicates flagged, actor controllers allowed")
	var sources := {}
	var stack: Array[String] = ["res://"]
	while not stack.is_empty():
		var dir: String = stack.pop_back()
		for sub in DirAccess.get_directories_at(dir):
			if not sub.begins_with(".") and sub not in ["tests", "tools", "test-results"]:
				stack.append(dir.path_join(sub))
		for f in DirAccess.get_files_at(dir):
			if f.ends_with(".gd"):
				sources[dir.path_join(f)] = FileAccess.get_file_as_string(dir.path_join(f))
	assert_true(sources.has("res://entities/playable_dog/playable_dog.gd") and sources.size() > 20, "runtime scripts scanned (%d)" % sources.size())
	assert_eq(_duplicate_player_controllers(sources), PackedStringArray(), "no duplicate playable/input movement controller")
	# Cleanup: freeing the host frees its world and dog.
	var dog := sw.player
	tree.root.remove_child(host)
	host.free()
	assert_false(is_instance_valid(sw) or is_instance_valid(dog), "world and dog freed with the host")
	tree.root.remove_child(gz)
	gz.free()


## Drives a PlayableDog through its own controller (walking intent, screen space) and the map's grid
## solver from its current position until it is within `radius` of the exact point (tx, ty)
## (`strict`: distance < radius, else <= radius): it steers to the next tile of the BFS field toward
## the target tile and straight at the point once in or next to that tile. Returns true on arrival;
## the dog's real position is where the next leg starts.
static func _drive_to(dog: PlayableDog, m: WorldMapModel, tx: float, ty: float, radius: float, strict: bool, max_ticks: int = 60 * 120) -> bool:
	var target := Vector2i(int(floor(tx)), int(floor(ty)))
	var dist := m.bfs(target.x, target.y)
	for t in max_ticks:
		var d := JsMath.hypot(dog.gx - tx, dog.gy - ty)
		if d < radius or (not strict and d <= radius):
			dog.set_intent(0.0, 0.0, false)
			return true
		var i := int(floor(dog.gx))
		var j := int(floor(dog.gy))
		var aim := Vector2(tx, ty)
		if absi(i - target.x) + absi(j - target.y) > 1:
			var here := dist[m.index(i, j)]
			for nb: Vector2i in [Vector2i(i + 1, j), Vector2i(i - 1, j), Vector2i(i, j + 1), Vector2i(i, j - 1)]:
				if m.is_walkable(nb.x, nb.y) and dist[m.index(nb.x, nb.y)] == here - 1:
					aim = Vector2(nb.x + 0.5, nb.y + 0.5)
					break
		var s := IsoGrid.grid_vec_to_screen(aim.x - dog.gx, aim.y - dog.gy)
		var length := JsMath.hypot(s.x, s.y)
		if length > 1e-9:
			dog.set_intent(s.x / length * 0.8, s.y / length * 0.8, false)
		dog.update_movement(1.0 / 60.0, m)
	return false


## COLL-005a (M2): one dog driven continuously through its own controller and the grid solver from
## the Green Zone start to each of the 30 treats' exact coordinates, within the rule's pickup radius
## (TREAT.PICKUP_RADIUS 0.55, eaten at distance <= 0.55), each leg starting where the previous one
## really ended, then from the last treat to the exit (level complete at distance < 0.8); plus the
## start, exit and every reachable marker of the twenty story maps (the earlier partial case).
## Story objectives are COLL-005b (M5-M7).
func test_COLL_005a_maps_start_exit_treats_and_markers_reachable_under_the_solver() -> void:
	test_P_COLL_005_start_exit_and_treats_reachable_under_the_solver()
	var def := GreenZoneLevel.definition()
	var m := GreenZoneLevel.load_model(def)
	var dog: PlayableDog = load("res://entities/playable_dog/playable_dog.tscn").instantiate()
	dog.set_grid_position(m.start.x, m.start.y)
	dog.face("N")
	var reached := 0
	for tr: Array in TreatPlacement.place_treats(m, def.spawns["treats"], def.seed):
		if assert_true(_drive_to(dog, m, tr[0], tr[1], GameConfig.Treat.PICKUP_RADIUS, false), "treat %d at (%.3f, %.3f) reached from (%.3f, %.3f)" % [reached, tr[0], tr[1], dog.gx, dog.gy]):
			reached += 1
		else:
			break
	assert_eq(reached, 30, "all 30 treats within their pickup radius")
	assert_true(_drive_to(dog, m, m.exit.x, m.exit.y, 0.8, true), "the exit (rule distance < 0.8) from the last treat's real endpoint")
	dog.free()
