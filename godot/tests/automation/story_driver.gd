class_name StoryDriver
extends RefCounted
## Story driver for the tests and the completion reports. Real-input mode plays a StoryScene through
## the same InputService path as a player: the joystick (injected movement toward what is on
## screen), the action and confirm edges, and real pointer taps on the choice rows. It reads what a
## player sees (the objective's goal and pickups, the choice rows, who stands in a gap) and never
## calls a step's or a rule's methods. Scripted mode (the smoke) instead places Zampanò on each
## target, a debug skip that still runs every step and rule.
## Navigation is a breadth-first search over the stage's walkable tiles (a test aid; the game has
## no pathfinding).
##
## M6: fights (approach the nearest foe; bark when one is close; a knight holds the shield while a
## red ring fills within reach and strikes a foe who reels or swings: the rings a player sees), the
## lull (stand within range, press the action once in each pause the gauge shows), listening (stand
## by the point), stealth (keep out of the cones a player sees, waiting behind cover when a watcher
## looks this way), and the beat games (press on the beats the cues show).

const DT := 1.0 / 60.0
const CB := GameConfig.Combat

var scene: StoryScene
## choice id -> option id; a choice not listed takes its first open option.
var policy: Dictionary = {}
## Jack's gate (1.2): "bark" (success: bark near him) or "push" (failure, then recovery).
var gate := "bark"
var scripted := false
var t := 0.0
var actions := 0
var taps := 0
var _next_confirm := 0.0
var _next_action := 0.0
var _path: Array = []
var _goal := Vector2(-99, -99)
var _repath := 0.0
var _lull_acted := false
## Beat games: the beats already pressed for; the skiff: the next stroke time.
var _pressed_beats := {}
var _next_stroke := 0.0
var _game: Object = null
## Minigames: false = never press (the loss path of the tests).
var plays_minigames := true
## M7 campaign policies. skill (1 = exact): below 1 some beats are pressed off the beat, the shield
## comes up a little late and some openings are missed (a fight may be lost and played again; a
## minigame may be lost: never skipped). choice_mode for choices the policy does not name: "" or
## "first" (the first open option), "last", "random" (from rng).
var skill := 1.0
var choice_mode := ""
var rng := RandomNumberGenerator.new()
var _beat_off := {}
var _threat_t := 0.0
## 8.1: the turn he has learned from watching where his legs take him (radians).
var _turn := 0.0
var _last_press := Vector2.ZERO


func _init(p_scene: StoryScene, p_policy: Dictionary = {}, p_gate: String = "bark", p_scripted: bool = false) -> void:
	scene = p_scene
	policy = p_policy
	gate = p_gate
	scripted = p_scripted


## The player's inputs for the next tick (before InputService.update and the scene's tick).
func drive(dt: float) -> void:
	t += dt
	InputService.inject_move(0.0, 0.0)
	if scene.finished or scene.paused or scene.world == null:
		return
	var step: StoryStep = scene.runner.current
	var st: Dictionary = scene.runner.st
	if step == null:
		return
	if not step is ObjectiveStep:
		InputService.guard_hold_injected = false
	# 8.1: he watches where his legs take him and learns the turn (only while the controls can
	# scramble: the walk says so); anywhere else he presses straight.
	if step is ObjectiveStep and (step as ObjectiveStep).rule == "waking":
		var dog := scene.world.player
		var v := IsoGrid.grid_vec_to_screen(dog.vx, dog.vy)
		if _last_press.length() > 0.5 and v.length() > 0.8:
			_turn = lerp_angle(_turn, _last_press.angle_to(v), 0.15)
	else:
		_turn = 0.0
	_last_press = Vector2.ZERO
	if step is MiniGameStep:
		_mini(step as MiniGameStep, st)
	elif step is ObjectiveStep:
		_objective(step as ObjectiveStep, st)
	elif step is ChoiceStep and st.get("phase", "") == "choosing":
		_choose(step as ChoiceStep, st)
	elif step is DialogueStep or step is NarrationStep or step is ChoiceStep or step is CardStep:
		_confirm()


