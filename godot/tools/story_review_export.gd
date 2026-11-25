extends Node
## Owner narrative review (correction 31): writes, for each scene of a chapter, its metadata and
## every player-visible line in play order — speakers, narration, cards, objectives and their lines,
## choices with costs, locks, effects and branches, remembered lines, persistent effects — read from
## the story Resources (the narrative authority). Development only (tools/ is not exported).
##   godot --headless --path godot res://tools/story_review_export.tscn -- --out <dir> [--chapter 1]
## Writes <dir>/<id>_transcript.md per scene and <dir>/chapter_<n>.md (intro, cast note, aside).

var cast: StoryCast


func _ready() -> void:
	var out := ""
	var number := 1
	var args := OS.get_cmdline_user_args()
	for k in args.size():
		if args[k] == "--out" and k + 1 < args.size():
			out = args[k + 1]
		elif args[k] == "--chapter" and k + 1 < args.size():
			number = int(args[k + 1])
	if out == "":
		printerr("story_review_export: --out <dir> is required")
		get_tree().quit(1)
		return
	DirAccess.make_dir_recursive_absolute(out)
	cast = load("res://data/story/cast.tres")
	var ch := StoryLibrary.chapter(number)
	if ch == null:
		printerr("story_review_export: no chapter %d" % number)
		get_tree().quit(1)
		return
	_write(out.path_join("chapter_%d.md" % number), _chapter(ch))
	for sc: StorySceneData in ch.scenes:
		_write(out.path_join("%s_transcript.md" % sc.id), _scene(sc))
	print("story_review_export: chapter %d, %d scene(s) -> %s" % [number, ch.scenes.size(), out])
	get_tree().quit(0)


