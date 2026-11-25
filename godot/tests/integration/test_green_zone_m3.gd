extends TestCase
## M3: the complete Green Zone with real node wiring. AUTO-001 is driven only through InputService
## (no teleports, no rule or threat calls); the flow, audio and UI cases may set up state directly
## and say so. Logic advances in fixed 1/60 s ticks.

const SCENE := preload("res://scenes/green_zone/green_zone_scene.tscn")
const DT := 1.0 / 60.0

var scene: GreenZoneScene


func after_each() -> void:
	if scene and is_instance_valid(scene):
		scene.get_parent().remove_child(scene)
		scene.free()
	InputService.clear_injection()


func _spawn(briefing: bool = false) -> GreenZoneScene:
	scene = SCENE.instantiate()
	scene.show_briefing = briefing
	scene.manual_ticks = true
	tree.root.add_child(scene)
	scene.resize(Vector2i(216, 432))
	return scene


func _step(n: int = 1, render_every: int = 4) -> void:
	for k in n:
		InputService.update(DT)
		AudioService.advance_pending(DT)
		scene.tick(DT)
		if scene.ticks % render_every == 0:
			scene._process(DT)


## Counts every model signal of a run.
func _count_events(s: GreenZoneScene) -> Dictionary:
	var c := {}
	var add := func(name: String) -> Callable:
		return func(...args: Array) -> void: c[name] = int(c.get(name, 0)) + 1
	for pair: Array in [[s.rules.treat_eaten, "treat"], [s.rules.poop_dropped, "poop"], [s.rules.pee_started, "pee"],
			[s.rules.poop_cleaned, "poop_cleaned"], [s.rules.drank, "drink"], [s.rules.life_lost, "life_lost"],
			[s.rules.pee_empty, "pee_empty"], [s.threats.cat_caught, "cat"], [s.threats.ball_added, "ball_spawn"],
			[s.threats.fetched, "fetch"], [s.threats.barked, "bark"], [s.threats.bark_hit, "bark_hit"],
			[s.threats.bagnaskiz_fled, "fled"], [s.threats.bumped, "bump"], [s.threats.pollution_surge, "wave"],
			[s.threats.attack_started, "attack_start"], [s.threats.attack_ended, "attack_end"],
			[s.threats.cat_added, "cat_spawn"], [s.threats.pug_added, "pug_spawn"]]:
		(pair[0] as Signal).connect(add.call(pair[1]))
	var marks := [0]
	s.rules.pee_started.connect(func(_x: float, _y: float, marking: bool, _r: float, score: int) -> void:
		if marking and score == GameConfig.Bladder.MARK_SCORE:
			marks[0] += 1)
	c["_first_marks"] = marks
	return c


## AUTO-001: one seeded run driven only through InputService (movement, RUN, PEE and BARK presses;
## no teleports, no rule or threat calls): it eats treats, poops, pees (cleaning its poop), marks a
## tree, catches a cat, fetches a magnet ball, meets the pollution waves, goes through one full
## Under Attack (start, Bagnaskiz barked away three times, zone healed, end), refills at water and
## reaches the exit; the Supervillained snap, the level-end summary and the CONTINUE campaign
## handoff follow. The run summary is deterministic (a second identical run is compared in
## test_SLICE_auto_run_is_reproducible).
func test_AUTO_001_real_input_seeded_run_with_attack_reaches_exit() -> void:
	var out := _auto_run()
	var c: Dictionary = out["events"]
	var st: Dictionary = out["stats"]
	print("       AUTO-001: %s" % [out["line"]])
	print("       events: %s" % [c])
	print("       driver: %s" % [out["driver"]])
	assert_eq(out["state"], "complete", "reached the exit")
	assert_true(int(c.get("treat", 0)) >= 1 and int(c.get("poop", 0)) >= 1, "ate and pooped")
	assert_true(int(c.get("pee", 0)) >= 1 and int(c.get("poop_cleaned", 0)) >= 1, "peed and cleaned a poop")
	assert_true(c["_first_marks"][0] == 1, "marked an object once")
	assert_true(int(c.get("cat", 0)) >= 1 and int(st["coins"]) >= GameConfig.Cat.COINS, "caught a cat")
	assert_true(int(c.get("fetch", 0)) >= 1, "fetched a magnet ball")
	assert_eq(int(c.get("wave", 0)), 3, "three pollution waves")
	assert_eq(int(c.get("attack_start", 0)), int(c.get("attack_end", 0)), "every attack ended")
	assert_true(int(c.get("attack_start", 0)) >= 1, "an attack happened")
	assert_true(int(c.get("bark_hit", 0)) >= 3 and int(c.get("fled", 0)) >= 1, "Bagnaskiz barked away")
	assert_true(int(c.get("drink", 0)) >= 1, "refilled the bladder")
	var r: Dictionary = out["result"]
	assert_eq(r.get("state"), "complete", "level-end result")
	var health := ScoringRules.final_health(out["map_health"], st["pees"], st["poops"])
	assert_near(r["health"], health, 1e-12, "final health with the pee deficit")
	assert_eq(r["stars"], ScoringRules.stars_from_health(health), "stars")
	assert_eq(r["total"], int(st["score"]) + ScoringRules.time_bonus(st["time"], GreenZoneLevel.definition().par_time) + ScoringRules.star_bonus(r["stars"]), "total")
	assert_eq(out["handoff"].get("coins"), int(st["coins"]), "handoff coins")
	assert_near(out["handoff"].get("time", -1.0), st["time"], 1e-9, "handoff time")
	assert_eq([out["handoff"].get("from"), out["handoff"].get("to")], ["1.0", "1.1"], "1.0 → 1.1")


