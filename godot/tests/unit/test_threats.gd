extends TestCase
## M3 threats against the audited source (tests/fixtures/source_reference.json, produced by
## executing src/systems/threats.ts, threatLogic.ts and src/entities/critters.ts): the bark cone,
## the magnet curve, the attack director, a scripted Rules + Threats run (cats, balls, waves, the
## scripted attack, Bagnaskiz) and the forced-fetch overlap scenario. The source's Math.random in
## the flee steering was replaced during extraction by the port's seeded critter RNG.

const DT := 1.0 / 60.0
const DOG := preload("res://entities/playable_dog/playable_dog.tscn")

static var _run_cache: Dictionary = {}


class FakeInput:
	extends RefCounted
	var move_x := 0.0
	var move_y := 0.0
	var run_held := false
	var pending := {}

	func consume(action: StringName) -> bool:
		if pending.has(String(action)):
			pending.erase(String(action))
			return true
		return false


func _world() -> Dictionary:
	var def := GreenZoneLevel.definition()
	var map := GreenZoneLevel.load_model(def)
	var dog: PlayableDog = DOG.instantiate()
	dog.set_grid_position(map.start.x, map.start.y)
	dog.face("N")
	var rules := GreenZoneRules.new(map, dog, def, 2)
	var threats := GreenZoneThreats.new(rules)
	return {"def": def, "map": map, "dog": dog, "rules": rules, "threats": threats}


## The first walkable non-water tile (row-major) whose centre progress is the smallest >= p.
static func _spot_at(m: WorldMapModel, p: float) -> Array:
	var best: Array = []
	var best_p := INF
	for j in m.height:
		for i in m.width:
			if not m.is_walkable(i, j) or m.is_water_at(i + 0.5, j + 0.5) or m.exit_distance[m.index(i, j)] < 0:
				continue
			var pr := m.progress_at(i + 0.5, j + 0.5)
			if pr >= p and pr < best_p:
				best_p = pr
				best = [i + 0.5, j + 0.5]
	return best


## The fixture's threats_run script, executed on the port (same teleports, facings and presses).
func _threats_run() -> Dictionary:
	if not _run_cache.is_empty():
		return _run_cache
	var w := _world()
	var m: WorldMapModel = w["map"]
	var dog: PlayableDog = w["dog"]
	var rules: GreenZoneRules = w["rules"]
	var threats: GreenZoneThreats = w["threats"]
	var input := FakeInput.new()
	var log: Array = []
	var tick := [0]
	var on := func(ev: String) -> Callable:
		return func(...args: Array) -> void: log.append([tick[0], ev, args])
	threats.cat_caught.connect(on.call("cat"))
	threats.ball_added.connect(func(ball: CritterControllers.BallController) -> void: log.append([tick[0], "ballSpawn", [ball.gx, ball.gy]]))
	threats.fetched.connect(on.call("fetch"))
	threats.barked.connect(on.call("bark"))
	threats.bark_hit.connect(on.call("barkHit"))
	threats.bagnaskiz_fled.connect(on.call("bagnaskizFled"))
	threats.bumped.connect(on.call("bump"))
	threats.pollution_surge.connect(on.call("pollutionSurge"))
	threats.attack_started.connect(on.call("attackStart"))
	threats.attack_ended.connect(on.call("attackEnd"))
	rules.life_lost.connect(on.call("lifeLost"))
	rules.game_over.connect(on.call("gameOver"))
	rules.treat_eaten.connect(on.call("treat"))
	rules.poop_dropped.connect(on.call("poop"))
	rules.pee_started.connect(on.call("pee"))
	var script: Array = []
	var trace: Array = []
	var attack_tick := -1
	var spot_cache := {}
	for k in 4800:
		tick[0] = k
		if k == 1000 and not threats.cats.is_empty():
			var c := threats.cats[0]
			dog.set_grid_position(c.gx, c.gy)
			script.append([k, "onto cat", c.gx, c.gy])
		if k == 1180 and not threats.cats.is_empty():
			var c := threats.cats[0]
			dog.set_grid_position(c.gx - 1.2, c.gy)
			dog.face(IsoGrid.dir_from_grid_vector(1.0, 0.0))
			input.pending["bark"] = true
			script.append([k, "bark at cat", c.gx - 1.2, c.gy])
		if k == 1700 and not threats.balls.is_empty():
			var b := threats.balls[0]
			dog.set_grid_position(b.gx + 1.6, b.gy)
			script.append([k, "near ball", b.gx + 1.6, b.gy])
		for tp: Array in [[2000, 0.25], [2100, 0.5], [2300, 0.57], [4000, 0.75]]:
			if k == tp[0]:
				if not spot_cache.has(tp[1]):
					spot_cache[tp[1]] = _spot_at(m, tp[1])
				var s: Array = spot_cache[tp[1]]
				dog.set_grid_position(s[0], s[1])
				script.append([k, "progress %s" % [tp[1]], s[0], s[1]])
		if threats.director.state == "attack" and attack_tick < 0:
			attack_tick = k
		var pug := threats.pug
		if pug != null and attack_tick >= 0 and k == attack_tick + 90:
			dog.set_grid_position(pug.gx + 0.3, pug.gy)
			script.append([k, "onto pug", pug.gx + 0.3, pug.gy])
		if pug != null and pug.is_active() and attack_tick >= 0 and k >= attack_tick + 200 and (k - attack_tick) % 40 == 0:
			var dx := dog.gx - pug.gx
			var dy := dog.gy - pug.gy
			var d := JsMath.hypot(dx, dy)
			if d == 0.0:
				d = 1.0
			var x := pug.gx + (dx / d) * 1.5
			var y := pug.gy + (dy / d) * 1.5
			dog.set_grid_position(x, y)
			dog.face(IsoGrid.dir_from_grid_vector(pug.gx - x, pug.gy - y, dog.facing))
			input.pending["action"] = true
			script.append([k, "bark at pug", x, y])
		rules.update(DT, input)
		if rules.state == "playing":
			threats.update(DT, input)
		m.update(DT)
		if k % 30 == 29:
			trace.append({"tick": k, "gx": dog.gx, "gy": dog.gy, "state": dog.state, "facing": dog.facing,
				"summary": threats.summary(), "health": m.health(), "score": rules.stats["score"], "coins": rules.stats["coins"],
				"time": rules.stats["time"], "barkHits": rules.stats["barkHits"], "lives": rules.stats["lives"],
				"hunger": rules.hunger.value, "rstate": rules.state})
		if rules.state != "playing":
			break
	dog.free()
	_run_cache = {"script": script, "trace": trace, "events": log, "attack_tick": attack_tick}
	return _run_cache


