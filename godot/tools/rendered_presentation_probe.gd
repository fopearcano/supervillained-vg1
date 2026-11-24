extends SceneTree
## Renderer-backed presentation probe for the rendered clauses of VIEW-004, CAM-004 and DOG-008a
## (not part of the headless suite; it needs a real renderer and a window):
##   <godot> --path godot --rendering-driver opengl3 --disable-vsync \
##     --script res://tools/rendered_presentation_probe.gd -- [--rates=30,60,90,120] [--out=<dir>]
## The checks live in rendered_presentation_probe_impl.gd, loaded once the autoloads exist (a
## --script SceneTree is compiled before them). Exit code 0 only when every measurement passed and
## every negative control was detected.

const IMPL := "res://tools/rendered_presentation_probe_impl.gd"


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var script: GDScript = load(IMPL)
	if script == null or not script.can_instantiate():
		print("PROBE {\"record\": \"summary\", \"ok\": false, \"failures\": [\"implementation does not load\"]}")
		quit(1)
		return
	var probe: RefCounted = script.new(self)
	var code: Variant = await probe.run()
	# A run aborted by a script error returns no code: that is a failure too.
	quit(code if code is int else 1)
