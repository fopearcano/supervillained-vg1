extends TestCase
## NeedsSystem and GreenZoneRules against the source: a 1500-tick needs script and a scripted Green
## Zone run (treats -> digestion warning -> poop -> pee clean -> drink -> starvation -> game over)
## recorded from src/systems/rules.ts with the real Zampano class.

const DT := 1.0 / 60.0
const DOG := preload("res://entities/playable_dog/playable_dog.tscn")


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


func test_P_GZ_002_needs_script_matches_source() -> void:
	var h := NeedsSystem.Hunger.new()
	var d := NeedsSystem.Digestion.new()
	var b := NeedsSystem.Bladder.new()
	var e := NeedsSystem.Energy.new()
	var expected: Array = fixture()["needs"]
	var idx := 0
	for k in 1500:
		var act := "idle" if k < 300 else ("walk" if k < 600 else ("run" if k < 900 else "idle"))
		var starved := h.update(DT, act)
		if k % 100 == 0:
			d.add(26)
		var de := d.update(DT)
		if de == "poop":
			d.done()
		b.update(DT)
		if k in [50, 60, 70, 80]:
			b.use()
		if k == 1300:
			b.drink()
		var ee := e.update(DT, act)
		if k % 50 == 49 or starved or de != "" or ee != "":
			var x: Dictionary = expected[idx]
			idx += 1
			assert_eq(k, x["k"], "event tick")
			assert_near(h.value, x["hunger"], 1e-9, "k=%d hunger" % k)
			assert_eq(starved, x["starved"], "k=%d starved" % k)
			assert_near(d.meter, x["meter"], 1e-9, "k=%d meter" % k)
			assert_eq(d.warning, x["warning"], "k=%d warning" % k)
			assert_near(d.warning_left, x["warningLeft"], 1e-9, "k=%d warningLeft" % k)
			assert_eq(d.due, x["due"], "k=%d due" % k)
			assert_eq(de if de != "" else null, x["de"], "k=%d digestion event" % k)
			assert_eq(b.charges, x["charges"], "k=%d charges" % k)
			assert_near(b.regen_fraction(), x["regen"], 1e-9, "k=%d regen" % k)
			assert_eq(b.can_drink(), x["canDrink"], "k=%d canDrink" % k)
			assert_near(e.value, x["energy"], 1e-9, "k=%d energy" % k)
			assert_eq(e.exhausted, x["exhausted"], "k=%d exhausted" % k)
			assert_eq(ee if ee != "" else null, x["ee"], "k=%d energy event" % k)
	assert_eq(idx, expected.size(), "checkpoint count")