static var _auto_cache: Dictionary = {}


func _auto_run() -> Dictionary:
	if not _auto_cache.is_empty():
		return _auto_cache
	_spawn()
	var c := _count_events(scene)
	var driver := GreenZoneDriver.new()
	var stalled := false
	for t in 60 * 300:
		if scene.rules.state != "playing":
			break
		driver.step(scene)
		_step(1, 6)
		if driver.stalled(60 * 60):
			stalled = true
			break
	InputService.clear_injection()
	var map_health := scene.world.map.health()
	_step(80)
	var out := {"state": scene.rules.state, "stalled": stalled, "events": c, "stats": scene.rules.stats.duplicate(),
		"driver": driver.report, "map_health": map_health, "result": scene.result, "handoff": {},
		"summary": scene.debug_state()}
	# The Supervillained snap, then the result card, then CONTINUE.
	var sv := scene._overlay as SupervillainedOverlay
	out["snap"] = sv != null
	if sv:
		sv.step(GameConfig.Supervillained.HOLD + 0.05)
	var end := scene._overlay as LevelEndOverlay
	out["level_end"] = end != null
	if end:
		var got := [{}]
		scene.campaign_handoff.connect(func(d: Dictionary) -> void: got[0] = d)
		end.skip = true
		end._process(DT)
		var labels: Array = end.items.map(func(i: Dictionary) -> String: return i["label"])
		out["menu"] = labels
		end.activate(labels.find("CONTINUE"))
		out["handoff"] = got[0]
	var st: Dictionary = out["stats"]
	out["line"] = "%s after %.1f s: treats %d, poops %d, pees %d, marks %d, coins %d, bark hits %d, lives %d, score %d, health %.4f, stars %.1f, total %s" % [
		out["state"], st["time"], st["treats"], st["poops"], st["pees"], st["marks"], st["coins"], st["barkHits"], st["lives"], st["score"],
		map_health, scene.result.get("stars", -1.0), scene.result.get("total", "-")]
	_auto_cache = out
	return out


## The same seeded real-input run twice: identical stats, events, driver decisions and final
## threat summary (same seed, same full spawn/threat summary through the whole scene).
func test_SLICE_auto_run_is_reproducible() -> void:
	_auto_cache = {}
	var a := _auto_run()
	scene.get_parent().remove_child(scene)
	scene.free()
	_auto_cache = {}
	var b := _auto_run()
	assert_eq(b["line"], a["line"], "same result line")
	var ea: Dictionary = a["events"].duplicate()
	var eb: Dictionary = b["events"].duplicate()
	ea.erase("_first_marks")
	eb.erase("_first_marks")
	assert_eq(eb, ea, "same events")
	assert_eq(b["driver"], a["driver"], "same driver decisions")
	assert_eq(b["summary"], a["summary"], "same final state and threat summary")


func _to_progress(p: float) -> void:
	var m := scene.world.map
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
	scene.world.player.set_grid_position(best[0], best[1])


