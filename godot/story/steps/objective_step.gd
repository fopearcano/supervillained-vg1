class_name ObjectiveStep
extends StoryStep
## A walk objective (port of src/story/walk.ts and the chapter helpers): the player walks with the
## joystick until the goal is met.
##   reach   — get within `goal_radius` of the goal (marker or point);
##   collect — pick up every pickup (StoryPickup), then (if a goal is set) reach it;
##   follow  — follow `leader` along `path` (it waits when he lags; `leader_lines` at each stop);
##   fight   — rout the `fight` foes (CombatController; also any pickups and goal);
##   rule    — the scene rule decides (a lull's count, listening long enough, an act at a spot);
##   survive — last `survive` seconds (a rule may start the clock again: 5.2's steady ladder; a fight
##             may run meanwhile: 7.2's hold-ground).
## Options: no running, a walking-speed modifier (heavy armour), the walk's own action
## (`action_label`, a bark/sniff/look that shows `action_text`; StoryActionRouter decides which input
## performs it and when a plain bark, the sword or the shield is performed instead), checkpoints, a
## timed hint, a fight (`fight`: knocked down, he gets up and the fight starts again, nothing kept),
## stealth (`caught`: a full sight cone or a hostile's touch shows the caught card and sends him back
## to the start or the last checkpoint), and one scene rule (STORY_REWRITE_SPEC.md §5.3): "visor"
## (1.1, the bucket), "jack_gate" (1.2, Jack blocks a gap: barks echo, pushes bump), "cut_off"
## (1.3, Jack cuts off the direct path), "receding" (2.1, the gate steps back; the helmet slips),
## "lull" (2.2 and 3.3, act in the pauses of a voice), "listen" (3.4, stay close to overhear),
## "sounder" (3.1's harbour bell; 3.4's goal found by ear: `hidden` takes its ring away).
## Rule numbers are in `rule_params`; every line a rule shows is in `rule_lines`.

const KINDS := ["reach", "collect", "follow", "fight", "rule", "survive"]
const RULES := ["", "visor", "jack_gate", "cut_off", "receding", "lull", "listen", "sounder", "steady", "act_at", "shoulder", "fire", "no_running", "waking", "companions"]
## Rules that complete a "rule" objective.
const COMPLETING_RULES := ["lull", "listen", "act_at", "shoulder"]
const RULE_SCRIPTS := {
	"visor": preload("res://story/rules/visor_rule.gd"),
	"jack_gate": preload("res://story/rules/jack_gate_rule.gd"),
	"cut_off": preload("res://story/rules/cut_off_rule.gd"),
	"receding": preload("res://story/rules/receding_rule.gd"),
	"lull": preload("res://story/rules/lull_rule.gd"),
	"listen": preload("res://story/rules/listen_rule.gd"),
	"sounder": preload("res://story/rules/sounder_rule.gd"),
	"steady": preload("res://story/rules/steady_rule.gd"),
	"act_at": preload("res://story/rules/act_at_rule.gd"),
	"shoulder": preload("res://story/rules/shoulder_rule.gd"),
	"fire": preload("res://story/rules/fire_rule.gd"),
	"no_running": preload("res://story/rules/no_running_rule.gd"),
	"waking": preload("res://story/rules/waking_rule.gd"),
	"companions": preload("res://story/rules/companions_rule.gd"),
}
const FIGHT_KEYS := ["foes", "hp", "speed", "radius", "leash", "health", "parry", "rout", "sword_cost"]
const PICKUP_KINDS := ["shard", "spot", "coin", "marvel"]
const S := GameConfig.Story
const CB := GameConfig.Combat
## Spot rings: goals, pickups (presentation).
const GOAL_COLOR := Color("#4dff5a")
const PICKUP_COLOR := Color("#3ff0ff")
const MARVEL_COLOR := Color("#ffe23a")
## Lecture scraps and the leader's lines (src/campaign/chapters/ch1.ts colour).
const SCRAP_COLOR := Color("#f0d8a0")
const CARD_RED := Color("#ff2a3a")