func test_SLICE_scripted_rules_run_matches_source() -> void:
	var fx: Dictionary = fixture()["rules_run"]
	var def := GreenZoneLevel.definition()
	var map := GreenZoneLevel.load_model(def)
	var dog: PlayableDog = DOG.instantiate()
	dog.set_grid_position(map.start.x, map.start.y)
	dog.face("N")
	var rules := GreenZoneRules.new(map, dog, def, 2)
	var log: Array = []
	var tick := [0]
	var rec := func(name: String) -> Callable:
		return func(_a = null, _b = null, _c = null, _d = null, _e = null) -> void: log.append([tick[0], name])
	rules.score_added.connect(rec.call("score"))
	rules.treat_eaten.connect(rec.call("treat"))
	rules.poop_dropped.connect(rec.call("poop"))
	rules.pee_started.connect(rec.call("pee"))
	rules.pee_empty.connect(rec.call("peeEmpty"))
	rules.drank.connect(rec.call("drink"))
	rules.splashed.connect(rec.call("splash"))
	rules.digest_warning.connect(rec.call("digestWarning"))
	rules.life_lost.connect(rec.call("lifeLost"))
	rules.game_over.connect(rec.call("gameOver"))
	rules.level_complete.connect(rec.call("levelComplete"))
	rules.poop_cleaned.connect(rec.call("poopCleaned"))
	rules.tired.connect(rec.call("tired"))
	assert_eq(rules.treats.size(), fx["treats_start"], "treats placed")
	var tp := {}
	for e: Array in fx["teleports"]:
		tp[int(e[0])] = [float(e[1][0]), float(e[1][1])]
	# The fixture recorded the target coordinates the source used; they must equal ours.
	assert_near(tp[180][0], rules.treats[0][0], 1e-9, "teleport target = first treat")
	var input := FakeInput.new()
	var trace: Array = fx["trace"]
	var ti := 0
	var final_tick := 0
	for t in 12000:
		tick[0] = t
		final_tick = t
		if tp.has(t):
			dog.set_grid_position(tp[t][0], tp[t][1])
		if t < 170:
			input.move_x = 0.0
			input.move_y = -0.8
			input.run_held = t > 90 and t < 140
		else:
			input.move_x = 0.0
			input.move_y = 0.0
			input.run_held = false
		if t >= 1000 and t < 1100:
			input.move_x = 0.6
			input.move_y = 0.2
		if t in [620, 640, 660, 680, 1200]:
			input.pending["pee"] = true
		rules.update(DT, input)
		if t % 60 == 59 or (t % 60 == 0 and t < 1300):
			if ti < trace.size():
				var e: Dictionary = trace[ti]
				ti += 1
				var lbl := "tick %d" % t
				assert_eq(t, e["tick"], "checkpoint tick")
				assert_near(dog.gx, e["gx"], 1e-9, lbl + " gx")
				assert_near(dog.gy, e["gy"], 1e-9, lbl + " gy")
				assert_eq(dog.state, e["state"], lbl + " dog state")
				for key in ["score", "pees", "poops", "treats", "marks", "lives"]:
					assert_eq(rules.stats[key], e[key], lbl + " " + key)
				assert_near(rules.stats["time"], e["time"], 1e-9, lbl + " time")
				assert_near(rules.hunger.value, e["hunger"], 1e-9, lbl + " hunger")
				assert_near(rules.digestion.meter, e["meter"], 1e-9, lbl + " digestion")
				assert_near(rules.poop_warning(), e["warning"], 1e-9, lbl + " warning")
				assert_eq(rules.bladder.charges, e["charges"], lbl + " charges")
				assert_eq(map.health(), e["health"], lbl + " health")
				assert_eq(map.clean_count, e["clean"], lbl + " clean tiles")
				assert_eq(rules.poops.map(func(p: PoopPileModel) -> float: return p.radius), e["poopRadius"], lbl + " poop radii")
				assert_eq(rules.state, e["rstate"], lbl + " run state")
				if not failures.is_empty():
					return
		if rules.state != "playing" and rules.ended_for() > 2.0:
			break
	assert_eq(final_tick, fx["final_tick"], "final tick")
	assert_eq(rules.state, fx["final_state"], "final state")
	var src_log: Array = (fx["events"] as Array).map(func(e: Array) -> Array: return [int(e[0]), e[1]])
	assert_eq(log, src_log, "event sequence")
	dog.free()


func test_SLICE_exit_completes_level_like_source() -> void:
	var fx: Dictionary = fixture()["exit_run"]
	var def := GreenZoneLevel.definition()
	var map := GreenZoneLevel.load_model(def)
	var dog: PlayableDog = DOG.instantiate()
	dog.set_grid_position(fx["start"][0], fx["start"][1])
	var rules := GreenZoneRules.new(map, dog, def, 2)
	var completed_at := [-1]
	var tick := [0]
	rules.level_complete.connect(func(_x: float, _y: float) -> void: completed_at[0] = tick[0])
	var input := FakeInput.new()
	input.move_y = -0.8
	var t := 0
	while t < 120 and rules.state == "playing":
		tick[0] = t
		rules.update(DT, input)
		t += 1
	assert_eq(t, fx["ticks"], "ticks to exit")
	assert_eq(rules.state, fx["state"], "state")
	assert_eq(completed_at[0], fx["log"][0][1], "levelComplete tick")
	assert_near(dog.gx, fx["player"][0], 1e-9, "gx")
	assert_eq(dog.state, fx["player"][2], "player state")
	dog.free()


