extends SceneTree
## Rendered multi-rate interpolation check (VIEW-004 / DOG-008). Needs a renderer:
##   xvfb-run -a godot --path godot --rendering-driver opengl3 --script res://tools/interpolation_probe.gd
## The real PlayableDog runs east at a constant scripted RUN on an open map, moved only in 60 Hz
## physics ticks, with a static camera on a black background. Every rendered frame is read back
## and the dog's on-screen x measured. With physics interpolation a frame never repeats the
## previous position while moving (no stutter/streak), never jumps more than two frames' worth
## (no double interpolation), and a teleport shows the new position at once (reset). A control run
## with interpolation off must show repeated frames above 60 FPS, proving the metric detects it.
## A last pass follows the dog with the real CameraRig (moving camera): two static markers 40 px
## apart must stay exactly 40 px apart on every frame (no static shimmer from fractional camera
## positions). Prints one JSON line per run and exits 1 if an interpolated run fails.

const DOG := preload("res://entities/playable_dog/playable_dog.tscn")
const FRAMES := 48

var _dog: PlayableDog
var _map: WorldMapModel
var _cam: Camera2D
var _rig: CameraRig
var _follow := false
## The run starts at grid (20, 20) (screen y 320) and heads screen-east inside the open map.
const START_GRID := Vector2(20.0, 20.0)
var _driving := false
var _results: Array = []


func _initialize() -> void:
	_run.call_deferred()


func _physics_frame() -> void:
	if _driving:
		_dog.set_intent(1.0, 0.0, "scripted")
		_dog.update_movement(1.0 / 60.0, _map)
	if _follow:
		var p := IsoGrid.grid_to_screen_xy(_dog.gx, _dog.gy)
		var v := _dog.screen_velocity()
		_rig.step(1.0 / 60.0, p[0], p[1] - 10.0, v.x, v.y)


## X centres of the bright blobs in a horizontal band (markers), left to right.
func _blobs(img: Image, y0: int, y1: int) -> Array[float]:
	var cols: Array[int] = []
	for x in img.get_width():
		for y in range(maxi(0, y0), mini(img.get_height(), y1)):
			if img.get_pixel(x, y).r > 0.9 and img.get_pixel(x, y).g < 0.3:
				cols.append(x)
				break
	var out: Array[float] = []
	var start := -10
	var last := -10
	for x in cols:
		if x != last + 1:
			if last >= 0:
				out.append((start + last) / 2.0)
			start = x
		last = x
	if last >= 0:
		out.append((start + last) / 2.0)
	return out


func _shimmer(fps: int) -> Dictionary:
	physics_interpolation = true
	Engine.max_fps = fps
	_dog.set_grid_position(START_GRID.x, START_GRID.y)
	_rig.snap(_dog.position.x, _dog.position.y - 10.0)
	_driving = true
	_follow = true
	for k in 20:
		await process_frame
	var gaps: Dictionary = {}
	var frames := 0
	for k in FRAMES:
		await RenderingServer.frame_post_draw
		var img := root.get_texture().get_image()
		var b := _blobs(img, 40, 160)
		if b.size() == 2:
			gaps[b[1] - b[0]] = true
			frames += 1
	_driving = false
	_follow = false
	return {"pass": "camera follow, static markers", "fps_cap": fps, "frames_measured": frames, "distinct_marker_gaps_px": gaps.keys(), "ok": frames > FRAMES / 2 and gaps.size() == 1 and gaps.has(40.0)}


func _dog_x(img: Image) -> float:
	var y0 := img.get_height() / 2 - 30
	var x_min := INF
	var x_max := -INF
	for y in range(y0, y0 + 40):
		for x in img.get_width():
			if img.get_pixel(x, y).v > 0.5:
				x_min = minf(x_min, x)
				x_max = maxf(x_max, x)
	return (x_min + x_max) / 2.0 if x_max >= x_min else NAN