@export var objective := ""
@export var objective_kind := "reach"
@export var goal_marker := ""
@export var goal_point := Vector2.ZERO
@export var goal_label := ""
## 0 = GameConfig.Story.GOAL_RADIUS.
@export var goal_radius := 0.0
## StoryPickup Resources.
@export var pickups: Array = []
## The pickups are a trail: only the next one shows (its ring), the one after appears when it is
## picked (6.2's talk followed from tent to tent).
@export var in_order := false
@export var no_run := false
## Walking speed when not running (1 = normal; 2.3's heavy armour 0.8: only a charge feels grand).
@export var walk_speed_mul := 1.0
## The action button's label ("" = no action button) and the line shown when pressed.
@export var action_label := ""
@export var action_text := ""
## Sound of the action ("bark" also plays his bark animation).
@export var action_sound := ""
## Markers that become the restart point once passed (stealth).
@export var checkpoints: PackedStringArray = []
## follow: the actor handle, its path (marker ids), speed and one line per stop.
@export var leader := ""
@export var path: PackedStringArray = []
@export var leader_speed := 0.0
@export var leader_lines: PackedStringArray = []
## follow: seconds the leader may walk one leg (waiting for the player not counted) before the
## scene stops with an explicit error (validated positive: a blocked leader never waits forever).
@export var leader_leg_timeout := 0.0
## A fight (CombatController): {"foes": [handles], "hp", "speed", "radius", "leash", "health",
## "parry", "rout"}; the routed foes' lines are rule_lines["rout"].
@export var fight: Dictionary = {}
## survive: seconds to last (the walk's clock; a rule may restart it).
@export var survive := 0.0
## The KNOCKED DOWN card's second line ("" = the interface's default).
@export var knocked_text := ""
## Stealth: "" (none) or "restart"; the caught card's title.
@export var caught := ""
@export var caught_text := ""
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
	for t in [objective, goal_label, action_label, action_text, hint, knocked_text, caught_text]:
		if t != "":
			out.append(t)
	for p: StoryPickup in pickups:
		out.append(p.label)
		if p.text != "":
			out.append(p.text)
		for t in [p.seen_label, p.seen_text]:
			if t != "":
				out.append(t)
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
	for k in ["blocker_home", "stand", "point", "goal_marker", "at"]:
		if rule_params.has(k) and rule_params[k] is String and String(rule_params[k]) != "":
			out.append(String(rule_params[k]))
	return out


func effect_sets() -> Array:
	var out: Array = []
	for p: StoryPickup in pickups:
		if not p.effects.is_empty():
			out.append(p.effects)
	if fight.get("sword_cost") is Dictionary and not (fight["sword_cost"] as Dictionary).is_empty():
		out.append(fight["sword_cost"])
	if rule_params.get("good_effects") is Dictionary and not (rule_params["good_effects"] as Dictionary).is_empty():
		out.append(rule_params["good_effects"])
	if rule_params.get("silence_effects") is Dictionary and not (rule_params["silence_effects"] as Dictionary).is_empty():
		out.append(rule_params["silence_effects"])
	if rule_params.get("cost") is Dictionary:
		out.append({String(rule_params["cost"]["meter"]): -1})
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
	for k in ["blocker", "source", "actor", "leader", "rejoin_actor", "window_actor", "escort", "silence_actor"]:
		if rule_params.has(k):
			out.append(String(rule_params[k]))
	for h: String in fight.get("foes", []):
		out.append(h)
	for group: Array in rule_params.get("responders", []):
		for h: String in group:
			out.append(h)
	if rule_params.get("spread") is Array:
		for h: String in rule_params["spread"]:
			out.append(h)
	for pair: Array in rule_params.get("companions", []):
		out.append(String(pair[0]))
	return out