## Threat events reach the source cues (src/fx/gameAudio.ts): cat → meow then the cash 0.35 s
## later; ball spawn → ball; fetch → fetch; bump → laser; bark hit → hit; Bagnaskiz fled → flee;
## attack start → alarm, the siren loop after SIREN_DELAY; pause stops the siren and resume
## restores it; attack end → siren stopped, saved, ZONE SAVED!. Setup places critters and the dog
## directly (a cue-mapping case, not the real-input run).
func test_SLICE_threat_events_reach_source_cues() -> void:
	_spawn()
	var dog := scene.world.player
	var th := scene.threats
	var cat := CritterControllers.CatController.new(dog.gx + 0.3, dog.gy, Color.WHITE)
	th.cats.append(cat)
	th.cat_added.emit(cat)
	_step(1)
	assert_eq(AudioService.requested.get(&"meow", 0), 1, "meow on the catch")
	assert_eq(AudioService.pending_count(), 1, "cash waits CASH_DELAY")
	_step(int(ceil(GameConfig.Audio.CASH_DELAY / DT)) + 1)
	assert_eq(AudioService.requested.get(&"coin", 0), 1, "cash after the meow")
	assert_eq(AudioService.pending_count(), 0, "cash started")
	var ball := CritterControllers.BallController.new(dog.gx + 0.2, dog.gy)
	th.balls.append(ball)
	th.ball_added.emit(ball)
	assert_eq(AudioService.requested.get(&"ball", 0), 1, "ball cue on spawn")
	_step(1)
	assert_eq([dog.state, AudioService.requested.get(&"fetch", 0)], ["fetch", 1], "fetch cue")
	_step(130)
	_to_progress(0.57)
	_step(1)
	assert_eq(th.director.state, "attack", "scripted attack")
	assert_eq(AudioService.requested.get(&"alarm", 0), 1, "alarm")
	assert_true(AudioService.active_loops().has(&"siren") and not AudioService.loop_started(&"siren"), "siren waits SIREN_DELAY")
	assert_true(scene.banner.big_title_shown(), "GREEN ZONE / UNDER ATTACK title")
	scene.open_pause()
	assert_false(AudioService.active_loops().has(&"siren"), "pause stops the siren")
	scene.resume()
	assert_true(AudioService.loop_started(&"siren"), "resume restarts the siren at once")
	var pug := th.pug
	if not assert_true(pug != null, "Bagnaskiz spawned"):
		return
	# Bump: put him on the dog.
	pug.gx = dog.gx + 0.2
	pug.gy = dog.gy
	dog.invulnerable = 0.0
	dog.state = "free"
	_step(1)
	assert_eq(AudioService.requested.get(&"laser", 0), 1, "bump → laser")
	# Three hits through the BARK button, facing him from 1.5 tiles.
	for k in 600:
		if th.pug == null or not th.pug.is_active():
			break
		if dog.controllable and th.bark_cooldown <= 0.0:
			dog.set_grid_position(th.pug.gx - 1.5, th.pug.gy)
			dog.face(IsoGrid.dir_from_grid_vector(1.0, 0.0))
			InputService.trigger(&"action")
		_step(1)
	assert_eq(AudioService.requested.get(&"hit", 0), 3, "three hits → hit ×3")
	assert_eq(AudioService.requested.get(&"flee", 0), 1, "fled → flee")
	# Heal the zone and wait for the end of the attack.
	for k in 600:
		if th.director.state != "attack":
			break
		scene.world.map.clean(dog.gx, dog.gy, 200.0)
		_step(1)
	assert_eq(th.director.state, "calm", "attack over")
	assert_false(AudioService.active_loops().has(&"siren"), "siren stopped")
	assert_eq(AudioService.requested.get(&"saved", 0), 1, "saved cue")
	assert_true(scene.banner.saved_shown(), "ZONE SAVED!")


