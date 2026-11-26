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

const GAMES := ["parade", "rowing", "boat", "ladders", "letter", "rumour"]
const RHYTHM_TEXTS := ["title", "objective", "cue", "hit", "miss", "won", "lost"]
const BOAT_TEXTS := ["title", "objective", "won"]
const LADDER_TEXTS := ["title", "objective", "help", "stone", "won"]
const LETTER_TEXTS := ["title", "objective", "send", "again", "accept", "answer", "won"]
const RUMOUR_TEXTS := ["title", "objective", "start", "wrong", "won"]
const TEXTS_OF := {"parade": RHYTHM_TEXTS, "rowing": RHYTHM_TEXTS, "boat": BOAT_TEXTS, "ladders": LADDER_TEXTS, "letter": LETTER_TEXTS, "rumour": RUMOUR_TEXTS}
## Games with no lost result (the source has none): the skiff, the ladder, the letter, the rumour.
const NEVER_LOST := ["boat", "ladders", "letter", "rumour"]
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
	for pc: Dictionary in params.get("pieces", []):
		out.append(String(pc["text"]))
		out.append(String(pc["garble"]))
	for s: Dictionary in params.get("slots", []):
		out.append(String(s["before"]).strip_edges(true, false).trim_prefix(", ").trim_prefix(". "))
		for o: String in s["options"]:
			out.append(o)
	return out


func effect_sets() -> Array:
	var out: Array = []
	for fx: Dictionary in [won_effects, lost_effects]:
		if not fx.is_empty():
			out.append(fx)
	for fx: Dictionary in (params.get("outcomes", {}) as Dictionary).values():
		out.append(fx)
	return out


func actor_refs() -> PackedStringArray:
	return PackedStringArray([String(params["bob"])]) if params.has("bob") else PackedStringArray()


func sounds() -> PackedStringArray:
	return PackedStringArray(["click", "treat", "empty", "splash", "hurt", "star"])


func check(errors: PackedStringArray) -> void:
	_need(errors, GAMES.has(game), "minigame %s: unknown game '%s'" % [id, game])
	for k: String in TEXTS_OF.get(game, []):
		_need(errors, String(lines.get(k, "")).strip_edges() != "", "minigame %s: needs lines.%s" % [id, k])
	_need(errors, not won_effects.is_empty(), "minigame %s: needs its won effects" % id)
	if game == "rumour":
		_need(errors, (params.get("pieces", []) as Array).size() >= 2, "minigame %s: the rumour needs its pieces" % id)
	if game == "letter":
		_need(errors, (params.get("slots", []) as Array).size() >= 2, "minigame %s: the letter needs its slots" % id)
		_need(errors, (params.get("outcomes", {}) as Dictionary).has("named") and (params.get("outcomes", {}) as Dictionary).has("necessity"), "minigame %s: the letter needs both outcomes" % id)
	if not NEVER_LOST.has(game):
		_need(errors, not lost_effects.is_empty(), "minigame %s: a beat game needs its lost effects (a loss applies them and goes on)" % id)
		_need(errors, int(params.get("need", S.PARADE_NEED)) <= int(params.get("beats", S.PARADE_BEATS)), "minigame %s: need more hits than beats" % id)


## The rhythm game's numbers: the parade's, rowing 8 BPM slower; `params` may override.
func rhythm() -> RhythmGame:
	var bpm := S.PARADE_BPM - (S.ROWING_BPM_DROP if game == "rowing" else 0.0)
	return RhythmGame.new().setup(int(params.get("beats", S.PARADE_BEATS)), float(params.get("bpm", bpm)), int(params.get("need", S.PARADE_NEED)))


func begin(ctx: StoryContext, st: Dictionary) -> void:
	match game:
		"boat":
			st["game"] = BoatGame.new()
		"ladders":
			st["game"] = LaddersGame.new().setup(int(params.get("rungs", S.LADDER_RUNGS)), float(ctx.scene.view_size().y), hash("ladders:" + ctx.data.id))
		"letter":
			st["game"] = LetterGame.new().setup(params["slots"], int(params.get("debt_slot", 1)), int(params.get("debt_option", 1)))
		"rumour":
			st["game"] = RumourGame.new().setup(params["pieces"], hash("rumour:" + ctx.data.id))
		_:
			st["game"] = rhythm()
	st["mx"] = 0.0
	st["my"] = 0.0
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
		# The result frame and its hold take every press: none reaches the next step.
		st["hold"] = float(st["hold"]) - dt
		InputService.drain_story_edges()
		return float(st["hold"]) <= 0.0
	var r := ""
	if game == "ladders":
		r = _tick_ladders(ctx, st, dt)
	elif game == "letter":
		r = _tick_letter(ctx, st)
	elif game == "rumour":
		r = _tick_rumour(ctx, st, dt)
	if game == "ladders" or game == "letter" or game == "rumour":
		if r == "running":
			return false
		_finish(ctx, st, r)
		InputService.drain_story_edges()
		return false
	var presses := _presses(ctx)
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
	InputService.drain_story_edges()
	return false