func check(errors: PackedStringArray) -> void:
	_need(errors, objective.strip_edges() != "", "objective %s without its objective line" % id)
	_need(errors, KINDS.has(objective_kind), "objective %s: bad kind '%s'" % [id, objective_kind])
	_need(errors, RULES.has(rule), "objective %s: unknown rule '%s'" % [id, rule])
	_need(errors, walk_speed_mul > 0.0 and walk_speed_mul <= 1.5, "objective %s: walk_speed_mul out of range" % id)
	_need(errors, ["", "restart"].has(caught), "objective %s: caught must be '' or 'restart'" % id)
	_need(errors, caught == "" or caught_text.strip_edges() != "", "objective %s: stealth without its caught card" % id)
	match objective_kind:
		"reach":
			_need(errors, goal_marker != "" or goal_point != Vector2.ZERO, "objective %s: reach without a goal" % id)
		"collect":
			_need(errors, not pickups.is_empty(), "objective %s: collect without pickups" % id)
		"follow":
			_need(errors, leader != "" and not path.is_empty() and leader_speed > 0.0, "objective %s: follow needs a leader, a path and a speed" % id)
			_need(errors, leader_leg_timeout > 0.0, "objective %s: follow needs a positive leader_leg_timeout" % id)
		"fight":
			_need(errors, not fight.is_empty(), "objective %s: fight without its foes" % id)
		"rule":
			_need(errors, COMPLETING_RULES.has(rule), "objective %s: a rule objective needs a rule that completes it (%s)" % [id, ", ".join(COMPLETING_RULES)])
		"survive":
			_need(errors, survive > 0.0, "objective %s: survive needs positive seconds" % id)
	if not fight.is_empty():
		for k: String in fight:
			_need(errors, FIGHT_KEYS.has(k), "objective %s: unknown fight key '%s'" % [id, k])
		_need(errors, not (fight.get("foes", []) as Array).is_empty(), "objective %s: a fight needs foes" % id)
		_need(errors, float(fight.get("hp", CB.FOE_HP)) > 0.0 and int(fight.get("health", CB.HEALTH)) > 0, "objective %s: fight hp and health must be positive" % id)
		_need(errors, not (rule_lines.get("rout", []) as Array).is_empty(), "objective %s: a fight needs rule_lines.rout" % id)
	for p: Variant in pickups:
		if not p is StoryPickup:
			errors.append("objective %s: a pickup is not a StoryPickup" % id)
			continue
		var pk: StoryPickup = p
		_need(errors, pk.label.strip_edges() != "", "objective %s: pickup without a label" % id)
		_need(errors, pk.at != "" or pk.point != Vector2.ZERO, "objective %s: pickup %s without a place" % [id, pk.label])
		_need(errors, PICKUP_KINDS.has(pk.kind), "objective %s: pickup %s bad kind" % [id, pk.label])
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
		"receding":
			for k in ["steps", "step", "within", "door_every", "door_offset"]:
				_need(errors, rule_params.has(k), "objective %s: receding needs rule_params.%s" % [id, k])
			for k in ["door", "recede", "slip"]:
				_need(errors, rule_lines.has(k), "objective %s: receding needs rule_lines.%s" % [id, k])
			_need(errors, goal_marker != "" or goal_point != Vector2.ZERO, "objective %s: receding needs a goal" % id)
		"lull":
			for k in ["source", "stand", "range", "need"]:
				_need(errors, rule_params.has(k), "objective %s: lull needs rule_params.%s" % [id, k])
			for k in ["noise", "noise_label", "drowned", "act_text"]:
				_need(errors, rule_lines.has(k), "objective %s: lull needs rule_lines.%s" % [id, k])
			_need(errors, int(rule_params.get("need", 0)) > 0, "objective %s: lull needs a positive count" % id)
			if rule_params.has("silence_after"):
				_need(errors, rule_params.has("silence_actor") and rule_lines.has("silence") and rule_params.has("silence_effects"),
					"objective %s: a lull that silence ends needs silence_actor, silence_effects and rule_lines.silence" % id)
			if rule_params.has("cost"):
				_need(errors, rule_lines.has("cost_ok") and rule_lines.has("cost_short"), "objective %s: a lull act with a cost needs rule_lines.cost_ok and cost_short" % id)
			_need(errors, action_label != "", "objective %s: lull needs its action" % id)
		"listen":
			for k in ["point", "radius", "seconds"]:
				_need(errors, rule_params.has(k), "objective %s: listen needs rule_params.%s" % [id, k])
			for k in ["close", "far", "fragments"]:
				_need(errors, rule_lines.has(k), "objective %s: listen needs rule_lines.%s" % [id, k])
			_need(errors, float(rule_params.get("seconds", 0.0)) > 0.0, "objective %s: listen needs positive seconds" % id)
		"steady":
			_need(errors, objective_kind == "survive", "objective %s: steady needs a survive objective" % id)
			for k in ["label", "wobble"]:
				_need(errors, rule_lines.has(k), "objective %s: steady needs rule_lines.%s" % [id, k])
		"shoulder":
			for k in ["leader", "from", "to", "band", "side", "lose", "gain", "speed", "pots_at", "rejoin_at", "rejoin_actor", "window_actor", "window_from"]:
				_need(errors, rule_params.has(k), "objective %s: shoulder needs rule_params.%s" % [id, k])
			for k in ["label", "ahead", "behind", "side", "pots", "rejoin", "window", "out_big", "out_small"]:
				_need(errors, rule_lines.has(k), "objective %s: shoulder needs rule_lines.%s" % [id, k])
		"fire":
			for k in ["from", "start_after", "spread_every", "per_tick", "breaths"]:
				_need(errors, rule_params.has(k), "objective %s: fire needs rule_params.%s" % [id, k])
			for k in ["fire_big", "fire_small", "hot", "label", "out_big", "out_small"]:
				_need(errors, rule_lines.has(k), "objective %s: fire needs rule_lines.%s" % [id, k])
			_need(errors, goal_marker != "" or goal_point != Vector2.ZERO, "objective %s: fire needs a goal" % id)
			_need(errors, not no_run, "objective %s: a fire walk lets him run" % id)
		"waking":
			for k in ["every", "angles", "settle_at", "knock_near", "knock_far", "knock_y", "knock_every", "smell", "jerusalem"]:
				_need(errors, rule_params.has(k), "objective %s: waking needs rule_params.%s" % [id, k])
			for k in ["scramble", "settle", "knock", "smell", "jerusalem", "jerusalem_moves"]:
				_need(errors, rule_lines.has(k), "objective %s: waking needs rule_lines.%s" % [id, k])
			_need(errors, goal_marker != "" or goal_point != Vector2.ZERO, "objective %s: waking needs a goal" % id)
		"companions":
			_need(errors, rule_params.has("companions") and rule_params.has("fall_in_x"), "objective %s: companions needs rule_params.companions and fall_in_x" % id)
			for k in ["wait", "fall_in"]:
				_need(errors, rule_lines.has(k), "objective %s: companions needs rule_lines.%s" % [id, k])
		"no_running":
			for k in ["out_big", "out_small"]:
				_need(errors, rule_lines.has(k), "objective %s: no_running needs rule_lines.%s" % [id, k])
			_need(errors, not no_run, "objective %s: no_running needs running possible (no_run off)" % id)
		"act_at":
			_need(errors, rule_params.has("radius") and action_label != "", "objective %s: act_at needs rule_params.radius and the walk's action" % id)
			_need(errors, goal_marker != "" or goal_point != Vector2.ZERO, "objective %s: act_at needs a goal" % id)
		"sounder":
			_need(errors, float(rule_params.get("every", 0.0)) > 0.0, "objective %s: sounder needs a positive interval" % id)
			_need(errors, rule_lines.has("sound"), "objective %s: sounder needs rule_lines.sound" % id)
			_need(errors, rule_params.has("at") or rule_params.has("actor") or goal_marker != "" or goal_point != Vector2.ZERO, "objective %s: sounder needs a place (actor, at, or the goal)" % id)