## UI-001 (part): the radar shows cats (cyan, 3 px), balls (yellow, 2 px) and Bagnaskiz (orange,
## 4 px, blinking) besides treats, poops and the exit; the attack banner gives the bark hint (touch
## or keyboard wording) and the pee hint once he is gone; the touch controls mirror pee charges,
## bark readiness and energy.
func test_P_UI_001_radar_threats_banner_hints_and_button_state() -> void:
	_spawn()
	var dog := scene.world.player
	var th := scene.threats
	var cat := CritterControllers.CatController.new(dog.gx + 3.0, dog.gy, Color.WHITE)
	th.cats.append(cat)
	var ball := CritterControllers.BallController.new(dog.gx, dog.gy + 3.0)
	th.balls.append(ball)
	_to_progress(0.57)
	_step(1)
	var radar: Array = scene.hud_state()["radar"]
	var by_color := func(c: String) -> Array: return radar.filter(func(d: Dictionary) -> bool: return d["color"] == Color(c))
	assert_eq(by_color.call("#3ff0ff").size(), 1, "one cat dot")
	assert_eq(by_color.call("#3ff0ff")[0]["size"], 3, "cat dot size")
	assert_eq(by_color.call("#ffe23a")[0]["size"], 2, "ball dot size")
	var pug_dot: Array = by_color.call("#ff7a1f")
	assert_true(pug_dot.size() == 1 and pug_dot[0]["size"] == 4 and pug_dot[0]["blink"], "Bagnaskiz dot blinks")
	InputService.using_touch = false
	assert_eq(scene.attack_hint(), "BARK (J) AT BAGNASKIZ!", "keyboard bark hint")
	InputService.using_touch = true
	assert_eq(scene.attack_hint(), "BARK AT BAGNASKIZ!", "touch bark hint")
	_step(int(GameConfig.Attack.TITLE_TIME / DT) + 2)
	assert_false(scene.banner.big_title_shown(), "the big title ends after TITLE_TIME")
	assert_eq(scene.banner.hint, "BARK AT BAGNASKIZ!", "the reminder shows the hint")
	th.pug.state = "gone"
	scene.world.map.stamp_dirt(dog.gx, dog.gy, 12.0, 1.0)
	_step(1)
	assert_eq(scene.attack_hint(), "PEE TO HEAL THE ZONE!", "pee hint once he is gone and the zone is unhealthy")
	InputService.trigger(&"pee")
	_step(1)
	scene._process(DT)
	assert_eq(scene.controls.charges, scene.rules.bladder.charges, "pee charges on the button")
	dog.state = "free"
	InputService.trigger(&"action")
	_step(1)
	scene._process(DT)
	assert_true(scene.controls.bark_ready < 1.0, "bark readiness after a bark")
	assert_eq(scene.controls.energy, dog.energy.fraction(), "energy ring")


## FLOW-004: the level end computes the source summary (final health with the pee deficit, half
## stars, time and star bonuses, total, record) after the Supervillained snap; the snap cannot be
## skipped before SKIP_AFTER and can after; the result card's reveal can be skipped with confirm
## at any time without losing values; each full or half star plays 'star'; CONTINUE/RETRY as the
## story's 1.0, RETRY/TITLE outside it. The dog is placed at the exit (flow case).
func test_FLOW_004_level_end_summary_snap_and_safe_skip() -> void:
	for story in [true, false]:
		AudioService.reset_for_tests()
		_spawn()
		scene.as_story_scene = story
		var m := scene.world.map
		m.stamp_dirt(m.start.x, m.start.y, 3.0, 1.0)
		InputService.trigger(&"pee")
		_step(60)
		scene.world.player.set_grid_position(m.exit.x + 0.3, m.exit.y + 0.3)
		_step(1)
		assert_eq(scene.rules.state, "complete", "at the exit")
		var health0 := m.health()
		_step(70)
		var sv := scene._overlay as SupervillainedOverlay
		if not assert_true(sv != null, "the Supervillained snap comes first"):
			return
		sv.step(0.1)
		InputService.trigger(&"confirm")
		sv.step(0.1)
		assert_false(sv.finished, "no skip before SKIP_AFTER")
		assert_eq([AudioService.requested.get(&"glitch", 0), AudioService.requested.get(&"bark", 0)], [1, 1], "snap: glitch and bark")
		sv.step(0.3)
		InputService.trigger(&"confirm")
		sv.step(DT)
		assert_true(sv.finished, "confirm skips after SKIP_AFTER")
		var end := scene._overlay as LevelEndOverlay
		if not assert_true(end != null, "the result card follows"):
			return
		var st: Dictionary = scene.rules.stats
		var r := scene.result
		var health := ScoringRules.final_health(health0, st["pees"], st["poops"])
		assert_near(r["health"], health, 1e-12, "final health")
		assert_eq(r["stars"], ScoringRules.stars_from_health(health), "half-star floor")
		var tb := ScoringRules.time_bonus(st["time"], scene.level.par_time)
		var sb := ScoringRules.star_bonus(r["stars"])
		assert_eq([r["time_bonus"], r["star_bonus"], r["total"]], [tb, sb, int(st["score"]) + tb + sb], "bonuses and total")
		assert_true(SaveService.get_record("level1") != null, "record saved")
		var star_before: int = AudioService.requested.get(&"star", 0)
		end._process(0.05)
		assert_false(end.menu_visible(), "reveal running")
		InputService.trigger(&"confirm")
		end._process(DT)
		assert_true(end.skip and end.menu_visible(), "confirm skips the reveal; the menu is shown")
		end._process(DT)
		var lit := 0
		for k in 5:
			if r["stars"] >= k + 0.5:
				lit += 1
		assert_eq(int(AudioService.requested.get(&"star", 0)) - star_before, lit, "one star cue per full or half star")
		var labels: Array = end.items.map(func(i: Dictionary) -> String: return i["label"])
		assert_eq(labels, ["CONTINUE", "RETRY"] if story else ["RETRY", "TITLE"], "menu")
		scene.get_parent().remove_child(scene)
		scene.free()
		scene = null


