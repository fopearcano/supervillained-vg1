class_name GreenZoneDriver
extends RefCounted
## Real-input Green Zone driver (AUTO-001, the slice run and captures). It only sets InputService
## movement/RUN and presses PEE and BARK (the action button) — it never teleports, never calls a
## rule or threat method and never writes game state; it reads the scene to decide.
## Behaviours, in priority order: bark Bagnaskiz away (approach, face, bark in the cone); chase one
## cat at a run; walk into the first magnet ball (forced fetch), run clear of later ones; pee on
## its own poops; mark one tree/pole; heal the zone after an attack (pee on dirt); refill the
## bladder once at water; otherwise follow the BFS field to the exit, detouring to treats ahead.

const MARK_ONCE := 1
const CAT_CHASE_LIMIT := 60 * 7

var pee_cooldown := 0
var best_distance := 1 << 30
var ticks := 0
var last_progress_tick := 0
## What the driver did (for reports): counts of attempted behaviours.
var report := {"cat_chases": 0, "ball_fetch_attempt": 0, "ball_escapes": 0, "marks": 0, "heal_pees": 0, "refill_trips": 0, "barks": 0}
var _wanted_fetch := false
var _chased: Dictionary = {}
var _chase_ticks := 0
var _marked := 0
var _refilled := false
var _refill_target: Variant = null
var _nav_cache: Dictionary = {}
var _mode := "route"