func _confirm() -> void:
	if t >= _next_confirm:
		_next_confirm = t + GameConfig.Story.PILOT_CONFIRM_EVERY
		InputService.trigger(&"confirm")


## A real tap on the wanted option's row.
func _choose(step: ChoiceStep, st: Dictionary) -> void:
	var open: Array = st["open"]
	var views: Array = st["views"]
	var want := String(policy.get(step.id, ""))
	var idx := -1
	for k in open.size():
		if (open[k] as StoryChoiceOption).id == want and String((views[k] as Dictionary)["locked"]) == "":
			idx = k
	if idx < 0:
		var free: Array = []
		for k in views.size():
			if String((views[k] as Dictionary)["locked"]) == "":
				free.append(k)
		if not free.is_empty():
			if choice_mode == "last":
				idx = free[free.size() - 1]
			elif choice_mode == "random":
				if not st.has("_pick"):
					st["_pick"] = free[rng.randi() % free.size()]
				idx = st["_pick"]
			else:
				idx = free[0]
	var rects: Array[Rect2] = scene.hud.choice_rects
	if idx < 0 or idx >= rects.size() or t < _next_confirm:
		return
	_next_confirm = t + 0.3
	var c := rects[idx].get_center()
	InputService.pointer_down(9, c)
	InputService.pointer_up(9, c)
	taps += 1


func _objective(step: ObjectiveStep, st: Dictionary) -> void:
	var dog := scene.world.player
	var pos := Vector2(dog.gx, dog.gy)
	if st.has("interrupt"):
		InputService.guard_hold_injected = false
		return
	var combat := scene.ctx.combat
	# A hold (survive) with foes: fight them until the clock runs out (none need be routed).
	if combat != null and combat.active() and (not combat.won() or step.objective_kind == "survive"):
		_fight(pos)
		return
	InputService.guard_hold_injected = false
	if step.rule == "lull":
		# 7.8: the policy's "oath" ("call" by default) or "silent" (stand and say nothing).
		if step.rule_params.has("silence_after") and String(policy.get("oath", "call")) == "silent":
			InputService.inject_move(0.0, 0.0)
			return
		_lull(step, pos)
		return
	if step.objective_kind == "survive" and step.rule == "steady":
		InputService.inject_move(0.0, 0.0)
		return
	if step.rule == "act_at":
		var gp: Vector2 = st["goal"]
		if pos.distance_to(gp) > float(step.rule_params["radius"]) - 0.4:
			if scripted:
				dog.set_grid_position(gp.x, gp.y)
			else:
				_steer(pos, gp, [])
		elif t >= _next_action:
			_next_action = t + 0.4
			InputService.trigger(&"action")
			actions += 1
		return
	if step.rule == "shoulder":
		# At Pierre's shoulder, a tile to his east, walking.
		var lead: StoryActor = scene.actors.get(String(step.rule_params["leader"]))
		if lead:
			var at := Vector2(lead.gx + 1.0, lead.gy)
			if scripted:
				dog.set_grid_position(at.x, at.y)
			elif pos.distance_to(at) > 0.15:
				_steer(pos, at, [])
		return
	if step.rule == "listen":
		var lp: Variant = step.rule_params["point"]
		var at: Vector2 = scene.ctx.marker(lp) if lp is String else lp
		if pos.distance_to(at) > float(step.rule_params["radius"]) - 0.6:
			if scripted:
				dog.set_grid_position(at.x, at.y)
			else:
				_steer(pos, at, [])
		return
	var target: Variant = null
	var blocked: Array = []
	var bark_here := false
	if step.rule == "cut_off":
		blocked.append(step.rule_params["gap"])
	# A fire: what a player sees is the burning tiles; he goes round them.
	if step.rule == "fire":
		for k: Vector2i in st.get("fire", {}):
			blocked.append(Rect2(k.x, k.y, 1, 1))
	if step.rule == "jack_gate" and not st.get("open", false):
		var gap: Rect2 = step.rule_params["gap"]
		if gate == "bark":
			var jack: StoryActor = scene.actors.get(String(step.rule_params["blocker"]))
			var spot := Vector2(gap.position.x - 1.2, jack.gy if jack else gap.get_center().y)
			blocked.append(gap)
			if pos.distance_to(spot) < 0.4:
				bark_here = true
			else:
				target = spot
	if step.objective_kind == "follow":
		var lead: StoryActor = scene.actors.get(step.leader)
		if lead:
			var lp := Vector2(lead.gx, lead.gy)
			target = lp if pos.distance_to(lp) > 1.1 else null
	elif target == null and not bark_here:
		var best := INF
		for p: StoryPickup in step.pickups:
			if (st.get("picked", []) as Array).has(p.id):
				continue
			if not (st["spots"] as Dictionary).has(p.id):
				continue
			var at: Vector2 = (st["spots"][p.id] as Dictionary)["at"]
			if pos.distance_to(at) < best:
				best = pos.distance_to(at)
				target = at
		if target == null and st.get("goal") != null:
			target = st["goal"]
			# A goal found by ear: walk to where the sound was last heard (no ring is shown).
			if step.rule == "sounder" and bool(step.rule_params.get("hidden", false)):
				target = _heard(String(step.rule_lines["sound"]), target)
	if bark_here:
		if t >= _next_action:
			_next_action = t + 0.45
			InputService.trigger(&"action")
			actions += 1
		return
	if target == null:
		return
	if scripted:
		dog.set_grid_position((target as Vector2).x, (target as Vector2).y)
		return
	if step.caught != "" and _stealthy(pos, target):
		return
	_steer(pos, target, blocked)


