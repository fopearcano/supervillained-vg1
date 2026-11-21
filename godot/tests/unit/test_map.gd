extends TestCase
## ASCII loader, Green Zone generator, BFS, treat placement, grid collision solver and pollution
## field, compared with the audited TypeScript's outputs.

var _gz: Dictionary


func before_each() -> void:
	_gz = fixture()["green_zone"]


func _model() -> WorldMapModel:
	return GreenZoneLevel.load_model(GreenZoneLevel.definition())


func test_MAP_001_parser_errors_match_source() -> void:
	var cases := [PackedStringArray([]), PackedStringArray(["S?E"]), PackedStringArray(["..E"]),
		PackedStringArray(["S.S", "E.."]), PackedStringArray(["S.."]), PackedStringArray(["SEE"])]
	var expected: Array = fixture()["map_parse"]["errors"]
	for k in cases.size():
		var r := AsciiMapLoader.parse(cases[k])
		assert_eq("ok" if r["ok"] else r["error"], expected[k], "case %d" % k)


func test_MAP_002_padding_markers_and_base() -> void:
	var mp: Dictionary = fixture()["map_parse"]
	var ok := AsciiMapLoader.parse(PackedStringArray(["S..", ".T", "E 1"]))
	assert_true(ok["ok"], "parse ok")
	var lv: Dictionary = ok["level"]
	assert_eq(Array(lv["ground"]), mp["ok"]["ground"], "padded ground")
	assert_eq(lv["markers"]["1"], Vector2i(mp["ok"]["markers"]["1"]["i"], mp["ok"]["markers"]["1"]["j"]), "marker 1")
	var base := AsciiMapLoader.parse(PackedStringArray(["S:2", ":E:"]), ":")
	assert_eq(Array(base["level"]["ground"]), mp["base"]["ground"], "base ground under S/E/markers")
	var no_exit := AsciiMapLoader.parse(PackedStringArray(["S.."]), ".", false)
	assert_eq(no_exit["level"]["exit"], no_exit["level"]["start"], "MAP-004 exit defaults to start")


func test_MAP_007_green_zone_rows_identical() -> void:
	var rows := GreenZoneLevel.build_rows()
	var expected: Array = _gz["rows"]
	assert_eq(rows.size(), expected.size(), "row count")
	for j in mini(rows.size(), expected.size()):
		if rows[j] != expected[j]:
			fail("row %d differs:\n  godot  %s\n  source %s" % [j, rows[j], expected[j]])
			return
	assert_eq("\n".join(rows).sha256_text(), _gz["rows_sha256"], "rows sha256")


func test_MAP_007b_topology_props_and_distances() -> void:
	var m := _model()
	assert_eq(m.width, _gz["width"], "width")
	assert_eq(m.start_tile, Vector2i(_gz["start"]["i"], _gz["start"]["j"]), "start")
	assert_eq(m.exit_tile, Vector2i(_gz["exit"]["i"], _gz["exit"]["j"]), "exit")
	assert_eq(m.playable_count, _gz["playable_count"], "playable count")
	var props: Array = _gz["props"]
	assert_eq(m.props.size(), props.size(), "prop count")
	for k in mini(m.props.size(), props.size()):
		var p := m.props[k]
		if p.kind != props[k][0] or p.i != int(props[k][1]) or p.j != int(props[k][2]):
			fail("prop %d %s@%d,%d != %s" % [k, p.kind, p.i, p.j, props[k]])
	var counts := {}
	for g in m.ground:
		counts[str(g)] = int(counts.get(str(g), 0)) + 1
	for key: String in _gz["ground_counts"]:
		assert_eq(counts.get(key, 0), _gz["ground_counts"][key], "ground %s count" % key)
	assert_eq(m.exit_distance[m.index(m.start_tile.x, m.start_tile.y)], _gz["start_exit_distance"], "MAP-005 start->exit BFS")
	var parts := PackedStringArray()
	var reachable := 0
	for d in m.exit_distance:
		parts.append(str(d))
		if d >= 0:
			reachable += 1
	assert_eq(",".join(parts).sha256_text(), _gz["exit_distance_sha256"], "MAP-005 distance field sha256")
	assert_eq(reachable, _gz["reachable_count"], "COLL-005 reachable tiles")
	for row: Array in _gz["progress_samples"]:
		assert_near(m.progress_at(row[0], row[1]), row[2], 1e-12, "progressAt(%s,%s)" % [row[0], row[1]])