func _write(path: String, text: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(text)
	f.close()


func _chapter(ch: StoryChapterData) -> String:
	var l := PackedStringArray()
	l.append("| Field | Value |")
	l.append("|---|---|")
	for row: Array in [["Level", str(ch.number)], ["Title", ch.title], ["Menu title", ch.menu_title], ["Music", ch.music],
			["Content version", str(ch.content_version)], ["Review status", ch.review_status], ["Cast note (tools only)", ch.cast_note]]:
		l.append("| %s | %s |" % [row[0], _cell(String(row[1]))])
	l.append("")
	l.append("**Level card (intro; not shown before 1.0 in this build, D-22/OQ-02):** %s" % ch.intro)
	l.append("")
	l.append("**The Professor's Level 1 aside (after 1.5 and the Supervillained snap):** %s" % ch.professor_aside)
	l.append("")
	l.append("**Review notes:**")
	for n in ch.review_notes:
		l.append("- %s" % n)
	return "\n".join(l) + "\n"


func _scene(sc: StorySceneData) -> String:
	var l := PackedStringArray()
	l.append("| Field | Value |")
	l.append("|---|---|")
	var names := Array(sc.cast).map(func(s: String) -> String: return "%s (`%s`)" % [cast.display_name(s), s])
	for row: Array in [["ID", sc.id], ["Title (draft title)", "%s (%s)" % [sc.title, sc.old_title]], ["Level", str(sc.level)], ["Map / music", "%s / %s" % [sc.map, sc.music]],
			["Cast", ", ".join(names)], ["Reality", "yes" if sc.reality else "no (dream)"], ["Entry conditions", JSON.stringify(sc.entry_conditions)],
			["Persistent effects (declared)", ", ".join(sc.persistent_effects)], ["Completion", JSON.stringify(sc.completion)],
			["Historical / place tags", ", ".join(sc.historical_tags)], ["Source references", "; ".join(sc.source_refs)],
			["Content version", str(sc.content_version)], ["Review status", sc.review_status], ["Technical status", sc.technical_status]]:
		l.append("| %s | %s |" % [row[0], _cell(String(row[1]))])
	l.append("")
	l.append("**Scene card (summary):** %s" % sc.summary)
	l.append("")
	l.append("**Review notes in the Resource:**")
	for n in sc.review_notes:
		l.append("- %s" % n)
	l.append("")
	l.append("### Every player-visible line, in play order")
	l.append("")
	l.append("Speech is **SPEAKER:** line; narration is *NARRATION:*; stage directions are in [brackets] (not shown as text).")
	l.append("")
	_steps(sc.steps, l, "")
	return "\n".join(l) + "\n"


func _steps(steps: Array, l: PackedStringArray, pad: String) -> void:
	for s: StoryStep in steps:
		_step(s, l, pad)


func _step(s: StoryStep, l: PackedStringArray, pad: String) -> void:
	var b := pad + "- "
	if s is StageStep:
		var st := s as StageStep
		var who := st.actors.map(func(a: StoryActorSpec) -> String: return "%s at %s" % [cast.display_name(a.role) if cast.has_speaker(a.role) else a.name, a.at if a.at != "" else str(a.point)])
		l.append(b + "[stage: %s; Zampanò at %s%s]" % [st.map, st.player_at if st.player_at != "" else str(st.player_point), ("; " + ", ".join(who)) if not who.is_empty() else ""])
	elif s is ActorStep:
		var a := s as ActorStep
		l.append(b + "[%s: %s%s]" % [a.actor, a.action, (" " + (a.at if a.at != "" else str(a.point))) if ["spawn", "goto", "place"].has(a.action) else ""])
	elif s is MoveStep:
		var m := s as MoveStep
		l.append(b + "[Zampanò walks to %s]" % (m.to_marker if m.to_marker != "" else str(m.to_point)))
	elif s is NarrationStep:
		l.append(b + "*NARRATION:* %s" % (s as NarrationStep).text)
	elif s is DialogueStep:
		var d := s as DialogueStep
		var extra := ""
		if d.remembered:
			extra += " — *remembered line (written in the book)*"
		if not d.effects.is_empty():
			extra += " — effects: %s" % _fx(d.effects)
		l.append(b + "**%s:** %s%s" % [cast.display_name(d.speaker), d.text, extra])
	elif s is ChoiceStep:
		var c := s as ChoiceStep
		l.append(b + "**CHOICE** (%s asks%s): %s" % [cast.display_name(c.speaker), ", asked again until every option is taken" if c.once_each else "", c.prompt])
		if c.prompt_again != "":
			l.append(pad + "  - *asked again as:* %s" % c.prompt_again)
		for o: StoryChoiceOption in c.options:
			var notes := PackedStringArray()
			if o.cost > 0:
				notes.append("costs %d COMMOZIONE (locked below that)" % o.cost)
			if o.locked_text != "":
				notes.append("always locked: \"%s\"" % o.locked_text)
			if not o.effects.is_empty():
				notes.append("effects: %s" % _fx(o.effects))
			l.append(pad + "  - option **\"%s\"**%s" % [o.label, (" — " + "; ".join(notes)) if not notes.is_empty() else ""])
			if o.said != "" and not o.silent:
				l.append(pad + "    - **%s:** %s" % [cast.display_name("zampano"), o.said])
			_steps(o.then_steps, l, pad + "    ")
	elif s is ObjectiveStep:
		var o := s as ObjectiveStep
		l.append(b + "**OBJECTIVE** (%s%s): %s" % [o.objective_kind, ", no running" if o.no_run else "", o.objective])
		if o.goal_label != "":
			l.append(pad + "  - goal: %s" % o.goal_label)
		if o.action_label != "":
			l.append(pad + "  - its own action (J/X, Space, the ACTION button): **%s** — \"%s\"" % [o.action_label, o.action_text])
		for p: StoryPickup in o.pickups:
			l.append(pad + "  - pickup **%s**%s%s%s" % [p.label, (": \"%s\"" % p.text) if p.text != "" else "", (" — effects: %s" % _fx(p.effects)) if not p.effects.is_empty() else "", (" — carried as: %s" % p.carry_label) if p.carry_label != "" else ""])
		for k in o.leader_lines.size():
			l.append(pad + "  - %s at stop %d: \"%s\"" % [o.leader, k + 1, o.leader_lines[k]])
		for k: String in o.rule_lines:
			var v: Variant = o.rule_lines[k]
			var lines: Array = v if v is Array else [v]
			l.append(pad + "  - %s (%s): %s" % [o.rule, k, " / ".join(lines.map(func(x: Variant) -> String: return "\"%s\"" % x))])
		if o.hint != "":
			l.append(pad + "  - hint: \"%s\"" % o.hint)
	elif s is EffectStep:
		l.append(b + "[effects: %s]" % _fx((s as EffectStep).effects))
	elif s is CardStep:
		var c := s as CardStep
		l.append(b + "**CARD:** %s%s%s" % [c.big, " — " if c.big != "" and c.small != "" else "", c.small])
	elif s is WaitStep:
		l.append(b + "[pause %.1f s]" % (s as WaitStep).seconds)
	elif s is CueStep:
		var c := s as CueStep
		if c.float_text != "":
			l.append(b + "*floating line:* %s" % c.float_text)
		else:
			l.append(b + "[cue%s%s%s]" % [(" sound " + c.sound) if c.sound != "" else "", " flash" if c.flash else "", (" shake %.0f" % c.shake) if c.shake > 0.0 else ""])
	elif s is PropStep:
		var p := s as PropStep
		l.append(b + "[%s %s]%s" % [p.action, p.prop, (" *floating line:* " + p.float_text) if p.float_text != "" else ""])
	elif s is CarryStep:
		var c := s as CarryStep
		l.append(b + ("[carries: %s]" % c.label if c.label != "" else "[drops what he carries]"))
	elif s is CompleteStep:
		l.append(b + "[the scene's completion boundary: one save]")


func _fx(fx: Dictionary) -> String:
	var parts := PackedStringArray()
	for k: String in fx:
		var v: Variant = fx[k]
		if v is Dictionary:
			for f: String in v:
				parts.append("%s.%s = %s" % [k, f, JSON.stringify(v[f])])
		elif v is String:
			parts.append("%s \"%s\"" % [k, v])
		else:
			parts.append("%s %s" % [k, ("+" if float(v) > 0 else "") + str(v)])
	return ", ".join(parts)


func _cell(t: String) -> String:
	return t.replace("|", "/")
