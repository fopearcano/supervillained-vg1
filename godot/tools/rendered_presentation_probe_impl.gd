extends RefCounted
## Renderer-backed presentation probe for the rendered clauses of VIEW-004, CAM-004 and DOG-008a.
## It is not part of the headless suite: it needs a real renderer and a window.
##   <godot> --path godot --rendering-driver opengl3 --disable-vsync \
##     --script res://tools/rendered_presentation_probe.gd -- [--rates=30,60,90,120] [--out=<dir>]
## Every measured frame is read back from a pixel SubViewport after RenderingServer.frame_post_draw.
##
## Controlled stage: a SubViewport with Main's GameViewport pixel settings (asserted), a solid blue
## background, 7×7 pixel-art markers in three colours, the real PlayableDog (its shadow hidden)
## moved only in 60 Hz physics ticks, and the shipped CameraRig node taken from world_2d.tscn. The
## background and marker colours are asserted absent from every frame of the dog's sprite sheet.
##  1. Motion: the dog runs screen-east under a static camera with its run animation frozen on one
##     frame. Every frame must hold exactly one dog component whose pixels equal the reference frame
##     (area, bounding box, translation-normalised pattern, intensity) at the screen position that the
##     interpolated physics state predicts. The rendered displacement and the fitted on-screen
##     velocity must match the logic within 2 px and 3 %, and the per-frame steps must follow the
##     elapsed time (RMS deviation at most 1 px, no hold that the interpolated state does not predict).
##  2. Camera: the real CameraRig follows the running dog. Every fully visible marker must sit at
##     the position that the interpolated camera predicts, with its exact pattern and intensity;
##     adjacent markers must keep their 48 px spacing (supplemental).
##  3. Resets: the first frame after a spawn, a teleport (set_grid_position) and CameraRig.snap(),
##     drawn right after the action's tick, shows the new state at once with nothing left at the old
##     position.
##  4. Restart: the real Main → Green Zone → pause → RESTART flow (keys and injected movement, as in
##     test_P_DOG_008a). The first frame drawn after the scene replacement (and, for reference, the
##     first frame of the fresh start) is analysed through same-instant redraws (force_draw without
##     advancing time): the frame reproduces exactly; its canvas transform is the snapped spawn
##     view; without the UI layers, the dog is one component equal to the displayed sprite frame at
##     the canonical spawn, with nothing elsewhere, in particular at the old run's position.
## Negative controls, each of which must be detected: interpolation off above 60 FPS, a synthetic
## doubled-displacement series, ghosted, trailed and stale-copy dog images, a teleport and a camera
## snap without the interpolation reset, a fractional-camera dither, and a subpixel camera without
## snapping and with linear sampling.
## `--only=motion,camera,resets,main` runs a subset (development only; evidence runs use all).
## Prints one `PROBE {json}` line per record and exits 1 on any failure (including a negative
## control that passes, and any engine or script error logged during the run).

const DOG_SCENE := preload("res://entities/playable_dog/playable_dog.tscn")
const WORLD_SCENE := preload("res://world/world_2d.tscn")
const MAIN_SCENE := preload("res://main/main.tscn")
const DT := 1.0 / 60.0
const STAGE := Vector2i(432, 240)
const MAIN_WINDOW := Vector2i(216, 432)
const START := Vector2(20.0, 20.0)
## IsoWorld.camera_lift: the camera follows a point 10 px above the dog's feet.
const CAMERA_LIFT := 10.0
## Static view for the motion pass: the start lies at stage (60, 170).
const STATIC_VIEW := Vector2(156.0, -32.0)
const FREEZE_ANIM := &"run_e"
const FREEZE_FRAME := 0
const WARM_TICKS := 36
const MEASURE_S := 1.4
const BG := Color8(0, 0, 255)
const MARKER_COLOURS := {"M": Color8(255, 0, 255), "C": Color8(0, 255, 255), "Y": Color8(255, 255, 0)}
const MARKER_ART := ["MMMMMMM", "MYCCCYM", "MCYYYCM", "MCYMYCM", "MCYYYCM", "MYCCCCM", "MMMMMMM"]
const MARKER_SIZE := 7
const MARKER_STEP := 48
const MARKER_ROWS := [180, 220, 370]
const MARKER_X_RANGE := Vector2i(-264, 648)
## Tolerances.
## A position within TIE_EPS of a half pixel may snap either way (float32 interpolation).
const TIE_EPS := 0.001
const FPS_TOL := 0.03
## Rendered vs logic displacement: two endpoints, each ≤ 0.5 px tick rounding + ≤ 0.5 px snap.
const DISP_TOL_PX := 2.0
const VEL_TOL := 0.03
const RMS_STEP_LIMIT_PX := 1.0
## A step may exceed its share of elapsed time by less than the two roundings (2 px).
const STEP_SLACK_PX := 2.0
## A no-reset control whose first frame lands this close to the next tick is retried.
const CONTROL_MAX_FRACTION := 0.98
const CONTROL_ATTEMPTS := 6
const SCREEN_RUN_SPEED := 7.5 * 2.0 * 0.7071067811865476 * 16.0

signal ticked

var _rates: Array[int] = [30, 60, 90, 120]
var _out_dir := ""
var _only := PackedStringArray()
var _failures := PackedStringArray()

var _bg_i := 0
var _marker_is: Array[int] = []
var _marker_tex: ImageTexture
var _marker_ref := {}

var _stage_box: SubViewportContainer
var _stage: SubViewport
var _world: Node2D
var _dog_parent: Node2D
var _dog: PlayableDog
var _rig: CameraRig
var _markers: Array = []
var _map: WorldMapModel

var _tick := 0
var _driving := false
var _following := false
var _dither := 0.0
var _hist := {}
var _actions := {}
var _flags := {}

var _seq := 0
var _capturing := false
var _capture_vp: Viewport = null
var _capture_main: Node = null
var _frames: Array = []
var _dog_refs := {}
var _stage_config := {}
var _main_game_vp := {}
var _in_redraw := false
var _redraw_when := Callable()


var tree: SceneTree


func _init(t: SceneTree) -> void:
	tree = t
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--rates="):
			_rates.clear()
			for s in a.substr(8).split(","):
				_rates.append(int(s))
		elif a.begins_with("--out="):
			_out_dir = a.substr(6)
		elif a.begins_with("--only="):
			_only = a.substr(7).split(",")


func _want(section: String) -> bool:
	return _only.is_empty() or _only.has(section)


## Runs every pass and returns the process exit code (0 only when everything passed).
func run() -> int:
	# Any engine or script error during the run fails it (the tests' ErrorCapture logger).
	var errors := ErrorCapture.new()
	OS.add_logger(errors)
	AudioServer.set_bus_mute(0, true)
	_isolate_save()
	_bg_i = _int_of(BG)
	for k in ["M", "C", "Y"]:
		_marker_is.append(_int_of(MARKER_COLOURS[k]))
	tree.physics_frame.connect(_on_physics_frame)
	RenderingServer.frame_post_draw.connect(_on_post_draw)
	await tree.process_frame
	_emit(_environment())
	_build_stage()
	var palette := _palette_check()
	_emit(palette)
	if not palette["ok"]:
		_failures.append("palette")
	await _ticks(3)
	var motion_runs := {}
	if _want("motion"):
		for fps in _rates:
			var frames: Array = await _motion_frames(fps, true)
			var r := _motion_eval(frames, fps, true)
			motion_runs[fps] = r
			_record(r)
			if fps == 60 or (not _rates.has(60) and fps == _rates[0]):
				_ghost_controls(frames)
		for fps in _rates:
			if fps > 60:
				var off := _motion_eval(await _motion_frames(fps, false), fps, false)
				_control("interpolation_off_%d" % fps, off, not off["smooth_motion"],
					"interpolation off above 60 FPS must fail the smooth-motion metric")
		for fps in motion_runs:
			var doubled := _doubled_control(motion_runs[fps])
			_control("doubled_displacement_%d" % fps, doubled, not doubled["ok"],
				"a synthetic 2× displacement series must fail")
	if _want("camera"):
		for fps in _rates:
			_record(_camera_eval(await _follow_frames(fps, ""), fps, "camera_follow"))
		var top: int = _rates.max()
		var dith := _camera_eval(await _follow_frames(top, "dither"), top, "fractional_camera_dither")
		_control("fractional_camera_dither_%d" % top, dith, not dith["marker_position_exact"],
			"a fractional camera dither must fail the absolute marker position check")
		var sub := _camera_eval(await _follow_frames(top, "subpixel"), top, "subpixel_camera_linear")
		_control("subpixel_camera_linear_%d" % top, sub, not (sub["marker_pattern_exact"] and sub["marker_intensity_exact"]),
			"an unsnapped subpixel camera with linear sampling must fail the pattern/intensity check")
	if _want("resets"):
		for fps in _rates:
			await _reset_pass(fps)
	_teardown_stage()
	if _want("main"):
		await _main_passes()
		# The briefing's music would otherwise still be playing at exit (leaked playback).
		AudioService.stop_music()
		await _process_frames(5)
	tree.physics_interpolation = true
	Engine.max_fps = 0
	OS.remove_logger(errors)
	var logged: Array = []
	for e: Dictionary in errors.take():
		logged.append("%s %s (%s)" % [e["code"], e["rationale"], e["where"]])
	if not logged.is_empty():
		_failures.append("engine_errors")
	_emit({"record": "summary", "failures": _failures, "engine_errors": logged, "ok": _failures.is_empty()})
	return 1 if not _failures.is_empty() else 0


# --- Records --------------------------------------------------------------------------------------

func _emit(rec: Dictionary) -> void:
	print("PROBE " + JSON.stringify(_clean(rec)))


## Drops internal keys (leading underscore) before printing.
static func _clean(v: Variant) -> Variant:
	if v is Dictionary:
		var out := {}
		for k in v:
			if not (k is String and (k as String).begins_with("_")):
				out[k] = _clean(v[k])
		return out
	if v is Array:
		var out: Array = []
		for x in v:
			out.append(_clean(x))
		return out
	return v


