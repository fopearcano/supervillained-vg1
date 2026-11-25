class_name StoryValidator
extends RefCounted
## Automated content validation of the story Resources (docs/porting/STORY_REWRITE_SPEC.md §6).
## Every problem is returned as a readable error naming the scene, the step and the field; a
## validator with errors means the content must not run. Checks:
## - stable IDs, levels and order against the frozen compatibility catalog (37 entries); display
##   titles against the generated StoryCatalog (which takes them from these Resources); every
##   chapter field of spec §5.2; unique step ids;
## - step types; speakers (StoryCast and the scene's cast); maps; markers on the stage each step
##   runs on; actors defined before use; cast roles with SpriteFrames; sprite, sound and music keys;
## - choices: reachable branches, no all-locked state;
## - effects: known meters, abilities, book keys and CampaignFlagSchema flags with valid values,
##   each declared in the scene's persistent_effects;
## - completion: exactly one final CompleteStep, and its required flags/abilities produced on every
##   branch; source and review metadata present;
## - execution scripts hold no player text (scan_scripts).

const STEP_TYPES := ["stage", "actor", "move", "narration", "dialogue", "choice", "objective", "effect", "card", "wait", "cue", "prop", "carry", "complete"]
const REVIEW_STATUSES := ["draft_reference", "draft_implemented_review_pending", "narrative_approved"]
const TECH_STATUSES := ["reference_only", "specified", "implemented", "technically_complete"]
const BOUNDARIES := ["scene", "sleep", "chapter_end"]
const EFFECT_KEYS := ["commozione", "supervillain", "grace", "standing", "flags", "marvel", "item", "value", "remembered", "shard", "unlock", "coins"]
const BOOK_KEYS := {"marvel": "marvels", "item": "items", "value": "values", "remembered": "remembered", "shard": "shards"}
## Reality levels (STORY_REWRITE_SPEC.md §2.4).
const REALITY_LEVELS := [1, 8]
## Script folders whose code must hold no player text.
const EXECUTION_DIRS := ["res://story", "res://scenes/story", "res://ui/story"]

## The runtime catalog (generated: compatibility IDs/order + the Resources' titles).
var catalog: StoryCatalog
## The frozen compatibility catalog (data/campaign/story_catalog.json): stable IDs, order, Green Zone.
var compat: Dictionary = {}
var cast: StoryCast
## map id -> StoryMapData
var maps: Dictionary = {}
var sprites: SpriteCatalog
var sound_keys: Array = []
var music_keys: Array = []


## A validator over the project's own Resources.
static func for_project() -> StoryValidator:
	var v := StoryValidator.new()
	v.catalog = load("res://data/campaign/story_catalog.tres")
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/campaign/story_catalog.json"))
	v.compat = parsed if parsed is Dictionary else {}
	v.cast = load("res://data/story/cast.tres")
	v.sprites = load("res://data/environment/green_zone_sprites.tres")
	for f in DirAccess.get_files_at("res://data/story/maps"):
		if f.ends_with(".tres"):
			var m: StoryMapData = load("res://data/story/maps/" + f)
			v.maps[m.id] = m
	var audio: Node = Engine.get_main_loop().root.get_node("AudioService")
	v.sound_keys = (audio.get("SFX") as Dictionary).keys().map(func(k: Variant) -> String: return String(k))
	v.sound_keys.append_array((audio.get("SYNTH") as Array).map(func(k: Variant) -> String: return String(k)))
	v.music_keys = (audio.get("MUSIC") as Dictionary).keys().map(func(k: Variant) -> String: return String(k))
	return v


# --- Chapters and scenes ------------------------------------------------------------------------

## The compatibility catalog's chapter `number` ({} if none).
func compat_chapter(number: int) -> Dictionary:
	for ch: Dictionary in compat.get("chapters", []):
		if int(ch["number"]) == number:
			return ch
	return {}


