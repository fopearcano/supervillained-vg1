extends SceneTree
## Renders the title portrait's first, middle and last frames, smooth-scaled to the logical widths
## of the narrowest, preferred and widest views (round(width * TITLE.DOG_WIDTH): 192 -> 88,
## 216 -> 99, 270 -> 124), through TitlePortrait (linear sampling + alpha cut) on a dark ground,
## each shown at integer scale 2 like the game. Needs a renderer (not --headless):
##   godot --path godot --script res://tools/title_capture.gd -- --out <dir>

const WIDTHS := [88, 99, 124]
const DOG_WIDTH := 0.46


func _initialize() -> void:
	var out := "user://title_capture"
	var args := OS.get_cmdline_user_args()
	for k in args.size():
		if args[k] == "--out" and k + 1 < args.size():
			out = args[k + 1]
	DirAccess.make_dir_recursive_absolute(out)
	var frames: SpriteFrames = load("res://data/title/title_animation.tres")
	var n := frames.get_frame_count(&"portrait")
	var vp := SubViewport.new()
	vp.size = Vector2i(8 + (126 + 8) * WIDTHS.size(), 8 + 172 + 8)
	vp.transparent_bg = false
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var bg := ColorRect.new()
	bg.color = Color("#120818")
	bg.size = Vector2(vp.size)
	vp.add_child(bg)
	var portraits: Array[TitlePortrait] = []
	for k in WIDTHS.size():
		var p := TitlePortrait.new()
		vp.add_child(p)
		p.fit_width(float(WIDTHS[k]))
		p.position = Vector2(8 + k * (126 + 8), 8)
		portraits.append(p)
	for idx: int in [0, n / 2, n - 1]:
		for p in portraits:
			p.stop()
			p.frame = idx
		for i in 4:
			await process_frame
		await RenderingServer.frame_post_draw
		var img := vp.get_texture().get_image()
		img.resize(img.get_width() * 2, img.get_height() * 2, Image.INTERPOLATE_NEAREST)
		var path := out.path_join("title_frame_%02d_widths_88_99_124.png" % idx)
		img.save_png(path)
		print("saved ", path)
	quit(0)
