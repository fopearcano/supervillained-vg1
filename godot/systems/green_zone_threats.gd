class_name GreenZoneThreats
extends RefCounted
## Threats and bonuses of the Green Zone (port of src/systems/threats.ts): cats (coins), magnet
## balls (forced fetch), the three route-progress pollution waves, the "under attack" director
## with Bagnaskiz, and the dog's BARK.
##
## Pure model: it owns the critter controllers (CritterControllers) and emits local signals; the
## scene creates/removes their views. One shared threat RNG (seed ^ 0x5bd1e995) is drawn in the
## source order: cat and ball timers/spots/tints, wave spots, Bagnaskiz spawn and green targets.
## The source's unseeded Math.random in the flee steering is a second, seeded critter RNG here.

signal barked(x: float, y: float, dir: String)
signal pollution_surge(x: float, y: float, radius: float, tiles: int)
signal cat_added(cat: CritterControllers.CatController)
signal cat_removed(cat: CritterControllers.CatController)
signal cat_caught(x: float, y: float, coins: int, score: int)
signal ball_added(ball: CritterControllers.BallController)
signal ball_removed(ball: CritterControllers.BallController)
signal fetched(x: float, y: float, penalty: float)
signal pug_added(pug: CritterControllers.BagnaskizController)
signal pug_removed(pug: CritterControllers.BagnaskizController)
signal bark_hit(x: float, y: float, hits: int)
signal bagnaskiz_fled(x: float, y: float, score: int)
signal bumped(x: float, y: float)
signal attack_started(intensity: float)
signal attack_ended

const CAT_TINTS := [Color8(0xff, 0xff, 0xff), Color8(0xd8, 0xd8, 0xd8), Color8(0xff, 0xf0, 0xc0)]
## Seed of the critter RNG that stands in for the source's Math.random (flee jitter only).
const CRITTER_SEED_XOR := 0x2545f491

var map: WorldMapModel
var player: PlayableDog
var rules: GreenZoneRules
var wave_director: PollutionWaveDirector
var director: ThreatLogic.AttackDirector
var cats: Array[CritterControllers.CatController] = []
var balls: Array[CritterControllers.BallController] = []
var pug: CritterControllers.BagnaskizController = null
var bark_cooldown := 0.0
## Bark hits on their way (the sound wave travels): [delay, from_x, from_y].
var pending_hits: Array = []
var _cat_timer: float
var _ball_timer: float
var _rng: DeterministicRng
var _critter_rng: DeterministicRng


func _init(p_rules: GreenZoneRules) -> void:
	rules = p_rules
	map = rules.map
	player = rules.player
	var level := rules.level
	var ev: Dictionary = level.events.get("underAttack", {})
	director = ThreatLogic.AttackDirector.new(float(ev.get("threshold", GameConfig.Attack.HEALTH_THRESHOLD)), float(ev.get("scriptedProgress", -1.0)))
	wave_director = PollutionWaveDirector.new(level.events.get("pollutionWaves", []))
	_cat_timer = float(level.spawns["cats"]["first"])
	_ball_timer = float(level.spawns["balls"]["first"])
	_rng = DeterministicRng.new((level.seed ^ 0x5bd1e995) & 0xFFFFFFFF)
	_critter_rng = DeterministicRng.new((level.seed ^ CRITTER_SEED_XOR) & 0xFFFFFFFF)


func bark_readiness() -> float:
	return 1.0 - maxf(0.0, bark_cooldown) / GameConfig.Bark.COOLDOWN


func update(dt: float, input: Object) -> void:
	if bark_cooldown > 0.0:
		bark_cooldown -= dt
	# The action button (BARK in the Green Zone), a bark gesture or B.
	var a: bool = input.consume(&"action")
	var b: bool = input.consume(&"bark")
	if a or b:
		try_bark()
	_resolve_bark_hits(dt)
	_spawn(dt)
	_update_cats(dt)
	_update_balls(dt)
	# Entering a new park district opens pollution hotspots around the route, ahead where possible.
	var progress := map.progress_at(player.gx, player.gy)
	for wave: Dictionary in wave_director.update(progress):
		_start_pollution_wave(wave)
	var health := map.health()
	var signal_name := director.update(dt, health, progress, pug == null or pug.state == "gone")
	if signal_name == "start":
		_start_attack()
	elif signal_name == "end":
		attack_ended.emit()
	_update_pug(dt)


func try_bark() -> void:
	if bark_cooldown > 0.0 or not player.controllable:
		return
	const R := GameConfig.Bark
	bark_cooldown = R.COOLDOWN
	player.start_action("bark", R.ANIM_TIME)
	player.bump(0.18)
	var f := IsoGrid.dir_to_grid_xy(player.facing)
	barked.emit(player.gx, player.gy, player.facing)
	if pug != null and pug.is_active() and ThreatLogic.in_bark_cone(player.gx, player.gy, f[0], f[1], pug.gx, pug.gy, R.RANGE, R.HALF_ANGLE):
		var d := JsMath.hypot(pug.gx - player.gx, pug.gy - player.gy)
		pending_hits.append([d / R.WAVE_SPEED, player.gx, player.gy])
	for cat in cats:
		if ThreatLogic.in_bark_cone(player.gx, player.gy, f[0], f[1], cat.gx, cat.gy, R.RANGE * 1.3, R.HALF_ANGLE * 1.3):
			cat.startle()


