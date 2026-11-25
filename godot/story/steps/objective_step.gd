class_name ObjectiveStep
extends StoryStep
## A walk objective (port of the parts of src/story/walk.ts and chapter helpers Level 1 uses):
## the player walks with the joystick until the goal is met.
##   reach  — get within `goal_radius` of the goal (marker or point);
##   collect — pick up every pickup (StoryPickup), then (if a goal is set) reach it;
##   follow — follow `leader` along `path` (it waits when he lags; `leader_lines` at each stop).
## Options: no running, the walk's own action (`action_label`, a bark/sniff that shows
## `action_text`; StoryActionRouter decides which input performs it and when a plain bark is
## performed instead), checkpoints, a timed hint, and one scene rule (STORY_REWRITE_SPEC.md §5.3): "visor" (1.1, the
## bucket slides down when he stops or barks), "jack_gate" (1.2, Jack blocks a gap: barks echo,
## pushes bump), "cut_off" (1.3, Jack cuts off the direct path). Rule numbers are in
## `rule_params`; every line a rule shows is in `rule_lines`.

const KINDS := ["reach", "collect", "follow"]
const RULES := ["", "visor", "jack_gate", "cut_off"]
const RULE_SCRIPTS := {
	"visor": preload("res://story/rules/visor_rule.gd"),
	"jack_gate": preload("res://story/rules/jack_gate_rule.gd"),
	"cut_off": preload("res://story/rules/cut_off_rule.gd"),
}
const S := GameConfig.Story
## Spot rings: goals, pickups (presentation).
const GOAL_COLOR := Color("#4dff5a")
const PICKUP_COLOR := Color("#3ff0ff")
## Lecture scraps and the leader's lines (src/campaign/chapters/ch1.ts colour).
const SCRAP_COLOR := Color("#f0d8a0")

@export var objective := ""
@export var objective_kind := "reach"
@export var goal_marker := ""
@export var goal_point := Vector2.ZERO
@export var goal_label := ""
## 0 = GameConfig.Story.GOAL_RADIUS.
@export var goal_radius := 0.0
## StoryPickup Resources.
@export var pickups: Array = []
@export var no_run := false
## The action button's label ("" = no action button) and the line shown when pressed.
@export var action_label := ""
@export var action_text := ""
## Sound of the action ("bark" also plays his bark animation).
@export var action_sound := ""
@export var checkpoints: PackedStringArray = []
## follow: the actor handle, its path (marker ids), speed and one line per stop.
@export var leader := ""
@export var path: PackedStringArray = []
@export var leader_speed := 0.0
@export var leader_lines: PackedStringArray = []
## follow: seconds the leader may walk one leg (waiting for the player not counted) before the
## scene stops with an explicit error (validated positive: a blocked leader never waits forever).
@export var leader_leg_timeout := 0.0
@export var rule := ""
@export var rule_params: Dictionary = {}
@export var rule_lines: Dictionary = {}
## A notice shown once after `hint_after` seconds ("" = none).
@export var hint := ""
@export var hint_after := 0.6


func kind() -> String:
	return "objective"


func texts() -> PackedStringArray:
	var out := PackedStringArray()
	for t in [objective, goal_label, action_label, action_text, hint]:
		if t != "":
			out.append(t)
	for p: StoryPickup in pickups:
		out.append(p.label)
		if p.text != "":
			out.append(p.text)
		if p.carry_label != "":
			out.append(p.carry_label)
	for l in leader_lines:
		out.append(l)
	for k: String in rule_lines:
		var v: Variant = rule_lines[k]
		if v is Array or v is PackedStringArray:
			for t: String in v:
				out.append(t)
		else:
			out.append(String(v))
	return out


func marker_refs() -> PackedStringArray:
	var out := PackedStringArray()
	if goal_marker != "":
		out.append(goal_marker)
	for p: StoryPickup in pickups:
		if p.at != "":
			out.append(p.at)
	out.append_array(checkpoints)
	out.append_array(path)
	for h: Dictionary in rule_params.get("heads", []):
		out.append(String(h.get("at", "")))
	if rule_params.has("blocker_home"):
		out.append(String(rule_params["blocker_home"]))
	return out


func effect_sets() -> Array:
	var out: Array = []
	for p: StoryPickup in pickups:
		if not p.effects.is_empty():
			out.append(p.effects)
	return out


func sounds() -> PackedStringArray:
	var out := PackedStringArray()
	if action_sound != "":
		out.append(action_sound)
	for p: StoryPickup in pickups:
		if p.sound != "":
			out.append(p.sound)
	return out


func sprites() -> PackedStringArray:
	var out := PackedStringArray()
	for p: StoryPickup in pickups:
		if p.sprite != "":
			out.append(p.sprite)
	return out


func roles() -> PackedStringArray:
	var out := PackedStringArray()
	for h: Dictionary in rule_params.get("heads", []):
		out.append(String(h.get("role", "")))
	return out


func actor_defs() -> PackedStringArray:
	var out := PackedStringArray()
	for h: Dictionary in rule_params.get("heads", []):
		out.append(String(h.get("name", "")))
	return out


