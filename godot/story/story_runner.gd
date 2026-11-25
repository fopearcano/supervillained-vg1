class_name StoryRunner
extends RefCounted
## Runs a scene's ordered StorySteps (port of the step loop of src/story/storyScene.ts). Each step
## gets begin(ctx, st), tick(ctx, st, dt) until it returns true, then end(ctx, st); `st` is the
## step's per-run state, owned here. Steps that finish at once chain within the same tick (with no
## time passing). A step may insert follow-up steps (a choice's branch) ahead of the queue. Local
## signals only (no global bus).

signal step_started(step: StoryStep)
signal finished

var queue: Array = []
var current: StoryStep = null
var st: Dictionary = {}
var done := false
## Ids of every step begun, in order (tests, the drivers, the completion reports).
var trace: PackedStringArray = []


func start(steps: Array) -> void:
	queue = steps.duplicate()
	current = null
	st = {}
	done = false
	trace = PackedStringArray()


## Queues `steps` to run right after the current step.
func insert(steps: Array) -> void:
	var front := steps.duplicate()
	front.append_array(queue)
	queue = front


func tick(ctx: StoryContext, dt: float) -> void:
	var guard := 0
	while not done and guard < 256 and ctx.error == "":
		guard += 1
		if current == null:
			if queue.is_empty():
				done = true
				finished.emit()
				return
			current = queue.pop_front()
			st = {}
			trace.append(current.id)
			step_started.emit(current)
			current.begin(ctx, st)
			if ctx.error != "":
				return
		if current.tick(ctx, st, dt):
			current.end(ctx, st)
			current = null
			dt = 0.0
			continue
		return


## Ends the running step (scene torn down, restarted or paused into a quit).
func stop(ctx: StoryContext) -> void:
	if current != null:
		current.end(ctx, st)
	current = null
	queue = []