## A fight: what a player sees is the foes, their red wind-up rings and yellow stagger rings.
func _fight(pos: Vector2) -> void:
	var combat := scene.ctx.combat
	var nearest: StoryActor = null
	var nd := INF
	var threat := false
	for a: StoryActor in combat.foes:
		if a.foe == null or a.foe.routed:
			continue
		var d := pos.distance_to(Vector2(a.gx, a.gy))
		if d < nd:
			nd = d
			nearest = a
		if a.foe.windup > 0.0 and d < CB.FOE_REACH + 0.3:
			threat = true
	if nearest == null:
		InputService.guard_hold_injected = false
		return
	var at := Vector2(nearest.gx, nearest.gy)
	# Below full skill the shield comes up a little after the ring starts filling.
	_threat_t = _threat_t + DT if threat else 0.0
	var seen_threat := threat and _threat_t >= (1.0 - skill) * 0.3
	if scene.ctx.armed():
		var open := nearest.foe.stun > 0.0 or nearest.foe.windup > 0.0
		InputService.guard_hold_injected = seen_threat and not (open and nd <= CB.SWORD_RANGE)
		if open and nd <= CB.SWORD_RANGE and t >= _next_action:
			_next_action = t + CB.SWORD_COOLDOWN + 0.03
			# Below full skill some openings are missed.
			if rng.randf() < 0.5 + 0.5 * skill:
				InputService.trigger(&"strike")
				actions += 1
	elif nd <= CB.BARK_RADIUS - 0.4 and t >= _next_action:
		_next_action = t + CB.BARK_COOLDOWN + 0.05
		InputService.trigger(&"bark")
		actions += 1
	if nd > 0.95:
		var to := at + (pos - at).normalized() * 0.8
		if scripted:
			scene.world.player.set_grid_position(to.x, to.y)
		else:
			_steer(pos, to, [])