func _record(rec: Dictionary) -> void:
	_emit(rec)
	if not rec["ok"]:
		_failures.append("%s_%s" % [rec["record"], rec.get("requested_fps", "")])


## A negative control: `detected` must be true (the fault was seen); the control itself then passes.
func _control(name: String, measured: Dictionary, detected: bool, claim: String) -> void:
	var failed: Array = []
	for k: String in measured.get("checks", {}):
		if not measured["checks"][k]:
			failed.append(k)
	failed.sort()
	_emit({"record": "negative_control", "name": name, "claim": claim, "failed_checks": failed,
		"measured": measured, "detected": detected, "ok": detected})
	if not detected:
		_failures.append("control_" + name)


static func _r(x: float, step: float = 0.001) -> float:
	return snappedf(x, step)


func _save(img: Image, name: String) -> void:
	if _out_dir != "" and img:
		DirAccess.make_dir_recursive_absolute(_out_dir)
		img.save_png(_out_dir.path_join(name + ".png"))


func _environment() -> Dictionary:
	var main: Node = MAIN_SCENE.instantiate()
	var gv: SubViewport = main.get_node("SafeAreaRoot/PixelViewportContainer/GameViewport")
	var game_vp := {"snap_2d_transforms_to_pixel": gv.snap_2d_transforms_to_pixel,
		"snap_2d_vertices_to_pixel": gv.snap_2d_vertices_to_pixel,
		"canvas_item_default_texture_filter": gv.canvas_item_default_texture_filter}
	main.free()
	_main_game_vp = game_vp
	var v := Engine.get_version_info()
	return {"record": "environment", "godot": "%s.%s.%s.%s" % [v["major"], v["minor"], v["patch"], v["status"]],
		"godot_hash": v["hash"].substr(0, 9), "os": OS.get_name(), "os_version": OS.get_version(),
		"adapter": RenderingServer.get_video_adapter_name(), "adapter_vendor": RenderingServer.get_video_adapter_vendor(),
		"api": RenderingServer.get_video_adapter_api_version(),
		"rendering_method": RenderingServer.get_current_rendering_method(),
		"rendering_driver": RenderingServer.get_current_rendering_driver_name(),
		"vsync_mode": DisplayServer.window_get_vsync_mode(), "screen_refresh_hz": _r(DisplayServer.screen_get_refresh_rate(), 0.01),
		"physics_ticks_per_second": Engine.physics_ticks_per_second,
		"physics_interpolation": ProjectSettings.get_setting("physics/common/physics_interpolation"),
		"default_texture_filter": ProjectSettings.get_setting("rendering/textures/canvas_textures/default_texture_filter"),
		"snap_2d_transforms_to_pixel": ProjectSettings.get_setting("rendering/2d/snap/snap_2d_transforms_to_pixel"),
		"snap_2d_vertices_to_pixel": ProjectSettings.get_setting("rendering/2d/snap/snap_2d_vertices_to_pixel"),
		"main_game_viewport": game_vp, "rates": _rates}


func _isolate_save() -> void:
	var dir := "user://rendered_probe/"
	DirAccess.make_dir_recursive_absolute(dir)
	for f in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir + f)
	SaveService.base_dir = dir
	SaveService.load_from_disk()
	AppState.reload()


# --- Ticks and frames ------------------------------------------------------------------------------

## One 60 Hz tick: the scripted RUN, the camera follow (as IsoWorld.end_step), scheduled actions,
## then the tick's state for the predictions.
func _on_physics_frame() -> void:
	_tick += 1
	_flags = {}
	if is_instance_valid(_dog) and _dog.is_inside_tree():
		if _driving:
			_dog.set_intent(1.0, 0.0, "scripted")
			_dog.update_movement(DT, _map)
		if _following:
			var p := IsoGrid.grid_to_screen_xy(_dog.gx, _dog.gy)
			var v := _dog.screen_velocity()
			_rig.step(DT, p[0], p[1] - CAMERA_LIFT, v.x, v.y)
	if _actions.has(_tick):
		for a: Callable in _actions[_tick]:
			a.call()
		_actions.erase(_tick)
	if is_instance_valid(_rig) and _rig.is_inside_tree():
		var rec := {"rig": _rig.position, "rig_reset": _flags.get("rig_reset", false)}
		if is_instance_valid(_dog) and _dog.is_inside_tree():
			var s := IsoGrid.grid_to_screen_xy(_dog.gx, _dog.gy)
			rec["dog"] = _dog.position
			rec["dog_reset"] = _flags.get("dog_reset", false)
			rec["dogc_x"] = s[0]
			rec["dogc_y"] = s[1]
		_hist[_tick] = rec
		# Control only: the camera leaves its whole-pixel path by a subpixel dither (not recorded).
		if _dither != 0.0:
			_rig.position += Vector2(_dither if _tick % 2 == 0 else -_dither, 0.0)
	ticked.emit()


func _on_post_draw() -> void:
	if _in_redraw:
		return
	_seq += 1
	if not _capturing:
		return
	var t := Time.get_ticks_usec()
	var vp: Viewport = _capture_vp
	if vp == null and is_instance_valid(_capture_main) and _capture_main.is_inside_tree() and _capture_main.is_node_ready():
		vp = _capture_main.game_viewport
	var rec := {"t": t, "n": _tick, "f": Engine.get_physics_interpolation_fraction(), "seq": _seq, "img": null}
	if vp:
		var img := vp.get_texture().get_image()
		if img.get_format() != Image.FORMAT_RGBA8:
			img.convert(Image.FORMAT_RGBA8)
		rec["img"] = img
	var dog := _dog
	if is_instance_valid(_capture_main) and _capture_main.is_node_ready() and _capture_main.current_scene:
		var world: IsoWorld = _capture_main.current_scene.world
		dog = world.player
		rec["cam"] = world.camera_rig.position
		rec["dog_pos"] = dog.position
		var gv: SubViewport = _capture_main.game_viewport
		rec["canvas_origin"] = gv.canvas_transform.origin
	if is_instance_valid(dog) and dog.is_inside_tree():
		var b := dog.body_sprite
		rec["anim"] = b.animation
		rec["frame"] = b.frame
		rec["playing"] = b.is_playing()
		rec["vscale"] = dog.visual_root.scale
		rec["modulate"] = b.modulate
	if _redraw_when.is_valid() and rec["img"] != null and _redraw_when.call(rec):
		_redraw_when = Callable()
		rec["redraws"] = _main_redraws()
	_frames.append(rec)


func _ticks(k: int) -> void:
	var target := _tick + k
	while _tick < target:
		await ticked


func _process_frames(k: int) -> void:
	for i in k:
		await tree.process_frame


func _capture_n(count: int) -> Array:
	_frames = []
	_capturing = true
	while _frames.size() < count:
		await RenderingServer.frame_post_draw
	_capturing = false
	return _frames


## Schedules `action` for the next tick and captures frames until `extra` frames after the first
## frame drawn after that tick. Returns [frames, index of that first frame, tick].
func _capture_action(action: Callable, extra: int = 2) -> Array:
	# Align to the pacing: after a draw, the next tick opens a frame; acting on the tick after it
	# makes that frame's last tick the action tick when a frame holds two ticks (30 FPS).
	await RenderingServer.frame_post_draw
	await ticked
	var tick := _tick + 1
	_actions[tick] = [action]
	_frames = []
	_capturing = true
	var first := -1
	while true:
		await RenderingServer.frame_post_draw
		if first < 0 and _frames[-1]["n"] >= tick:
			first = _frames.size() - 1
		if first >= 0 and _frames.size() - 1 - first >= extra:
			break
	_capturing = false
	return [_frames, first, tick]


# --- Stage ------------------------------------------------------------------------------------------

func _build_stage() -> void:
	tree.root.size = STAGE
	_stage_box = SubViewportContainer.new()
	_stage_box.stretch = true
	_stage_box.size = Vector2(STAGE)
	tree.root.add_child(_stage_box)
	_stage = SubViewport.new()
	_stage.size = STAGE
	_stage.snap_2d_transforms_to_pixel = true
	_stage.snap_2d_vertices_to_pixel = true
	_stage.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	_stage.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_stage_box.add_child(_stage)
	_capture_vp = _stage
	var under := CanvasLayer.new()
	under.layer = -100
	var bg := ColorRect.new()
	bg.color = BG
	bg.size = Vector2(STAGE)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	under.add_child(bg)
	_stage.add_child(under)
	_world = Node2D.new()
	_stage.add_child(_world)
	var art := Image.create(MARKER_SIZE, MARKER_SIZE, false, Image.FORMAT_RGBA8)
	for y in MARKER_SIZE:
		for x in MARKER_SIZE:
			art.set_pixel(x, y, MARKER_COLOURS[MARKER_ART[y][x]])
	_marker_tex = ImageTexture.create_from_image(art)
	var bordered := Image.create(MARKER_SIZE + 2, MARKER_SIZE + 2, false, Image.FORMAT_RGBA8)
	bordered.fill(BG)
	bordered.blit_rect(art, Rect2i(0, 0, MARKER_SIZE, MARKER_SIZE), Vector2i(1, 1))
	_marker_ref = {"ints": bordered.get_data().to_int32_array(), "w": MARKER_SIZE + 2, "h": MARKER_SIZE + 2,
		"intensity": _intensity_all(art.get_data().to_int32_array())}
	var row := 0
	for y: int in MARKER_ROWS:
		var col := 0
		for x in range(MARKER_X_RANGE.x, MARKER_X_RANGE.y + 1, MARKER_STEP):
			var s := Sprite2D.new()
			s.texture = _marker_tex
			s.centered = false
			s.position = Vector2(x, y)
			_world.add_child(s)
			_markers.append({"node": s, "x": x, "y": y, "row": row, "col": col})
			col += 1
		row += 1
	_dog_parent = Node2D.new()
	_world.add_child(_dog_parent)
	# The shipped camera node: world_2d.tscn's CameraRig with its Camera2D, detached from IsoWorld.
	var shipped := WORLD_SCENE.instantiate()
	_rig = shipped.get_node("CameraRig")
	shipped.remove_child(_rig)
	_rig.owner = null
	_rig.get_node("Camera2D").owner = null
	shipped.free()
	_world.add_child(_rig)
	_rig.set_view_size(Vector2(STAGE))
	var rows := PackedStringArray()
	for j in 40:
		rows.append(".".repeat(60) if j > 0 and j < 39 else "#".repeat(60))
	var parsed := AsciiMapLoader.parse(PackedStringArray(["S" + rows[1].substr(1)] + Array(rows.slice(1))), ".", false)
	_map = WorldMapModel.new(parsed["level"])
	_dog = _spawn_dog()
	var s0 := IsoGrid.grid_to_screen_xy(START.x, START.y)
	_rig.snap(s0[0] + STATIC_VIEW.x, s0[1] + STATIC_VIEW.y)
	_stage_config = {"stage_snap_2d_transforms_to_pixel": _stage.snap_2d_transforms_to_pixel,
		"stage_snap_2d_vertices_to_pixel": _stage.snap_2d_vertices_to_pixel,
		"stage_canvas_item_default_texture_filter": _stage.canvas_item_default_texture_filter,
		"camera_process_callback": _rig.camera.process_callback,
		"camera_physics_interpolated": _rig.camera.is_physics_interpolated(),
		"dog_physics_interpolated": _dog.is_physics_interpolated()}


