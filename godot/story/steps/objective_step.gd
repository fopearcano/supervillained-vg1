class_name ObjectiveStep
extends StoryStep
## A walk objective (port of the parts of src/story/walk.ts and chapter helpers Level 1 uses):
## the player walks with the joystick until the goal is met.
##   reach  — get within `goal_radius` of the goal (marker or point);
##   collect — pick up every pickup (StoryPickup), then (if a goal is set) reach it;
##   follow — follow `leader` along `path` (it waits when he lags; `leader_lines` at each stop).
## Options: no running, an action button (`action_label`, a bark/sniff that shows `action_text`),
## checkpoints, a timed hint, and one scene rule (STORY_REWRITE_SPEC.md §5.3): "visor" (1.1, the
## bucket slides down when he stops or barks), "jack_gate" (1.2, Jack blocks a gap: barks echo,
## pushes bump), "cut_off" (1.3, Jack cuts off the direct path). Rule numbers are in
## `rule_params`; every line a rule shows is in `rule_lines`.

const KINDS := ["reach", "collect", "follow"]
const RULES := ["", "visor", "jack_gate", "cut_off"]

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
@export var checkpoints: PackedStringArray = []
## follow: the actor handle, its path (marker ids), speed and one line per stop.
@export var leader := ""
@export var path: PackedStringArray = []
@export var leader_speed := 0.0
@export var leader_lines: PackedStringArray = []
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