## Bark cone (src/systems/threatLogic.ts inBarkCone): 80 seeded samples with the pug and the cat
## (×1.3) ranges, the touching case and a zero facing vector. Magnet curve sampled every 0.05 tile.
func test_SLICE_bark_cone_and_magnet_curve_match_source() -> void:
	var tl: Dictionary = fixture()["threat_logic"]
	for s: Array in tl["bark_cone"]:
		assert_eq(ThreatLogic.in_bark_cone(s[0], s[1], s[2], s[3], s[4], s[5], s[6], s[7]), s[8], "bark cone %s" % [s])
	for s: Array in tl["magnet"]:
		assert_near(ThreatLogic.magnet_pull(s[0], GameConfig.Ball.MAGNET_RADIUS, GameConfig.Ball.MAGNET_STRENGTH), s[1], 1e-12, "magnet at %.2f" % s[0])


## GZ-038–041: the director starts on unhealthy zone health (not during its cooldown) and once at
## the scripted route progress, reports the source's intensity curve, and ends only when Bagnaskiz
## is gone and health is back above threshold + hysteresis; 4200 ticks equal the source's signals,
## states, elapsed times and intensities.
func test_GZ_038_041_attack_director_triggers_cooldown_intensity_hysteresis_like_source() -> void:
	var expected: Array = fixture()["threat_logic"]["attack"]
	var dir := ThreatLogic.AttackDirector.new(GameConfig.Attack.HEALTH_THRESHOLD, 0.56)
	var got: Array = []
	for k in 4200:
		var t := k * DT
		var health := 0.99 if t < 5 else (0.94 if t < 10 else (0.952 if t < 14 else (0.955 if t < 16 else (0.93 if t < 30 else 0.97))))
		var progress := 0.3 if t < 50 else 0.6
		var pug_gone := t < 12 or (t > 20 and t < 50) or t > 60
		var s := dir.update(DT, health, progress, pug_gone)
		if s != "" or k % 300 == 0:
			got.append([k, s if s != "" else null, dir.state, dir.elapsed, dir.intensity(health)])
	assert_eq(got.size(), expected.size(), "same number of records")
	for i in mini(got.size(), expected.size()):
		var g: Array = got[i]
		var e: Array = expected[i]
		assert_eq([g[0], g[1], g[2]], [e[0], e[1], e[2]], "record %d" % i)
		assert_near(g[3], e[3], 1e-8, "elapsed at %d" % g[0])
		assert_near(g[4], e[4], 1e-12, "intensity at %d" % g[0])


## GZ-001: the spawn/threat director is deterministic and draws the shared threat RNG in the source
## order. The fixture script (teleports onto a cat and next to a ball, route-progress jumps, barks)
## gives the same cat/ball spawns, wave placements, Bagnaskiz spawn and every threat event at the
## same tick as the source; a second run reproduces the summary exactly.
func test_GZ_001_spawn_director_is_deterministic_in_source_rng_order() -> void:
	# Map, props and treat placement load identically twice (their source parity is MAP-007).
	var def := GreenZoneLevel.definition()
	var ma := GreenZoneLevel.load_model(def)
	var mb := GreenZoneLevel.load_model(def)
	assert_eq([ma.ground, ma.exit_distance, ma.start, ma.exit], [mb.ground, mb.exit_distance, mb.start, mb.exit], "map data identical")
	assert_eq(ma.props.map(func(p: WorldMapModel.MapProp) -> Array: return [p.kind, p.x, p.y]), mb.props.map(func(p: WorldMapModel.MapProp) -> Array: return [p.kind, p.x, p.y]), "props identical")
	assert_eq(TreatPlacement.place_treats(ma, def.spawns["treats"], def.seed), TreatPlacement.place_treats(mb, def.spawns["treats"], def.seed), "treat placement identical")
	var src: Dictionary = fixture()["threats_run"]
	var run := _threats_run()
	assert_eq(run["attack_tick"], int(src["attack_tick"]), "attack starts on the source tick")
	assert_eq(run["script"].size(), src["script"].size(), "same scripted steps")
	for i in mini(run["script"].size(), src["script"].size()):
		var g: Array = run["script"][i]
		var e: Array = src["script"][i]
		assert_eq([g[0], g[1]], [e[0], e[1]], "script step %d" % i)
		assert_near(g[2], e[2], 1e-6, "script x %d" % i)
		assert_near(g[3], e[3], 1e-6, "script y %d" % i)
	var got_events: Array = run["events"].map(func(e: Array) -> Array: return [e[0], e[1]])
	var want_events: Array = src["events"].map(func(e: Array) -> Array: return [int(e[0]), e[1]])
	assert_eq(got_events, want_events, "every threat event on the source tick")
	for e: Array in run["events"]:
		if e[1] == "ballSpawn":
			var w: Dictionary = src["events"].filter(func(x: Array) -> bool: return int(x[0]) == e[0] and x[1] == "ballSpawn")[0][2]
			assert_near(e[2][0], w["x"], 1e-9, "ball spawn x")
			assert_near(e[2][1], w["y"], 1e-9, "ball spawn y")
	_run_cache = {}
	var again := _threats_run()
	assert_eq(again["trace"].map(func(t: Dictionary) -> Dictionary: return t["summary"]), run["trace"].map(func(t: Dictionary) -> Dictionary: return t["summary"]), "same seed, same full spawn/threat summary")