## A dog entering like IsoWorld.setup: add_child, then set_grid_position (spawn reset).
func _spawn_dog() -> PlayableDog:
	var d: PlayableDog = DOG_SCENE.instantiate()
	_dog_parent.add_child(d)
	d.set_grid_position(START.x, START.y)
	d.get_node("Shadow").visible = false
	return d


func _teardown_stage() -> void:
	_driving = false
	_following = false
	_dither = 0.0
	_capture_vp = null
	if is_instance_valid(_stage_box):
		tree.root.remove_child(_stage_box)
		_stage_box.queue_free()
	_dog = null
	_rig = null


## The dog sheet must not use the background or marker colours (classification by exact colour).
func _palette_check() -> Dictionary:
	var sf := _dog.body_sprite.sprite_frames
	var reserved := {_bg_i: "background"}
	for k in _marker_is.size():
		reserved[_marker_is[k]] = "marker"
	var hits := 0
	var texels := 0
	var frames := 0
	for anim in sf.get_animation_names():
		for f in sf.get_frame_count(anim):
			frames += 1
			var img := sf.get_frame_texture(anim, f).get_image()
			if img.is_compressed():
				img.decompress()
			img.convert(Image.FORMAT_RGBA8)
			var px := img.get_data().to_int32_array()
			for v in px:
				if (v >> 24) & 255 == 0:
					continue
				texels += 1
				if reserved.has(v):
					hits += 1
	var ok := hits == 0
	# The stage uses the shipped GameViewport's pixel settings (read from main.tscn).
	var main_match: bool = _stage.snap_2d_transforms_to_pixel == _main_game_vp["snap_2d_transforms_to_pixel"] \
		and _stage.snap_2d_vertices_to_pixel == _main_game_vp["snap_2d_vertices_to_pixel"] \
		and _stage.canvas_item_default_texture_filter == _main_game_vp["canvas_item_default_texture_filter"] \
		and _main_game_vp["snap_2d_transforms_to_pixel"] and _main_game_vp["snap_2d_vertices_to_pixel"] \
		and _main_game_vp["canvas_item_default_texture_filter"] == Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	return {"record": "stage", "dog_frames_checked": frames, "opaque_texels": texels,
		"texels_in_reserved_colours": hits, "background": BG.to_html(false),
		"marker_colours": [MARKER_COLOURS["M"].to_html(false), MARKER_COLOURS["C"].to_html(false), MARKER_COLOURS["Y"].to_html(false)],
		"stage_size": [STAGE.x, STAGE.y], "markers": _markers.size(), "config": _stage_config,
		"stage_matches_main_game_viewport": main_match, "ok": ok and main_match}


# --- Pixels -----------------------------------------------------------------------------------------

static func _int_of(c: Color) -> int:
	var img := Image.create(1, 1, false, Image.FORMAT_RGBA8)
	img.set_pixel(0, 0, c)
	return img.get_data().to_int32_array()[0]


static func _rgb_sum(v: int) -> int:
	return (v & 255) + ((v >> 8) & 255) + ((v >> 16) & 255)


static func _intensity_all(px: PackedInt32Array) -> int:
	var s := 0
	for v in px:
		s += _rgb_sum(v)
	return s


## Pixel classes: 0 background, 1 dog (any other colour), 2 marker.
func _classes(px: PackedInt32Array) -> PackedByteArray:
	var out := PackedByteArray()
	out.resize(px.size())
	var m0 := _marker_is[0]
	var m1 := _marker_is[1]
	var m2 := _marker_is[2]
	for i in px.size():
		var v := px[i]
		if v != _bg_i:
			out[i] = 2 if (v == m0 or v == m1 or v == m2) else 1
	return out


## 8-connected components of the pixels whose class is `want`.
@warning_ignore("integer_division")
static func _components(cls: PackedByteArray, w: int, h: int, want: int) -> Array:
	var seen := PackedByteArray()
	seen.resize(cls.size())
	var out: Array = []
	var stack := PackedInt32Array()
	for i in cls.size():
		if cls[i] != want or seen[i] != 0:
			continue
		seen[i] = 1
		stack.append(i)
		var area := 0
		var x0 := w
		var y0 := h
		var x1 := -1
		var y1 := -1
		var sx := 0
		var sy := 0
		while not stack.is_empty():
			var p := stack[stack.size() - 1]
			stack.resize(stack.size() - 1)
			var x := p % w
			var y := p / w
			area += 1
			x0 = mini(x0, x)
			x1 = maxi(x1, x)
			y0 = mini(y0, y)
			y1 = maxi(y1, y)
			sx += x
			sy += y
			for dy in range(-1, 2):
				var yy := y + dy
				if yy < 0 or yy >= h:
					continue
				for dx in range(-1, 2):
					var xx := x + dx
					if xx < 0 or xx >= w:
						continue
					var q := yy * w + xx
					if cls[q] == want and seen[q] == 0:
						seen[q] = 1
						stack.append(q)
		out.append({"area": area, "x0": x0, "y0": y0, "x1": x1, "y1": y1, "cx": float(sx) / area, "cy": float(sy) / area})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["area"] > b["area"])
	return out


## Pixels of the w×h frame in the reference-sized rect at (x, y) that differ from the reference
## (pixels outside the frame count as different).
static func _mismatch(px: PackedInt32Array, w: int, h: int, x: int, y: int, ref: Dictionary) -> int:
	var n := 0
	var rw: int = ref["w"]
	var rh: int = ref["h"]
	var ri: PackedInt32Array = ref["ints"]
	for j in rh:
		var yy := y + j
		for i in rw:
			var xx := x + i
			if xx < 0 or yy < 0 or xx >= w or yy >= h:
				n += 1
			elif px[yy * w + xx] != ri[j * rw + i]:
				n += 1
	return n


## Whole-pixel candidates for the renderer's snap of u (floor(u + 0.5); both neighbours at a tie).
static func _snaps(u: float) -> Array:
	var a := int(floor(u + 0.5 - TIE_EPS))
	var b := int(floor(u + 0.5 + TIE_EPS))
	return [a] if a == b else [a, b]


static func _residual(v: int, cands: Array) -> int:
	if cands.has(v):
		return 0
	var best: int = cands[0]
	for c: int in cands:
		if absi(v - c) < absi(v - best):
			best = c
	return v - best


static func _shift(cands: Array, d: int) -> Array:
	var out: Array = []
	for c: int in cands:
		out.append(c + d)
	return out


## The reference pixels of a sprite frame's opaque rectangle on the stage background.
func _dog_ref(anim: StringName, frame: int) -> Dictionary:
	var key := "%s:%d" % [anim, frame]
	if _dog_refs.has(key):
		return _dog_refs[key]
	var sf: SpriteFrames = load("res://data/characters/zampano_profile.tres").normal_frames
	var img := sf.get_frame_texture(anim, frame).get_image()
	if img.is_compressed():
		img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	var used := img.get_used_rect()
	var crop := img.get_region(used)
	var px := crop.get_data().to_int32_array()
	var ints := PackedInt32Array()
	ints.resize(px.size())
	var area := 0
	var inten := 0
	for i in px.size():
		if (px[i] >> 24) & 255 == 0:
			ints[i] = _bg_i
		else:
			ints[i] = px[i]
			area += 1
			inten += _rgb_sum(px[i])
	var ref := {"ints": ints, "w": used.size.x, "h": used.size.y, "used": used.position, "area": area, "intensity": inten,
		"anim": String(anim), "frame": frame}
	_dog_refs[key] = ref
	return ref


# --- Interpolated state ------------------------------------------------------------------------------

## The value of `key` presented by a frame: lerp between the last two ticks at the frame's
## interpolation fraction, or the latest tick's value when that tick reset interpolation.
func _at(rec: Dictionary, key: String) -> Vector2:
	var n: int = rec["n"]
	var cur: Dictionary = _hist[n]
	var b: Vector2 = cur[key]
	if cur.get(key + "_reset", false) or not _hist.has(n - 1) or not _hist[n - 1].has(key):
		return b
	var a: Vector2 = _hist[n - 1][key]
	var f: float = rec["f"]
	return Vector2(a.x + (b.x - a.x) * f, a.y + (b.y - a.y) * f)


func _at_x(rec: Dictionary, key: String) -> float:
	var n: int = rec["n"]
	var b: float = _hist[n][key]
	if not _hist.has(n - 1) or not _hist[n - 1].has(key):
		return b
	var a: float = _hist[n - 1][key]
	return a + (b - a) * float(rec["f"])


