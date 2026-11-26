extends TestCase
## Focused contract for the editable dog sandbox. It intentionally does not test discarded
## campaign, story, exit, enemies, lives, records or minigames.

const DT := 1.0 / 60.0
const GREEN_ZONE := preload("res://scenes/green_zone/green_zone_scene.tscn")
const MAIN := preload("res://main/main.tscn")

var _owned: Array[Node] = []


func after_each() -> void:
	for node in _owned:
		if is_instance_valid(node):
			if node.get_parent():
				node.get_parent().remove_child(node)
			node.queue_free()
	_owned.clear()


func _spawn_green_zone() -> GreenZoneScene:
	var scene: GreenZoneScene = GREEN_ZONE.instantiate()
	scene.manual_ticks = true
	tree.root.add_child(scene)
	_owned.append(scene)
	await tree.process_frame
	return scene


func _step(scene: GreenZoneScene, frames: int, move := Vector2.ZERO, run := false) -> void:
	InputService.inject_move(move.x, move.y, run)
	for _frame in frames:
		InputService.update(DT)
		scene.tick(DT)
	InputService.clear_injection()


func test_PROTOTYPE_001_launches_directly_into_the_dog_sandbox() -> void:
	var scene := await _spawn_green_zone()
	assert_true(scene.active, "sandbox starts immediately")
	assert_false(scene.paused, "not paused")
	assert_true(scene.world.player is PlayableDog, "Zampano uses the playable dog scene")
	assert_eq(scene.world.player.active_profile().id, &"zampano", "only Zampano is selected")
	assert_eq(scene.rules.treats.size(), 30, "treat loop is populated")
	assert_true(InputService.buttons.has(&"pee"), "PEE touch button")
	assert_true(InputService.buttons.has(&"run"), "RUN touch button")
	assert_true(InputService.buttons.has(&"menu"), "MENU touch button")
	assert_false(InputService.buttons.has(&"bark"), "no secondary BARK game")
	assert_eq(scene.rules.stats.keys().size(), 6, "only prototype counters remain")


func test_PROTOTYPE_002_movement_and_blocked_tiles_work() -> void:
	var scene := await _spawn_green_zone()
	var dog := scene.world.player
	var start := Vector2(dog.gx, dog.gy)
	_step(scene, 60, Vector2.RIGHT)
	assert_true(Vector2(dog.gx, dog.gy).distance_to(start) > 0.25, "dog moves through the real input/rules path")

	var edge := []
	for y in range(1, scene.world.map.height - 1):
		for x in range(1, scene.world.map.width - 1):
			if not scene.world.map.is_walkable(x, y):
				continue
			for direction: Vector2i in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]:
				if not scene.world.map.is_walkable(x + direction.x, y + direction.y):
					edge = [Vector2i(x, y), direction]
					break
			if not edge.is_empty():
				break
		if not edge.is_empty():
			break
	assert_false(edge.is_empty(), "map has a walkable edge against collision")
	if edge.is_empty():
		return
	var cell: Vector2i = edge[0]
	var direction: Vector2i = edge[1]
	dog.set_grid_position(cell.x + 0.5, cell.y + 0.5)
	var screen_direction := IsoGrid.grid_vec_to_screen(direction.x, direction.y).normalized()
	_step(scene, 90, screen_direction)
	assert_true(scene.world.map.is_walkable(int(floor(dog.gx)), int(floor(dog.gy))), "dog never enters the blocked tile")


func test_PROTOTYPE_003_treats_digest_into_poop_and_pee_cleans_it() -> void:
	var scene := await _spawn_green_zone()
	var planned := scene.rules.treats.slice(0, 4, 1, true)
	for treat: Array in planned:
		scene.world.player.set_grid_position(treat[0], treat[1])
		_step(scene, 2)
	assert_eq(scene.rules.stats["treats"], 4, "four treats eaten")
	assert_true(scene.rules.digestion.warning or scene.rules.digestion.due, "digestion reaches the poop warning")
	_step(scene, 260)
	assert_eq(scene.rules.stats["poops"], 1, "digestion automatically produces poop")
	assert_eq(scene.rules.poops.size(), 1, "poop exists in the world model")
	assert_true(scene.rules.health() < 1.0, "poop pollutes the Green Zone")
	if scene.rules.poops.is_empty():
		return

	var pile: PoopPileModel = scene.rules.poops[0]
	_step(scene, 60)
	scene.world.player.set_grid_position(pile.gx, pile.gy)
	var charges_before := scene.rules.bladder.charges
	InputService.trigger(&"pee")
	_step(scene, 2)
	assert_eq(scene.rules.bladder.charges, charges_before - 1, "pee consumes one charge")
	assert_true(pile.cleaned, "pee neutralises the nearby poop")
	assert_true(scene.rules.stats["score"] >= GameConfig.Poop.CLEAN_SCORE, "cleaning awards score")

	var water := Vector2i(-1, -1)
	for y in scene.world.map.height:
		for x in scene.world.map.width:
			if scene.world.map.ground_at(x, y) == TileCatalog.Ground.WATER:
				water = Vector2i(x, y)
				break
		if water.x >= 0:
			break
	assert_true(water.x >= 0, "prototype map has drinkable water")
	if water.x >= 0:
		scene.rules.bladder.charges = 0
		scene.world.player.set_grid_position(water.x + 0.5, water.y + 0.5)
		_step(scene, 90)
		assert_eq(scene.rules.bladder.charges, scene.rules.bladder.max_charges, "water refills pee charges")


func test_PROTOTYPE_004_pause_freezes_and_resume_restores_the_sandbox() -> void:
	var scene := await _spawn_green_zone()
	_step(scene, 10, Vector2.RIGHT)
	var ticks_before := scene.ticks
	var time_before: float = scene.rules.stats["time"]
	scene.open_pause()
	scene.tick(1.0)
	assert_true(scene.paused, "pause opens")
	assert_eq(scene.ticks, ticks_before, "paused scene does not tick")
	assert_eq(scene.rules.stats["time"], time_before, "rules freeze while paused")
	scene.resume()
	_step(scene, 1)
	assert_false(scene.paused, "resume closes pause")
	assert_eq(scene.ticks, ticks_before + 1, "sandbox ticks after resume")


func test_PROTOTYPE_005_main_restart_resets_the_sandbox() -> void:
	var main := MAIN.instantiate()
	tree.root.add_child(main)
	_owned.append(main)
	await tree.process_frame
	var old: GreenZoneScene = main.current_scene
	old.manual_ticks = true
	old.rules.stats["score"] = 999
	old.rules.bladder.charges = 0
	old.world.player.set_grid_position(40.5, 40.5)
	old.restart_requested.emit()
	await tree.process_frame
	await tree.process_frame
	var fresh: GreenZoneScene = main.current_scene
	assert_true(fresh != old, "Main replaces the old sandbox")
	assert_eq(fresh.rules.stats["score"], 0, "score resets")
	assert_eq(fresh.rules.bladder.charges, GameConfig.Bladder.START_CHARGES, "pee charges reset")
	assert_vec_near(Vector2(fresh.world.player.gx, fresh.world.player.gy), fresh.world.map.start, 0.001, "Zampano returns to spawn")