func actor_refs() -> PackedStringArray:
	var out := PackedStringArray()
	if leader != "":
		out.append(leader)
	if rule_params.has("blocker"):
		out.append(String(rule_params["blocker"]))
	return out


func check(errors: PackedStringArray) -> void:
	_need(errors, objective.strip_edges() != "", "objective %s without its objective line" % id)
	_need(errors, KINDS.has(objective_kind), "objective %s: bad kind '%s'" % [id, objective_kind])
	_need(errors, RULES.has(rule), "objective %s: unknown rule '%s'" % [id, rule])
	match objective_kind:
		"reach":
			_need(errors, goal_marker != "" or goal_point != Vector2.ZERO, "objective %s: reach without a goal" % id)
		"collect":
			_need(errors, not pickups.is_empty(), "objective %s: collect without pickups" % id)
		"follow":
			_need(errors, leader != "" and not path.is_empty() and leader_speed > 0.0, "objective %s: follow needs a leader, a path and a speed" % id)
			_need(errors, leader_leg_timeout > 0.0, "objective %s: follow needs a positive leader_leg_timeout" % id)
	for p: Variant in pickups:
		if not p is StoryPickup:
			errors.append("objective %s: a pickup is not a StoryPickup" % id)
			continue
		var pk: StoryPickup = p
		_need(errors, pk.label.strip_edges() != "", "objective %s: pickup without a label" % id)
		_need(errors, pk.at != "" or pk.point != Vector2.ZERO, "objective %s: pickup %s without a place" % [id, pk.label])
		_need(errors, ["shard", "spot"].has(pk.kind), "objective %s: pickup %s bad kind" % [id, pk.label])
	_need(errors, action_label == "" or action_text != "" or rule != "", "objective %s: action without its text" % id)
	match rule:
		"jack_gate":
			for k in ["blocker", "gap", "echo_open", "heads_at", "hint_bumps", "recover_bumps", "range", "creak_point"]:
				_need(errors, rule_params.has(k), "objective %s: jack_gate needs rule_params.%s" % [id, k])
			for k in ["echo", "nope", "hint", "creak"]:
				_need(errors, rule_lines.has(k), "objective %s: jack_gate needs rule_lines.%s" % [id, k])
			_need(errors, (rule_lines.get("echo", []) as Array).size() >= int(rule_params.get("echo_open", 0)), "objective %s: jack_gate needs one echo line per bark" % id)
		"cut_off":
			for k in ["blocker", "gap", "block_point", "lane_y", "joke_every", "joke_y"]:
				_need(errors, rule_params.has(k), "objective %s: cut_off needs rule_params.%s" % [id, k])
			for k in ["cut", "notice", "jokes"]:
				_need(errors, rule_lines.has(k), "objective %s: cut_off needs rule_lines.%s" % [id, k])


# --- Execution ----------------------------------------------------------------------------------

func begin(ctx: StoryContext, st: Dictionary) -> void:
	st["t"] = 0.0
	st["hinted"] = false
	st["goal"] = null
	if goal_marker != "" or goal_point != Vector2.ZERO:
		st["goal"] = ctx.place(goal_marker, goal_point)
		if ctx.error != "":
			return
	st["radius"] = goal_radius if goal_radius > 0.0 else S.GOAL_RADIUS
	st["picked"] = []
	st["spots"] = {}
	for p: StoryPickup in pickups:
		var at := ctx.place(p.at, p.point)
		if ctx.error != "":
			return
		var handle := ""
		if p.sprite != "":
			handle = "pickup_%s_%s" % [id, p.id]
			ctx.scene.place_prop(handle, p.sprite, at, Color.WHITE)
		st["spots"][p.id] = {"marker": ctx.scene.add_marker(at, S.PICKUP_RADIUS, PICKUP_COLOR), "prop": handle, "at": at}
	if st["goal"] != null:
		st["goal_node"] = ctx.scene.add_marker(st["goal"], st["radius"], GOAL_COLOR)
	ctx.hud.objective = objective
	ctx.no_run = no_run
	ctx.actions.configure(action_label, ctx.ui_text("story_mode_bark"))
	ctx.set_controls(true)
	if objective_kind == "follow":
		st["leg"] = 0
		st["leg_t"] = 0.0
		st["waiting"] = false
		var lead := ctx.actor(leader)
		if lead:
			lead.go_to(ctx.marker(path[0]), leader_speed)
	if rule != "":
		var r: ObjectiveRule = RULE_SCRIPTS[rule].new()
		st["rule"] = r
		r.begin(ctx, self, st)