func _measure(fps: int, interpolate: bool) -> Dictionary:
	physics_interpolation = interpolate
	Engine.max_fps = fps
	_dog.set_grid_position(START_GRID.x, START_GRID.y)
	_dog.vx = 0.0
	_dog.vy = 0.0
	_driving = true
	for k in 20:
		await process_frame
	var xs: Array[float] = []
	var times: Array[float] = []
	for k in FRAMES:
		await RenderingServer.frame_post_draw
		xs.append(_dog_x(root.get_texture().get_image()))
		times.append(Time.get_ticks_usec() / 1e6)
	# Teleport 60 px back: the next frame must show the new place, not a streak from the old one.
	var back := IsoGrid.screen_to_grid_xy(_dog.position.x - 60.0, _dog.position.y)
	_dog.set_grid_position(back[0], back[1])
	var target_x := float(_dog.position.x) - _cam.position.x + root.size.x / 2.0
	await RenderingServer.frame_post_draw
	var after_teleport := _dog_x(root.get_texture().get_image())
	_driving = false
	var dx: Array[float] = []
	for k in range(1, xs.size()):
		dx.append(xs[k] - xs[k - 1])
	var elapsed := times[times.size() - 1] - times[0]
	var achieved := (xs.size() - 1) / elapsed
	var speed := 7.5 * IsoGrid.grid_vec_to_screen(0.7071067811865476, -0.7071067811865476).x
	var per_frame := speed / achieved
	var repeats := dx.filter(func(d: float) -> bool: return d <= 0.0).size()
	var max_dx: float = dx.max()
	var r := {
		"fps_cap": fps, "interpolation": interpolate, "achieved_fps": snappedf(achieved, 0.1),
		"expected_px_per_frame": snappedf(per_frame, 0.01), "repeated_frames": repeats,
		"max_px_per_frame": max_dx, "teleport_error_px": snappedf(absf(after_teleport - target_x), 0.1),
	}
	r["ok"] = (repeats == 0 or per_frame < 1.0) and max_dx <= 2.0 * per_frame + 2.0 and r["teleport_error_px"] <= per_frame + 2.0
	return r


func _run() -> void:
	root.size = Vector2i(432, 432)
	RenderingServer.set_default_clear_color(Color.BLACK)
	var rows := PackedStringArray()
	for j in 40:
		rows.append(".".repeat(60) if j > 0 and j < 39 else "#".repeat(60))
	var parsed := AsciiMapLoader.parse(PackedStringArray(["S" + rows[1].substr(1)] + Array(rows.slice(1))), ".", false)
	_map = WorldMapModel.new(parsed["level"])
	var world := Node2D.new()
	root.add_child(world)
	_cam = Camera2D.new()
	_cam.process_callback = Camera2D.CAMERA2D_PROCESS_PHYSICS
	var s0 := IsoGrid.grid_to_screen(START_GRID.x, START_GRID.y)
	_cam.position = Vector2(s0.x + 150.0, s0.y)
	world.add_child(_cam)
	_dog = DOG.instantiate()
	world.add_child(_dog)
	_dog.get_node("Shadow").visible = false
	_rig = load("res://iso/camera_rig.gd").new()
	var rig_cam := Camera2D.new()
	rig_cam.name = "Camera2D"
	rig_cam.process_callback = Camera2D.CAMERA2D_PROCESS_PHYSICS
	_rig.add_child(rig_cam)
	world.add_child(_rig)
	_rig.set_view_size(Vector2(root.size))
	for k in 2:
		var m := Polygon2D.new()
		m.color = Color(1, 0, 0)
		m.polygon = PackedVector2Array([Vector2(-2, -2), Vector2(2, -2), Vector2(2, 2), Vector2(-2, 2)])
		m.position = Vector2(s0.x + 60.0 + k * 40.0, s0.y - 110.0)
		world.add_child(m)
	physics_frame.connect(_physics_frame)
	await process_frame
	var failed := false
	for fps in [30, 60, 90, 120]:
		var r := await _measure(fps, true)
		print(JSON.stringify(r))
		failed = failed or not r["ok"]
	var control := await _measure(120, false)
	control["control"] = "interpolation off: repeated frames expected above 60 FPS"
	print(JSON.stringify(control))
	if control["repeated_frames"] == 0:
		print("control run did not show repeated frames: the probe cannot detect stutter here")
		failed = true
	rig_cam.make_current()
	for fps in [90, 120]:
		var sh := await _shimmer(fps)
		print(JSON.stringify(sh))
		failed = failed or not sh["ok"]
	physics_interpolation = true
	Engine.max_fps = 0
	quit(1 if failed else 0)
