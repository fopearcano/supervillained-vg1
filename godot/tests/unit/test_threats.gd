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


## GZ-042–045: Bagnaskiz spawns with the scripted attack, roams toward green targets leaving a
## pollution trail, bumps the dog (knockback, hurt, hunger), takes delayed bark hits inside the
## cone, flees after three, awards FLEE_SCORE once and leaves; positions and states equal the
## source run.
func test_GZ_042_045_bagnaskiz_targets_trails_bumps_hits_and_flees_like_source() -> void:
	var run := _threats_run()
	var ev: Array = run["events"]
	var names: Array = ev.map(func(e: Array) -> String: return e[1])
	assert_eq(names.count("attackStart"), 1, "one attack")
	assert_eq(names.count("bump"), 1, "bumped once (cooldown and invulnerability)")
	assert_eq(names.count("barkHit"), 3, "three hits")
	assert_eq(names.count("bagnaskizFled"), 1, "fled once")
	var hits: Array = ev.filter(func(e: Array) -> bool: return e[1] == "barkHit").map(func(e: Array) -> int: return e[2][2])
	assert_eq(hits, [1, 2, 3], "hit counter")
	var fled: Array = ev.filter(func(e: Array) -> bool: return e[1] == "bagnaskizFled")[0]
	assert_eq(fled[2][2], GameConfig.Bagnaskiz.FLEE_SCORE, "flee award")
	var bump_tick: int = ev.filter(func(e: Array) -> bool: return e[1] == "bump")[0][0]
	var after: Array = run["trace"].filter(func(t: Dictionary) -> bool: return t["tick"] > bump_tick)
	assert_true(after.size() > 0 and after[0]["hunger"] < 100.0, "hunger after the bump")
	var pugs: Array = run["trace"].filter(func(t: Dictionary) -> bool: return t["summary"]["pug"] != null)
	assert_true(pugs.size() >= 4, "Bagnaskiz on stage for a while (%d samples)" % pugs.size())
	var states := {}
	for t: Dictionary in pugs:
		states[t["summary"]["pug"][2]] = true
	assert_true(states.has("roam") and states.has("flee"), "roamed and fled (%s)" % [states.keys()])
	assert_eq(run["trace"][run["trace"].size() - 1]["summary"]["pug"], null, "gone at the end")
	# Targeting and trail: every sampled position, state and the zone health (trail dirt) equal the source.
	var src: Array = fixture()["threats_run"]["trace"]
	for i in mini(run["trace"].size(), src.size()):
		var g: Dictionary = run["trace"][i]
		var e: Dictionary = src[i]
		if e["pug"] == null:
			continue
		var p: Array = g["summary"]["pug"]
		assert_eq([p[2], p[3]], [e["pug"][2], int(e["pug"][3])], "tick %d pug state" % e["tick"])
		assert_near(p[0], e["pug"][0], 1e-6, "tick %d pug x" % e["tick"])
		assert_near(p[1], e["pug"][1], 1e-6, "tick %d pug y" % e["tick"])
		assert_near(g["health"], e["health"], 1e-9, "tick %d trail health" % e["tick"])


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
## shared solver; a bark startles it (0.8 s hop) before it flees; after LIFETIME it leaves and fades
## out over 1.2 s; touching one catches it (coins, score, removal). The bark cone that startles cats
## (×1.3) is in test_SLICE_bark_cone_and_magnet_curve_match_source; the cue pair (GZ-033) in
## test_green_zone_m3.gd.
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
	dog.free()


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