func step(scene: GreenZoneScene) -> void:
	ticks += 1
	var m := scene.world.map
	var dog := scene.world.player
	var rules := scene.rules
	var threats := scene.threats
	var i := int(floor(dog.gx))
	var j := int(floor(dog.gy))
	var here := m.exit_distance[m.index(i, j)]
	if here < best_distance:
		best_distance = here
		last_progress_tick = ticks
	if pee_cooldown > 0:
		pee_cooldown -= 1
	var ready_to_bark := dog.state == "free" or dog.state == "bark" or dog.state == "eat"
	# Pee on its own poops once the squat ends.
	for p in rules.poops:
		if not p.cleaned and dog.state == "free" and JsMath.hypot(p.gx - dog.gx, p.gy - dog.gy) < 1.0 and pee_cooldown == 0 and rules.bladder.charges > 0:
			_pee()
	# 1. Bagnaskiz: approach, face him, bark inside the cone.
	var pug := threats.pug
	if pug != null and pug.is_active() and JsMath.hypot(pug.gx - dog.gx, pug.gy - dog.gy) < 10.0:
		_mode = "bagnaskiz"
		var d := JsMath.hypot(pug.gx - dog.gx, pug.gy - dog.gy)
		var f := IsoGrid.dir_to_grid_xy(dog.facing)
		if ready_to_bark and threats.bark_cooldown <= 0.0 and ThreatLogic.in_bark_cone(dog.gx, dog.gy, f[0], f[1], pug.gx, pug.gy, GameConfig.Bark.RANGE, GameConfig.Bark.HALF_ANGLE):
			InputService.trigger(&"action")
			report["barks"] += 1
		_steer(dog, pug.gx, pug.gy, 0.8 if d > 2.0 else 0.35, false)
		return
	# 2. One cat chase at a run.
	var cat := _cat_target(threats, dog)
	if cat != null:
		_mode = "cat"
		_chase_ticks += 1
		_steer(dog, cat.gx, cat.gy, 1.0, dog.can_run)
		return
	# 3. Balls: walk into the first one (forced fetch), run clear of the others.
	for ball in threats.balls:
		if ball.age > GameConfig.Ball.LIFETIME:
			continue
		var bd := JsMath.hypot(ball.gx - dog.gx, ball.gy - dog.gy)
		if not _wanted_fetch and bd < 6.0:
			_mode = "fetch"
			if not ball.taken and dog.controllable:
				report["ball_fetch_attempt"] = 1
				_steer(dog, ball.gx, ball.gy, 0.8, false)
				if bd < 0.6:
					_wanted_fetch = true
				return
		elif _wanted_fetch and bd < GameConfig.Ball.MAGNET_RADIUS:
			_mode = "escape"
			report["ball_escapes"] += 1
			_steer(dog, dog.gx * 2.0 - ball.gx, dog.gy * 2.0 - ball.gy, 1.0, dog.can_run)
			return
	if dog.state == "fetch":
		_wanted_fetch = true
	# 4. Mark one vertical prop on the way.
	if _marked < MARK_ONCE and dog.state == "free" and rules.bladder.charges >= 1 and pee_cooldown == 0:
		var prop := m.nearest_prop(dog.gx, dog.gy, GameConfig.Player.MARK_DISTANCE * 0.9, func(p: WorldMapModel.MapProp) -> bool: return p.vertical)
		if prop != null:
			_marked += 1
			report["marks"] += 1
			_pee()
	# 5. Heal after an attack: Bagnaskiz gone, zone below the end threshold → pee on dirt.
	var need_heal := threats.director.state == "attack" and threats.pug == null and m.health() < threats.director.threshold + GameConfig.Attack.HYSTERESIS
	if need_heal:
		_mode = "heal"
		if rules.bladder.charges > 0:
			var dirt: Variant = _nearest_dirt(m, dog)
			if dirt != null:
				if JsMath.hypot(dirt[0] - dog.gx, dirt[1] - dog.gy) < 1.0:
					if dog.state == "free" and pee_cooldown == 0:
						report["heal_pees"] += 1
						_pee()
					InputService.inject_move(0.0, 0.0, false)
					return
				_nav(m, dog, dirt[0], dirt[1], 0.8, false)
				return
		# Out of pee: refill at water (below) or wait for regeneration on the spot.
	# 6. Refill once at water/fountain when low.
	if (rules.bladder.charges == 0 or need_heal and rules.bladder.charges < rules.bladder.max_charges) and not _refilled:
		if _refill_target == null:
			_refill_target = _nearest_water(m, dog)
			if _refill_target != null:
				report["refill_trips"] += 1
		if _refill_target != null:
			_mode = "refill"
			if rules.bladder.charges == rules.bladder.max_charges or JsMath.hypot(_refill_target[0] - dog.gx, _refill_target[1] - dog.gy) < 0.4:
				_refilled = true
			else:
				_nav(m, dog, _refill_target[0], _refill_target[1], 0.8, false)
				return
	if need_heal:
		InputService.inject_move(0.0, 0.0, false)
		return
	_mode = "route"
	# 7. Route: treats ahead, else down the BFS distance field to the exit.
	var goal_x := -1.0
	var goal_y := -1.0
	var best_d := 4.0
	for tr: Array in rules.treats:
		var td := m.exit_distance[m.index(int(floor(tr[0])), int(floor(tr[1])))]
		var d := JsMath.hypot(tr[0] - dog.gx, tr[1] - dog.gy)
		if td >= 0 and td <= here + 1 and d < best_d:
			best_d = d
			goal_x = tr[0]
			goal_y = tr[1]
	if goal_x < 0.0:
		var next := _downhill(m, m.exit_distance, i, j)
		goal_x = next.x + 0.5
		goal_y = next.y + 0.5
	_steer(dog, goal_x, goal_y, 0.8, false)


func _pee() -> void:
	InputService.trigger(&"pee")
	pee_cooldown = 60


func _cat_target(threats: GreenZoneThreats, dog: PlayableDog) -> CritterControllers.CatController:
	if _chased.size() >= 1 and _chase_ticks > CAT_CHASE_LIMIT:
		return null
	for c in threats.cats:
		if c.state == "leave":
			continue
		var d := JsMath.hypot(c.gx - dog.gx, c.gy - dog.gy)
		if d < 9.0 and (_chased.is_empty() or _chased.has(c)) and _chase_ticks <= CAT_CHASE_LIMIT:
			if not _chased.has(c):
				_chased[c] = true
				report["cat_chases"] += 1
			return c
	return null


