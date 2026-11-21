extends TestCase
## Config parity, RNG, projection, facing, viewport, depth, scoring and lives — all compared with
## fixtures produced by the audited TypeScript (tests/fixtures/source_reference.json).


func test_CFG_001_config_matches_source() -> void:
	var src: Dictionary = fixture()["config"]
	var groups := GameConfig.groups()
	for g: String in groups:
		assert_true(src.has(g), "source group %s missing from fixture" % g)
		var consts: Dictionary = (groups[g] as GDScript).get_script_constant_map()
		for key: String in src[g]:
			if not consts.has(key):
				fail("GameConfig.%s lacks %s" % [g, key])
				continue
			if not values_equal(consts[key], src[g][key]):
				fail("GameConfig.%s.%s = %s, source %s" % [g, key, consts[key], src[g][key]])
	var audio: Dictionary = src["AUDIO"]
	assert_eq(GameConfig.Audio.DEFAULT_VOLUME, audio["DEFAULT_VOLUME"], "AUDIO.DEFAULT_VOLUME")
	assert_eq(GameConfig.Audio.MUSIC_FILE_VOLUME, audio["MUSIC_FILE_VOLUME"], "AUDIO.MUSIC_FILE_VOLUME")
	assert_eq(GameConfig.Audio.SFX_VOLUME, audio["SFX_VOLUME"], "AUDIO.SFX_VOLUME")
	assert_true(values_equal(GameConfig.Audio.FILE_GAIN, audio["FILE_GAIN"]), "AUDIO.FILE_GAIN")


func test_CORE_002_physics_tick_is_60hz() -> void:
	assert_eq(ProjectSettings.get_setting("physics/common/physics_ticks_per_second"), 60, "physics ticks")
	assert_true(ProjectSettings.get_setting("physics/common/physics_interpolation"), "physics interpolation on")
	var t := 0.0
	for k in 600:
		t += GameConfig.Loop.STEP
	assert_near(t, 10.0, 1e-9, "600 ticks")


func test_RNG_001_mulberry32_sequences() -> void:
	var seqs: Dictionary = fixture()["rng"]["sequences"]
	for seed_key: String in seqs:
		var r := DeterministicRng.new(int(seed_key))
		var expected: Array = seqs[seed_key]
		for k in expected.size():
			# Outputs are exact multiples of 2^-32: compare the integer numerators bit-exactly.
			var got_k := int(r.next_float() * 4294967296.0)
			var want_k := int(round(float(expected[k]) * 4294967296.0))
			if got_k != want_k:
				fail("seed %s #%d: %d/2^32 != %d/2^32" % [seed_key, k, got_k, want_k])
				break


func test_RNG_002_int_range_reproduces() -> void:
	var ints: Dictionary = fixture()["rng"]["ints"]
	for seed_key: String in ints:
		var r := DeterministicRng.new(int(seed_key))
		var expected: Array = ints[seed_key]
		for k in expected.size():
			assert_eq(r.int_range(-3, 3 + (k % 5)), int(expected[k]), "seed %s int #%d" % [seed_key, k])


func test_RNG_003_seeds_independent_and_hash2() -> void:
	var a := DeterministicRng.new(1)
	var b := DeterministicRng.new(2)
	var same := 0
	for k in 16:
		if a.next_float() == b.next_float():
			same += 1
	assert_eq(same, 0, "different seeds share outputs")
	var before := randi()
	seed(12345)
	var g1 := randi()
	seed(12345)
	DeterministicRng.new(9).next_float()
	assert_eq(randi(), g1, "DeterministicRng touched the global RNG")
	for row: Array in fixture()["rng"]["hash2"]:
		assert_eq(DeterministicRng.hash2(int(row[0]), int(row[1]), int(row[2])), float(row[3]), "hash2%s" % [row.slice(0, 3)])
	assert_true(before != null)


func test_ISO_001_grid_to_screen() -> void:
	for row: Array in fixture()["projection"]["grid_to_screen"]:
		var s := IsoGrid.grid_to_screen_xy(row[0], row[1])
		assert_near(s[0], row[2]["x"], 1e-6, "g2s.x %s,%s" % [row[0], row[1]])
		assert_near(s[1], row[2]["y"], 1e-6, "g2s.y %s,%s" % [row[0], row[1]])
		# Presentation (32-bit Vector2) stays within float32 resolution of the same point.
		assert_vec_near(IsoGrid.grid_to_screen(row[0], row[1]), Vector2(row[2]["x"], row[2]["y"]), 1e-3, "g2s Vector2")
	for row: Array in fixture()["projection"]["screen_to_grid"]:
		var g := IsoGrid.screen_to_grid_xy(row[0], row[1])
		assert_near(g[0], row[2]["x"], 1e-6, "s2g.x %s,%s" % [row[0], row[1]])
		assert_near(g[1], row[2]["y"], 1e-6, "s2g.y %s,%s" % [row[0], row[1]])


