class_name GreenZoneRules
extends RefCounted
## Endless prototype rules: movement, treats, hunger, digestion, poop, pee and pollution.
## This model has no campaign, lives, exit, enemies or game-over state.

signal score_added(x: float, y: float, amount: int, label: String)
signal treat_eaten(index: int, x: float, y: float, score: int)
signal poop_dropped(pile: PoopPileModel)
signal poop_removed(pile: PoopPileModel)
signal pee_started(x: float, y: float, marking: bool, radius: float, score: int)
signal pee_empty(x: float, y: float)
signal drank(x: float, y: float)
signal splashed(x: float, y: float)
signal digest_warning(x: float, y: float)
signal hunger_depleted(x: float, y: float)
signal poop_cleaned(x: float, y: float, score: int)
signal tired(x: float, y: float)

const B := GameConfig.Bladder

var map: WorldMapModel
var player: PlayableDog
var level: LevelDefinition
var stats := {"score": 0, "pees": 0, "poops": 0, "treats": 0, "marks": 0, "time": 0.0}
var hunger := NeedsSystem.Hunger.new()
var digestion := NeedsSystem.Digestion.new()
var bladder := NeedsSystem.Bladder.new()
## Remaining treats: [[x, y, id], ...] in placement order.
var treats: Array = []
var poops: Array[PoopPileModel] = []

var _pees: Array = []  # [x, y, radius, elapsed, duration]
var _marked: Dictionary = {}
var _in_water := false


func _init(p_map: WorldMapModel, p_player: PlayableDog, p_level: LevelDefinition) -> void:
	map = p_map
	player = p_player
	level = p_level
	var placed := TreatPlacement.place_treats(map, level.spawns["treats"], level.seed)
	for k in placed.size():
		treats.append([placed[k][0], placed[k][1], k])


func health() -> float:
	return map.health()


func add_score(amount: int, x: float, y: float, label: String = "") -> void:
	stats["score"] += amount
	score_added.emit(x, y, amount, label)


func update(dt: float, input: Object) -> void:
	stats["time"] += dt
	if input.consume(&"pee"):
		try_pee()
	player.energy.recovery = GameConfig.Energy.HUNGRY_RECOVERY if hunger.value <= GameConfig.Hunger.LOW_WARNING else 1.0
	player.set_intent(input.move_x, input.move_y, input.run_held)
	player.update_movement(dt, map)
	if player.energy_event == "empty":
		tired.emit(player.gx, player.gy)
	var activity := "idle"
	if player.moving:
		activity = "run" if player.running else "walk"
	if hunger.update(dt, activity):
		# The prototype never ends: starvation briefly stuns Zampano and restores half hunger.
		hunger.value = GameConfig.Hunger.REFILL_ON_LIFE_LOST
		player.start_action("hurt", 0.6)
		player.invulnerable = GameConfig.Player.HURT_INVULN
		hunger_depleted.emit(player.gx, player.gy)
	# When the warning expires the poop is due; it happens as soon as he is free.
	digestion.update(dt)
	if digestion.due and player.state == "free":
		_do_poop()
	bladder.update(dt)
	_check_drink()
	_check_treats()
	# Pee spreads clean ground and neutralises poop while poop spreads pollution.
	for k in range(_pees.size() - 1, -1, -1):
		var p: Array = _pees[k]
		p[3] += dt
		var t := minf(1.0, p[3] / p[4])
		var r: float = p[2] * (1.0 - (1.0 - t) * (1.0 - t))
		map.clean(p[0], p[1], r)
		for poop in poops:
			if not poop.cleaned and JsMath.hypot(poop.gx - p[0], poop.gy - p[1]) <= r:
				poop.cleaned = true
				add_score(GameConfig.Poop.CLEAN_SCORE, poop.gx, poop.gy, "CLEAN!")
				poop_cleaned.emit(poop.gx, poop.gy, GameConfig.Poop.CLEAN_SCORE)
		if t >= 1.0:
			_pees.remove_at(k)
	for k in range(poops.size() - 1, -1, -1):
		var poop := poops[k]
		if not poop.step(dt, map):
			poops.remove_at(k)
			poop_removed.emit(poop)