## Replays a source rules scenario (fixture rules_busy / rules_overlap) tick by tick.
func _scenario(name: String, script: Callable, ticks: int) -> void:
	var fx: Dictionary = fixture()[name]
	var def := GreenZoneLevel.definition()
	var map := GreenZoneLevel.load_model(def)
	var dog: PlayableDog = DOG.instantiate()
	dog.set_grid_position(map.start.x, map.start.y)
	dog.face("N")
	var rules := GreenZoneRules.new(map, dog, def, 2)
	var log: Array = []
	var tick := [0]
	var rec := func(ev: String) -> Callable:
		return func(_a = null, _b = null, _c = null, _d = null, _e = null) -> void: log.append([tick[0], ev])
	rules.treat_eaten.connect(rec.call("treat"))
	rules.poop_dropped.connect(rec.call("poop"))
	rules.pee_started.connect(rec.call("pee"))
	rules.pee_empty.connect(rec.call("peeEmpty"))
	rules.drank.connect(rec.call("drink"))
	rules.splashed.connect(rec.call("splash"))
	rules.digest_warning.connect(rec.call("digestWarning"))
	rules.life_lost.connect(rec.call("lifeLost"))
	rules.game_over.connect(rec.call("gameOver"))
	rules.level_complete.connect(rec.call("levelComplete"))
	rules.poop_cleaned.connect(rec.call("poopCleaned"))
	var fountain: WorldMapModel.MapProp = null
	for p in map.props:
		if p.kind == "fountain":
			fountain = p
			break
	var ctx := {"map": map, "dog": dog, "rules": rules, "fountain": fountain}
	var input := FakeInput.new()
	var expected: Array = fx["trace"]
	for t in ticks:
		tick[0] = t
		script.call(t, ctx, input)
		rules.update(DT, input)
		var e: Array = expected[t]
		var lbl := "%s tick %d" % [name, t]
		var ok := assert_eq(dog.state, e[1], lbl + " state") and assert_near(dog.state_duration, e[2], 1e-6, lbl + " duration") \
			and assert_near(rules.poop_warning(), e[3], 1e-9, lbl + " warning") and assert_eq(rules.digestion.due, e[4], lbl + " due") \
			and assert_eq([rules.stats["poops"], rules.stats["pees"], rules.stats["treats"], rules.bladder.charges, rules.stats["lives"], rules.state],
				[e[5], e[6], e[7], e[8], e[9], e[10]], lbl + " counters")
		if not ok:
			dog.free()
			return
	assert_eq(log, (fx["events"] as Array).map(func(x: Array) -> Array: return [int(x[0]), x[1]]), name + " event sequence")
	dog.free()


func test_DOG_004_poop_waits_for_the_busy_action() -> void:
	_scenario("rules_busy", func(t: int, c: Dictionary, input: FakeInput) -> void:
		if t in [10, 20, 30, 40]:
			var tr: Array = c["rules"].treats.filter(func(x: Array) -> bool: return int(x[2]) == t / 10 - 1)[0]
			c["dog"].set_grid_position(tr[0], tr[1])
		if t == 215:
			input.pending["pee"] = true, 330)


func test_P_DOG_005_overlapping_actions_resolve_like_source() -> void:
	var first_treat: Array = []
	_scenario("rules_overlap", func(t: int, c: Dictionary, input: FakeInput) -> void:
		var dog: PlayableDog = c["dog"]
		if t == 0:
			first_treat.append_array(c["rules"].treats[0])
		if t == 5:
			dog.start_action("bark", GameConfig.Bark.ANIM_TIME)
		if t in [8, 40, 50, 125, 170]:
			input.pending["pee"] = true
		if t == 52:
			dog.set_grid_position(first_treat[0], first_treat[1])
		if t == 120:
			c["rules"].hunger.value = 0.001
		if t == 150:
			dog.set_grid_position(c["fountain"].x + 0.9, c["fountain"].y)
		if t == 230:
			dog.set_grid_position(c["map"].exit.x + 0.3, c["map"].exit.y + 0.3), 260)


func test_SLICE_bark_is_gated_like_source_try_bark() -> void:
	# Source Threats.tryBark: needs the cooldown elapsed and a controllable dog; bark keeps control.
	var def := GreenZoneLevel.definition()
	var map := GreenZoneLevel.load_model(def)
	var dog: PlayableDog = DOG.instantiate()
	dog.set_grid_position(map.start.x, map.start.y)
	var rules := GreenZoneRules.new(map, dog, def, 2)
	var threats := GreenZoneThreats.new(rules)
	var barks := [0]
	threats.barked.connect(func(_x: float, _y: float, _d: String) -> void: barks[0] += 1)
	threats.try_bark()
	assert_eq([barks[0], dog.state, dog.controllable], [1, "bark", true], "bark starts and keeps control")
	threats.try_bark()
	assert_eq(barks[0], 1, "cooldown blocks a second bark")
	threats.bark_cooldown = 0.0
	dog.start_action("pee", GameConfig.Bladder.PEE_TIME)
	threats.try_bark()
	assert_eq(barks[0], 1, "no bark while a locking action runs")
	dog.free()