## The whole scripted run, every 30 ticks: dog, cats, balls, Bagnaskiz, director, waves left,
## health, score, coins, time, bark hits, lives and hunger equal the source.
func test_SLICE_threats_run_trace_matches_source() -> void:
	var src: Array = fixture()["threats_run"]["trace"]
	var got: Array = _threats_run()["trace"]
	assert_eq(got.size(), src.size(), "trace length")
	for i in mini(got.size(), src.size()):
		var g: Dictionary = got[i]
		var e: Dictionary = src[i]
		var s: Dictionary = g["summary"]
		var at := "tick %d" % e["tick"]
		assert_eq([g["tick"], g["state"], g["facing"], g["rstate"], s["attack"], s["waves_left"]], [int(e["tick"]), e["state"], e["facing"], e["rstate"], e["attack"], int(e["waves"])], at)
		assert_near(g["gx"], e["gx"], 1e-6, at + " gx")
		assert_near(g["gy"], e["gy"], 1e-6, at + " gy")
		assert_eq([g["score"], g["coins"], g["barkHits"], g["lives"]], [int(e["score"]), int(e["coins"]), int(e["barkHits"]), int(e["lives"])], at + " stats")
		assert_near(g["time"], e["time"], 1e-6, at + " time")
		assert_near(g["hunger"], e["hunger"], 1e-6, at + " hunger")
		assert_near(g["health"], e["health"], 1e-9, at + " health")
		assert_eq(s["cats"].size(), e["cats"].size(), at + " cats")
		for c in mini(s["cats"].size(), e["cats"].size()):
			assert_eq(s["cats"][c][2], e["cats"][c][2], at + " cat state")
			assert_near(s["cats"][c][0], e["cats"][c][0], 1e-6, at + " cat x")
			assert_near(s["cats"][c][1], e["cats"][c][1], 1e-6, at + " cat y")
		assert_eq(s["balls"].size(), e["balls"].size(), at + " balls")
		for b in mini(s["balls"].size(), e["balls"].size()):
			assert_near(s["balls"][b][0], e["balls"][b][0], 1e-9, at + " ball x")
			assert_near(s["balls"][b][1], e["balls"][b][1], 1e-9, at + " ball y")
		assert_eq(s["pug"] == null, e["pug"] == null, at + " pug presence")
		if s["pug"] != null and e["pug"] != null:
			assert_eq([s["pug"][2], s["pug"][3]], [e["pug"][2], int(e["pug"][3])], at + " pug state/hits")
			assert_near(s["pug"][0], e["pug"][0], 1e-6, at + " pug x")
			assert_near(s["pug"][1], e["pug"][1], 1e-6, at + " pug y")


## GZ-037: the three route-progress waves fire once each, in order, with the source's seeded
## placement (centre, radius, newly polluted tiles) and one cue event per wave; none fires again.
func test_GZ_037_three_waves_once_with_seeded_placement_and_cue() -> void:
	var src: Array = fixture()["threats_run"]["events"].filter(func(e: Array) -> bool: return e[1] == "pollutionSurge")
	var got: Array = _threats_run()["events"].filter(func(e: Array) -> bool: return e[1] == "pollutionSurge")
	assert_eq(got.size(), 3, "three surges")
	assert_eq(got.size(), src.size(), "as many as the source")
	var waves: Array = GreenZoneLevel.definition().events["pollutionWaves"]
	for i in mini(got.size(), src.size()):
		var g: Array = got[i]
		var e: Dictionary = src[i][2]
		assert_eq(g[0], int(src[i][0]), "wave %d tick" % i)
		assert_near(g[2][0], e["x"], 1e-9, "wave %d centre x" % i)
		assert_near(g[2][1], e["y"], 1e-9, "wave %d centre y" % i)
		assert_eq([g[2][2], g[2][3]], [e["radius"], int(e["tiles"])], "wave %d radius and tiles" % i)
		assert_eq(g[2][2], waves[i]["radius"], "radius from the level data")
	var trace: Array = _threats_run()["trace"]
	assert_eq(trace[trace.size() - 1]["summary"]["waves_left"], 0, "all three consumed, never again")


## A world with the dog on open ground facing grid +x (in cone ahead, out of cone behind): the
## first tile (row-major) from which a critter circle is free 3 tiles behind to 4.5 ahead along
## the facing line and 0.8 tiles to either side, so knockback and fleeing are never blocked.
func _facing_world() -> Dictionary:
	var w := _world()
	var dog: PlayableDog = w["dog"]
	var m: WorldMapModel = w["map"]
	dog.face(IsoGrid.dir_from_grid_vector(1.0, 0.0))
	var f := IsoGrid.dir_to_grid_xy(dog.facing)
	var fl := JsMath.hypot(f[0], f[1])
	var ux := f[0] / fl
	var uy := f[1] / fl
	var found: Array = []
	for j in m.height:
		for i in m.width:
			if not found.is_empty() or not m.is_walkable(i, j) or m.is_water_at(i + 0.5, j + 0.5) or m.exit_distance[m.index(i, j)] < 0:
				continue
			var x := i + 0.5
			var y := j + 0.5
			var clear := true
			for t in range(-30, 46):
				for side in [-0.8, 0.0, 0.8]:
					var px: float = x + ux * t * 0.1 - uy * side
					var py: float = y + uy * t * 0.1 + ux * side
					if not m.in_bounds(int(floor(px)), int(floor(py))) or m.circle_blocked(px, py, 0.35) or m.is_water_at(px, py):
						clear = false
						break
				if not clear:
					break
			if clear:
				found = [x, y]
	assert_false(found.is_empty(), "open ground for the facing tests")
	dog.set_grid_position(found[0], found[1])
	w["f"] = [f[0], f[1]]
	return w


## Bagnaskiz `d` tiles from the dog along the facing vector (negative: behind him).
func _place_pug(w: Dictionary, pug: CritterControllers.BagnaskizController, d: float) -> void:
	var dog: PlayableDog = w["dog"]
	var f: Array = w["f"]
	var len := JsMath.hypot(f[0], f[1])
	pug.gx = dog.gx + f[0] / len * d
	pug.gy = dog.gy + f[1] / len * d


