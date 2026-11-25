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
		for k in views.size():
			if String((views[k] as Dictionary)["locked"]) == "":
				idx = k
				break
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
	if combat != null and combat.active() and not combat.won():
		_fight(pos)
		return
	InputService.guard_hold_injected = false
	if step.rule == "lull":
		_lull(step, pos)
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
	if scene.ctx.armed():
		var open := nearest.foe.stun > 0.0 or nearest.foe.windup > 0.0
		InputService.guard_hold_injected = threat and not (open and nd <= CB.SWORD_RANGE)
		if open and nd <= CB.SWORD_RANGE and t >= _next_action:
			_next_action = t + CB.SWORD_COOLDOWN + 0.03
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
		_next_stroke = 0.0
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
		if absf(g.time + DT - g.beat_at(k)) <= 0.04:
			_pressed_beats[k] = true
			InputService.trigger(&"action")
			actions += 1
		break


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
	var s := IsoGrid.grid_vec_to_screen(d.x, d.y).normalized()
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
