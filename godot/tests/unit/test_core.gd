extends TestCase
## Config parity, RNG, projection, facing, viewport, depth, scoring and lives — all compared with
## fixtures produced by the audited TypeScript (tests/fixtures/source_reference.json).


func test_SLICE_config_matches_source() -> void:
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


func test_P_CORE_002_settings_and_tick_accumulator() -> void:
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


func test_P_RNG_002_int_range_reproduces() -> void:
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


## VIEW-002 (resolved in the M2 review in favour of the original executable algorithm): logical size
## and integer scale equal the SOURCE computeViewport, executed by tools/source_extract over a dense
## grid of device sizes and DPRs. The 192..270 width and 0.42..0.62 aspect then hold wherever the
## source gives them; the only exceptions are the source's own: areas narrower than MIN_WIDTH (scale
## 1, their own width) and constrained areas 271..383 px (scale 2, width 135..191). No new clamp.
func test_VIEW_002_logical_size_and_scale_follow_the_source_algorithm() -> void:
	var grid: Dictionary = fixture()["viewport_grid"]
	var out: PackedStringArray = String(grid["out"]).split(";")
	var n := 0
	var counts := {"in_range": 0, "narrow": 0, "band": 0}
	for dpr: float in grid["dprs"]:
		for w in range(int(grid["w"][0]), int(grid["w"][1]), int(grid["w"][2])):
			for h in range(int(grid["h"][0]), int(grid["h"][1]), int(grid["h"][2])):
				var v := PixelViewportController.compute_viewport(w / dpr, h / dpr, dpr)
				var got := "%d,%d,%d,%d,%d" % [v["width"], v["height"], v["scale"], v["cssLeft"], v["cssTop"]]
				if not assert_eq(got, out[n], "case %d (%dx%d device px @%s)" % [n, w, h, dpr]):
					return
				n += 1
				assert_true(typeof(v["scale"]) == TYPE_INT and v["scale"] >= 1, "integer scale")
				var width: int = v["width"]
				var area_w := mini(int(floor(float(w / dpr) * dpr)), int(floor(int(floor(float(h / dpr) * dpr)) * GameConfig.Display.MAX_ASPECT)))
				if area_w < GameConfig.Display.MIN_WIDTH:
					counts["narrow"] += 1
					assert_eq([v["scale"], width], [1, area_w], "narrow area keeps scale 1")
				elif area_w > GameConfig.Display.MAX_WIDTH and area_w < 2 * GameConfig.Display.MIN_WIDTH:
					counts["band"] += 1
					assert_eq([v["scale"], width], [2, area_w / 2], "source band 135..191 at scale 2")
				else:
					counts["in_range"] += 1
					assert_true(width >= GameConfig.Display.MIN_WIDTH and width <= GameConfig.Display.MAX_WIDTH, "width %d in 192..270" % width)
					var aspect: float = float(width) / int(v["height"])
					assert_true(aspect >= GameConfig.Display.MIN_ASPECT - 0.01 and aspect <= GameConfig.Display.MAX_ASPECT + 0.01, "aspect %.4f" % aspect)
	assert_eq(n, out.size(), "every source case compared")
	assert_true(counts["in_range"] > 500 and counts["band"] > 0 and counts["narrow"] > 0, "all three regimes sampled %s" % counts)
	print("       %d source viewport cases: %s" % [n, counts])


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


func test_DEPTH_002_stable_across_frames_and_remove_readd() -> void:
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
	# Remove and re-add objects with their ids: the order is the same total order again.
	var removed: Array[IsoRenderable] = []
	for k in range(0, 50, 3):
		removed.append(items[k])
	for r in removed:
		items.erase(r)
	IsoDepthSorter.sort(items)
	var without := first.filter(func(id: int) -> bool: return not removed.any(func(r: IsoRenderable) -> bool: return r.id == id))
	assert_eq(items.map(func(r: IsoRenderable) -> int: return r.id), without, "order without the removed objects")
	items.append_array(removed)
	items.shuffle()
	IsoDepthSorter.sort(items)
	assert_eq(items.map(func(r: IsoRenderable) -> int: return r.id), first, "order restored after re-adding")