# --- Execution ----------------------------------------------------------------------------------

func begin(ctx: StoryContext, st: Dictionary) -> void:
	st["t"] = 0.0
	st["hinted"] = false
	st["goal"] = null
	st["start"] = ctx.player_pos()
	st["passed"] = []
	if goal_marker != "" or goal_point != Vector2.ZERO:
		st["goal"] = ctx.place(goal_marker, goal_point)
		if ctx.error != "":
			return
	st["radius"] = goal_radius if goal_radius > 0.0 else S.GOAL_RADIUS
	st["picked"] = []
	st["spots"] = {}
	for p: StoryPickup in pickups:
		_show_spot(ctx, st, p)
		if ctx.error != "" or in_order:
			break
	if st["goal"] != null:
		st["goal_node"] = ctx.scene.add_marker(st["goal"], st["radius"], GOAL_COLOR)
	ctx.hud.objective = objective
	ctx.no_run = no_run
	ctx.walk_speed_mul = walk_speed_mul
	# No edge pressed before the walk (in a line, a card) is performed in it.
	for a: StringName in [&"action", &"pee", &"bark", &"switch", &"strike", &"guard"]:
		InputService.consume(a)
	ctx.combat = CombatController.new()
	var def := {}
	if not fight.is_empty():
		def = fight.duplicate(true)
		def["rout_lines"] = rule_lines.get("rout", [])
		if rule_lines.has("sword_cost"):
			def["sword_cost_text"] = String(rule_lines["sword_cost"])
	ctx.combat.start(ctx, def)
	if ctx.error != "":
		return
	_configure_actions(ctx)
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