## A minigame, from what a player sees: a beat game's cue reaching the hit line (press on it, once
## per beat); the skiff's gentle strokes (slower than the splash gap, none while swamped).
func _mini(step: MiniGameStep, st: Dictionary) -> void:
	if not plays_minigames or String(st.get("result", "")) != "" or not st.has("game"):
		return
	# A new game (another step, or the same one after a restart) starts from nothing.
	if st["game"] != _game:
		_game = st["game"]
		_pressed_beats.clear()
		_beat_off.clear()
		_next_stroke = 0.0
	if step.game == "ladders":
		_ladders(st["game"] as LaddersGame)
		return
	if step.game == "letter":
		_letter(step, st["game"] as LetterGame)
		return
	if step.game == "rumour":
		var rg: RumourGame = st["game"]
		if t >= _next_action:
			for b: Dictionary in rg.layout(float(scene.view_size().x)):
				if int(b["id"]) == rg.placed.size():
					_next_action = t + 0.5
					var c: Vector2 = (b["rect"] as Rect2).get_center()
					InputService.pointer_down(8, c)
					InputService.pointer_up(8, c)
					taps += 1
		return
	if step.game == "tug":
		# Row as fast as a person can tap (about 8 a second); it is lost anyway.
		if t >= _next_stroke:
			_next_stroke = t + 0.125
			InputService.trigger(&"action")
			actions += 1
		return
	if step.game == "boat":
		var b: BoatGame = st["game"]
		if b.swamped_t <= 0.0 and t >= _next_stroke:
			_next_stroke = t + GameConfig.Story.BOAT_MIN_GAP * 1.15
			InputService.trigger(&"action")
			actions += 1
		return
	var g: RhythmGame = st["game"]
	for k in g.beats:
		if g.judged.has(k) or _pressed_beats.has(k):
			continue
		if not _beat_off.has(k):
			_beat_off[k] = 0.0 if rng.randf() < skill else rng.randf_range(0.12, 0.3) * (1.0 if rng.randf() < 0.5 else -1.0)
		if absf(g.time + DT - (g.beat_at(k) + float(_beat_off[k]))) <= 0.04:
			_pressed_beats[k] = true
			InputService.trigger(&"action")
			actions += 1
		break


## The ladder, from what a player sees: a stone's warning or a stone above him on his ladder sends
## him to a clear one (a tap on that side); otherwise he climbs at a human tapping rate (J), under the
## game's own input cap.
func _ladders(g: LaddersGame) -> void:
	var w := float(scene.view_size().x)
	if g.threatened(g.lane) and t >= _next_action:
		var options: Array = []
		for l: int in [g.lane - 1, g.lane + 1, g.lane - 2, g.lane + 2]:
			if l >= 0 and l <= 2 and not g.threatened(l):
				options.append(l)
		if not options.is_empty():
			_next_action = t + 0.15
			var x := w * 0.1 if int(options[0]) < g.lane else w * 0.9
			InputService.pointer_down(8, Vector2(x, 300))
			InputService.pointer_up(8, Vector2(x, 300))
			taps += 1
			return
	if t >= _next_stroke:
		_next_stroke = t + 1.0 / 6.0
		InputService.trigger(&"action")
		actions += 1


## The letter, by touch: the policy's "letter" ("named" by default: the debt named outright, one tap
## on the second slot; "necessity": no change), then READ IT ALOUD and HEAR THE ANSWER OUT.
func _letter(step: MiniGameStep, g: LetterGame) -> void:
	if t < _next_action:
		return
	_next_action = t + 0.3
	var want_named := String(policy.get("letter", "named")) == "named"
	var target := ""
	if g.phase == "write":
		target = "slot%d" % g.debt_slot if (g.picks[g.debt_slot] == g.debt_option) != want_named else "send"
	else:
		target = "accept"
	for b: Dictionary in g.layout(float(scene.view_size().x)):
		if String(b["id"]) == target:
			var c: Vector2 = (b["rect"] as Rect2).get_center()
			InputService.pointer_down(8, c)
			InputService.pointer_up(8, c)
			taps += 1


## Where `sound` was last seen floating (the place a hidden goal is heard from), else `fallback`.
func _heard(sound: String, fallback: Vector2) -> Vector2:
	var best: Variant = null
	var age := INF
	for f: Dictionary in scene.hud.floats:
		if String(f["text"]) == sound and float(f["t"]) < age:
			age = float(f["t"])
			best = f["at"]
	return best if best != null else fallback