## Screen-space steering toward a grid point.
func _steer(dog: PlayableDog, gx: float, gy: float, mag: float, run: bool) -> void:
	var s := IsoGrid.grid_vec_to_screen(gx - dog.gx, gy - dog.gy)
	var length := JsMath.hypot(s.x, s.y)
	if length > 1e-6:
		InputService.inject_move(s.x / length * mag, s.y / length * mag, run)
	else:
		InputService.inject_move(0.0, 0.0, false)


## Steering along a BFS field from the target tile (around obstacles), direct when close.
func _nav(m: WorldMapModel, dog: PlayableDog, gx: float, gy: float, mag: float, run: bool) -> void:
	var key := Vector2i(int(floor(gx)), int(floor(gy)))
	if not _nav_cache.has(key):
		_nav_cache[key] = m.bfs(key.x, key.y)
	var field: PackedInt32Array = _nav_cache[key]
	var i := int(floor(dog.gx))
	var j := int(floor(dog.gy))
	if field[m.index(i, j)] <= 1 or field[m.index(i, j)] < 0:
		_steer(dog, gx, gy, mag, run)
		return
	var next := _downhill(m, field, i, j)
	_steer(dog, next.x + 0.5, next.y + 0.5, mag, run)


func _downhill(m: WorldMapModel, field: PackedInt32Array, i: int, j: int) -> Vector2i:
	var here := field[m.index(i, j)]
	for nb: Vector2i in [Vector2i(i + 1, j), Vector2i(i - 1, j), Vector2i(i, j + 1), Vector2i(i, j - 1)]:
		if m.in_bounds(nb.x, nb.y) and m.is_walkable(nb.x, nb.y) and field[m.index(nb.x, nb.y)] == here - 1:
			return nb
	return Vector2i(i, j)


## The nearest polluted playable tile centre within 8 tiles, or null.
func _nearest_dirt(m: WorldMapModel, dog: PlayableDog) -> Variant:
	var best: Variant = null
	var best_d := 8.0
	var ci := int(floor(dog.gx))
	var cj := int(floor(dog.gy))
	for j in range(cj - 8, cj + 9):
		for i in range(ci - 8, ci + 9):
			if not m.in_bounds(i, j) or not m.is_walkable(i, j):
				continue
			var idx := m.index(i, j)
			if m.playable[idx] and m.dirt[idx] >= GameConfig.Pollution.CLEAN_THRESHOLD:
				var d := JsMath.hypot(i + 0.5 - dog.gx, j + 0.5 - dog.gy)
				if d < best_d:
					best_d = d
					best = [i + 0.5, j + 0.5]
	return best


## The nearest water tile or fountain within 14 tiles, or null.
func _nearest_water(m: WorldMapModel, dog: PlayableDog) -> Variant:
	var best: Variant = null
	var best_d := 14.0
	var ci := int(floor(dog.gx))
	var cj := int(floor(dog.gy))
	for j in range(cj - 14, cj + 15):
		for i in range(ci - 14, ci + 15):
			if not m.in_bounds(i, j):
				continue
			var p := m.prop_at(i, j)
			var spot: Variant = null
			if p != null and p.kind == "fountain":
				spot = [p.x + p.radius + 0.6, p.y]
			elif m.is_walkable(i, j) and m.is_water_at(i + 0.5, j + 0.5):
				spot = [i + 0.5, j + 0.5]
			if spot != null:
				var d := JsMath.hypot(spot[0] - dog.gx, spot[1] - dog.gy)
				if d < best_d:
					best_d = d
					best = spot
	return best


func stalled(limit_ticks: int) -> bool:
	return ticks - last_progress_tick > limit_ticks