# --- Terminal freeze (correction 26) -------------------------------------------------------------

## Everything the frozen level must keep: dog, critters (models and their AnimatedSprite2D),
## rule time, map dirt and fresh timers, camera, attack director and look, scene clocks.
func _frozen_state() -> Dictionary:
	var dog := scene.world.player
	var cam := scene.world.camera_rig
	var critters: Array = []
	for model: RefCounted in scene._critter_views:
		var v: CritterView = scene._critter_views[model]
		var sp: AnimatedSprite2D = v._sprite
		critters.append([model.get("gx"), model.get("gy"), v.position, sp.animation if sp else &"", sp.frame if sp else -1, sp.frame_progress if sp else -1.0])
	var rect := scene._attack_rect
	return {
		"dog": [dog.gx, dog.gy, dog.vx, dog.vy, dog.position, dog.state, dog.state_time, dog.invulnerable],
		"dog_sprite": [dog.body_sprite.animation, dog.body_sprite.frame, dog.body_sprite.frame_progress, dog.visual_root.scale],
		"critters": critters,
		"rules": [scene.rules.stats.duplicate(), scene.rules.ended_for(), scene.rules.hunger.value, scene.rules.state],
		"clocks": [scene.ticks, scene._time],
		"map": [Marshalls.raw_to_base64(scene.world.map.dirt.to_byte_array()).sha256_text(), scene.world.map.fresh.duplicate(), scene.world.map.health()],
		# The HUD clock (radar sweep, blinks) and the exit ring pulse: the presentation pass is frozen too.
		"presentation": [scene.hud._clock, scene._exit_ring.modulate, scene.world.visible_count],
		"camera": [cam.position, cam.model.x, cam.model.y, cam.model.shake_x, cam.model.shake_y, cam.model._shake_amp, cam.model._time],
		"attack": [scene.threats.director.state, scene.threats.director.elapsed, scene.attack_fx, scene.burst,
			rect.sepia, rect.scanlines, rect.glitch, rect.rgb, rect.fx_time, rect.visible, scene.banner._t],
	}


func _assert_same(frozen: Dictionary, where: String) -> void:
	var now := _frozen_state()
	for k: String in frozen:
		assert_eq(now[k], frozen[k], "%s unchanged %s" % [k, where])


## Tries hard to move the frozen level: manual ticks and presentation passes, then real frames
## with the scene ticking on its own physics callback (as in the shipped game).
func _push_frozen_level(overlay: Control) -> Dictionary:
	for k in 30:
		scene.tick(DT)
		scene._process(DT)
	scene.manual_ticks = false
	var t0: float = overlay.get("time")
	for k in 12:
		await tree.physics_frame
		await tree.process_frame
	scene.manual_ticks = true
	return {"overlay_time_before": t0, "overlay_time_after": overlay.get("time")}


## A level with a cat, a ball and Bagnaskiz on stage and the attack look running.
func _busy_level() -> void:
	_spawn()
	var dog := scene.world.player
	var th := scene.threats
	_to_progress(0.57)
	_step(1)
	var cat := CritterControllers.CatController.new(dog.gx + 4.0, dog.gy, Color.WHITE)
	th.cats.append(cat)
	th.cat_added.emit(cat)
	var ball := CritterControllers.BallController.new(dog.gx - 5.0, dog.gy)
	th.balls.append(ball)
	th.ball_added.emit(ball)
	_step(40)
	assert_true(th.director.state == "attack" and th.pug != null and scene.attack_fx > 0.0, "busy level: attack, Bagnaskiz, attack look")