## Expected top-left of the dog's reference rectangle: the interpolated dog under the
## interpolated camera, snapped; both snap orders (item, then canvas; or the sum) are accepted.
func _dog_expect(rec: Dictionary, ref: Dictionary, size: Vector2i) -> Array:
	var d := _at(rec, "dog")
	var c := _at(rec, "rig")
	var half := Vector2(size) / 2.0
	var off := Vector2i(int(_dog.body_sprite.offset.x), int(_dog.body_sprite.offset.y)) + (ref["used"] as Vector2i)
	var xs := _snaps(d.x - c.x + half.x)
	var ys := _snaps(d.y - c.y + half.y)
	for a: int in _snaps(d.x):
		for b: int in _snaps(a - c.x + half.x):
			if not xs.has(b):
				xs.append(b)
	for a: int in _snaps(d.y):
		for b: int in _snaps(a - c.y + half.y):
			if not ys.has(b):
				ys.append(b)
	return [_shift(xs, off.x), _shift(ys, off.y)]


## One frame's dog: components, the main component's geometry, exact match with the reference.
func _dog_eval(px: PackedInt32Array, cls: PackedByteArray, ref: Dictionary, ex: Array, ey: Array) -> Dictionary:
	var comps := _components(cls, STAGE.x, STAGE.y, 1)
	var out := {"components": comps.size()}
	if comps.is_empty():
		out["ok_shape"] = false
		out["ok_position"] = false
		return out
	var c: Dictionary = comps[0]
	var inten := 0
	var amin := 255
	var amax := 0
	for y in range(c["y0"], c["y1"] + 1):
		for x in range(c["x0"], c["x1"] + 1):
			var i: int = y * STAGE.x + x
			if cls[i] == 1:
				var v := px[i]
				inten += _rgb_sum(v)
				amin = mini(amin, (v >> 24) & 255)
				amax = maxi(amax, (v >> 24) & 255)
	out["area"] = c["area"]
	out["bbox"] = [c["x0"], c["y0"], c["x1"] - c["x0"] + 1, c["y1"] - c["y0"] + 1]
	out["centroid"] = [_r(c["cx"]), _r(c["cy"])]
	out["mismatch"] = _mismatch(px, STAGE.x, STAGE.y, c["x0"], c["y0"], ref)
	out["intensity"] = inten
	out["alpha"] = [amin, amax]
	out["dx"] = _residual(c["x0"], ex)
	out["dy"] = _residual(c["y0"], ey)
	out["ok_shape"] = comps.size() == 1 and c["area"] == ref["area"] and out["bbox"][2] == ref["w"] \
		and out["bbox"][3] == ref["h"] and out["mismatch"] == 0 and inten == ref["intensity"]
	out["ok_position"] = out["dx"] == 0 and out["dy"] == 0
	return out


# --- 1. Motion -----------------------------------------------------------------------------------------

func _place_start(follow: bool) -> void:
	_driving = false
	_following = false
	_dither = 0.0
	_dog.body_sprite.play()
	_dog.vx = 0.0
	_dog.vy = 0.0
	_dog.set_grid_position(START.x, START.y)
	var s := IsoGrid.grid_to_screen_xy(START.x, START.y)
	if follow:
		_rig.snap(s[0], s[1] - CAMERA_LIFT)
	else:
		_rig.snap(s[0] + STATIC_VIEW.x, s[1] + STATIC_VIEW.y)


func _freeze() -> void:
	_dog.body_sprite.pause()
	_dog.body_sprite.set_frame_and_progress(FREEZE_FRAME, 0.0)


func _motion_frames(fps: int, interpolate: bool) -> Array:
	tree.physics_interpolation = interpolate
	Engine.max_fps = fps
	_place_start(false)
	await _ticks(2)
	_driving = true
	await _ticks(WARM_TICKS)
	_freeze()
	await _ticks(1)
	var frames: Array = await _capture_n(int(round(MEASURE_S * fps)) + 1)
	_driving = false
	_dog.body_sprite.play()
	tree.physics_interpolation = true
	return frames


func _motion_eval(frames: Array, fps: int, interpolate: bool) -> Dictionary:
	var ref := _dog_ref(FREEZE_ANIM, FREEZE_FRAME)
	var per: Array = []
	var frozen := true
	for rec: Dictionary in frames:
		var px := (rec["img"] as Image).get_data().to_int32_array()
		var cls := _classes(px)
		var e := _dog_expect(rec, ref, STAGE)
		var ev := _dog_eval(px, cls, ref, e[0], e[1])
		ev["pred_x"] = e[0][0]
		per.append(ev)
		frozen = frozen and rec.get("anim", &"") == FREEZE_ANIM and rec.get("frame", -1) == FREEZE_FRAME \
			and not rec.get("playing", true) and rec.get("vscale", Vector2.ZERO) == Vector2.ONE
	var label := "motion" if interpolate else "motion_interpolation_off"
	var out := _dog_frames_summary(per, ref)
	out["record"] = label
	out["requested_fps"] = fps
	out["interpolation"] = interpolate
	out["frozen_frame"] = {"animation": String(FREEZE_ANIM), "frame": FREEZE_FRAME, "constant": frozen}
	var xs: Array = []
	var ts: Array = []
	var logic: Array = []
	var taus: Array = []
	var pred: Array = []
	for k in frames.size():
		var rec: Dictionary = frames[k]
		xs.append(per[k].get("bbox", [NAN])[0])
		ts.append((int(rec["t"]) - int(frames[0]["t"])) / 1e6)
		logic.append(_at_x(rec, "dogc_x"))
		taus.append(int(rec["n"]) - 1 + float(rec["f"]))
		pred.append(per[k]["pred_x"])
	var n_first: int = frames[0]["n"]
	var n_last: int = frames[-1]["n"]
	var s_tick := (float(_hist[n_last]["dogc_x"]) - float(_hist[n_first - 1]["dogc_x"])) / (n_last - n_first + 1)
	var steady := true
	for m in range(n_first, n_last + 1):
		steady = steady and absf(float(_hist[m]["dogc_x"]) - float(_hist[m - 1]["dogc_x"]) - s_tick) < 0.001
	out["expected_screen_px_per_s"] = _r(s_tick * 60.0)
	out["constant_speed_px_per_s"] = _r(SCREEN_RUN_SPEED)
	out["checks"] = {}
	out["checks"]["steady_logic_speed"] = steady and absf(s_tick * 60.0 - SCREEN_RUN_SPEED) < 0.05
	out["checks"]["frozen_frame_constant"] = frozen
	_series(out, xs, ts, logic, taus, pred, s_tick * 60.0, fps)
	out["smooth_motion"] = out["checks"]["model_position"] and out["checks"]["step_rms"] and out["checks"]["no_unexpected_holds"]
	out["ok"] = _all(out["checks"])
	out["_series"] = {"xs": xs, "ts": ts, "logic": logic, "taus": taus, "pred": pred}
	_save_frames(frames, "%s_%d" % [label, fps])
	return out


func _save_frames(frames: Array, prefix: String) -> void:
	if frames.is_empty():
		return
	_save(frames[0]["img"], prefix + "_first")
	_save(frames[_half(frames.size())]["img"], prefix + "_mid")


@warning_ignore("integer_division")
static func _half(n: int) -> int:
	return n / 2


static func _all(checks: Dictionary) -> bool:
	for k: String in checks:
		if not checks[k]:
			return false
	return true


## Per-frame dog results (components, area, bbox, pattern, intensity, position) folded into ranges.
func _dog_frames_summary(per: Array, ref: Dictionary) -> Dictionary:
	var comp_fail := 0
	var shape_fail := 0
	var pos_fail := 0
	var ranges := {}
	for ev: Dictionary in per:
		if ev["components"] != 1:
			comp_fail += 1
		if not ev["ok_shape"]:
			shape_fail += 1
		if not ev["ok_position"]:
			pos_fail += 1
		if not ev.has("bbox"):
			continue
		for pair: Array in [["components", ev["components"]], ["area", ev["area"]], ["bbox_w", ev["bbox"][2]],
				["bbox_h", ev["bbox"][3]], ["mismatch_px", ev["mismatch"]], ["intensity", ev["intensity"]],
				["alpha_min", ev["alpha"][0]], ["alpha_max", ev["alpha"][1]], ["position_residual_x", ev["dx"]],
				["position_residual_y", ev["dy"]]]:
			var r: Array = ranges.get(pair[0], [pair[1], pair[1]])
			ranges[pair[0]] = [mini(r[0], pair[1]), maxi(r[1], pair[1])]
	return {"frames_measured": per.size(), "component_failures": comp_fail, "shape_failures": shape_fail,
		"position_failures": pos_fail, "ranges": ranges,
		"reference": {"animation": ref["anim"], "frame": ref["frame"], "area": ref["area"], "bbox": [ref["w"], ref["h"]], "intensity": ref["intensity"]},
		"dog_checks": {"single_component": comp_fail == 0, "shape_exact": shape_fail == 0}}