## GZ-042: Bagnaskiz spawns with the scripted attack, heads for the greenest nearby spot (the
## source's 14 seeded samples scored by clean tiles minus distance) and stamps his pollution trail
## every TRAIL_INTERVAL; in the source threats run every sampled position, state and the zone
## health (trail dirt) equal the source; directly, his first roam step stamps the trail formula.
func test_GZ_042_bagnaskiz_targets_green_and_trails_like_source() -> void:
	var run := _threats_run()
	var names: Array = run["events"].map(func(e: Array) -> String: return e[1])
	assert_eq(names.count("attackStart"), 1, "one attack")
	var src: Array = fixture()["threats_run"]["trace"]
	var on_stage := 0
	for i in mini(run["trace"].size(), src.size()):
		var g: Dictionary = run["trace"][i]
		var e: Dictionary = src[i]
		if e["pug"] == null:
			assert_eq(g["summary"]["pug"], null, "tick %d no pug" % e["tick"])
			continue
		on_stage += 1
		var p: Array = g["summary"]["pug"]
		assert_eq([p[2], p[3]], [e["pug"][2], int(e["pug"][3])], "tick %d pug state" % e["tick"])
		assert_near(p[0], e["pug"][0], 1e-6, "tick %d pug x (targeting)" % e["tick"])
		assert_near(p[1], e["pug"][1], 1e-6, "tick %d pug y (targeting)" % e["tick"])
		assert_near(g["health"], e["health"], 1e-9, "tick %d trail health" % e["tick"])
	assert_true(on_stage >= 4, "Bagnaskiz on stage for a while (%d samples)" % on_stage)
	# Trail, directly: the first roam step stamps strength * (1 - 0.55 (d/r)^2) under him.
	var w := _facing_world()
	var m: WorldMapModel = w["map"]
	var th: GreenZoneThreats = w["threats"]
	var pug := CritterControllers.BagnaskizController.new(0.0, 0.0)
	th.pug = pug
	for d in [3.0, 2.5, 3.5, 4.0, -3.0, -2.5]:
		_place_pug(w, pug, d)
		if m.in_bounds(int(floor(pug.gx)), int(floor(pug.gy))) and m.playable[m.index(int(floor(pug.gx)), int(floor(pug.gy)))]:
			break
	var x0 := pug.gx
	var y0 := pug.gy
	assert_true(m.playable[m.index(int(floor(x0)), int(floor(y0)))], "on a playable tile")
	var tiles_before := m.health()
	th.update(DT, FakeInput.new())
	const G := GameConfig.Bagnaskiz
	var i := int(floor(x0))
	var j := int(floor(y0))
	var d := JsMath.hypot(i + 0.5 - x0, j + 0.5 - y0)
	assert_near(m.dirt[m.index(i, j)], G.TRAIL_STRENGTH * (1.0 - 0.55 * pow(d / G.TRAIL_RADIUS, 2.0)), 1e-6, "trail stamp under him")
	assert_true(m.health() < tiles_before, "the trail pollutes")
	var dog: PlayableDog = w["dog"]
	assert_true(JsMath.hypot(pug.target_x - dog.gx, pug.target_y - dog.gy) <= 6.0 + 0.75, "green target picked near the dog (within 6 tiles + a tile centre)")
	(w["dog"] as PlayableDog).free()


## GZ-043: a roaming Bagnaskiz touching the dog bumps him: exactly BUMP_HUNGER of hunger, hurt for
## 0.35 s, knockback 6 tiles/s directly away from him; no second bump before BUMP_COOLDOWN, the
## next one right after it; none while the dog is invulnerable or leaving by the exit; the source
## run's single bump costs the same hunger.
func test_GZ_043_bump_hunger_hurt_knockback_and_cooldown() -> void:
	const G := GameConfig.Bagnaskiz
	var w := _facing_world()
	var dog: PlayableDog = w["dog"]
	var rules: GreenZoneRules = w["rules"]
	var th: GreenZoneThreats = w["threats"]
	var pug := CritterControllers.BagnaskizController.new(0.0, 0.0)
	th.pug = pug
	var bumps: Array = []
	var tick := [0]
	th.bumped.connect(func(_x: float, _y: float) -> void: bumps.append(tick[0]))
	var hunger0: float = rules.hunger.value
	_place_pug(w, pug, 0.2)
	th.update(DT, FakeInput.new())
	assert_eq(bumps, [0], "bumped at once")
	assert_eq(rules.hunger.value, hunger0 - G.BUMP_HUNGER, "exactly BUMP_HUNGER")
	assert_eq([dog.state, dog.state_duration, dog.controllable], ["hurt", 0.35, false], "hurt for 0.35 s")
	var dx := dog.gx - pug.gx
	var dy := dog.gy - pug.gy
	var len := JsMath.hypot(dx, dy)
	assert_near(dog.knock_x, dx / len * 6.0, 1e-12, "knockback x away from him")
	assert_near(dog.knock_y, dy / len * 6.0, 1e-12, "knockback y away from him")
	# Cooldown: held against the dog, the next bump comes BUMP_COOLDOWN later.
	for k in range(1, 100):
		tick[0] = k
		_place_pug(w, pug, 0.2)
		th.update(DT, FakeInput.new())
	assert_eq(bumps.size(), 2, "two bumps in 100 ticks")
	assert_true(bumps[1] >= int(G.BUMP_COOLDOWN / DT) - 1 and bumps[1] <= int(G.BUMP_COOLDOWN / DT) + 1, "second bump after BUMP_COOLDOWN (tick %d)" % bumps[1])
	assert_eq(rules.hunger.value, hunger0 - 2.0 * G.BUMP_HUNGER, "hunger per bump")
	# Invulnerable or leaving: no bump effect.
	for blocker in ["invulnerable", "exit"]:
		var n0 := bumps.size()
		var h0: float = rules.hunger.value
		for k in 200:
			tick[0] = 1000 + k
			if blocker == "invulnerable":
				dog.invulnerable = 1.0
			else:
				dog.invulnerable = 0.0
				dog.state = "exit"
			_place_pug(w, pug, 0.2)
			th.update(DT, FakeInput.new())
		assert_eq([bumps.size(), rules.hunger.value], [n0, h0], "no bump while %s" % blocker)
	# The source run's bump: the same hunger cost between the samples around it.
	var src: Dictionary = fixture()["threats_run"]
	var bump_tick := -1
	for e: Array in src["events"]:
		if e[1] == "bump":
			bump_tick = int(e[0])
	assert_true(bump_tick >= 0, "the source run has a bump")
	var run := _threats_run()
	var got_bump: Array = run["events"].filter(func(e: Array) -> bool: return e[1] == "bump")
	assert_eq(got_bump.size(), 1, "one bump in the port run")
	assert_eq(got_bump[0][0], bump_tick, "on the source tick")
	dog.free()