## The compatibility catalog's entry for `id`: {"chapter", "sub"} or {}.
func compat_find(id: String) -> Dictionary:
	for ch: Dictionary in compat.get("chapters", []):
		for sub: Dictionary in ch["subLevels"]:
			if String(sub["id"]) == id:
				return {"chapter": ch, "sub": sub}
	return {}


## Every compatibility ID in catalog order.
func compat_ids() -> Array:
	var out: Array = []
	for ch: Dictionary in compat.get("chapters", []):
		for sub: Dictionary in ch["subLevels"]:
			out.append(String(sub["id"]))
	return out


func validate_chapter(ch: StoryChapterData) -> PackedStringArray:
	var errors := PackedStringArray()
	var where := "chapter %d" % ch.number
	var cc := compat_chapter(ch.number)
	if ch.number < 1 or cc.is_empty():
		errors.append("%s: not a chapter of the compatibility catalog" % where)
		return errors
	# Spec §5.2: every field present.
	for f: Array in [["title", ch.title], ["menu_title", ch.menu_title], ["intro", ch.intro], ["cast_note", ch.cast_note], ["professor_aside", ch.professor_aside]]:
		_need(errors, String(f[1]).strip_edges() != "", "%s: no %s" % [where, f[0]])
	_need(errors, music_keys.has(ch.music), "%s: unknown music '%s'" % [where, ch.music])
	_need(errors, ch.content_version >= 1, "%s: content_version must be >= 1" % where)
	_need(errors, REVIEW_STATUSES.has(ch.review_status), "%s: bad review_status '%s'" % [where, ch.review_status])
	_need(errors, not ch.review_notes.is_empty(), "%s: no review_notes" % where)
	_need(errors, not ch.scenes.is_empty(), "%s: no scenes" % where)
	# The display titles come from this Resource: the generated catalog must show them.
	var cat_ch := catalog.chapter(ch.number)
	_need(errors, not cat_ch.is_empty() and String(cat_ch["title"]) == ch.title and String(cat_ch["menu_title"]) == ch.menu_title,
		"%s: the generated catalog shows '%s' / '%s', not this Resource's '%s' / '%s' (run tools/build_resources.gd)" % [where, cat_ch.get("title", ""), cat_ch.get("menu_title", ""), ch.title, ch.menu_title])
	# Scripted scenes in the compatibility order (1.0 is the Green Zone walk, never a story scene).
	var catalog_ids: Array = []
	for s: Dictionary in cc["subLevels"]:
		if int(s["greenZone"]) == 0:
			catalog_ids.append(String(s["id"]))
	var ids: Array = []
	for s: Variant in ch.scenes:
		if not s is StorySceneData:
			errors.append("%s: a scene is not a StorySceneData" % where)
			continue
		var sc: StorySceneData = s
		ids.append(sc.id)
		_need(errors, sc.level == ch.number, "%s: scene %s says level %d" % [where, sc.id, sc.level])
		errors.append_array(validate_scene(sc))
	_need(errors, ids == catalog_ids.slice(0, ids.size()), "%s: scenes %s are not the catalog order %s" % [where, ids, catalog_ids])
	return errors