## Series metrics on the rendered left edge: rate, displacement, velocity, steps and holds.
func _series(out: Dictionary, xs: Array, ts: Array, logic: Array, taus: Array, pred: Array, v_exp: float, fps: int) -> void:
	var n := xs.size()
	var elapsed: float = ts[n - 1] - ts[0]
	var achieved := (n - 1) / elapsed if elapsed > 0.0 else 0.0
	var valid := true
	for x in xs:
		valid = valid and typeof(x) == TYPE_INT
	out["achieved_fps"] = _r(achieved, 0.01)
	out["elapsed_s"] = _r(elapsed, 0.0001)
	var checks: Dictionary = out["checks"]
	checks["achieved_fps"] = absf(achieved / fps - 1.0) <= FPS_TOL
	if out.has("dog_checks"):
		checks["single_component"] = out["dog_checks"]["single_component"]
		checks["shape_exact"] = out["dog_checks"]["shape_exact"]
	if not valid:
		for k in ["model_position", "displacement", "velocity", "step_rms", "no_unexpected_holds", "max_step"]:
			checks[k] = false
		return
	var residual_fail := 0
	var rmin := 0
	var rmax := 0
	for k in n:
		var r: int = int(xs[k]) - int(pred[k])
		if r != 0:
			residual_fail += 1
		rmin = mini(rmin, r)
		rmax = maxi(rmax, r)
	# The per-frame candidates already accept ties; pred holds the first candidate, so a residual
	# here is re-checked against the dog evaluation's tie-aware residual.
	var tie_aware_fail: int = out.get("position_failures", residual_fail)
	checks["model_position"] = tie_aware_fail == 0
	out["model_position"] = {"failures": tie_aware_fail, "residual_vs_first_candidate_px": [rmin, rmax]}
	var disp_r: float = float(xs[n - 1]) - float(xs[0])
	var disp_l: float = float(logic[n - 1]) - float(logic[0])
	out["displacement"] = {"rendered_px": disp_r, "logic_px": _r(disp_l), "error_px": _r(disp_r - disp_l), "tolerance_px": DISP_TOL_PX}
	checks["displacement"] = absf(disp_r - disp_l) <= DISP_TOL_PX
	# Least-squares slope of the rendered left edge against the frame time.
	var mt := 0.0
	var mx := 0.0
	for k in n:
		mt += ts[k]
		mx += xs[k]
	mt /= n
	mx /= n
	var num := 0.0
	var den := 0.0
	for k in n:
		num += (ts[k] - mt) * (xs[k] - mx)
		den += (ts[k] - mt) * (ts[k] - mt)
	var v_fit := num / den if den > 0.0 else 0.0
	var tick_rate: float = (taus[n - 1] - taus[0]) / elapsed if elapsed > 0.0 else 0.0
	out["velocity"] = {"fitted_px_per_s": _r(v_fit), "expected_px_per_s": _r(v_exp), "ratio": _r(v_fit / v_exp, 0.0001),
		"tolerance": VEL_TOL, "physics_ticks_per_s": _r(tick_rate, 0.01)}
	checks["velocity"] = absf(v_fit / v_exp - 1.0) <= VEL_TOL
	var sq := 0.0
	var holds := 0
	var pred_holds := 0
	var excess := -INF
	var max_step := 0
	for k in range(1, n):
		var step: int = int(xs[k]) - int(xs[k - 1])
		var vdt: float = v_exp * (ts[k] - ts[k - 1])
		sq += (step - vdt) * (step - vdt)
		if vdt >= 1.0 and step == 0:
			holds += 1
		if vdt >= 1.0 and int(pred[k]) == int(pred[k - 1]):
			pred_holds += 1
		excess = maxf(excess, step - vdt)
		max_step = maxi(max_step, absi(step))
	var rms := sqrt(sq / (n - 1))
	out["steps"] = {"rms_error_px": _r(rms), "rms_limit_px": RMS_STEP_LIMIT_PX, "held_frames": holds,
		"held_frames_predicted": pred_holds, "max_step_px": max_step, "max_excess_px": _r(excess), "excess_limit_px": STEP_SLACK_PX}
	checks["step_rms"] = rms <= RMS_STEP_LIMIT_PX
	checks["no_unexpected_holds"] = holds <= pred_holds
	checks["max_step"] = excess < STEP_SLACK_PX


## Synthetic double interpolation: the measured series with its displacement doubled.
func _doubled_control(run: Dictionary) -> Dictionary:
	var src: Dictionary = run["_series"]
	var xs: Array = []
	var pred: Array = src["pred"]
	for k in src["xs"].size():
		xs.append(int(src["xs"][0]) + 2 * (int(src["xs"][k]) - int(src["xs"][0])))
	var out := {"record": "doubled_series", "requested_fps": run["requested_fps"], "checks": {}, "position_failures": 0}
	var fails := 0
	for k in xs.size():
		if int(xs[k]) != int(pred[k]):
			fails += 1
	out["position_failures"] = fails
	_series(out, xs, src["ts"], src["logic"], src["taus"], pred, float(run["expected_screen_px_per_s"]), run["requested_fps"])
	out["ok"] = _all(out["checks"])
	return out


## Ghosted, trailed and stale-copy images built from a measured frame must fail the dog analysis.
func _ghost_controls(frames: Array) -> void:
	var rec: Dictionary = frames[_half(frames.size())]
	var img: Image = rec["img"]
	var ref := _dog_ref(FREEZE_ANIM, FREEZE_FRAME)
	var px := img.get_data().to_int32_array()
	var base := _dog_eval(px, _classes(px), ref, [0], [0])
	if not base.has("bbox"):
		_failures.append("ghost_controls_no_base")
		return
	var x0: int = base["bbox"][0]
	var y0: int = base["bbox"][1]
	for spec: Array in [["ghost_trail_3px", -3, 0.5], ["ghost_trail_1px", -1, 0.5], ["ghost_separate_60px", -60, 0.5], ["stale_copy_60px", -60, 1.0]]:
		var g := _paste(img, ref, x0 + int(spec[1]), y0, spec[2])
		var gp := g.get_data().to_int32_array()
		var ev := _dog_eval(gp, _classes(gp), ref, [x0], [y0])
		var stale := _class_count(_classes(gp), Rect2i(0, 0, x0, STAGE.y), 1)
		var measured := {"components": ev["components"], "bbox": ev.get("bbox"), "area": ev.get("area"),
			"mismatch": ev.get("mismatch"), "intensity": ev.get("intensity"), "reference_area": ref["area"],
			"reference_bbox": [ref["w"], ref["h"]], "pixels_behind_dog": stale,
			"checks": {"single_component": ev["components"] == 1, "shape_exact": ev["ok_shape"]}}
		_control(spec[0], measured, not ev["ok_shape"], "a %s image must fail the component/bbox/shape analysis" % spec[0])
		_save(g, "control_" + spec[0])


## A copy of the reference sprite pasted at (x, y) over background pixels with the given opacity.
func _paste(img: Image, ref: Dictionary, x: int, y: int, alpha: float) -> Image:
	var g: Image = img.duplicate()
	var bg := BG
	for j in ref["h"]:
		for i in ref["w"]:
			var v: int = ref["ints"][j * int(ref["w"]) + i]
			if v == _bg_i:
				continue
			var xx: int = x + i
			var yy: int = y + j
			if xx < 0 or yy < 0 or xx >= g.get_width() or yy >= g.get_height():
				continue
			if g.get_pixel(xx, yy) != bg:
				continue
			var c := Color8(v & 255, (v >> 8) & 255, (v >> 16) & 255)
			g.set_pixel(xx, yy, bg.lerp(c, alpha))
	return g


static func _class_count(cls: PackedByteArray, r: Rect2i, want: int) -> int:
	var n := 0
	for y in range(maxi(0, r.position.y), mini(STAGE.y, r.end.y)):
		for x in range(maxi(0, r.position.x), mini(STAGE.x, r.end.x)):
			if cls[y * STAGE.x + x] == want:
				n += 1
	return n


# --- 2. Camera ------------------------------------------------------------------------------------------

func _follow_frames(fps: int, mode: String) -> Array:
	tree.physics_interpolation = true
	Engine.max_fps = fps
	_place_start(true)
	await _ticks(2)
	_driving = true
	_following = true
	await _ticks(WARM_TICKS + 12)
	_freeze()
	if mode == "dither" or mode == "subpixel":
		_dither = 0.45
	if mode == "subpixel":
		_stage.snap_2d_transforms_to_pixel = false
		_stage.snap_2d_vertices_to_pixel = false
		for m: Dictionary in _markers:
			(m["node"] as Sprite2D).texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	await _ticks(2)
	var frames: Array = await _capture_n(int(round(MEASURE_S * fps)) + 1)
	_driving = false
	_following = false
	_dither = 0.0
	_stage.snap_2d_transforms_to_pixel = true
	_stage.snap_2d_vertices_to_pixel = true
	for m: Dictionary in _markers:
		(m["node"] as Sprite2D).texture_filter = CanvasItem.TEXTURE_FILTER_PARENT_NODE
	_dog.body_sprite.play()
	return frames


## Every fully visible marker against the position the (interpolated, expected) camera predicts.
func _markers_eval(px: PackedInt32Array, cls: PackedByteArray, cam: Vector2) -> Dictionary:
	var w := STAGE.x
	var h := STAGE.y
	var half := Vector2(w, h) / 2.0
	var found: Array = []
	var missing := 0
	var claimed := {}
	for m: Dictionary in _markers:
		var cx := _snaps(float(m["x"]) - cam.x + half.x)
		var cy := _snaps(float(m["y"]) - cam.y + half.y)
		if cx.min() < 1 or cx.max() > w - MARKER_SIZE - 1 or cy.min() < 1 or cy.max() > h - MARKER_SIZE - 1:
			continue
		var bx0 := w
		var by0 := h
		var bx1 := -1
		var by1 := -1
		var count := 0
		var sx := 0
		var sy := 0
		for y in range(maxi(0, cy.min() - 4), mini(h, cy.max() + MARKER_SIZE + 4)):
			for x in range(maxi(0, cx.min() - 4), mini(w, cx.max() + MARKER_SIZE + 4)):
				if cls[y * w + x] == 2:
					count += 1
					sx += x
					sy += y
					bx0 = mini(bx0, x)
					by0 = mini(by0, y)
					bx1 = maxi(bx1, x)
					by1 = maxi(by1, y)
		if count == 0:
			missing += 1
			continue
		claimed[Vector2i(bx0, by0)] = true
		var inten := 0
		for y in range(by0, mini(h, by0 + MARKER_SIZE)):
			for x in range(bx0, mini(w, bx0 + MARKER_SIZE)):
				inten += _rgb_sum(px[y * w + x])
		found.append({"row": m["row"], "col": m["col"], "x0": bx0, "y0": by0, "w": bx1 - bx0 + 1, "h": by1 - by0 + 1,
			"dx": _residual(bx0, cx), "dy": _residual(by0, cy), "tie": cx.size() > 1 or cy.size() > 1,
			"cdx": float(sx) / count - (cx[0] + 3.0), "cdy": float(sy) / count - (cy[0] + 3.0),
			"mismatch": _mismatch(px, w, h, bx0 - 1, by0 - 1, _marker_ref), "intensity": inten, "count": count})
	var extras := 0
	for c: Dictionary in _components(cls, w, h, 2):
		if claimed.has(Vector2i(c["x0"], c["y0"])):
			continue
		if c["x0"] == 0 or c["y0"] == 0 or c["x1"] == w - 1 or c["y1"] == h - 1:
			continue
		extras += 1
	return {"found": found, "missing": missing, "extras": extras}