## GZ-044: BARK (through the input) queues a hit only for Bagnaskiz inside the cone and range
## (source inBarkCone, the fixture's pug-range samples); the hit lands after the sound wave's
## travel time d / WAVE_SPEED, not before; hits count up 1, 2, 3 in order (stunned, stunned, flee)
## with a knockback away from the dog.
func test_GZ_044_bark_cone_travel_delay_and_ordered_hits() -> void:
	const R := GameConfig.Bark
	for smp: Array in fixture()["threat_logic"]["bark_cone"]:
		if smp[6] == R.RANGE:
			assert_eq(ThreatLogic.in_bark_cone(smp[0], smp[1], smp[2], smp[3], smp[4], smp[5], smp[6], smp[7]), smp[8], "source cone sample %s" % [smp])
	var w := _facing_world()
	var dog: PlayableDog = w["dog"]
	var th: GreenZoneThreats = w["threats"]
	var pug := CritterControllers.BagnaskizController.new(0.0, 0.0)
	th.pug = pug
	var input := FakeInput.new()
	var hits: Array = []
	var tick := [0]
	th.bark_hit.connect(func(_x: float, _y: float, n: int) -> void: hits.append([tick[0], n, pug.state]))
	# Behind him, and ahead but out of range: barks queue nothing, no hit ever lands.
	for d in [-2.0, R.RANGE + 0.2]:
		th.bark_cooldown = 0.0
		_place_pug(w, pug, d)
		input.pending["bark"] = true
		th.update(DT, input)
		assert_eq(th.pending_hits.size(), 0, "no hit queued at %.1f tiles" % d)
		for k in 30:
			_place_pug(w, pug, d)
			th.update(DT, FakeInput.new())
		assert_eq([hits.size(), pug.hits], [0, 0], "no hit at %.1f tiles" % d)
	# Ahead at 2 tiles: three barks, each hit after the travel time.
	var expected_n := 0
	var left := 2.0 / R.WAVE_SPEED
	while left > 0.0:
		left -= DT
		expected_n += 1
	var barked_at: Array = []
	for k in 400:
		tick[0] = k
		if pug.is_active():
			_place_pug(w, pug, 2.0)
			if th.bark_cooldown <= 0.0 and th.pending_hits.is_empty() and barked_at.size() < 3:
				input.pending["action"] = true
				barked_at.append(k)
		var before := JsMath.hypot(pug.gx - dog.gx, pug.gy - dog.gy)
		th.update(DT, input)
		if hits.size() > 0 and hits[hits.size() - 1][0] == k:
			assert_true(JsMath.hypot(pug.gx - dog.gx, pug.gy - dog.gy) > before, "knocked away from the dog on hit %d (%.6f -> %.6f, k %.3f,%.3f)" % [hits.size(), before, JsMath.hypot(pug.gx - dog.gx, pug.gy - dog.gy), pug._kx, pug._ky])
		if hits.size() == 3:
			break
	assert_eq(hits.map(func(h: Array) -> int: return h[1]), [1, 2, 3], "ordered hit counts")
	assert_eq(hits.map(func(h: Array) -> String: return h[2]), ["stunned", "stunned", "flee"], "stunned, stunned, flee")
	for i in 3:
		assert_eq(hits[i][0] - barked_at[i], expected_n - 1, "hit %d lands after the travel time (%d ticks)" % [i + 1, expected_n])
	assert_eq(int((w["rules"] as GreenZoneRules).stats["barkHits"]), 3, "bark hits counted")
	dog.free()