## The ladder: a middle tap, J/X, Space, Enter or up climbs; a side tap or left/right changes ladder.
func _tick_ladders(ctx: StoryContext, st: Dictionary, dt: float) -> String:
	var w := float(ctx.scene.view_size().x)
	var climbs := 0
	var moves: Array = []
	for t: Vector2 in InputService.consume_taps():
		if t.x < w * 0.3:
			moves.append(-1)
		elif t.x > w * 0.7:
			moves.append(1)
		else:
			climbs += 1
	if InputService.consume_any([&"action", &"pee", &"confirm"] as Array[StringName]):
		climbs += 1
	var mx := InputService.move_x
	var my := InputService.move_y
	if mx < -0.5 and float(st["mx"]) >= -0.5:
		moves.append(-1)
	elif mx > 0.5 and float(st["mx"]) <= 0.5:
		moves.append(1)
	if my < -0.5 and float(st["my"]) >= -0.5:
		climbs += 1
	st["mx"] = mx
	st["my"] = my
	var g: LaddersGame = st["game"]
	var r := g.update(dt, climbs, moves)
	for ev: String in g.events:
		match ev:
			"climb":
				AudioService.play(&"click", 0.4, 1.0 + (int(g.rung) % 4) * 0.1)
			"hit":
				AudioService.play(&"hurt")
				ctx.notice(String(lines["stone"]), Color("#ff2a3a"))
	return r


## The letter: a tap on a slot cycles its word; READ IT ALOUD (or confirm) sends; in the answer
## phase WRITE IT AGAIN, or HEAR THE ANSWER OUT (or confirm) finishes with its outcome's effects.
func _tick_letter(ctx: StoryContext, st: Dictionary) -> String:
	var g: LetterGame = st["game"]
	var picked := ""
	var w := float(ctx.scene.view_size().x)
	for t: Vector2 in InputService.consume_taps():
		for b: Dictionary in g.layout(w):
			if (b["rect"] as Rect2).has_point(t):
				picked = String(b["id"])
	if InputService.consume_any([&"confirm", &"action", &"pee"] as Array[StringName]):
		picked = "send" if g.phase == "write" else "accept"
	var r := g.pick(picked)
	for ev: String in g.events:
		AudioService.play(&"star" if ev == "sent" else &"click")
	if r == "won":
		var fx: Dictionary = (params["outcomes"] as Dictionary)[g.outcome]
		ctx.apply(fx)
		(ctx.metrics.get_or_add("letter", []) as Array).append(g.outcome)
		if lines.has(g.outcome):
			ctx.notice(String(lines[g.outcome]), Color("#ffe23a"))
	return r


## The garbled news: a tap on a piece places it if it comes next in the offer, else the "came later"
## feedback. Pieces arrive over time.
func _tick_rumour(ctx: StoryContext, st: Dictionary, dt: float) -> String:
	var g: RumourGame = st["game"]
	var tapped := -1
	var w := float(ctx.scene.view_size().x)
	for t: Vector2 in InputService.consume_taps():
		for b: Dictionary in g.layout(w):
			if (b["rect"] as Rect2).has_point(t):
				tapped = int(b["id"])
	var r := g.update(dt, tapped)
	for ev: String in g.events:
		match ev:
			"arrive":
				AudioService.play(&"click")
			"placed":
				AudioService.play(&"treat")
			"wrong":
				AudioService.play(&"empty")
				ctx.notice(String(lines["wrong"]), Color("#ff2a3a"))
	return r


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
	InputService.drain_story_edges()
	var v: Variant = st.get("view")
	if v != null and is_instance_valid(v):
		ctx.scene.hide_minigame(v)
	st.erase("view")
	if params.has("bob") and ctx.has_actor(String(params["bob"])):
		var a := ctx.actor(String(params["bob"]))
		if a.get_child_count() > 0:
			(a.get_child(0) as Node2D).position.y = 0.0
	ctx.hud.objective = ""