func _camera_eval(frames: Array, fps: int, label: String) -> Dictionary:
	var ref := _dog_ref(FREEZE_ANIM, FREEZE_FRAME)
	var samples := 0
	var missing := 0
	var extras := 0
	var pos_fail := 0
	var jitter_frames := 0
	var pattern_fail := 0
	var size_fail := 0
	var ties := 0
	var gaps := {}
	var rx := [0, 0]
	var ry := [0, 0]
	var cdev := 0.0
	var inten := [INF, -INF]
	var dog_per: Array = []
	var frozen := true
	for rec: Dictionary in frames:
		var px := (rec["img"] as Image).get_data().to_int32_array()
		var cls := _classes(px)
		var cam := _at(rec, "rig")
		var me := _markers_eval(px, cls, cam)
		missing += me["missing"]
		extras += me["extras"]
		var jitter := false
		var by_cell := {}
		for f: Dictionary in me["found"]:
			samples += 1
			if f["tie"]:
				ties += 1
			if f["dx"] != 0 or f["dy"] != 0:
				pos_fail += 1
				jitter = true
			rx = [mini(rx[0], f["dx"]), maxi(rx[1], f["dx"])]
			ry = [mini(ry[0], f["dy"]), maxi(ry[1], f["dy"])]
			cdev = maxf(cdev, maxf(absf(f["cdx"]), absf(f["cdy"])))
			if f["mismatch"] != 0:
				pattern_fail += 1
			if f["w"] != MARKER_SIZE or f["h"] != MARKER_SIZE or f["count"] != MARKER_SIZE * MARKER_SIZE:
				size_fail += 1
			inten = [minf(inten[0], f["intensity"]), maxf(inten[1], f["intensity"])]
			by_cell[Vector2i(f["col"], f["row"])] = f
		for cell: Vector2i in by_cell:
			var nxt := cell + Vector2i(1, 0)
			if by_cell.has(nxt):
				gaps[int(by_cell[nxt]["x0"]) - int(by_cell[cell]["x0"])] = true
		if jitter:
			jitter_frames += 1
		var e := _dog_expect(rec, ref, STAGE)
		dog_per.append(_dog_eval(px, cls, ref, e[0], e[1]))
		frozen = frozen and rec.get("anim", &"") == FREEZE_ANIM and rec.get("frame", -1) == FREEZE_FRAME and not rec.get("playing", true)
	var n := frames.size()
	var elapsed := (int(frames[n - 1]["t"]) - int(frames[0]["t"])) / 1e6
	var achieved := (n - 1) / elapsed
	var dog := _dog_frames_summary(dog_per, ref)
	var gap_list := gaps.keys()
	gap_list.sort()
	var out := {"record": label, "requested_fps": fps, "achieved_fps": _r(achieved, 0.01), "frames_measured": n,
		"marker_samples": samples, "markers_missing": missing, "extra_marker_components": extras,
		"marker_position_failures": pos_fail, "marker_tie_samples": ties, "common_mode_jitter_frames": jitter_frames,
		"marker_residual_x_px": rx, "marker_residual_y_px": ry, "marker_centroid_max_deviation_px": _r(cdev),
		"marker_pattern_failures": pattern_fail, "marker_size_failures": size_fail,
		"marker_intensity_range": [inten[0], inten[1]], "marker_reference_intensity": _marker_ref["intensity"],
		"marker_gaps_px": gap_list, "dog": dog, "frozen_frame_constant": frozen}
	out["checks"] = {
		"achieved_fps": absf(achieved / fps - 1.0) <= FPS_TOL,
		"markers_found": missing == 0 and samples > 0,
		"marker_position_exact": pos_fail == 0,
		"marker_pattern_exact": pattern_fail == 0 and size_fail == 0,
		"marker_intensity_exact": inten[0] == _marker_ref["intensity"] and inten[1] == _marker_ref["intensity"],
		"no_stale_or_extra_markers": extras == 0,
		"spacing_constant_supplemental": gap_list == [MARKER_STEP],
		"dog_single_component": dog["dog_checks"]["single_component"],
		"dog_shape_exact": dog["dog_checks"]["shape_exact"],
		"dog_position": dog["position_failures"] == 0,
		"frozen_frame_constant": frozen,
	}
	out["marker_position_exact"] = out["checks"]["marker_position_exact"]
	out["marker_pattern_exact"] = out["checks"]["marker_pattern_exact"]
	out["marker_intensity_exact"] = out["checks"]["marker_intensity_exact"]
	out["ok"] = _all(out["checks"])
	_save_frames(frames, "%s_%d" % [label, fps])
	return out


# --- 3. Resets --------------------------------------------------------------------------------------------

func _reset_frame_eval(rec: Dictionary, name: String, fps: int, tick: int, old_rect: Rect2i, markers: bool) -> Dictionary:
	var img: Image = rec["img"]
	var px := img.get_data().to_int32_array()
	var cls := _classes(px)
	var ref := _dog_ref(rec["anim"], rec["frame"])
	var e := _dog_expect(rec, ref, STAGE)
	var ev := _dog_eval(px, cls, ref, e[0], e[1])
	var out := {"record": "reset_first_frame", "name": name, "requested_fps": fps, "action_tick": tick,
		"frame_tick": rec["n"], "fraction": _r(rec["f"], 0.0001), "dog": ev.duplicate(),
		"dog_reference": {"animation": ref["anim"], "frame": ref["frame"]}}
	out["dog"].erase("ok_shape")
	out["dog"].erase("ok_position")
	out["ticks_after_action"] = int(rec["n"]) - tick
	out["checks"] = {"first_frame_follows_action_tick": int(rec["n"]) == tick,
		"dog_single_component": ev["components"] == 1, "dog_shape_exact": ev["ok_shape"], "dog_at_new_position": ev["ok_position"]}
	if old_rect.has_area():
		var stale := _class_count(cls, old_rect.grow(2), 1)
		out["old_rect"] = [old_rect.position.x, old_rect.position.y, old_rect.size.x, old_rect.size.y]
		out["dog_pixels_at_old_position"] = stale
		out["checks"]["nothing_at_old_position"] = stale == 0
	if markers:
		var me := _markers_eval(px, cls, _at(rec, "rig"))
		var bad := 0
		var pat := 0
		for f: Dictionary in me["found"]:
			if f["dx"] != 0 or f["dy"] != 0:
				bad += 1
			if f["mismatch"] != 0:
				pat += 1
		out["markers"] = {"visible": me["found"].size(), "missing": me["missing"], "position_failures": bad,
			"pattern_failures": pat, "extra_components": me["extras"]}
		out["checks"]["markers_at_snapped_view"] = me["missing"] == 0 and bad == 0 and me["found"].size() > 0
		out["checks"]["marker_pattern_exact"] = pat == 0
		out["checks"]["no_stale_markers"] = me["extras"] == 0
	out["ok"] = _all(out["checks"])
	_save(img, "reset_%s_%d" % [name, fps])
	return out


## The dog's expected reference rectangle on the stage at tick m (for the old position).
func _dog_rect_at(m: int, ref: Dictionary) -> Rect2i:
	var d: Vector2 = _hist[m]["dog"]
	var c: Vector2 = _hist[m]["rig"]
	var off := Vector2i(int(_dog.body_sprite.offset.x), int(_dog.body_sprite.offset.y)) + (ref["used"] as Vector2i)
	var tl := Vector2i(int(floor(d.x - c.x + STAGE.x / 2.0 + 0.5)), int(floor(d.y - c.y + STAGE.y / 2.0 + 0.5))) + off
	return Rect2i(tl, Vector2i(ref["w"], ref["h"]))


## A no-reset control can only show its fault on a frame drawn right after the action tick and
## not at the very end of that tick.
static func _control_frame_usable(rec: Dictionary, tick: int) -> bool:
	return int(rec["n"]) == tick and float(rec["f"]) < CONTROL_MAX_FRACTION


## Set_grid_position without its reset_physics_interpolation() (control only).
func _teleport_no_reset(x: float, y: float) -> void:
	_dog.gx = x
	_dog.gy = y
	_dog.iso.gx = x
	_dog.iso.gy = y
	var s := IsoGrid.grid_to_screen_xy(x, y)
	_dog.position = Vector2(JsMath.round(s[0]), JsMath.round(s[1]))
	_flags["dog_reset"] = true


## CameraRig.snap() without its interpolation resets (control only).
func _snap_no_reset(tx: float, ty: float) -> void:
	_rig.model.snap_to(tx, ty)
	_rig.position = _rig.model.view_origin() + Vector2(_rig.model.view_w, _rig.model.view_h) / 2.0
	_flags["rig_reset"] = true


## Runs `prepare` (a coroutine), then `action` aligned to the frame pacing, until the first frame
## drawn after the action's tick follows that tick directly (at 30 FPS a frame can include the
## next tick too, which would hide a missing reset), and for a control also does not lie within
## 2 % of the next tick. At most CONTROL_ATTEMPTS tries; the attempts are recorded.
func _aligned_case(prepare: Callable, action: Callable, low_fraction: bool) -> Dictionary:
	var cap: Array = []
	var attempts := 0
	for attempt in CONTROL_ATTEMPTS:
		attempts = attempt + 1
		await prepare.call()
		cap = await _capture_action(action)
		var rec: Dictionary = cap[0][cap[1]]
		if int(rec["n"]) == int(cap[2]) and (not low_fraction or float(rec["f"]) < CONTROL_MAX_FRACTION):
			break
	return {"frames": cap[0], "first": cap[1], "tick": cap[2], "attempts": attempts}