## GZ-045: the third hit makes Bagnaskiz flee and raises the rules score by exactly FLEE_SCORE,
## once ("BYE PUG!"); later barks at the fleeing pug queue nothing and award nothing; he fades out
## and leaves the stage; the source run's flee award is the same.
func test_GZ_045_flee_awards_flee_score_exactly_once() -> void:
	const G := GameConfig.Bagnaskiz
	var w := _facing_world()
	var dog: PlayableDog = w["dog"]
	var rules: GreenZoneRules = w["rules"]
	var th: GreenZoneThreats = w["threats"]
	var pug := CritterControllers.BagnaskizController.new(0.0, 0.0)
	th.pug = pug
	var input := FakeInput.new()
	var scores: Array = []
	rules.score_added.connect(func(_x: float, _y: float, amount: int, label: String) -> void: scores.append([amount, label]))
	var fled := [0]
	th.bagnaskiz_fled.connect(func(_x: float, _y: float, s: int) -> void:
		fled[0] += 1
		assert_eq(s, G.FLEE_SCORE, "event score"))
	var gone := [0]
	th.pug_removed.connect(func(_p: RefCounted) -> void: gone[0] += 1)
	var score_before_flee := -1
	for k in 400:
		if pug.is_active():
			_place_pug(w, pug, 2.0)
			if th.bark_cooldown <= 0.0 and th.pending_hits.is_empty():
				input.pending["action"] = true
			if pug.hits == 2 and score_before_flee < 0:
				score_before_flee = rules.stats["score"]
		th.update(DT, input)
		if pug.state == "flee":
			break
	assert_eq(pug.state, "flee", "three hits: flee")
	assert_eq(rules.stats["score"] - score_before_flee, G.FLEE_SCORE, "score raised by exactly FLEE_SCORE")
	assert_eq(scores, [[G.FLEE_SCORE, "BYE PUG!"]], "one award, labelled")
	var after_flee: int = rules.stats["score"]
	# Barks at the fleeing pug, in cone and range, until he is gone.
	var barks_after := 0
	for k in 400:
		if th.pug == null:
			break
		if th.bark_cooldown <= 0.0 and JsMath.hypot(pug.gx - dog.gx, pug.gy - dog.gy) <= GameConfig.Bark.RANGE:
			dog.face(IsoGrid.dir_from_grid_vector(pug.gx - dog.gx, pug.gy - dog.gy, dog.facing))
			input.pending["bark"] = true
			barks_after += 1
		th.update(DT, input)
		assert_true(th.pending_hits.is_empty(), "no hit queued at a fleeing pug")
	assert_true(barks_after >= 1, "barked at him while he fled (%d)" % barks_after)
	assert_eq([rules.stats["score"], fled[0], scores.size(), pug.hits], [after_flee, 1, 1, 3], "never awarded again")
	assert_eq([th.pug, gone[0], pug.state], [null, 1, "gone"], "left the stage")
	# The source run: one flee event carrying FLEE_SCORE, and the score jump at that point.
	var src_fled: Array = fixture()["threats_run"]["events"].filter(func(e: Array) -> bool: return e[1] == "bagnaskizFled")
	assert_eq(src_fled.size(), 1, "one flee in the source run")
	assert_eq(int(src_fled[0][2]["score"]), G.FLEE_SCORE, "source award")
	dog.free()


## DOG-005b: the forced fetch (a grabbed magnet ball) cannot overlap illegally with bark, pee,
## eat, drink, hurt or exit: every tick's state, duration, control, lives, hunger, time, treats,
## pees, charges and balls equal the source scenario (bark/pee ignored and consumed during the
## fetch, a treat eaten without the eat state, no drink, a bump's hurt interrupting the fetch, the
## exit interrupting a second fetch), with the same event order.
func test_DOG_005b_forced_fetch_never_overlaps_illegally_like_source() -> void:
	var src: Dictionary = fixture()["rules_fetch"]
	var w := _world()
	var m: WorldMapModel = w["map"]
	var dog: PlayableDog = w["dog"]
	var rules: GreenZoneRules = w["rules"]
	var threats: GreenZoneThreats = w["threats"]
	var input := FakeInput.new()
	var log: Array = []
	var tick := [0]
	threats.fetched.connect(func(_x: float, _y: float, _p: float) -> void: log.append([tick[0], "fetch"]))
	threats.barked.connect(func(_x: float, _y: float, _d: String) -> void: log.append([tick[0], "bark"]))
	threats.bumped.connect(func(_x: float, _y: float) -> void: log.append([tick[0], "bump"]))
	rules.treat_eaten.connect(func(_i: int, _x: float, _y: float, _s: int) -> void: log.append([tick[0], "treat"]))
	rules.pee_started.connect(func(_x: float, _y: float, _m: bool, _r: float, _s: int) -> void: log.append([tick[0], "pee"]))
	rules.pee_empty.connect(func(_x: float, _y: float) -> void: log.append([tick[0], "peeEmpty"]))
	rules.drank.connect(func(_x: float, _y: float) -> void: log.append([tick[0], "drink"]))
	rules.life_lost.connect(func(_x: float, _y: float, _l: int) -> void: log.append([tick[0], "lifeLost"]))
	rules.level_complete.connect(func(_x: float, _y: float) -> void: log.append([tick[0], "levelComplete"]))
	var treat0: Array = rules.treats[0]
	var fountain: WorldMapModel.MapProp = null
	for p in m.props:
		if p.kind == "fountain":
			fountain = p
			break
	assert_eq([treat0[0], treat0[1]], src["treats"][0], "same first treat")
	var expected: Array = src["trace"]
	for k in 300:
		tick[0] = k
		if k == 5 or k == 150:
			threats.balls.append(CritterControllers.BallController.new(dog.gx + 0.3, dog.gy))
		if k == 10 or k == 160:
			input.pending["bark"] = true
		if k == 12 or k == 165:
			input.pending["pee"] = true
		if k == 20:
			dog.set_grid_position(treat0[0], treat0[1])
		if k == 40:
			dog.set_grid_position(fountain.x + 0.9, fountain.y)
		if k == 60:
			threats.pug = CritterControllers.BagnaskizController.new(dog.gx + 0.2, dog.gy)
			threats.pug.target_x = dog.gx
			threats.pug.target_y = dog.gy
		if k == 100:
			threats.pug = null
		if k == 200:
			dog.set_grid_position(m.exit.x + 0.3, m.exit.y + 0.3)
		rules.update(DT, input)
		if rules.state == "playing":
			threats.update(DT, input)
		var e: Array = expected[k]
		var got := [k, dog.state, dog.controllable, rules.stats["lives"], rules.stats["treats"], rules.stats["pees"], rules.bladder.charges, threats.balls.size(), rules.state]
		var want := [int(e[0]), e[1], e[3], int(e[4]), int(e[7]), int(e[8]), int(e[9]), int(e[10]), e[11]]
		if not assert_eq(got, want, "tick %d" % k):
			break
		assert_near(dog.state_duration, e[2], 1e-6, "tick %d duration" % k)
		assert_near(rules.hunger.value, e[5], 1e-6, "tick %d hunger" % k)
		assert_near(rules.stats["time"], e[6], 1e-6, "tick %d time" % k)
	assert_eq(log, src["events"].map(func(x: Array) -> Array: return [int(x[0]), x[1]]), "event order")
	dog.free()