## The action modes of this walk: its own action, the plain bark, and the arms when he is a knight.
func _configure_actions(ctx: StoryContext) -> void:
	ctx.actions.configure(action_label, ctx.ui_text("story_mode_bark"), ctx.armed(), ctx.ui_text("story_mode_sword"), ctx.ui_text("story_mode_shield"))


func tick(ctx: StoryContext, st: Dictionary, dt: float) -> bool:
	if st.has("interrupt"):
		return _tick_interrupt(ctx, st, dt)
	st["t"] = float(st["t"]) + dt
	if hint != "" and not st["hinted"] and float(st["t"]) > hint_after:
		st["hinted"] = true
		ctx.notice(hint, PixelText.CYAN)
	var routed := ctx.actions.poll()
	if routed["switched"]:
		# The mode changed: the click cue, the button's new label (and, on keys, a notice).
		ctx.play_sound("click")
		ctx.set_controls(true)
		if not InputService.using_touch:
			ctx.notice(ctx.ui_text("story_switch_notice") % ctx.actions.label(), PixelText.CYAN)
	for mode: String in routed["perform"]:
		_perform(ctx, st, mode)
	# The shield stays up while I is held, or while the selected SHIELD mode's action (J/X, the round
	# button) is held; a tap is the pulse.
	ctx.combat.update(dt, InputService.guard_held or (ctx.actions.mode == "shield" and InputService.action_held))
	if ctx.combat.knocked:
		(ctx.metrics["knockdowns"] as Array).append(id)
		_interrupt(ctx, st, "knocked", ctx.ui_text("story_knocked"), knocked_text if knocked_text != "" else ctx.ui_text("story_knocked_small"), CB.KNOCKED_CARD)
		return false
	var pp := ctx.player_pos()
	for p: StoryPickup in pickups:
		if (st["picked"] as Array).has(p.id):
			continue
		if not (st["spots"] as Dictionary).has(p.id):
			continue
		var spot: Dictionary = st["spots"][p.id]
		if pp.distance_to(spot["at"]) <= S.PICKUP_RADIUS:
			(st["picked"] as Array).append(p.id)
			_clear_spot(ctx, spot)
			ctx.play_sound(p.sound)
			var said := p.shown_text(ctx.state)
			if said != "":
				ctx.notice(said, MARVEL_COLOR if p.kind == "marvel" else SCRAP_COLOR)
			if not p.effects.is_empty():
				ctx.apply(p.effects)
			if p.carry_label != "":
				ctx.carry(p.carry_label, p.sprite)
			if in_order:
				for q: StoryPickup in pickups:
					if not (st["picked"] as Array).has(q.id) and not (st["spots"] as Dictionary).has(q.id):
						_show_spot(ctx, st, q)
						break
	for c in checkpoints:
		if (st["passed"] as Array).has(c):
			continue
		var at := ctx.marker(c)
		if pp.distance_to(at) <= S.CHECKPOINT_RADIUS:
			(st["passed"] as Array).append(c)
			st["start"] = at
			ctx.notice(ctx.ui_text("story_checkpoint"), PixelText.GREEN)
			ctx.play_sound("star")
	if caught != "" and _detected(ctx, dt):
		(ctx.metrics["caught"] as Array).append(id)
		ctx.play_sound("hurt")
		ctx.shake(3.0)
		_interrupt(ctx, st, "caught", caught_text, ctx.ui_text("story_caught_small"), S.CAUGHT_CARD)
		return false
	if st.has("rule") and (st["rule"] as ObjectiveRule).tick(ctx, self, st, dt):
		return true
	if st.has("rule_restart"):
		var rr: Dictionary = st["rule_restart"]
		_interrupt(ctx, st, "rule", String(rr["big"]), String(rr["small"]), 2.0)
		return false
	if ctx.error != "":
		return true
	if objective_kind == "follow":
		return _tick_follow(ctx, st, dt)
	if objective_kind == "rule":
		return false
	if objective_kind == "survive":
		return float(st["t"]) >= survive
	if not ctx.combat.won():
		return false
	if (st["picked"] as Array).size() < pickups.size():
		return false
	if st["goal"] == null:
		return true
	return pp.distance_to(st["goal"]) <= float(st["radius"])


