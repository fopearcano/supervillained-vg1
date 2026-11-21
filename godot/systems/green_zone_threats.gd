class_name GreenZoneThreats
extends RefCounted
## The part of src/systems/threats.ts in this milestone: the bark action and the three
## deterministic pollution waves. Cats, magnet balls, Bagnaskiz and the Under Attack director
## arrive in M3; until then the shared threat RNG is consumed only by the waves, so wave placement
## matches the source only up to the first cat spawn (16 s) — recorded as deviation D-03.

signal barked(x: float, y: float, dir: String)
signal pollution_surge(x: float, y: float, radius: float, tiles: int)

var map: WorldMapModel
var player: PlayableDog
var rules: GreenZoneRules
var wave_director: PollutionWaveDirector
var bark_cooldown := 0.0
var _rng: DeterministicRng


func _init(p_rules: GreenZoneRules) -> void:
	rules = p_rules
	map = rules.map
	player = rules.player
	wave_director = PollutionWaveDirector.new(rules.level.events.get("pollutionWaves", []))
	_rng = DeterministicRng.new((rules.level.seed ^ 0x5bd1e995) & 0xFFFFFFFF)


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
	var progress := map.progress_at(player.gx, player.gy)
	for wave: Dictionary in wave_director.update(progress):
		_start_pollution_wave(wave)


func try_bark() -> void:
	if bark_cooldown > 0.0 or not player.controllable:
		return
	bark_cooldown = GameConfig.Bark.COOLDOWN
	player.start_action("bark", GameConfig.Bark.ANIM_TIME)
	player.bump(0.18)
	barked.emit(player.gx, player.gy, player.facing)


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
	if tiles > 0 and not centers.is_empty():
		pollution_surge.emit(centers[0][0], centers[0][1], radius, tiles)