## The level stops under the Supervillained snap and the result card (source scenes pause the
## scene below), after the unchanged 1.1 s post-exit delay; the overlays keep running and taking
## input; CONTINUE and RETRY still emit their requests.
func test_SLICE_terminal_freeze_under_snap_and_result_card() -> void:
	_busy_level()
	var m := scene.world.map
	scene.world.player.set_grid_position(m.exit.x + 0.3, m.exit.y + 0.3)
	_step(1)
	assert_eq(scene.rules.state, "complete", "at the exit")
	# The post-exit delay: the level still ticks (and its sprites animate) until ended_for > 1.1.
	var before_delay := _frozen_state()
	for k in 6:
		await tree.process_frame
	_step(30)
	assert_false(scene.terminal_frozen, "not frozen during the post-exit delay")
	assert_true(scene._overlay == null, "no overlay during the delay")
	var during := _frozen_state()
	assert_true(during["rules"][1] > before_delay["rules"][1] and during["clocks"] != before_delay["clocks"], "the delay ticks on")
	assert_true(during["dog_sprite"] != before_delay["dog_sprite"] or during["critters"] != before_delay["critters"], "control: world sprites animate before the freeze")
	var n := 0
	while scene._overlay == null and n < 120:
		_step(1)
		n += 1
	var sv := scene._overlay as SupervillainedOverlay
	if not assert_true(sv != null and scene.terminal_frozen, "snap opened, level frozen"):
		return
	assert_true(scene.rules.ended_for() > 1.1 and scene.rules.ended_for() < 1.1 + 2.0 * DT, "opened right after the 1.1 s delay (%.4f s)" % scene.rules.ended_for())
	assert_eq(scene.world.process_mode, Node.PROCESS_MODE_DISABLED, "world nodes disabled")
	var frozen := _frozen_state()
	var push := await _push_frozen_level(sv)
	_assert_same(frozen, "under the snap")
	assert_true(push["overlay_time_after"] > push["overlay_time_before"], "the snap keeps running")
	# Input still reaches the snap: confirm after SKIP_AFTER opens the result card.
	sv.step(GameConfig.Supervillained.SKIP_AFTER)
	InputService.trigger(&"confirm")
	sv.step(DT)
	var end := scene._overlay as LevelEndOverlay
	if not assert_true(end != null, "confirm moved on to the result card"):
		return
	push = await _push_frozen_level(end)
	_assert_same(frozen, "under the result card")
	assert_true(push["overlay_time_after"] > push["overlay_time_before"], "the result card keeps running")
	InputService.trigger(&"confirm")
	end._process(DT)
	assert_true(end.skip and end.menu_visible(), "confirm still skips the reveal")
	var got := {"handoff": 0, "retry": 0}
	scene.campaign_handoff.connect(func(_d: Dictionary) -> void: got["handoff"] += 1)
	scene.restart_requested.connect(func() -> void: got["retry"] += 1)
	end.activate(0)
	end.activate(1)
	assert_eq(got, {"handoff": 1, "retry": 1}, "CONTINUE and RETRY still emit")
	_assert_same(frozen, "after the menu")


## The level stops under GAME OVER (after the same delay); the card keeps running; RETRY and
## QUIT TO TITLE still emit.
func test_SLICE_terminal_freeze_under_game_over() -> void:
	_busy_level()
	scene.rules.stats["lives"] = 1
	scene.rules.hunger.value = 0.01
	_step(1)
	assert_eq(scene.rules.state, "gameover", "starved")
	var n := 0
	while scene._overlay == null and n < 120:
		_step(1)
		n += 1
	var over := scene._overlay as GameOverOverlay
	if not assert_true(over != null and scene.terminal_frozen, "game over opened, level frozen"):
		return
	assert_true(scene.rules.ended_for() > 1.1 and scene.rules.ended_for() < 1.1 + 2.0 * DT, "opened right after the 1.1 s delay")
	var frozen := _frozen_state()
	var push := await _push_frozen_level(over)
	_assert_same(frozen, "under GAME OVER")
	assert_true(push["overlay_time_after"] > push["overlay_time_before"], "the card keeps running")
	var got := {"retry": 0, "title": 0}
	scene.restart_requested.connect(func() -> void: got["retry"] += 1)
	scene.title_requested.connect(func() -> void: got["title"] += 1)
	over.activate(0)
	over.activate(1)
	assert_eq(got, {"retry": 1, "title": 1}, "RETRY and QUIT TO TITLE still emit")
	_assert_same(frozen, "after the menu")