func tick(ctx: StoryContext, st: Dictionary, dt: float) -> bool:
	st["t"] = float(st["t"]) + dt
	if hint != "" and not st["hinted"] and float(st["t"]) > hint_after:
		st["hinted"] = true
		ctx.notice(hint, PixelText.CYAN)
	var routed := ctx.actions.poll()
	if routed["switched"]:
		ctx.set_controls(true)
		if not InputService.using_touch:
			ctx.notice(ctx.ui_text("story_switch_notice") % ctx.actions.label(), PixelText.CYAN)
	for mode: String in routed["perform"]:
		_perform(ctx, st, mode)
	var pp := ctx.player_pos()
	for p: StoryPickup in pickups:
		if (st["picked"] as Array).has(p.id):
			continue
		var spot: Dictionary = st["spots"][p.id]
		if pp.distance_to(spot["at"]) <= S.PICKUP_RADIUS:
			(st["picked"] as Array).append(p.id)
			_clear_spot(ctx, spot)
			ctx.play_sound(p.sound)
			if p.text != "":
				ctx.notice(p.text, SCRAP_COLOR)
			if not p.effects.is_empty():
				ctx.apply(p.effects)
			if p.carry_label != "":
				ctx.carry(p.carry_label, p.sprite)
	if st.has("rule") and (st["rule"] as ObjectiveRule).tick(ctx, self, st, dt):
		return true
	if ctx.error != "":
		return true
	if objective_kind == "follow":
		return _tick_follow(ctx, st, dt)
	if (st["picked"] as Array).size() < pickups.size():
		return false
	if st["goal"] == null:
		return true
	return pp.distance_to(st["goal"]) <= float(st["radius"])


## Performs one action mode (StoryActionRouter): the walk's own action, or a plain bark (which
## the scene rule hears too, RD-28). "sword"/"shield" are never offered before M6.
func _perform(ctx: StoryContext, st: Dictionary, mode: String) -> void:
	(ctx.metrics["actions"] as Array).append(mode)
	if mode == "scene" and action_label != "":
		ctx.play_sound(action_sound)
		if action_sound == "bark":
			ctx.player.start_action("bark", S.BARK_ANIM)
		if action_text != "":
			ctx.say_float(action_text, ctx.player_pos(), Color.WHITE)
		if st.has("rule"):
			(st["rule"] as ObjectiveRule).on_action(ctx, self, st)
	elif mode == "bark" or mode == "scene":
		ctx.play_sound("bark")
		ctx.player.start_action("bark", S.BARK_ANIM)
		ctx.say_float(ctx.ui_text("story_bark_text"), ctx.player_pos(), Color.WHITE)
		if st.has("rule"):
			(st["rule"] as ObjectiveRule).on_bark(ctx, self, st)


## The leader walks the path, waiting while he lags; at each stop one line; done once he has caught
## up at the last stop. A leg that takes longer than `leader_leg_timeout` of walking stops the
## scene with an explicit error.
func _tick_follow(ctx: StoryContext, st: Dictionary, dt: float) -> bool:
	var lead := ctx.actor(leader)
	if lead == null:
		return true
	var lag := Vector2(lead.gx, lead.gy).distance_to(ctx.player_pos())
	var leg := int(st["leg"])
	if leg >= path.size():
		return lag <= S.LEAD_ARRIVE
	var wp := ctx.marker(path[leg])
	if lag > S.LEAD_WAIT_DISTANCE:
		if not st["waiting"]:
			st["waiting"] = true
			lead.set_idle()
			lead.face_point(ctx.player_pos())
		return false
	if st["waiting"]:
		st["waiting"] = false
		lead.go_to(wp, leader_speed)
	st["leg_t"] = float(st["leg_t"]) + dt
	if float(st["leg_t"]) > leader_leg_timeout:
		ctx.fail("leader '%s' did not reach stop %d (marker '%s') within %.1f s" % [leader, leg + 1, path[leg], leader_leg_timeout])
		return true
	if Vector2(lead.gx, lead.gy).distance_to(wp) < 0.1:
		if not leader_lines.is_empty():
			ctx.say_float(leader_lines[leg % leader_lines.size()], Vector2(lead.gx, lead.gy - 1.2), SCRAP_COLOR)
		st["leg"] = leg + 1
		st["leg_t"] = 0.0
		if leg + 1 < path.size():
			lead.go_to(ctx.marker(path[leg + 1]), leader_speed)
		else:
			lead.set_idle()
	return false


## Removes a pickup's ring and sprite once (a picked spot is already cleared).
func _clear_spot(ctx: StoryContext, spot: Dictionary) -> void:
	ctx.scene.remove_marker(spot["marker"])
	spot["marker"] = null
	if String(spot["prop"]) != "":
		ctx.scene.remove_prop(spot["prop"])
		spot["prop"] = ""


func end(ctx: StoryContext, st: Dictionary) -> void:
	if ctx.scene.world == null:
		return
	for spot: Dictionary in (st.get("spots", {}) as Dictionary).values():
		_clear_spot(ctx, spot)
	if st.has("goal_node"):
		ctx.scene.remove_marker(st["goal_node"])
		st["goal_node"] = null
	if st.has("rule"):
		(st["rule"] as ObjectiveRule).end(ctx, self, st)
	ctx.hud.objective = ""
	ctx.actions.configure("", ctx.ui_text("story_mode_bark"))
	ctx.no_run = false
	ctx.set_controls(false)
