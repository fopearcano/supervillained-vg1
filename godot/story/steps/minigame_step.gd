class_name MiniGameStep
extends StoryStep
## A focused minigame inside a scene (port of src/story/minigames/miniGame.ts MiniGameStep, for the
## three this build has — no general framework): "parade" (4.1, raise shields on the beat), "rowing"
## (4.3, row on the beat), both RhythmGame; "boat" (4.2, ease the skiff alongside), BoatGame. The walk
## controls are off; a press is a tap in the game's lower band, J/X, Space or confirm. When the game
## ends its result's effects (`won_effects` / `lost_effects`) are applied once, the result shows for
## MINI_RESULT_HOLD seconds, and the scene goes on — there is no automatic retry (restarting the scene
## from the pause is the retry path). Every word shown is in `lines` (title, objective, cue, hit,
## miss, won, lost) or ShellText; `params` may set beats, bpm, need, and the actor that rocks with
## the boat ("bob").

const GAMES := ["parade", "rowing", "boat"]
const RHYTHM_TEXTS := ["title", "objective", "cue", "hit", "miss", "won", "lost"]
const BOAT_TEXTS := ["title", "objective", "won"]
const S := GameConfig.Story
## A tap counts as a press in the band this far above the screen's bottom (source: h − 120).
const TAP_BAND := 120.0

@export var game := ""
@export var lines: Dictionary = {}
@export var won_effects: Dictionary = {}
@export var lost_effects: Dictionary = {}
@export var params: Dictionary = {}


func kind() -> String:
	return "minigame"


func texts() -> PackedStringArray:
	var out := PackedStringArray()
	for k: String in lines:
		out.append(String(lines[k]))
	return out


func effect_sets() -> Array:
	var out: Array = []
	for fx: Dictionary in [won_effects, lost_effects]:
		if not fx.is_empty():
			out.append(fx)
	return out


func actor_refs() -> PackedStringArray:
	return PackedStringArray([String(params["bob"])]) if params.has("bob") else PackedStringArray()


func sounds() -> PackedStringArray:
	return PackedStringArray(["click", "treat", "empty", "splash", "hurt", "star"])


func check(errors: PackedStringArray) -> void:
	_need(errors, GAMES.has(game), "minigame %s: unknown game '%s'" % [id, game])
	for k: String in (BOAT_TEXTS if game == "boat" else RHYTHM_TEXTS):
		_need(errors, String(lines.get(k, "")).strip_edges() != "", "minigame %s: needs lines.%s" % [id, k])
	_need(errors, not won_effects.is_empty(), "minigame %s: needs its won effects" % id)
	if game != "boat":
		_need(errors, not lost_effects.is_empty(), "minigame %s: a beat game needs its lost effects (a loss applies them and goes on)" % id)
		_need(errors, int(params.get("need", S.PARADE_NEED)) <= int(params.get("beats", S.PARADE_BEATS)), "minigame %s: need more hits than beats" % id)


## The rhythm game's numbers: the parade's, rowing 8 BPM slower; `params` may override.
func rhythm() -> RhythmGame:
	var bpm := S.PARADE_BPM - (S.ROWING_BPM_DROP if game == "rowing" else 0.0)
	return RhythmGame.new().setup(int(params.get("beats", S.PARADE_BEATS)), float(params.get("bpm", bpm)), int(params.get("need", S.PARADE_NEED)))


func begin(ctx: StoryContext, st: Dictionary) -> void:
	st["game"] = BoatGame.new() if game == "boat" else rhythm()
	st["result"] = ""
	st["hold"] = 0.0
	st["applied"] = false
	ctx.set_controls(false)
	ctx.hud.objective = String(lines.get("objective", ""))
	for a: StringName in [&"action", &"pee", &"confirm", &"bark"]:
		InputService.consume(a)
	InputService.consume_taps()
	var v := MiniGameView.new().setup(self, st, ctx)
	st["view"] = v
	ctx.scene.show_minigame(v)


## This tick's presses: taps in the lower band, J/X, Space, confirm.
func _presses(ctx: StoryContext) -> int:
	var n := 0
	var h := float(ctx.scene.view_size().y)
	for t: Vector2 in InputService.consume_taps():
		if t.y > h - TAP_BAND:
			n += 1
	if InputService.consume_any([&"action", &"pee", &"confirm"] as Array[StringName]):
		n += 1
	return n


func tick(ctx: StoryContext, st: Dictionary, dt: float) -> bool:
	if String(st["result"]) != "":
		st["hold"] = float(st["hold"]) - dt
		InputService.consume_taps()
		return float(st["hold"]) <= 0.0
	var presses := _presses(ctx)
	var r := ""
	if game == "boat":
		var b: BoatGame = st["game"]
		r = b.update(dt, presses)
		for ev: String in b.events:
			match ev:
				"stroke":
					AudioService.play(&"click", 0.5)
				"splash":
					AudioService.play(&"splash", 0.5)
					ctx.notice(ctx.ui_text("story_boat_splash"), Color("#ff9a1f"))
				"swamped":
					AudioService.play(&"hurt")
					ctx.shake(4.0)
					ctx.notice(ctx.ui_text("story_boat_swamped_notice"), Color("#ff2a3a"))
		# The one beside him rocks with the boat (the sprite only; his grid place never moves).
		if params.has("bob"):
			var a := ctx.actor(String(params["bob"]))
			if a and a.get_child_count() > 0:
				(a.get_child(0) as Node2D).position.y = roundf(sin(b.time * 2.0) * 1.5)
	else:
		var g: RhythmGame = st["game"]
		r = g.update(dt, presses > 0)
		for ev: String in g.events:
			match ev:
				"click":
					AudioService.play(&"click", 0.5)
				"hit":
					AudioService.play(&"treat")
				"miss":
					AudioService.play(&"empty")
	if r == "running":
		return false
	_finish(ctx, st, r)
	return false


## The result: its effects applied once, then held on screen before the scene goes on.
func _finish(ctx: StoryContext, st: Dictionary, r: String) -> void:
	st["result"] = r
	st["hold"] = S.MINI_RESULT_HOLD
	if st["applied"]:
		return
	st["applied"] = true
	(ctx.metrics.get_or_add("minis", []) as Array).append("%s:%s" % [game, r])
	var fx := won_effects if r == "won" else lost_effects
	if not fx.is_empty():
		ctx.apply(fx)
	AudioService.play(&"star" if r == "won" else &"empty")


func end(ctx: StoryContext, st: Dictionary) -> void:
	var v: Variant = st.get("view")
	if v != null and is_instance_valid(v):
		ctx.scene.hide_minigame(v)
	st.erase("view")
	if params.has("bob") and ctx.has_actor(String(params["bob"])):
		var a := ctx.actor(String(params["bob"]))
		if a.get_child_count() > 0:
			(a.get_child(0) as Node2D).position.y = 0.0
	ctx.hud.objective = ""