func _reset_pass(fps: int) -> void:
	tree.physics_interpolation = true
	Engine.max_fps = fps
	_place_start(false)
	await _ticks(2)
	var ref := _dog_ref(FREEZE_ANIM, FREEZE_FRAME)
	var run := func(ticks: int, freeze: bool) -> void:
		_driving = true
		await _ticks(ticks)
		if freeze:
			_freeze()
			await _ticks(1)
	# Spawn: after a run the old dog leaves and a new one enters at the start like IsoWorld.setup
	# (add_child, then set_grid_position).
	var spawn := func() -> void:
		var old := _dog
		_dog_parent.remove_child(old)
		old.queue_free()
		_dog = _spawn_dog()
		_driving = false
		_flags["dog_reset"] = true
	var case: Dictionary = await _aligned_case(run.bind(WARM_TICKS + 18, false), spawn, false)
	var rec: Dictionary = case["frames"][case["first"]]
	var tick: int = case["tick"]
	var od: Vector2 = _hist[tick - 1]["dog"]
	var oc: Vector2 = _hist[tick - 1]["rig"]
	var old_box := Rect2i(Vector2i(od - oc + Vector2(STAGE) / 2.0) + Vector2i(int(_dog.body_sprite.offset.x), int(_dog.body_sprite.offset.y)), Vector2i(40, 40))
	var r := _reset_frame_eval(rec, "spawn", fps, tick, old_box, true)
	r["attempts"] = case["attempts"]
	_record(r)
	# Teleport with set_grid_position after a run (frozen frame).
	var teleport := func() -> void:
		_dog.set_grid_position(START.x, START.y)
		_flags["dog_reset"] = true
	case = await _aligned_case(run.bind(WARM_TICKS + 18, true), teleport, false)
	rec = case["frames"][case["first"]]
	tick = case["tick"]
	var old_rect := _dog_rect_at(tick - 1, ref)
	r = _reset_frame_eval(rec, "teleport", fps, tick, old_rect, false)
	r["attempts"] = case["attempts"]
	_record(r)
	# Stale-copy control: the same first frame with the dog pasted at the old position.
	var stale_rec := rec.duplicate()
	stale_rec["img"] = _paste(rec["img"], ref, old_rect.position.x, old_rect.position.y, 1.0)
	var stale := _reset_frame_eval(stale_rec, "stale_copy_control", fps, tick, old_rect, false)
	_control("stale_copy_after_teleport_%d" % fps, stale, not stale["checks"]["nothing_at_old_position"] or not stale["checks"]["dog_single_component"],
		"a stale dog image at the old position must fail the reset check")
	# Control: the same teleport without the interpolation reset.
	case = await _aligned_case(run.bind(WARM_TICKS, true), func() -> void: _teleport_no_reset(START.x, START.y), true)
	rec = case["frames"][case["first"]]
	tick = case["tick"]
	var nc := _reset_frame_eval(rec, "teleport_without_reset", fps, tick, _dog_rect_at(tick - 1, ref), false)
	nc["attempts"] = case["attempts"]
	_control("teleport_without_reset_%d" % fps, nc, not nc["checks"]["dog_at_new_position"] or not nc["checks"]["nothing_at_old_position"],
		"a teleport without the interpolation reset must fail the first-frame check")
	# Camera snap while following.
	_following = true
	var p := IsoGrid.grid_to_screen_xy(_dog.gx, _dog.gy)
	_rig.snap(p[0], p[1] - CAMERA_LIFT)
	var snap := func() -> void:
		_rig.snap(_rig.model.x + 140.0, _rig.model.y - GameConfig.Camera.BIAS_Y)
		_flags["rig_reset"] = true
	case = await _aligned_case(run.bind(WARM_TICKS, true), snap, false)
	rec = case["frames"][case["first"]]
	r = _reset_frame_eval(rec, "camera_snap", fps, case["tick"], Rect2i(), true)
	r["attempts"] = case["attempts"]
	_record(r)
	var snap_nc := func() -> void: _snap_no_reset(_rig.model.x + 140.0, _rig.model.y - GameConfig.Camera.BIAS_Y)
	case = await _aligned_case(run.bind(WARM_TICKS, true), snap_nc, true)
	rec = case["frames"][case["first"]]
	nc = _reset_frame_eval(rec, "camera_snap_without_reset", fps, case["tick"], Rect2i(), true)
	nc["attempts"] = case["attempts"]
	_control("camera_snap_without_reset_%d" % fps, nc, not nc["checks"]["markers_at_snapped_view"],
		"a camera snap without the interpolation reset must fail the first-frame marker check")
	_driving = false
	_following = false
	_dog.body_sprite.play()


# --- 4. Main restart ----------------------------------------------------------------------------------------

func _key(code: Key, pressed: bool) -> void:
	var e := InputEventKey.new()
	e.keycode = code
	e.physical_keycode = code
	e.pressed = pressed
	Input.parse_input_event(e)


func _tap_key(code: Key) -> void:
	await tree.process_frame
	_key(code, true)
	await tree.process_frame
	_key(code, false)
	await tree.process_frame


func _until(cond: Callable, max_frames: int) -> bool:
	for k in max_frames:
		if cond.call():
			return true
		await tree.process_frame
	return cond.call()


## Adds a fresh Main in the deferred-call flush that follows the process_frame signal (before the
## nodes' _process, as the engine's own main scene is in place before its first frame) and returns
## its first drawn frame with the same-instant analysis redraws.
func _main_first_frame(main: Node) -> Dictionary:
	await tree.process_frame
	_capture_vp = null
	_capture_main = main
	_frames = []
	_redraw_when = func(rec: Dictionary) -> bool: return rec["img"] != null
	_capturing = true
	tree.root.add_child.call_deferred(main)
	while _frames.is_empty() or _frames[-1]["img"] == null:
		await RenderingServer.frame_post_draw
	_capturing = false
	var rec: Dictionary = _frames[-1]
	rec["first_with_main"] = _frames.size() == 1 or _frames[-2]["img"] == null
	return rec


func _free_main(main: Node) -> void:
	_capture_main = null
	tree.root.remove_child(main)
	main.queue_free()
	await _process_frames(3)


static func _vp_image(vp: Viewport) -> Image:
	var img := vp.get_texture().get_image()
	if img.get_format() != Image.FORMAT_RGBA8:
		img.convert(Image.FORMAT_RGBA8)
	return img


static func _collect(node: Node, layers: Array, dogs: Array, rigs: Array) -> void:
	if node is CanvasLayer and (node as CanvasLayer).layer != -100 and (node as CanvasLayer).visible:
		layers.append(node)
	if node is PlayableDog:
		dogs.append(node)
	if node is CameraRig:
		rigs.append(node)
	for c in node.get_children():
		_collect(c, layers, dogs, rigs)


## Same-instant redraws of the state just drawn (RenderingServer.force_draw without swapping and
## without advancing the render time, so tile animations keep their phase): unchanged (it must
## reproduce the frame exactly), without the UI layers and the dogs' shadows (world and dog
## only), and additionally without every PlayableDog. Everything is restored afterwards; the
## redraws are never presented.
func _main_redraws() -> Dictionary:
	_in_redraw = true
	var gv: SubViewport = _capture_main.game_viewport
	var layers: Array = []
	var dogs: Array = []
	var rigs: Array = []
	_collect(gv, layers, dogs, rigs)
	var out := {"dogs_in_tree": dogs.size(), "rigs_in_tree": rigs.size(), "ui_layers_hidden": layers.size()}
	RenderingServer.force_draw(false, 0.0)
	out["again"] = _vp_image(gv)
	var hidden: Array = []
	for l: CanvasLayer in layers:
		l.visible = false
	for d: PlayableDog in dogs:
		var sh: CanvasItem = d.get_node("Shadow")
		if sh.visible:
			hidden.append(sh)
			sh.visible = false
	RenderingServer.force_draw(false, 0.0)
	out["world"] = _vp_image(gv)
	var shown: Array = []
	for d: PlayableDog in dogs:
		if d.visible:
			shown.append(d)
			d.visible = false
	RenderingServer.force_draw(false, 0.0)
	out["world_without_dogs"] = _vp_image(gv)
	for d: CanvasItem in shown:
		d.visible = true
	for sh: CanvasItem in hidden:
		sh.visible = true
	for l: CanvasLayer in layers:
		l.visible = true
	_in_redraw = false
	return out


static func _diff(a: PackedInt32Array, b: PackedInt32Array) -> PackedByteArray:
	var out := PackedByteArray()
	out.resize(a.size())
	for i in a.size():
		if a[i] != b[i]:
			out[i] = 1
	return out


static func _count_in(mask: PackedByteArray, w: int, r: Rect2i, exclude: Rect2i) -> int:
	var n := 0
	var h := int(mask.size() / float(w))
	for y in range(maxi(0, r.position.y), mini(h, r.end.y)):
		for x in range(maxi(0, r.position.x), mini(w, r.end.x)):
			if mask[y * w + x] == 1 and not exclude.has_point(Vector2i(x, y)):
				n += 1
	return n


static func _bbox_of(comps: Array) -> Rect2i:
	if comps.is_empty():
		return Rect2i()
	var r := Rect2i(comps[0]["x0"], comps[0]["y0"], comps[0]["x1"] - comps[0]["x0"] + 1, comps[0]["y1"] - comps[0]["y0"] + 1)
	for c: Dictionary in comps:
		r = r.merge(Rect2i(c["x0"], c["y0"], c["x1"] - c["x0"] + 1, c["y1"] - c["y0"] + 1))
	return r


static func _rect_list(r: Rect2i) -> Array:
	return [r.position.x, r.position.y, r.size.x, r.size.y]