func _resolve_bark_hits(dt: float) -> void:
	for k in range(pending_hits.size() - 1, -1, -1):
		var h: Array = pending_hits[k]
		h[0] -= dt
		if h[0] > 0.0:
			continue
		pending_hits.remove_at(k)
		if pug == null or not pug.is_active():
			continue
		pug.hit(h[1], h[2])
		rules.stats["barkHits"] += 1
		bark_hit.emit(pug.gx, pug.gy, pug.hits)
		if pug.state == "flee":
			var score := GameConfig.Bagnaskiz.FLEE_SCORE
			rules.add_score(score, pug.gx, pug.gy, "BYE PUG!")
			bagnaskiz_fled.emit(pug.gx, pug.gy, score)


func _spawn(dt: float) -> void:
	var sp := rules.level.spawns
	var here := map.exit_distance[map.index(int(floor(player.gx)), int(floor(player.gy)))]
	# Prefer spots ahead of the dog (closer to the exit).
	var ahead := func(i: int, j: int) -> bool:
		var d := map.exit_distance[map.index(i, j)]
		return here < 0 or (d >= 0 and d <= here + 1)
	var cs: Dictionary = sp["cats"]
	_cat_timer -= dt
	if _cat_timer <= 0.0:
		_cat_timer = _rng.range_float(cs["interval"][0], cs["interval"][1])
		if cats.size() < int(cs["max"]):
			var spot: Variant = TreatPlacement.random_spot_near(map, player.gx, player.gy, GameConfig.Cat.SPAWN_MIN_DISTANCE, GameConfig.Cat.SPAWN_MAX_DISTANCE, _rng, ahead)
			if spot != null:
				var tint: Color = _rng.pick(CAT_TINTS)
				var cat := CritterControllers.CatController.new(spot[0], spot[1], tint)
				cats.append(cat)
				cat_added.emit(cat)
	var bs: Dictionary = sp["balls"]
	_ball_timer -= dt
	if _ball_timer <= 0.0:
		_ball_timer = _rng.range_float(bs["interval"][0], bs["interval"][1])
		if balls.size() < int(bs["max"]):
			var spot: Variant = TreatPlacement.random_spot_near(map, player.gx, player.gy, GameConfig.Ball.SPAWN_MIN_DISTANCE, GameConfig.Ball.SPAWN_MAX_DISTANCE, _rng, ahead)
			if spot != null:
				var ball := CritterControllers.BallController.new(spot[0], spot[1])
				balls.append(ball)
				ball_added.emit(ball)


func _update_cats(dt: float) -> void:
	const C := GameConfig.Cat
	for k in range(cats.size() - 1, -1, -1):
		var cat := cats[k]
		var alive := cat.step(dt, map, player.gx, player.gy, _critter_rng)
		if alive and cat.state != "leave" and JsMath.hypot(cat.gx - player.gx, cat.gy - player.gy) < C.TOUCH_RADIUS:
			rules.stats["coins"] += C.COINS
			rules.add_score(C.SCORE, cat.gx, cat.gy, "MEOW!")
			cat_caught.emit(cat.gx, cat.gy, C.COINS, C.SCORE)
			cats.remove_at(k)
			cat_removed.emit(cat)
			player.bump(0.2)
			continue
		if not alive:
			cats.remove_at(k)
			cat_removed.emit(cat)


func _update_balls(dt: float) -> void:
	const B := GameConfig.Ball
	for k in range(balls.size() - 1, -1, -1):
		var ball := balls[k]
		if not ball.step(dt):
			balls.remove_at(k)
			ball_removed.emit(ball)
			continue
		if ball.age > B.LIFETIME or not player.controllable:
			continue
		var dx := ball.gx - player.gx
		var dy := ball.gy - player.gy
		var d := JsMath.hypot(dx, dy)
		if d < B.GRAB_RADIUS:
			ball.taken = true
			player.start_action("fetch", B.FETCH_TIME)
			if rules.hunger.lose(B.FETCH_HUNGER):
				rules.lose_life()
			rules.stats["time"] += B.TIME_PENALTY
			fetched.emit(ball.gx, ball.gy, B.TIME_PENALTY)
			continue
		var pull := ThreatLogic.magnet_pull(d, B.MAGNET_RADIUS, B.MAGNET_STRENGTH)
		if pull > 0.0:
			player.push_x += (dx / d) * pull
			player.push_y += (dy / d) * pull