func validate_scene(scene: StorySceneData) -> PackedStringArray:
	var errors := PackedStringArray()
	var where := "scene %s" % scene.id
	var found := compat_find(scene.id)
	if found.is_empty() or int(found["sub"]["greenZone"]) != 0:
		errors.append("%s: not a scripted scene of the catalog" % where)
		return errors
	_need(errors, scene.title.strip_edges() != "", "%s: no title" % where)
	var shown := catalog.find(scene.id)
	_need(errors, not shown.is_empty() and String(shown["sub"]["title"]) == scene.title,
		"%s: the generated catalog shows '%s', not this Resource's title '%s' (run tools/build_resources.gd)" % [where, shown["sub"]["title"] if not shown.is_empty() else "", scene.title])
	_need(errors, scene.level == int(found["chapter"]["number"]), "%s: level %d, catalog %d" % [where, scene.level, found["chapter"]["number"]])
	_need(errors, scene.content_version >= 1, "%s: content_version must be >= 1" % where)
	_need(errors, scene.summary.strip_edges() != "", "%s: no summary (scene card)" % where)
	_need(errors, maps.has(scene.map), "%s: unknown map '%s'" % [where, scene.map])
	_need(errors, music_keys.has(scene.music), "%s: unknown music '%s'" % [where, scene.music])
	_need(errors, not scene.cast.is_empty(), "%s: empty cast" % where)
	for sp in scene.cast:
		_need(errors, cast.has_speaker(sp), "%s: cast member '%s' is not a known speaker" % [where, sp])
	_need(errors, not scene.source_refs.is_empty(), "%s: no source references" % where)
	_need(errors, not scene.historical_tags.is_empty(), "%s: no historical/place tags" % where)
	_need(errors, REVIEW_STATUSES.has(scene.review_status), "%s: bad review_status '%s'" % [where, scene.review_status])
	_need(errors, TECH_STATUSES.has(scene.technical_status), "%s: bad technical_status '%s'" % [where, scene.technical_status])
	_need(errors, scene.reality == REALITY_LEVELS.has(scene.level), "%s: reality flag does not match level %d" % [where, scene.level])
	_need(errors, BOUNDARIES.has(String(scene.completion.get("boundary", ""))), "%s: bad completion boundary" % where)
	for k: String in scene.entry_conditions:
		_need(errors, ["requires_completed", "requires_abilities"].has(k), "%s: unknown entry condition '%s'" % [where, k])
	var order := compat_ids()
	for req: String in scene.entry_conditions.get("requires_completed", []):
		_need(errors, order.has(req) and order.find(req) < order.find(scene.id), "%s: entry requires '%s', which is not an earlier catalog ID" % [where, req])
	for a: String in scene.entry_conditions.get("requires_abilities", []):
		_need(errors, CampaignSchema.ABILITIES.has(a), "%s: entry requires unknown ability '%s'" % [where, a])
	if scene.steps.is_empty():
		errors.append("%s: no steps" % where)
		return errors
	# The final step, and only it, is the completion boundary.
	_need(errors, scene.steps.back() is CompleteStep, "%s: the last step must be a CompleteStep" % where)
	_need(errors, scene.steps[0] is StageStep, "%s: the first step must be a StageStep (it builds the first stage)" % where)
	var ids: Array = []
	var walk := {"map": scene.map, "actors": [], "errors": errors, "scene": scene, "ids": ids, "top": true}
	_walk_steps(scene.steps, walk)
	# Every branch must produce the completion's required state.
	var finals := _paths(scene.steps, [{}])
	for req: String in scene.completion.get("requires_flags", []):
		for state: Dictionary in finals:
			if not state.has("flags." + req):
				errors.append("%s: a branch completes without setting flag '%s'" % [where, req])
				break
	for req: String in scene.completion.get("requires_abilities", []):
		for state: Dictionary in finals:
			if not state.has("unlock." + req):
				errors.append("%s: a branch completes without unlocking '%s'" % [where, req])
				break
	return errors