## Stealth, from what a player sees (the cones, red while they fill; the bushes): inside a cone, get
## out of it (to the nearest cover, or straight away from the watcher); if the next step would enter
## one, wait. True when this tick's movement was decided here.
func _stealthy(pos: Vector2, target: Vector2) -> bool:
	var map := scene.world.map
	var hides: Array = scene.ctx.hides
	var watchers: Array = []
	for a: StoryActor in scene.actors.values():
		if a.sight_range > 0.0:
			watchers.append(a)
	if watchers.is_empty():
		return false
	var seen_by: StoryActor = null
	for a: StoryActor in watchers:
		if StorySight.can_see(map, a, pos.x, pos.y, hides):
			seen_by = a
	if seen_by != null:
		var away := (pos - Vector2(seen_by.gx, seen_by.gy)).normalized()
		var cover: Variant = null
		for h: Vector2 in hides:
			if h.distance_to(pos) < 2.5 and (cover == null or h.distance_to(pos) < (cover as Vector2).distance_to(pos)):
				cover = h
		var to: Vector2 = cover if cover != null else pos + away * 1.5
		_steer(pos, to, [])
		return true
	var ahead := pos + (target - pos).normalized() * 0.9
	for a: StoryActor in watchers:
		if StorySight.can_see(map, a, ahead.x, ahead.y, hides):
			InputService.inject_move(0.0, 0.0)
			return true
	return false


## The lull: stand within range, press the walk's action once in each pause the gauge shows.
func _lull(step: ObjectiveStep, pos: Vector2) -> void:
	var s: Variant = step.rule_params["stand"]
	var stand: Vector2 = scene.ctx.marker(s) if s is String else s
	if pos.distance_to(stand) > float(step.rule_params["range"]) - 0.6:
		if scripted:
			scene.world.player.set_grid_position(stand.x, stand.y)
		else:
			_steer(pos, stand, [])
		return
	var in_lull := scene.hud.mode_label == scene.ctx.ui_text("story_lull_now")
	if not in_lull:
		_lull_acted = false
	elif not _lull_acted:
		_lull_acted = true
		InputService.trigger(&"action")
		actions += 1


func _steer(pos: Vector2, target: Vector2, blocked: Array) -> void:
	_repath -= DT
	if _repath <= 0.0 or target.distance_to(_goal) > 0.01:
		_path = _bfs(pos, target, blocked)
		_goal = target
		_repath = 0.25
	while _path.size() > 1 and pos.distance_to(_path[0]) < 0.3:
		_path.pop_front()
	var aim: Vector2 = _path[0] if _path.size() > 1 else target
	var d := aim - pos
	if d.length() < 0.02:
		return
	var s := IsoGrid.grid_vec_to_screen(d.x, d.y).normalized().rotated(-_turn)
	_last_press = s
	InputService.inject_move(s.x, s.y, false)


func _passable(map: WorldMapModel, i: int, j: int, blocked: Array) -> bool:
	if i < 0 or j < 0 or i >= map.width or j >= map.height or map.is_blocked_tile(i, j):
		return false
	var p := map.prop_at(i, j)
	if p != null and p.solid:
		return false
	var c := Vector2(i + 0.5, j + 0.5)
	for r: Rect2 in blocked:
		if r.grow(0.3).has_point(c):
			return false
	return true


## Tile centres from `from` to `to` (8-connected, no corner cutting), ending at `to` exactly.
func _bfs(from: Vector2, to: Vector2, blocked: Array) -> Array:
	var map := scene.world.map
	var start := Vector2i(int(floor(from.x)), int(floor(from.y)))
	var goal := Vector2i(int(floor(to.x)), int(floor(to.y)))
	var prev := {start: start}
	var queue: Array[Vector2i] = [start]
	var dirs := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)]
	while not queue.is_empty():
		var c: Vector2i = queue.pop_front()
		if c == goal:
			break
		for d: Vector2i in dirs:
			var n: Vector2i = c + d
			if prev.has(n) or not _passable(map, n.x, n.y, blocked):
				continue
			if d.x != 0 and d.y != 0 and (not _passable(map, c.x + d.x, c.y, blocked) or not _passable(map, c.x, c.y + d.y, blocked)):
				continue
			prev[n] = c
			queue.append(n)
	if not prev.has(goal):
		return [to]
	var out: Array = [to]
	var c: Vector2i = prev[goal]
	while c != start:
		out.push_front(Vector2(c.x + 0.5, c.y + 0.5))
		c = prev[c]
	return out