## GZ-031–032: a cat sits (facing the dog) until he is within ALERT_DISTANCE, then flees on the
## shared solver; a startle (0.8 s hop) precedes fleeing; after LIFETIME it leaves and fades out over
## 1.2 s; touching one catches it once (coins, score, removal, never paid again); a BARK through
## GreenZoneThreats and the input startles only a cat inside the widened cone. The cue pair (GZ-033)
## is in test_green_zone_m3.gd.
func test_GZ_031_032_cat_idle_flee_startle_and_leave() -> void:
	var w := _world()
	var m: WorldMapModel = w["map"]
	var rng := DeterministicRng.new(7)
	var s: Array = _spot_at(m, 0.05)
	var cat := CritterControllers.CatController.new(s[0], s[1], Color.WHITE)
	assert_true(cat.step(DT, m, s[0] + 6.0, s[1], rng), "alive")
	assert_eq([cat.state, cat.anim.anim], ["idle", "idle"], "idle while the dog is far")
	cat.step(DT, m, s[0] + 4.0, s[1], rng)
	assert_eq(cat.state, "flee", "alerted within 5 tiles")
	var x0 := cat.gx
	var y0 := cat.gy
	for k in 30:
		cat.step(DT, m, s[0] + 1.0, s[1], rng)
	var moved := JsMath.hypot(cat.gx - x0, cat.gy - y0)
	assert_true(moved > 0.5 and moved <= GameConfig.Cat.SPEED * 31 * DT + 1e-9, "fled at cat speed (%.3f tiles in 0.5 s)" % moved)
	assert_eq(cat.anim.anim, "run", "runs at full speed")
	cat.startle()
	cat.step(DT, m, s[0] + 1.0, s[1], rng)
	assert_eq(cat.state, "startled", "startled by a bark")
	assert_true(cat.z > 0.0, "hops")
	for k in 48:
		cat.step(DT, m, s[0] + 1.0, s[1], rng)
	assert_eq(cat.state, "flee", "flees again after 0.8 s")
	cat.age = GameConfig.Cat.LIFETIME
	cat.step(DT, m, s[0] + 1.0, s[1], rng)
	assert_eq(cat.state, "leave", "leaves after its lifetime")
	cat.startle()
	assert_eq(cat.state, "leave", "a leaving cat cannot be startled")
	var alive := true
	var n := 0
	while alive and n < 200:
		alive = cat.step(DT, m, s[0] + 1.0, s[1], rng)
		n += 1
	assert_true(n >= 71 and n <= 73, "gone 1.2 s after leaving (%d ticks)" % n)
	# Catch: touching a cat that is not leaving pays COINS and SCORE once, removes it, bumps the dog.
	var dog: PlayableDog = w["dog"]
	var rules: GreenZoneRules = w["rules"]
	var threats: GreenZoneThreats = w["threats"]
	var caught := CritterControllers.CatController.new(dog.gx + 0.3, dog.gy, Color.WHITE)
	threats.cats.append(caught)
	var got: Array = []
	threats.cat_caught.connect(func(_x: float, _y: float, coins: int, score: int) -> void: got.append([coins, score]))
	threats.update(DT, FakeInput.new())
	assert_eq(got, [[GameConfig.Cat.COINS, GameConfig.Cat.SCORE]], "one catch")
	assert_eq([rules.stats["coins"], rules.stats["score"], threats.cats.size()], [GameConfig.Cat.COINS, GameConfig.Cat.SCORE, 0], "coins, score, removed")
	for k in 30:
		threats.update(DT, FakeInput.new())
	assert_eq([got.size(), rules.stats["coins"], rules.stats["score"]], [1, GameConfig.Cat.COINS, GameConfig.Cat.SCORE], "paid once, never again")
	dog.free()
	# Bark through GreenZoneThreats and the input: a cat inside the widened cone (×1.3 range and
	# angle, the source predicate on the fixture's cat-range samples) is startled; one behind the
	# dog and one ahead beyond the range are only alerted by distance.
	const R := GameConfig.Bark
	for smp: Array in fixture()["threat_logic"]["bark_cone"]:
		if smp[6] == R.RANGE * 1.3:
			assert_eq(ThreatLogic.in_bark_cone(smp[0], smp[1], smp[2], smp[3], smp[4], smp[5], smp[6], smp[7]), smp[8], "source cat-cone sample %s" % [smp])
	var w2 := _facing_world()
	var dog2: PlayableDog = w2["dog"]
	var th2: GreenZoneThreats = w2["threats"]
	var f: Array = w2["f"]
	var fl := JsMath.hypot(f[0], f[1])
	var at := func(d: float) -> CritterControllers.CatController:
		return CritterControllers.CatController.new(dog2.gx + f[0] / fl * d, dog2.gy + f[1] / fl * d, Color.WHITE)
	var cat_in: CritterControllers.CatController = at.call(2.0)
	var cat_out: CritterControllers.CatController = at.call(-2.0)
	var cat_far: CritterControllers.CatController = at.call(R.RANGE * 1.3 + 0.3)
	th2.cats.append_array([cat_in, cat_out, cat_far])
	var barks := [0]
	th2.barked.connect(func(_x: float, _y: float, _d: String) -> void: barks[0] += 1)
	var input := FakeInput.new()
	input.pending["bark"] = true
	th2.update(DT, input)
	assert_eq([barks[0], input.pending.has("bark")], [1, false], "one bark from the input, consumed")
	assert_eq([cat_in.state, cat_out.state, cat_far.state], ["startled", "flee", "flee"], "in cone: startled; behind or beyond range: alerted only")
	assert_true(cat_in.z > 0.0 and cat_out.z == 0.0 and cat_far.z == 0.0, "only the startled cat hops")
	dog2.free()