## Performs one action mode (StoryActionRouter): the walk's own action, a plain bark (which the
## scene rule hears too, RD-28; in a fight it also pushes the foes back), the sword or the shield
## (CombatController: only with the knight's capability).
func _perform(ctx: StoryContext, st: Dictionary, mode: String) -> void:
	(ctx.metrics["actions"] as Array).append(mode)
	match mode:
		"sword":
			ctx.combat.strike()
			return
		"shield":
			ctx.combat.raise_shield()
			return
	if mode == "scene" and action_label != "":
		ctx.play_sound(action_sound)
		if action_sound == "bark":
			ctx.player.start_action("bark", S.BARK_ANIM)
		if action_text != "" and rule != "lull":
			ctx.say_float(action_text, ctx.player_pos(), Color.WHITE)
		if st.has("rule"):
			(st["rule"] as ObjectiveRule).on_action(ctx, self, st)
	elif mode == "bark" or mode == "scene":
		if not ctx.combat.bark():
			return
		if st.has("rule"):
			(st["rule"] as ObjectiveRule).on_bark(ctx, self, st)


## Seen (a sight cone filled) or touched by a hostile who is not fighting him this tick.
func _detected(ctx: StoryContext, dt: float) -> bool:
	var hit := false
	var p := ctx.player_pos()
	for a: StoryActor in ctx.scene.actors.values():
		if a.hostile and a.foe == null and Vector2(a.gx, a.gy).distance_to(p) < S.HOSTILE_TOUCH:
			hit = true
		if a.sight_range <= 0.0:
			continue
		var seen := StorySight.can_see(ctx.world.map, a, p.x, p.y, ctx.hides)
		a.alert = clampf(a.alert + (dt * S.ALERT_GAIN if seen else -dt * S.ALERT_DECAY), 0.0, 1.0)
		if a.alert >= 1.0:
			hit = true
	return hit