func test_GZ_019_020_half_stars_and_pee_deficit_penalty() -> void:
	var s: Dictionary = fixture()["scoring"]
	for row: Array in s["stars"]:
		assert_eq(ScoringRules.stars_from_health(row[0]), row[1], "stars(%s)" % row[0])
	for row: Array in s["final_health"]:
		assert_near(ScoringRules.final_health(row[0], int(row[1]), int(row[2])), row[3], 1e-12, "finalHealth%s" % [row])


func test_P_GZ_021_score_components_time_bonus_and_formats() -> void:
	var s: Dictionary = fixture()["scoring"]
	for row: Array in s["time_bonus"]:
		assert_eq(ScoringRules.time_bonus(row[0], row[1]), row[2], "timeBonus%s" % [row])
	for row: Array in s["star_bonus"]:
		assert_eq(ScoringRules.star_bonus(row[0]), row[1], "starBonus(%s)" % row[0])
	for row: Array in s["format_time"]:
		assert_eq(ScoringRules.format_time(row[0]), row[1], "formatTime")
	for row: Array in s["format_score"]:
		assert_eq(ScoringRules.format_score(row[0]), row[1], "formatScore")


func test_GZ_024_lives_clamp_2_to_9() -> void:
	for row: Array in fixture()["zampano"]["speed_mul"]["lives"]:
		var n: float = NAN if row[0] is String else float(row[0])
		assert_eq(LivesRules.clamp_lives(n), row[1], "clampLives(%s)" % row[0])
	assert_eq(LivesRules.next_lives(9), 2, "wraps after MAX")
	assert_eq(LivesRules.next_lives(2), 3, "next")


func test_P_GZ_025_speed_for_lives_factor() -> void:
	for row: Array in fixture()["zampano"]["speed_mul"]["lives"]:
		var n: float = NAN if row[0] is String else float(row[0])
		assert_near(LivesRules.lives_speed(n), row[2], 1e-12, "livesSpeed(%s)" % row[0])


func test_CAM_003_sway_and_shake_deterministic_and_decay_to_zero() -> void:
	var a := CameraModel.new()
	var b := CameraModel.new()
	for cam in [a, b]:
		cam.snap_to(0.0, 0.0)
		cam.shake(GameConfig.Fx.SHAKE_HURT)
	var max_sway := 0.0
	var zero_at := -1
	for k in 240:
		a.update(1.0 / 60.0, 0.0, 0.0, 0.0, 0.0)
		b.update(1.0 / 60.0, 0.0, 0.0, 0.0, 0.0)
		assert_eq([a.shake_x, a.shake_y, a.x, a.y], [b.shake_x, b.shake_y, b.x, b.y], "identical under the same seed (k=%d)" % k)
		assert_true(absf(a.shake_x) <= GameConfig.Fx.SHAKE_HURT and absf(a.shake_y) <= GameConfig.Fx.SHAKE_HURT, "shake bounded")
		if zero_at < 0 and a.shake_x == 0.0 and a.shake_y == 0.0:
			zero_at = k
		max_sway = maxf(max_sway, maxf(absf(a.x), absf(a.y - GameConfig.Camera.BIAS_Y)))
	# amp·e^(−9t) < 0.05 after ln(4/0.05)/9 ≈ 0.49 s ≈ 30 ticks; then exactly zero for good.
	assert_true(zero_at > 0 and zero_at <= 32, "shake reaches exactly zero (%d)" % zero_at)
	assert_eq([a.shake_x, a.shake_y], [0.0, 0.0], "stays zero")
	assert_true(max_sway <= GameConfig.Camera.SWAY_AMPLITUDE + 1e-9, "sway within ±amplitude (%.4f)" % max_sway)


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