func _update_pug(dt: float) -> void:
	if pug == null:
		return
	var p := pug
	var r := p.step(dt, map, player.gx, player.gy, pick_green_target, _critter_rng)
	if r == "bump" and player.invulnerable <= 0.0 and player.state != "exit":
		player.knockback(player.gx - p.gx, player.gy - p.gy, 6.0)
		player.start_action("hurt", 0.35)
		bumped.emit(player.gx, player.gy)
		if rules.hunger.lose(GameConfig.Bagnaskiz.BUMP_HUNGER):
			rules.lose_life()
	if p.state == "gone":
		pug = null
		pug_removed.emit(p)


func _start_attack() -> void:
	if pug == null:
		const G := GameConfig.Bagnaskiz
		var spot: Variant = TreatPlacement.random_spot_near(map, player.gx, player.gy, G.SPAWN_DISTANCE - 2.0, G.SPAWN_DISTANCE, _rng)
		if spot == null:
			spot = TreatPlacement.random_spot_near(map, player.gx, player.gy, 3.0, 6.0, _rng)
		if spot != null:
			pug = CritterControllers.BagnaskizController.new(spot[0], spot[1])
			pug.target_x = player.gx
			pug.target_y = player.gy
			pug_added.emit(pug)
	attack_started.emit(director.intensity(map.health()))


func _start_pollution_wave(wave: Dictionary) -> void:
	var pi := int(floor(player.gx))
	var pj := int(floor(player.gy))
	var here := map.exit_distance[map.index(pi, pj)] if map.in_bounds(pi, pj) else -1
	var centers: Array = []
	var tiles := 0
	var radius: float = wave["radius"]
	var accepts := func(i: int, j: int) -> bool:
		var d := map.exit_distance[map.index(i, j)]
		if d < 0 or (here >= 0 and d > here + 2):
			return false
		for p: Array in centers:
			if JsMath.hypot(p[0] - i - 0.5, p[1] - j - 0.5) < radius * 1.4:
				return false
		return true
	var spread := func(i: int, j: int) -> bool:
		for p: Array in centers:
			if JsMath.hypot(p[0] - i - 0.5, p[1] - j - 0.5) < radius:
				return false
		return true
	var dist: Array = wave["distance"]
	for k in int(wave["count"]):
		var spot: Variant = TreatPlacement.random_spot_near(map, player.gx, player.gy, dist[0], dist[1], _rng, accepts)
		if spot == null:
			spot = TreatPlacement.random_spot_near(map, player.gx, player.gy, dist[0], dist[1], _rng, spread)
		if spot == null:
			continue
		centers.append(spot)
		tiles += map.stamp_dirt(spot[0], spot[1], radius, wave["strength"])
	# One global cue per encounter; the patches appear through the pollution overlay.
	if tiles > 0 and not centers.is_empty():
		pollution_surge.emit(centers[0][0], centers[0][1], radius, tiles)


## The greenest spot near the dog: where Bagnaskiz wants to go next. Returns [x, y].
func pick_green_target() -> Array:
	var best: Array = [player.gx, player.gy]
	var best_score := -INF
	for k in 14:
		var spot: Variant = TreatPlacement.random_spot_near(map, player.gx, player.gy, 1.0, 6.0, _rng)
		if spot == null:
			continue
		var clean := _clean_tiles_in_radius(spot[0], spot[1], 1.6)
		var score: float = clean - 0.15 * JsMath.hypot(spot[0] - pug.gx, spot[1] - pug.gy)
		if score > best_score:
			best_score = score
			best = spot
	return best


## Playable clean tiles whose centre lies within `radius` (source GameMap.forTilesInRadius).
func _clean_tiles_in_radius(cx: float, cy: float, radius: float) -> int:
	var n := 0
	var i0 := maxi(0, int(floor(cx - radius)))
	var i1 := mini(map.width - 1, int(floor(cx + radius)))
	var j0 := maxi(0, int(floor(cy - radius)))
	var j1 := mini(map.height - 1, int(floor(cy + radius)))
	for j in range(j0, j1 + 1):
		for i in range(i0, i1 + 1):
			if JsMath.hypot(i + 0.5 - cx, j + 0.5 - cy) <= radius:
				var idx := j * map.width + i
				if map.playable[idx] and map.dirt[idx] < GameConfig.Pollution.CLEAN_THRESHOLD:
					n += 1
	return n


## Deterministic run summary (debug and same-seed checks): live threats and the director.
func summary() -> Dictionary:
	var cat_list: Array = []
	for c in cats:
		cat_list.append([c.gx, c.gy, c.state])
	var ball_list: Array = []
	for b in balls:
		ball_list.append([b.gx, b.gy, b.taken])
	return {
		"cats": cat_list, "balls": ball_list, "attack": director.state, "waves_left": wave_director.remaining(),
		"pug": null if pug == null else [pug.gx, pug.gy, pug.state, pug.hits],
	}