func _walk_steps(steps: Array, w: Dictionary) -> void:
	var scene: StorySceneData = w["scene"]
	var errors: PackedStringArray = w["errors"]
	for k in steps.size():
		var s: Variant = steps[k]
		if not s is StoryStep:
			errors.append("scene %s: step %d is not a StoryStep" % [scene.id, k])
			continue
		var step: StoryStep = s
		var where := "scene %s step %s" % [scene.id, step.id]
		_need(errors, step.id != "", "scene %s: step %d (%s) without an id" % [scene.id, k, step.kind()])
		_need(errors, not (w["ids"] as Array).has(step.id), "%s: duplicate step id" % where)
		(w["ids"] as Array).append(step.id)
		_need(errors, STEP_TYPES.has(step.kind()), "%s: unknown step type '%s'" % [where, step.kind()])
		if step is CompleteStep:
			_need(errors, w["top"] and k == steps.size() - 1, "%s: a CompleteStep must be the scene's last top-level step" % where)
		var field_errors := PackedStringArray()
		step.check(field_errors)
		for e in field_errors:
			errors.append("%s: %s" % [where, e])
		# The stage the step runs on.
		var new_map := step.stage_map()
		if new_map != "":
			_need(errors, w["top"], "%s: stage changes are not allowed inside a choice branch" % where)
			if not maps.has(new_map):
				errors.append("%s: unknown map '%s'" % [where, new_map])
			else:
				w["map"] = new_map
				w["actors"] = []
		var marker_ids: PackedStringArray = (maps[w["map"]] as StoryMapData).marker_ids() if maps.has(w["map"]) else PackedStringArray()
		for m in step.marker_refs():
			_need(errors, marker_ids.has(m), "%s: marker '%s' is not on map '%s'" % [where, m, w["map"]])
		for a in step.actor_refs():
			_need(errors, (w["actors"] as Array).has(a), "%s: actor '%s' is used before it is placed on this stage" % [where, a])
		for a in step.actor_defs():
			(w["actors"] as Array).append(a)
		if step is ActorStep and (step as ActorStep).action == "despawn":
			(w["actors"] as Array).erase((step as ActorStep).actor)
		for sp in step.speakers():
			_need(errors, cast.has_speaker(sp), "%s: unknown speaker '%s'" % [where, sp])
			_need(errors, scene.cast.has(sp), "%s: speaker '%s' is not in the scene's cast" % [where, sp])
		for r in step.roles():
			_need(errors, r == "legs" or StoryCast.frames_path(r) != "", "%s: cast role '%s' has no SpriteFrames" % [where, r])
		for key in step.sprites():
			_need(errors, sprites.has_key(key), "%s: unknown sprite '%s'" % [where, key])
		for snd in step.sounds():
			_need(errors, sound_keys.has(snd), "%s: unknown sound '%s'" % [where, snd])
		for fx: Dictionary in step.effect_sets():
			check_effects(fx, scene.persistent_effects, errors, where)
		for branch: Array in step.branches():
			var sub := w.duplicate()
			sub["top"] = false
			sub["actors"] = (w["actors"] as Array).duplicate()
			_walk_steps(branch, sub)


## Every state a scene can complete in, as sets of produced keys ("flags.<name>", "unlock.<id>",
## "meter.<name>", "book.<key>"), one per path through the choices.
func _paths(steps: Array, states: Array) -> Array:
	var cur := states
	for s: Variant in steps:
		if not s is StoryStep:
			continue
		var step: StoryStep = s
		if step is ChoiceStep:
			var c: ChoiceStep = step
			var next: Array = []
			for st: Dictionary in cur:
				if c.once_each:
					var all := [st.duplicate()]
					for o: StoryChoiceOption in c.options:
						all = _paths(o.then_steps, _with(all, o.effects))
					next.append_array(all)
				else:
					for o: StoryChoiceOption in c.options:
						if o.locked_text == "":
							next.append_array(_paths(o.then_steps, _with([st.duplicate()], o.effects)))
			cur = next
			continue
		for fx: Dictionary in step.effect_sets():
			cur = _with(cur, fx)
	return cur


static func _with(states: Array, fx: Dictionary) -> Array:
	var out: Array = []
	for st: Dictionary in states:
		var n := st.duplicate()
		for key in _declared_keys(fx):
			n[key] = true
		out.append(n)
	return out


# --- Effects ------------------------------------------------------------------------------------

## The persistent_effects declarations an effect dictionary needs.
static func _declared_keys(fx: Dictionary) -> PackedStringArray:
	var out := PackedStringArray()
	for k: String in fx:
		if CampaignSchema.METER_KEYS.has(k):
			out.append("meter." + k)
		elif k == "flags" and fx[k] is Dictionary:
			for f: String in fx[k]:
				out.append("flags." + f)
		elif BOOK_KEYS.has(k):
			out.append("book." + String(BOOK_KEYS[k]))
		elif k == "unlock":
			out.append("unlock." + String(fx[k]))
		elif k == "coins":
			out.append("coins")
	return out