## GZ-034–036: the magnet pull beats walking near the ball but not running; a grab starts the
## forced fetch (2 s, no control) with the hunger and time penalties, once, and removes the ball.
func test_GZ_034_036_ball_magnet_escape_by_running_and_fetch_penalties() -> void:
	for run in [false, true]:
		var w := _world()
		var m: WorldMapModel = w["map"]
		var dog: PlayableDog = w["dog"]
		var rules: GreenZoneRules = w["rules"]
		var threats: GreenZoneThreats = w["threats"]
		var s: Array = _spot_at(m, 0.05)
		dog.set_grid_position(s[0], s[1])
		var ball := CritterControllers.BallController.new(s[0] + 0.55, s[1])
		threats.balls.append(ball)
		# Already at full speed away from the ball (steady state: walking 4.4, running 7.5 tiles/s).
		dog.vx = -(GameConfig.Player.RUN_SPEED if run else GameConfig.Player.WALK_SPEED)
		dog.vy = 0.0
		var fetched := [0]
		threats.fetched.connect(func(_x: float, _y: float, p: float) -> void:
			fetched[0] += 1
			assert_eq(p, GameConfig.Ball.TIME_PENALTY, "penalty"))
		var input := FakeInput.new()
		# Away from the ball on screen (the ball is +x in grid = down-right on screen).
		var away := IsoGrid.grid_vec_to_screen(-1.0, 0.0).normalized()
		input.move_x = away.x
		input.move_y = away.y
		input.run_held = run
		dog.energy.value = GameConfig.Energy.MAX
		var hunger0: float = rules.hunger.value
		for k in 90:
			rules.update(DT, input)
			threats.update(DT, input)
		if run:
			assert_eq(fetched[0], 0, "running escapes the magnet")
			assert_true(JsMath.hypot(dog.gx - ball.gx, dog.gy - ball.gy) > GameConfig.Ball.MAGNET_RADIUS * 0.5, "ran clear")
		else:
			assert_eq(fetched[0], 1, "walking is pulled in: one fetch")
			assert_true(threats.balls.is_empty(), "the grabbed ball is removed")
			assert_true(rules.stats["time"] >= GameConfig.Ball.TIME_PENALTY + 89 * DT - 1e-9, "time penalty added")
			assert_true(hunger0 - rules.hunger.value >= GameConfig.Ball.FETCH_HUNGER, "fetch hunger lost")
		dog.free()
	# Attraction curve (source magnetPull samples).
	for smp: Array in fixture()["threat_logic"]["magnet"]:
		assert_near(ThreatLogic.magnet_pull(smp[0], GameConfig.Ball.MAGNET_RADIUS, GameConfig.Ball.MAGNET_STRENGTH), smp[1], 1e-12, "curve at %.2f" % smp[0])
	# Fetch lock: FETCH_TIME seconds without control, then free again.
	var w2 := _world()
	var dog2: PlayableDog = w2["dog"]
	var th2: GreenZoneThreats = w2["threats"]
	var r2: GreenZoneRules = w2["rules"]
	th2.balls.append(CritterControllers.BallController.new(dog2.gx + 0.2, dog2.gy))
	var idle := FakeInput.new()
	var locked := 0
	for k in 180:
		r2.update(DT, idle)
		th2.update(DT, idle)
		if dog2.state == "fetch":
			locked += 1
			assert_false(dog2.controllable, "no control while fetching")
	assert_true(absi(locked - int(GameConfig.Ball.FETCH_TIME / DT)) <= 1, "fetch lasts FETCH_TIME (%d ticks)" % locked)
	assert_eq(dog2.state, "free", "free again")
	dog2.free()


## GZ-016–017: a pee within MARK_DISTANCE of a vertical prop marks it: larger radius and duration,
## the pee centred between dog and prop, MARK_SCORE and "MARKING!" the first time, the plain pee
## score for the same prop again; both count as marks.
func test_GZ_016_017_marking_radius_points_and_once_per_object() -> void:
	var w := _world()
	var m: WorldMapModel = w["map"]
	var dog: PlayableDog = w["dog"]
	var rules: GreenZoneRules = w["rules"]
	# A vertical prop with no other vertical prop within 4 tiles (so it is the one marked).
	var tree: WorldMapModel.MapProp = null
	for p in m.props:
		if not (p.vertical and p.solid):
			continue
		var alone := true
		for q in m.props:
			if q != p and q.vertical and JsMath.hypot(q.x - p.x, q.y - p.y) < 4.0:
				alone = false
				break
		if alone:
			tree = p
			break
	if not assert_true(tree != null, "an isolated vertical prop exists"):
		dog.free()
		return
	var seen: Array = []
	rules.pee_started.connect(func(x: float, y: float, marking: bool, r: float, score: int) -> void: seen.append([x, y, marking, r, score]))
	var labels: Array = []
	rules.score_added.connect(func(_x: float, _y: float, _a: int, label: String) -> void: labels.append(label))
	for k in 2:
		dog.set_grid_position(tree.x + 0.9, tree.y)
		rules.bladder.charges = rules.bladder.max_charges
		rules.try_pee()
		dog.state = "free"
	assert_eq(seen.size(), 2, "two pees")
	assert_eq([seen[0][2], seen[0][3], seen[0][4]], [true, GameConfig.Bladder.MARK_RADIUS, GameConfig.Bladder.MARK_SCORE], "first mark")
	assert_eq([seen[1][2], seen[1][3], seen[1][4]], [true, GameConfig.Bladder.MARK_RADIUS, GameConfig.Bladder.SCORE], "same prop again: plain score")
	assert_near(seen[0][0], (tree.x + 0.9 + tree.x) / 2.0, 1e-12, "centred between dog and prop")
	assert_eq(labels, ["MARKING!", ""], "MARKING! only once")
	assert_eq(rules.stats["marks"], 2, "both are marks")
	assert_eq(rules.stats["score"], GameConfig.Bladder.MARK_SCORE + GameConfig.Bladder.SCORE, "score")
	dog.set_grid_position(tree.x + GameConfig.Player.MARK_DISTANCE + tree.radius + 0.05, tree.y)
	rules.bladder.charges = 1
	dog.state = "free"
	rules.try_pee()
	assert_eq([seen[2][2], seen[2][3]], [false, GameConfig.Bladder.RADIUS], "beyond MARK_DISTANCE: a plain pee")
	dog.free()
