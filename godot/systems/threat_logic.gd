class_name ThreatLogic
extends RefCounted
## Pure helpers of the threats and bonuses (port of src/systems/threatLogic.ts): the bark cone,
## the ball magnet curve and the critters' flee steering. No nodes, no rendering.


## True if (tx, ty) is inside the bark cone (range + half-angle around the facing vector).
static func in_bark_cone(px: float, py: float, facing_x: float, facing_y: float, tx: float, ty: float, bark_range: float, half_angle: float) -> bool:
	var dx := tx - px
	var dy := ty - py
	var d := JsMath.hypot(dx, dy)
	if d > bark_range:
		return false
	if d < 0.35:
		return true  # touching: always hit
	var fl := JsMath.hypot(facing_x, facing_y)
	if fl == 0.0:
		fl = 1.0
	var c := (dx * facing_x + dy * facing_y) / (d * fl)
	return c >= cos(half_angle)


## Ball magnet: pull speed (tiles/s) toward the ball at distance d; zero outside the radius.
static func magnet_pull(d: float, radius: float, strength: float) -> float:
	if d >= radius:
		return 0.0
	var t := 1.0 - d / radius
	return strength * pow(t, 0.6)


## Flee direction for a critter at (x, y) running from (from_x, from_y): 16 sampled directions,
## away from the threat, keeping momentum, avoiding blocked tiles ahead. Returns a unit grid
## vector [x, y] (64-bit), or [0, 0] when cornered. `rng` replaces the source's Math.random and is drawn once per
## open direction, in the source's order.
static func flee_direction(map: WorldMapModel, x: float, y: float, from_x: float, from_y: float, cur_x: float, cur_y: float, radius: float, rng: DeterministicRng) -> PackedFloat64Array:
	var best := PackedFloat64Array([0.0, 0.0])
	var best_score := -INF
	var d0 := JsMath.hypot(x - from_x, y - from_y)
	for k in 16:
		var a := (float(k) / 16.0) * PI * 2.0
		var dx := cos(a)
		var dy := sin(a)
		if map.circle_blocked(x + dx * 0.6, y + dy * 0.6, radius) or map.circle_blocked(x + dx * 1.3, y + dy * 1.3, radius):
			continue
		var far := JsMath.hypot(x + dx * 2.0 - from_x, y + dy * 2.0 - from_y) - d0
		var momentum := dx * cur_x + dy * cur_y
		var open := -0.8 if map.circle_blocked(x + dx * 2.4, y + dy * 2.4, radius) else 0.0
		var score := far + momentum * 0.6 + open + rng.next_float() * 0.4
		if score > best_score:
			best_score = score
			best = PackedFloat64Array([dx, dy])
	return best


## "GREEN ZONE UNDER ATTACK" (src/systems/threatLogic.ts AttackDirector): starts when zone health
## drops below the threshold (after the cooldown) or once at the scripted route progress; ends when
## Bagnaskiz is gone AND health is back above threshold + hysteresis.
class AttackDirector:
	extends RefCounted

	const A := GameConfig.Attack

	## "calm" or "attack".
	var state := "calm"
	var threshold: float
	## Route progress of the one scripted attack, or a negative value for none.
	var scripted_progress: float
	var cooldown := 0.0
	var scripted_done := false
	## Seconds since the attack started.
	var elapsed := 0.0

	func _init(p_threshold: float = A.HEALTH_THRESHOLD, p_scripted_progress: float = -1.0) -> void:
		threshold = p_threshold
		scripted_progress = p_scripted_progress

	## Returns "start", "end" or "".
	func update(dt: float, health: float, progress: float, pug_gone: bool) -> String:
		if state == "calm":
			if cooldown > 0.0:
				cooldown -= dt
			var scripted := scripted_progress >= 0.0 and not scripted_done and progress >= scripted_progress
			var unhealthy := health < threshold and cooldown <= 0.0
			if scripted or unhealthy:
				if scripted:
					scripted_done = true
				state = "attack"
				elapsed = 0.0
				return "start"
			return ""
		elapsed += dt
		if pug_gone and health >= threshold + A.HYSTERESIS:
			state = "calm"
			cooldown = A.COOLDOWN
			return "end"
		return ""

	## 0..1 strength of the visual effects at this health.
	func intensity(health: float) -> float:
		if state != "attack":
			return 0.0
		var deficit := maxf(0.0, threshold - health) / A.FULL_INTENSITY_DEFICIT
		return minf(1.0, A.BASE_INTENSITY + (1.0 - A.BASE_INTENSITY) * deficit)