func test_GZ_029_treat_placement_identical() -> void:
	var m := _model()
	var def := GreenZoneLevel.definition()
	var treats := TreatPlacement.place_treats(m, def.spawns["treats"], def.seed)
	var expected: Array = _gz["treats"]
	assert_eq(treats.size(), expected.size(), "treat count")
	for k in mini(treats.size(), expected.size()):
		assert_eq(treats[k][0], expected[k]["x"], "treat %d x" % k)
		assert_eq(treats[k][1], expected[k]["y"], "treat %d y" % k)


func test_GZ_001_random_spot_near_identical() -> void:
	var m := _model()
	var r := DeterministicRng.new(5)
	for k in (_gz["random_spot"] as Array).size():
		var e: Variant = _gz["random_spot"][k]
		var got: Variant = TreatPlacement.random_spot_near(m, 60.5, 60.5, 3, 8, r)
		if e == null:
			assert_eq(got, null, "spot %d" % k)
		else:
			assert_eq(got, [e["x"], e["y"]], "spot %d" % k)


func test_COLL_002_grid_solver_matches_source_traces() -> void:
	var m := _model()
	var worst := 0.0
	for c: Dictionary in fixture()["move_circle"]:
		var x: float = c["start"][0]
		var y: float = c["start"][1]
		var dx: float = c["dir"][0]
		var dy: float = c["dir"][1]
		var length := JsMath.hypot(dx, dy)
		var sx := dx / length * float(c["step"])
		var sy := dy / length * float(c["step"])
		var idx := 0
		for k in 90:
			var r := m.move_circle(x, y, sx, sy, GameConfig.Player.RADIUS)
			x = r[0]
			y = r[1]
			if k % 10 == 9:
				var e: Array = c["trace"][idx]
				worst = maxf(worst, JsMath.hypot(x - e[0], y - e[1]))
				if r[2] != e[2]:
					fail("blocked flag at %s dir %s k=%d" % [c["start"], c["dir"], k])
				idx += 1
	assert_near(worst, 0.0, 1e-9, "worst deviation from source moveCircle (tiles)")


func test_COLL_004_walkability_rules() -> void:
	var m := _model()
	var G := TileCatalog.Ground
	for g in [G.VOID, G.FOREST, G.DEEP, G.WALL]:
		assert_false(TileCatalog.is_ground_walkable(g), "ground %d must block" % g)
	for g in [G.GRASS, G.PATH, G.TALL_GRASS, G.WATER]:
		assert_true(TileCatalog.is_ground_walkable(g), "ground %d must be walkable" % g)
	var bush := fixture()["zampano"]["terrain_cells"]["bush"] as Array
	assert_true(m.is_walkable(int(bush[0]), int(bush[1])), "bush tile walkable")
	assert_false(m.circle_blocked(bush[0], bush[1], GameConfig.Player.RADIUS), "bush does not block")


func test_GZ_008_pollution_field_matches_source() -> void:
	var p: Dictionary = fixture()["pollution"]
	var m := _model()
	assert_eq(m.stamp_dirt(60.3, 61.2, 2.6, 1.0), p["newly"][0], "stamp 1 newly polluted")
	assert_eq(m.stamp_dirt(61.0, 60.0, 1.7, 0.75), p["newly"][1], "stamp 2 newly polluted")
	for row: Array in p["dirt_after_stamps"]:
		assert_eq(m.dirt[int(row[0])], float(row[1]), "dirt[%d] after stamps" % int(row[0]))
	assert_eq(m.health(), p["health_after_stamps"], "health after stamps")
	assert_eq(m.clean(60.6, 60.9, 2.2), p["cleaned"], "cleaned tiles")
	var left := 0
	for k in m.dirt.size():
		if m.dirt[k] > 0.0:
			left += 1
	assert_eq(left, (p["dirt_after_clean"] as Array).size(), "dirty tiles after clean")
	assert_eq(m.fresh.size(), p["fresh_count"], "fresh highlights")
	assert_eq(m.health(), p["health_after_clean"], "health after clean")
	for row: Array in p["surface"]:
		assert_eq(m.poop_surface_at(row[0], row[1]), row[2], "poop surface at %s,%s" % [row[0], row[1]])
