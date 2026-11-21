extends TestCase
## The runner's per-case isolation: the first case dirties every global it can; the second, run
## right after, must find them all back at their defaults.


func test_SLICE_isolation_1_dirty_every_global() -> void:
	var root: Window = (Engine.get_main_loop() as SceneTree).root
	InputService.left_handed = true
	InputService.run_toggle = true
	InputService.inject_move(1.0, 0.0, true)
	InputService.trigger(&"pee")
	InputService.set_button(&"pee", &"pee", Vector2(10, 10), 8.0, true)
	Input.action_press(&"move_up")
	AudioService.play(&"bark")
	AudioService.set_suspended(true)
	root.get_node("SaveService").save_record("level1", {"score": 999, "stars": 5, "time": 1})
	var s: Dictionary = root.get_node("AppState").settings.duplicate(true)
	s["lives"] = 9
	root.get_node("AppState").update_settings(s)
	root.get_node("SaveService").fault_after = "temp_written"
	Engine.max_fps = 33
	for k in 5:
		IsoRenderable.new()
	assert_true(true)


func test_SLICE_isolation_2_globals_are_back_to_defaults() -> void:
	var root: Window = (Engine.get_main_loop() as SceneTree).root
	assert_eq([InputService.left_handed, InputService.run_toggle, InputService.buttons.size()], [false, false, 0], "input settings reset")
	InputService.update(1.0 / 60.0)
	assert_eq([InputService.move_x, InputService.move_y, InputService.run_held], [0.0, 0.0, false], "no injection, no held action")
	assert_false(InputService.consume(&"pee"), "no queued edge")
	assert_false(Input.is_action_pressed(&"move_up"), "Input actions released")
	assert_eq([AudioService.requested.size(), AudioService.suspended], [0, false], "audio reset")
	assert_eq(root.get_node("SaveService").get_record("level1"), null, "fresh save storage")
	assert_eq(root.get_node("SaveService").load_status, "new", "nothing on disk")
	assert_eq(root.get_node("SaveService").fault_after, "", "no fault injection")
	assert_eq(root.get_node("AppState").lives(), GameConfig.Lives.START, "default settings")
	assert_eq(Engine.max_fps, 0, "engine pacing reset")
	assert_eq(IsoRenderable.new().id, 1, "renderable ids restart")