## A knockdown or a capture: the card, controls off; then back to the start (or last checkpoint).
func _interrupt(ctx: StoryContext, st: Dictionary, what: String, big: String, small: String, seconds: float) -> void:
	st["interrupt"] = {"kind": what, "t": seconds}
	ctx.set_controls(false)
	ctx.hud.show_card(big, small, CARD_RED, 0.55, false)


func _tick_interrupt(ctx: StoryContext, st: Dictionary, dt: float) -> bool:
	var it: Dictionary = st["interrupt"]
	it["t"] = float(it["t"]) - dt
	if float(it["t"]) > 0.0:
		return false
	ctx.hud.hide_card()
	st.erase("interrupt")
	var at: Vector2 = st["start"]
	var dog := ctx.player
	dog.set_grid_position(at.x, at.y)
	dog.vx = 0.0
	dog.vy = 0.0
	dog.knock_x = 0.0
	dog.knock_y = 0.0
	ctx.world.snap_camera()
	for a: StoryActor in ctx.scene.actors.values():
		a.alert = 0.0
	if String(it["kind"]) == "knocked":
		ctx.combat.reset()
		# A hold (survive) starts again after a knockdown.
		if objective_kind == "survive":
			st["t"] = 0.0
	if String(it["kind"]) == "rule":
		st.erase("rule_restart")
		(st["rule"] as ObjectiveRule).restart(ctx, self, st)
	for a: StringName in [&"action", &"pee", &"bark", &"switch", &"strike", &"guard"]:
		InputService.consume(a)
	ctx.set_controls(true)
	return false


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
		if not leader_lines.is_empty() and leader_lines[leg % leader_lines.size()] != "":
			ctx.say_float(leader_lines[leg % leader_lines.size()], Vector2(lead.gx, lead.gy - 1.2), SCRAP_COLOR)
		st["leg"] = leg + 1
		st["leg_t"] = 0.0
		if leg + 1 < path.size():
			lead.go_to(ctx.marker(path[leg + 1]), leader_speed)
		else:
			lead.set_idle()
	return false


## Places a pickup's ring (and its sprite).
func _show_spot(ctx: StoryContext, st: Dictionary, p: StoryPickup) -> void:
	var at := ctx.place(p.at, p.point)
	if ctx.error != "":
		return
	var handle := ""
	if p.sprite != "":
		handle = "pickup_%s_%s" % [id, p.id]
		ctx.scene.place_prop(handle, p.sprite, at, Color.WHITE)
	var color := MARVEL_COLOR if p.kind == "marvel" else PICKUP_COLOR
	st["spots"][p.id] = {"marker": ctx.scene.add_marker(at, S.PICKUP_RADIUS, color), "prop": handle, "at": at}


## Removes a pickup's ring and sprite once (a picked spot is already cleared).
func _clear_spot(ctx: StoryContext, spot: Dictionary) -> void:
	ctx.scene.remove_marker(spot["marker"])
	spot["marker"] = null
	if String(spot["prop"]) != "":
		ctx.scene.remove_prop(spot["prop"])
		spot["prop"] = ""


func end(ctx: StoryContext, st: Dictionary) -> void:
	if ctx.combat:
		ctx.combat.stop()
		ctx.combat = null
	ctx.walk_speed_mul = 1.0
	ctx.scramble_angle = 0.0
	if st.has("interrupt"):
		ctx.hud.hide_card()
		st.erase("interrupt")
	if ctx.scene.world == null:
		return
	for spot: Dictionary in (st.get("spots", {}) as Dictionary).values():
		_clear_spot(ctx, spot)
	if st.has("goal_node"):
		ctx.scene.remove_marker(st["goal_node"])
		st["goal_node"] = null
	if st.has("rule"):
		(st["rule"] as ObjectiveRule).end(ctx, self, st)
	for a: StoryActor in ctx.scene.actors.values():
		a.alert = 0.0
	ctx.hud.objective = ""
	ctx.hud.clear_mode()
	ctx.actions.configure("", ctx.ui_text("story_mode_bark"))
	ctx.no_run = false
	ctx.set_controls(false)