func test_ISO_002_round_trip_1000_points() -> void:
	var r := DeterministicRng.new(424242)
	for k in 1000:
		var px := r.range_float(-500, 500)
		var py := r.range_float(-500, 500)
		var s := IsoGrid.grid_to_screen_xy(px, py)
		var back := IsoGrid.screen_to_grid_xy(s[0], s[1])
		if JsMath.hypot(px - back[0], py - back[1]) > 1e-6:
			fail("round trip %s,%s -> %s" % [px, py, back])
			return


func test_ISO_003_tile_centres_and_rows() -> void:
	assert_vec_near(IsoGrid.tile_center_screen(0, 0), Vector2(0, 8), 1e-9, "tile (0,0) centre")
	assert_vec_near(IsoGrid.tile_center_screen(3, 2), Vector2(16, 48), 1e-9, "tile (3,2) centre")
	# Map columns are gx, rows gy: moving +1 column goes down-right on screen.
	assert_vec_near(IsoGrid.grid_to_screen(1, 0) - IsoGrid.grid_to_screen(0, 0), Vector2(16, 8), 1e-9, "column step")
	assert_vec_near(IsoGrid.grid_to_screen(0, 1) - IsoGrid.grid_to_screen(0, 0), Vector2(-16, 8), 1e-9, "row step")


func test_ISO_004_screen_input_projects_parallel() -> void:
	for row: Array in fixture()["projection"]["screen_dir_to_grid"]:
		var g := IsoGrid.screen_dir_to_grid_xy(row[0], row[1])
		assert_eq(g[0], row[2]["x"], "screenDirToGrid.x %s,%s" % [row[0], row[1]])
		assert_eq(g[1], row[2]["y"], "screenDirToGrid.y %s,%s" % [row[0], row[1]])
		var ix: float = row[0]
		var iy: float = row[1]
		if ix != 0.0 or iy != 0.0:
			var sx := (g[0] - g[1]) * 16.0
			var sy := (g[0] + g[1]) * 8.0
			var cross := sx * iy - sy * ix
			var dot := sx * ix + sy * iy
			assert_near(cross, 0.0, 1e-9, "screen motion parallel to input")
			assert_true(dot > 0.0, "screen motion same direction as input")


func test_MOVE_002_facing_classification() -> void:
	for row: Array in fixture()["projection"]["dir_from_grid"]:
		assert_eq(IsoGrid.dir_from_grid_vector(row[0], row[1], "S"), row[2], "dirFromGridVector(%s,%s)" % [row[0], row[1]])
	for row: Array in fixture()["projection"]["dir_to_grid"]:
		var g := IsoGrid.dir_to_grid_xy(row[0])
		assert_near(g[0], row[1]["x"], 1e-12, "dirToGridVector.x " + String(row[0]))
		assert_near(g[1], row[1]["y"], 1e-12, "dirToGridVector.y " + String(row[0]))
	assert_eq(IsoGrid.dir_from_screen_vector(0, 0, "NE"), "NE", "zero vector keeps fallback")


func test_VIEW_001_viewport_matches_source() -> void:
	for c: Dictionary in fixture()["viewport"]:
		var v := PixelViewportController.compute_viewport(c["css_w"], c["css_h"], c["dpr"])
		var e: Dictionary = c["out"]
		for key in ["width", "height", "scale", "cssLeft", "cssTop"]:
			assert_eq(v[key], e[key], "%sx%s@%s %s" % [c["css_w"], c["css_h"], c["dpr"], key])
		assert_near(v["cssWidth"], e["cssWidth"], 1e-9, "cssWidth")
		assert_near(v["cssHeight"], e["cssHeight"], 1e-9, "cssHeight")


func test_VIEW_002_bounds_and_integer_scale() -> void:
	for w in range(240, 2600, 97):
		for h in range(400, 3000, 131):
			var v := PixelViewportController.compute_viewport(w, h, 1.0)
			var width: int = v["width"]
			var height: int = v["height"]
			if float(w) / h >= 0.42 * 192.0 / 192.0 and w >= 192:
				assert_true(width >= 1 and width <= GameConfig.Display.MAX_WIDTH, "width %d for %dx%d" % [width, w, h])
			assert_true(typeof(v["scale"]) == TYPE_INT and v["scale"] >= 1, "integer scale")
			var aspect := float(width) / height
			assert_true(aspect <= GameConfig.Display.MAX_ASPECT + 0.02, "aspect %.3f too wide (%dx%d)" % [aspect, w, h])