## Known keys, valid values, declared in `declared`.
func check_effects(fx: Dictionary, declared: PackedStringArray, errors: PackedStringArray, where: String) -> void:
	for k: String in fx:
		if not EFFECT_KEYS.has(k):
			errors.append("%s: unknown effect key '%s'" % [where, k])
			continue
		var v: Variant = fx[k]
		if CampaignSchema.METER_KEYS.has(k):
			_need(errors, CampaignSchema.is_finite_number(v) and float(v) != 0.0, "%s: meter '%s' needs a nonzero number" % [where, k])
		elif k == "flags":
			if not v is Dictionary or (v as Dictionary).is_empty():
				errors.append("%s: flags must be a nonempty dictionary" % where)
				continue
			for f: String in v:
				var known: bool = CampaignSchema.FLAG_ENUMS.has(f) or CampaignSchema.FLAG_NUMBERS.has(f) or CampaignSchema.FLAG_BOOLEANS.has(f) or CampaignSchema.FLAG_ANY_SCALAR.has(f)
				if not known:
					errors.append("%s: flag '%s' is not in CampaignFlagSchema (a new flag needs a recorded decision and a schema update)" % [where, f])
					continue
				_need(errors, CampaignSchema.normalize_flags({f: v[f]}) == {f: v[f]}, "%s: flag '%s' has an invalid value %s" % [where, f, v[f]])
		elif k == "unlock":
			_need(errors, CampaignSchema.ABILITIES.has(v), "%s: unknown ability '%s'" % [where, v])
		elif k == "coins":
			_need(errors, CampaignSchema.is_finite_number(v) and float(v) == floor(float(v)), "%s: coins must be an integer" % where)
		else:
			_need(errors, typeof(v) == TYPE_STRING and String(v).strip_edges() != "", "%s: book entry '%s' must be nonempty text" % [where, k])
	for key in _declared_keys(fx):
		_need(errors, declared.has(key), "%s: effect '%s' is not declared in persistent_effects" % [where, key])


# --- Execution scripts --------------------------------------------------------------------------

## Uppercase string literals (player text) in the story engine's scripts: "<file>:<line>: <literal>".
static func scan_scripts(dirs: Array = EXECUTION_DIRS) -> PackedStringArray:
	var found := PackedStringArray()
	var literal := RegEx.create_from_string("\"((?:[^\"\\\\]|\\\\.)*)\"")
	var player_text := RegEx.create_from_string("^[A-Z0-9][A-Z0-9 ,.'!?:;()\\-]*$")
	var letters := RegEx.create_from_string("[A-Z]")
	for dir: String in dirs:
		for path in _scripts_under(dir):
			var lines := FileAccess.get_file_as_string(path).split("\n")
			for n in lines.size():
				var line := lines[n].strip_edges()
				if line.begins_with("#"):
					continue
				for m in literal.search_all(line):
					var s := m.get_string(1)
					# Words and sentences, not constant names ("SYNTH"): a space or end punctuation.
					var sentence := s.contains(" ") or s.ends_with(".") or s.ends_with("!") or s.ends_with("?")
					if sentence and player_text.search(s) != null and letters.search_all(s).size() >= 4:
						found.append("%s:%d: %s" % [path, n + 1, s])
	return found


static func _scripts_under(dir: String) -> PackedStringArray:
	var out := PackedStringArray()
	if not DirAccess.dir_exists_absolute(dir):
		return out
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".gd"):
			out.append(dir.path_join(f))
	for d in DirAccess.get_directories_at(dir):
		out.append_array(_scripts_under(dir.path_join(d)))
	return out


static func _need(errors: PackedStringArray, ok: bool, what: String) -> void:
	if not ok:
		errors.append(what)