## The snapped spawn view a scene's CameraRig must show (as test_P_DOG_008a computes it).
static func _expected_spawn_view(gz: GreenZoneScene, view: Vector2i, s: PackedFloat64Array) -> Vector2:
	var cm := CameraModel.new()
	cm.view_w = view.x
	cm.view_h = view.y
	cm.set_bounds(gz.world.walkable_bounds(4))
	cm.snap_to(s[0], s[1] - gz.world.camera_lift)
	return cm.view_origin() + Vector2(view) / 2.0


## One Main frame (the start, or the first frame after RESTART) from its same-instant redraws: the
## canvas transform used for the frame is the snapped spawn view; the frame reproduces exactly;
## the world image differs from the world without dogs by exactly one component equal to the
## displayed sprite frame's opaque pixels at the canonical spawn; nothing elsewhere, in particular
## nothing in old_rect (the previous run's dog).
func _main_frame_eval(rec: Dictionary, view: Vector2i, expected_cam: Vector2, spawn_px: Vector2, dog: PlayableDog, old_rect: Rect2i) -> Dictionary:
	var w := view.x
	var h := view.y
	var full := Rect2i(0, 0, w, h)
	var rd: Dictionary = rec["redraws"]
	var real := (rec["img"] as Image).get_data().to_int32_array()
	var world := (rd["world"] as Image).get_data().to_int32_array()
	var mask := _diff(world, (rd["world_without_dogs"] as Image).get_data().to_int32_array())
	var repro := _count_in(_diff(real, (rd["again"] as Image).get_data().to_int32_array()), w, full, Rect2i())
	var comps := _components(mask, w, h, 1)
	var box := _bbox_of(comps)
	var ref := _dog_ref(rec["anim"], rec["frame"])
	var off := Vector2i(int(dog.body_sprite.offset.x), int(dog.body_sprite.offset.y)) + (ref["used"] as Vector2i)
	var tl := Vector2i(spawn_px - expected_cam + Vector2(view) / 2.0) + off
	var expect_rect := Rect2i(tl, Vector2i(ref["w"], ref["h"]))
	var texel_mismatch := 0
	var rw: int = ref["w"]
	var ri: PackedInt32Array = ref["ints"]
	for j in int(ref["h"]):
		for i in rw:
			var v := ri[j * rw + i]
			if v == _bg_i:
				continue
			var x := tl.x + i
			var y := tl.y + j
			if x < 0 or y < 0 or x >= w or y >= h or world[y * w + x] != v:
				texel_mismatch += 1
	var area := _count_in(mask, w, full, Rect2i())
	var origin: Vector2 = rec["canvas_origin"]
	var expected_origin := Vector2(view) / 2.0 - expected_cam
	var cam: Vector2 = rec["cam"]
	var dog_at: Vector2 = rec["dog_pos"]
	var out := {"canvas_origin": [origin.x, origin.y], "expected_canvas_origin": [expected_origin.x, expected_origin.y],
		"camera_at": [cam.x, cam.y], "expected_camera": [expected_cam.x, expected_cam.y],
		"dog_at": [dog_at.x, dog_at.y], "spawn_px": [spawn_px.x, spawn_px.y],
		"displayed": [String(rec["anim"]), rec["frame"]], "dogs_in_tree": rd["dogs_in_tree"], "rigs_in_tree": rd["rigs_in_tree"],
		"ui_layers_hidden_for_analysis": rd["ui_layers_hidden"], "redraw_px_differing_from_frame": repro,
		"dog_components": comps.size(), "dog_bbox": _rect_list(box), "expected_dog_rect": _rect_list(expect_rect),
		"dog_area": area, "reference_area": ref["area"], "dog_texel_mismatches": texel_mismatch,
		"dog_pixels_outside_expected_rect": _count_in(mask, w, full, expect_rect)}
	var checks := {
		"canvas_at_snapped_view": origin == expected_origin,
		"camera_at_snapped_view": cam == expected_cam,
		"frame_reproducible": repro == 0,
		"one_dog_and_camera": rd["dogs_in_tree"] == 1 and rd["rigs_in_tree"] == 1,
		"single_dog_component": comps.size() == 1,
		"dog_at_canonical_spawn": dog_at == spawn_px and box == expect_rect and area == ref["area"] and texel_mismatch == 0,
		"nothing_outside_dog": out["dog_pixels_outside_expected_rect"] == 0,
	}
	if old_rect.has_area():
		var visible_old := old_rect.intersection(full)
		out["old_rect"] = _rect_list(old_rect)
		out["old_rect_visible_px"] = visible_old.get_area()
		out["dog_pixels_at_old_position"] = _count_in(mask, w, old_rect, expect_rect)
		checks["nothing_at_old_position"] = out["dog_pixels_at_old_position"] == 0 and visible_old.get_area() >= 400
	out["checks"] = checks
	return out


func _main_passes() -> void:
	tree.physics_interpolation = true
	tree.root.size = MAIN_WINDOW
	var usable := DisplayServer.screen_get_usable_rect()
	tree.root.position = usable.position + Vector2i(40, 40)
	await _process_frames(4)
	for fps in _rates:
		_record(await _main_restart(fps))


func _main_restart(fps: int) -> Dictionary:
	Engine.max_fps = fps
	InputService.clear_injection()
	var main: Node = MAIN_SCENE.instantiate()
	var a: Dictionary = await _main_first_frame(main)
	var out := {"record": "main_restart", "requested_fps": fps, "checks": {}}
	var checks: Dictionary = out["checks"]
	var view: Vector2i = main.viewport_controller.logical_size
	out["logical_size"] = [view.x, view.y]
	out["scale"] = main.viewport_controller.scale
	checks["logical_view_216x432"] = view == MAIN_WINDOW
	var gz: GreenZoneScene = main.current_scene
	var canon := GreenZoneLevel.load_model(GreenZoneLevel.definition())
	var s := IsoGrid.grid_to_screen_xy(canon.start.x, canon.start.y)
	var spawn_px := Vector2(JsMath.round(s[0]), JsMath.round(s[1]))
	var start := _main_frame_eval(a, view, _expected_spawn_view(gz, view, s), spawn_px, gz.world.player, Rect2i())
	start["first_frame_with_main"] = a["first_with_main"]
	out["start"] = start
	for k: String in start["checks"]:
		checks["start_" + k] = start["checks"][k]
	_save(a["img"], "main_%d_start_first_frame" % fps)
	_save(a["redraws"]["world"], "main_%d_start_world_redraw" % fps)
	# Close the briefing, walk away from the spawn (staying inside its view) and stop: real 60 Hz
	# ticks with injected movement, as in test_P_DOG_008a.
	var briefing: OverlayPanel = gz._overlay
	await _until(func() -> bool: return briefing.time > 0.6, 5000)
	await _tap_key(KEY_ENTER)
	checks["briefing_closed"] = await _until(func() -> bool: return gz.active, 300)
	var t0 := gz.ticks
	InputService.inject_move(0.3, -0.9)
	await _until(func() -> bool: return gz.ticks >= t0 + 60, 20000)
	InputService.clear_injection()
	var t1 := gz.ticks
	await _until(func() -> bool: return gz.ticks >= t1 + 30, 20000)
	var old_pos := gz.world.player.position
	var old_cam := gz.world.camera_rig.position
	var b: Array = await _capture_n(1)
	_save(b[0]["img"], "main_%d_before_restart" % fps)
	var cam0: Vector2 = a["cam"]
	checks["dog_walked_away"] = old_pos.distance_to(spawn_px) > 24.0 and old_cam.distance_to(cam0) > 8.0 and not gz.paused
	out["old"] = {"dog_at": [old_pos.x, old_pos.y], "camera_at": [old_cam.x, old_cam.y]}
	# Esc opens the pause menu; Down and Enter choose RESTART (restart_requested reaches
	# Main.start_green_zone through a deferred call).
	await _tap_key(KEY_ESCAPE)
	checks["paused"] = await _until(func() -> bool: return gz.paused, 300)
	var pause: OverlayPanel = gz._overlay
	await _until(func() -> bool: return pause.time > 0.4, 5000)
	await _tap_key(KEY_DOWN)
	checks["restart_selected"] = pause is PauseOverlay and pause.items[pause.selected]["label"] == "RESTART"
	var added := {"seq": -1}
	var watch := func(n: Node) -> void:
		if n is GreenZoneScene and int(added["seq"]) < 0:
			added["seq"] = _seq
	tree.node_added.connect(watch)
	var old_id := gz.get_instance_id()
	_frames = []
	_redraw_when = func(rec: Dictionary) -> bool: return int(added["seq"]) >= 0 and int(rec["seq"]) > int(added["seq"])
	_capturing = true
	await _tap_key(KEY_ENTER)
	var replaced := await _until(func() -> bool: return main.current_scene.get_instance_id() != old_id, 300)
	await RenderingServer.frame_post_draw
	_capturing = false
	_redraw_when = Callable()
	tree.node_added.disconnect(watch)
	checks["scene_replaced"] = replaced
	var c: Dictionary = {}
	for rec: Dictionary in _frames:
		if rec.has("redraws"):
			c = rec
			break
	if c.is_empty():
		checks["first_replacement_frame"] = false
		out["ok"] = false
		await _free_main(main)
		return out
	var fresh: GreenZoneScene = main.current_scene
	var expected_cam := _expected_spawn_view(fresh, view, s)
	var old_rect := Rect2i(Vector2i(old_pos - expected_cam + Vector2(view) / 2.0) + Vector2i(-20, -36), Vector2i(40, 40))
	var after := _main_frame_eval(c, view, expected_cam, spawn_px, fresh.world.player, old_rect)
	after["replacement_added_after_draw"] = added["seq"]
	after["first_frame_seq"] = c["seq"]
	out["restart"] = after
	checks["first_replacement_frame"] = int(c["seq"]) == int(added["seq"]) + 1
	for k: String in after["checks"]:
		checks["restart_" + k] = after["checks"][k]
	_save(c["img"], "main_%d_first_frame_after_restart" % fps)
	_save(c["redraws"]["world"], "main_%d_first_frame_after_restart_world_redraw" % fps)
	out["ok"] = _all(checks)
	await _free_main(main)
	return out