func test_DEPTH_001_sort_order_matches_source() -> void:
	var data: Dictionary = fixture()["depth"]
	var items: Array[IsoRenderable] = []
	for s: Dictionary in data["items"]:
		var r := IsoRenderable.new()
		r.id = int(s["id"])
		r.gx = s["gx"]
		r.gy = s["gy"]
		r.depth_bias = s["depthBias"]
		items.append(r)
	items.reverse()
	IsoDepthSorter.sort(items)
	var ids: Array = items.map(func(r: IsoRenderable) -> int: return r.id)
	assert_eq(ids, (data["sorted_ids"] as Array).map(func(x: float) -> int: return int(x)), "sorted ids")


func test_DEPTH_002_stable_across_frames() -> void:
	var items: Array[IsoRenderable] = []
	for k in 50:
		var r := IsoRenderable.new()
		r.gx = float(k % 5)
		r.gy = float(4 - k % 5)
		items.append(r)
	IsoDepthSorter.sort(items)
	var first := items.map(func(r: IsoRenderable) -> int: return r.id)
	for frame in 1000:
		items.shuffle()
		IsoDepthSorter.sort(items)
		if items.map(func(r: IsoRenderable) -> int: return r.id) != first:
			fail("order changed at frame %d" % frame)
			return


func test_GZ_018_scoring_matches_source() -> void:
	var s: Dictionary = fixture()["scoring"]
	for row: Array in s["stars"]:
		assert_eq(ScoringRules.stars_from_health(row[0]), row[1], "stars(%s)" % row[0])
	for row: Array in s["final_health"]:
		assert_near(ScoringRules.final_health(row[0], int(row[1]), int(row[2])), row[3], 1e-12, "finalHealth%s" % [row])
	for row: Array in s["time_bonus"]:
		assert_eq(ScoringRules.time_bonus(row[0], row[1]), row[2], "timeBonus%s" % [row])
	for row: Array in s["star_bonus"]:
		assert_eq(ScoringRules.star_bonus(row[0]), row[1], "starBonus(%s)" % row[0])
	for row: Array in s["format_time"]:
		assert_eq(ScoringRules.format_time(row[0]), row[1], "formatTime")
	for row: Array in s["format_score"]:
		assert_eq(ScoringRules.format_score(row[0]), row[1], "formatScore")


func test_GZ_024_lives_clamp_and_speed() -> void:
	for row: Array in fixture()["zampano"]["speed_mul"]["lives"]:
		var n: float = NAN if row[0] is String else float(row[0])
		assert_eq(LivesRules.clamp_lives(n), row[1], "clampLives(%s)" % row[0])
		assert_near(LivesRules.lives_speed(n), row[2], 1e-12, "livesSpeed(%s)" % row[0])
	assert_eq(LivesRules.next_lives(9), 2, "wraps after MAX")
	assert_eq(LivesRules.next_lives(2), 3, "next")


func test_CAM_001_follow_lookahead_matches_source() -> void:
	var c: Dictionary = fixture()["camera"]
	var cam := CameraModel.new()
	cam.view_w = c["view"][0]
	cam.view_h = c["view"][1]
	var b: Dictionary = c["bounds"]
	cam.set_bounds(Rect2(b["x"], b["y"], b["w"], b["h"]))
	cam.snap_to(c["snap"][0], c["snap"][1])
	var tx: float = c["snap"][0]
	var ty: float = c["snap"][1]
	var idx := 0
	for k in 240:
		var vx := 50.0 if k < 120 else -30.0
		var vy := 0.0 if k < 60 else -25.0
		tx += vx / 60.0
		ty += vy / 60.0
		cam.update(1.0 / 60.0, tx, ty, vx, vy)
		if k % 20 == 19:
			var e: Dictionary = c["trace"][idx]
			assert_near(cam.x, e["x"], 1e-6, "camera.x k=%d" % k)
			assert_near(cam.y, e["y"], 1e-6, "camera.y k=%d" % k)
			assert_vec_near(cam.view_origin(), Vector2(e["origin"]["x"], e["origin"]["y"]), 0.0, "origin k=%d" % k)
			idx += 1
	for row: Array in c["clamp_axis"]:
		assert_near(CameraModel.clamp_axis(row[0], row[1], row[2], row[3]), row[4], 1e-12, "clampAxis%s" % [row])