func try_pee() -> void:
	if not player.controllable:
		return
	if not bladder.use():
		pee_empty.emit(player.gx, player.gy)
		return
	var target := map.nearest_prop(player.gx, player.gy, GameConfig.Player.MARK_DISTANCE, func(p: WorldMapModel.MapProp) -> bool: return p.vertical)
	var marking := target != null
	if target:
		player.face(IsoGrid.dir_from_grid_vector(target.x - player.gx, target.y - player.gy, player.facing))
	var radius := B.MARK_RADIUS if marking else B.RADIUS
	var duration := B.MARK_TIME if marking else B.PEE_TIME
	player.start_action("pee", duration)
	stats["pees"] += 1
	var cx := (player.gx + target.x) / 2.0 if target else player.gx
	var cy := (player.gy + target.y) / 2.0 if target else player.gy
	_pees.append([cx, cy, radius, 0.0, duration])
	var first_mark := target != null and not _marked.has(target.id)
	if target:
		_marked[target.id] = true
	var score := B.MARK_SCORE if first_mark else B.SCORE
	if marking:
		stats["marks"] += 1
	add_score(score, player.gx, player.gy, "MARKING!" if first_mark else "")
	pee_started.emit(cx, cy, marking, radius, score)


func _do_poop() -> void:
	var surface := map.poop_surface_at(player.gx, player.gy)
	var footprint := WorldMapModel.poop_footprint(surface)
	# Drop it just behind the dog.
	var bx := -JsMath.sign(player.vx if player.vx != 0.0 else 0.0001) * 0.15
	var by := -JsMath.sign(player.vy if player.vy != 0.0 else 0.0001) * 0.15
	var pile := PoopPileModel.new(player.gx + bx, player.gy + by, surface, footprint)
	poops.append(pile)
	map.stamp_dirt(pile.gx, pile.gy, footprint["radius"], footprint["strength"])
	player.start_action("poop", GameConfig.Digestion.SQUAT_TIME)
	player.bump(-0.25)
	stats["poops"] += 1
	var next := digestion.done()
	poop_dropped.emit(pile)
	if next == "warning":
		digest_warning.emit(player.gx, player.gy)


func _check_drink() -> void:
	var on_water := map.is_water_at(player.gx, player.gy)
	if on_water and not _in_water:
		splashed.emit(player.gx, player.gy)
	_in_water = on_water
	if not player.controllable or not bladder.can_drink():
		return
	var fountain: WorldMapModel.MapProp = null
	if not on_water:
		fountain = map.nearest_prop(player.gx, player.gy, GameConfig.Player.DRINK_DISTANCE, func(p: WorldMapModel.MapProp) -> bool: return p.kind == "fountain")
	if not on_water and fountain == null:
		return
	if bladder.drink():
		if fountain:
			player.face(IsoGrid.dir_from_grid_vector(fountain.x - player.gx, fountain.y - player.gy, player.facing))
		player.start_action("drink", B.DRINK_TIME)
		drank.emit(player.gx, player.gy)


func _check_treats() -> void:
	for k in range(treats.size() - 1, -1, -1):
		var t: Array = treats[k]
		if JsMath.hypot(t[0] - player.gx, t[1] - player.gy) > GameConfig.Treat.PICKUP_RADIUS:
			continue
		treats.remove_at(k)
		hunger.feed(GameConfig.Treat.HUNGER)
		stats["treats"] += 1
		add_score(GameConfig.Treat.SCORE, t[0], t[1])
		if player.state == "free":
			player.start_action("eat", 0.3)
		player.bump(0.22)
		treat_eaten.emit(int(t[2]), t[0], t[1], GameConfig.Treat.SCORE)
		if digestion.add(GameConfig.Treat.DIGESTION) == "warning":
			digest_warning.emit(player.gx, player.gy)


## Remaining warning time (HUD bubble), 0 when due, -1 when none.
func poop_warning() -> float:
	if digestion.warning:
		return digestion.warning_left
	return 0.0 if digestion.due else -1.0
