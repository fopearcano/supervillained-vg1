extends Node
## Persistent root: owns scene replacement, the overlay stack inside the pixel viewport and the
## product flow (port of the non-story part of src/scenes/flow.ts and src/story/storyFlow.ts):
##   Title → NEW GAME (confirmation over a saved story) | CONTINUE | COUCH | OPTIONS (CONTROLS,
##   LEVELS (REPLAY), MERAVIGLIA BOOK) | GLOSSARY | QUIT (Goodbye where an app cannot close);
##   1.0 = the Green Zone walk; its CONTINUE hands the walk to the campaign (AppState.complete_walk)
##   and leads to 1.1; story scenes (M5R: Level 1, 1.1–1.5) open with their scene card and play in
##   StoryScene; each completion is one atomic save (AppState.commit_scene); after a level's last
##   scene the Supervillained snap, the Professor's aside, then the next level (this build shows
##   a scene without Resources honestly as not built yet).
## Every save the flow depends on is checked: a failed or refused NEW GAME stays on the title, a
## failed CONTINUE stays on the result card, a failed notice save keeps the notice; each shows the
## save-error card (what failed, that nothing changed, what to do) and never moves on.
## Scenes and overlays are instanced into GameViewport; nothing renders outside it except the
## black letterbox.

const GREEN_ZONE_SCENE := preload("res://scenes/green_zone/green_zone_scene.tscn")
const TITLE_SCENE := preload("res://scenes/title/title_screen.tscn")
const STORY_SCENE := preload("res://scenes/story/story_scene.tscn")
const MARKUP: StoryMarkup = preload("res://data/story/markup.tres")
const TEXT: ShellText = preload("res://data/shell/shell_text.tres")

@onready var viewport_controller: PixelViewportController = $ViewportController
@onready var game_viewport: SubViewport = %GameViewport
@onready var scene_host: Node = %SceneHost
@onready var overlay_host: Control = %OverlayHost
@onready var transition_host: Control = %TransitionHost
## The game's own background inside the pixel viewport (source renderer background 0x0c3a10);
## everything outside the viewport stays the black clear colour (the source's black page).
@onready var underlay: ColorRect = %Underlay

const UNDERLAY_COLOR := Color8(0x0c, 0x3a, 0x10)

var current_scene: Node = null
## The glitch burst between scenes (source game.transition + Flow.glitch).
var transition: GlitchTransition
## Every Green Zone → campaign handoff received (the data CONTINUE carried), for diagnostics.
var campaign := CampaignHandoff.Receiver.new()
## Opens the publisher's site (tests replace it; the game opens the system browser).
var open_url: Callable = func(url: String) -> void: OS.shell_open(url)
## Closes the app where an app can close itself (Android, desktop); otherwise the Goodbye card.
var can_quit: bool = OS.get_name() != "iOS" and OS.get_name() != "Web"
var quit_app: Callable = func() -> void: get_tree().quit()
## Developer start (source `?skip=game`): "" = the title; "game" = the walk outside the story
## (`-- --skip=game`: RETRY/TITLE on its result); "walk" = the walk as the story's 1.0, as Main
## started before the title existed (tests and tools set it before adding Main to the tree).
var start_target := ""
## The scene whose walk was handed over to the campaign (its instance id; 0 = none), so a repeated
## CONTINUE on the same result card never hands it over twice.
var _handed_over := 0


func _ready() -> void:
	transition = GlitchTransition.new()
	transition_host.add_child(transition)
	viewport_controller.viewport_changed.connect(_on_viewport_changed)
	_on_viewport_changed(viewport_controller.logical_size, viewport_controller.scale)
	AppState.save_error.connect(func(context: String, reason: String) -> void: show_save_error(context, reason))
	var target := start_target if start_target != "" else _arg_start()
	match target:
		"game":
			start_green_zone(true, false)
		"walk":
			start_green_zone(true)
		_:
			show_title()


static func _arg_start() -> String:
	return "game" if OS.get_cmdline_user_args().has("--skip=game") else ""


func _on_viewport_changed(logical: Vector2i, _scale: int) -> void:
	underlay.color = UNDERLAY_COLOR
	underlay.size = Vector2(logical)
	overlay_host.size = Vector2(logical)
	transition_host.size = Vector2(logical)
	if transition:
		transition.size = Vector2(logical)
	for o in overlay_host.get_children():
		(o as Control).size = Vector2(logical)
	if current_scene and current_scene.has_method("resize"):
		current_scene.resize(logical)


func change_scene(packed: PackedScene, configure: Callable = Callable()) -> Node:
	clear_overlays()
	if current_scene:
		scene_host.remove_child(current_scene)
		current_scene.queue_free()
	current_scene = packed.instantiate()
	if configure.is_valid():
		configure.call(current_scene)
	if current_scene.has_method("bind_main"):
		current_scene.bind_main(self)
	scene_host.add_child(current_scene)
	if current_scene.has_method("resize"):
		current_scene.resize(viewport_controller.logical_size)
	return current_scene


func push_overlay(overlay: Control) -> void:
	overlay_host.add_child(overlay)
	overlay.size = overlay_host.size


func pop_overlay(overlay: Control) -> void:
	if overlay and overlay.get_parent() == overlay_host:
		overlay_host.remove_child(overlay)
		overlay.queue_free()


func clear_overlays() -> void:
	for child in overlay_host.get_children():
		overlay_host.remove_child(child)
		child.queue_free()


func top_overlay() -> Control:
	var n := overlay_host.get_child_count()
	return overlay_host.get_child(n - 1) as Control if n > 0 else null


func logical_size() -> Vector2i:
	return viewport_controller.logical_size


func _glitch(mid: Callable) -> void:
	transition.play(mid, 0.5, 0.6)


# --- Title ----------------------------------------------------------------------------------------

## The title page (source Flow.toTitle): intro music, the save notice once, CONTINUE preselected
## when a story is saved.
func show_title() -> void:
	AppState.end_replay()
	var title: TitleScreen = change_scene(TITLE_SCENE, func(n: Node) -> void:
		(n as TitleScreen).setup({
			"new_game": new_game, "cont": continue_game, "couch": open_couch, "options": open_options,
			"glossary": open_glossary, "quit": quit, "publisher": func() -> void:
				AudioService.play(&"click")
				open_url.call(GameConfig.Title.PUBLISHER_URL),
		}, AppState.has_progress()))
	title.covered = func() -> bool: return overlay_host.get_child_count() > 0 or transition.running
	InputService.set_context(&"menu")
	AudioService.stop_all_loops()
	AudioService.play_music(&"intro")
	AudioService.set_duck(1.0)
	_show_save_notice()


## A pending save notice (recovery from backup, unreadable save, newer version, legacy import)
## shown once over the title.
func _show_save_notice() -> void:
	var kind := SaveService.take_notice()
	var key := ""
	match kind:
		"recovered_backup": key = "save_recovered_backup"
		"recovered_temp": key = "save_recovered_temp"
		"corrupt_reset": key = "save_corrupt_reset"
		"future_blocked": key = "save_future_blocked"
		"save_unpreserved": key = "save_unpreserved"
	var li: Dictionary = SaveService.legacy_import_state()
	if key == "" and li["status"] == "retryable_error":
		key = "legacy_retry"
	elif key == "" and li["status"] == "blocked":
		key = "legacy_blocked"
	if key == "":
		return
	var m := MessageOverlay.new().setup("SAVE", [[TEXT.get_text(key), PixelText.WHITE]], [], Callable(), 0.85)
	m.dismiss = func() -> void: pop_overlay(m)
	m.back_action = m.dismiss
	push_overlay(m)


## NEW GAME: over a saved story, ask first (source Flow.newGame).
func new_game() -> void:
	if not AppState.has_progress():
		_begin_new_game()
		return
	var c := ConfirmOverlay.new()
	c.setup("NEW GAME?", "THE SAVED STORY WILL BE LOST.", func() -> void:
		pop_overlay(c)
		_begin_new_game(), func() -> void: pop_overlay(c))
	push_overlay(c)


## The new campaign is saved first; only then the walk starts. A failed or refused save stays on
## the title with the save-error card (the saved story is unchanged). Ignored while a transition
## runs (its pending scene change is never run early or replaced).
func _begin_new_game() -> void:
	if transition.running:
		return
	if not AppState.new_game():
		show_save_error("new_game", SaveService.last_error, _begin_new_game)
		return
	_glitch(func() -> void: _play_scene.call_deferred("1.0"))


## CONTINUE (source StoryFlow.continueGame): the one-time migration notice first (shown only once
## its clearing is saved; a failed save keeps it and shows the save-error card); then the next
## unfinished scene, or the level list when the story is finished. With no saved story it starts it.
func continue_game() -> void:
	if transition.running:
		return
	var n := AppState.take_story_notice()
	if not n["saved"]:
		show_save_error("notice", String(n["error"]), continue_game)
		return
	if n["notice"]:
		var m := MessageOverlay.new().setup(TEXT.get_text("notice_title"), [[TEXT.get_text("notice_body"), PixelText.WHITE], [TEXT.get_text("notice_foot"), Color("#9aa4c0")]], [], Callable(), 0.96)
		m.dismiss = func() -> void:
			pop_overlay(m)
			continue_game()
		push_overlay(m)
		return
	var target := AppState.continue_target()
	if target.is_empty():
		open_levels()
		return
	_glitch(func() -> void: _play_scene.call_deferred(String(target["id"])))


## Plays a scene of the catalog: the Green Zone walk, a rewritten story scene (its card first), or
## this build's boundary for a scene without Resources.
func _play_scene(id: String) -> void:
	var f := SaveService.CATALOG.find(id)
	if not f.is_empty() and int(f["sub"]["green_zone"]) > 0:
		start_green_zone(true)
	elif StoryLibrary.has_scene(id):
		show_story_card(id)
	else:
		show_boundary(id)


# --- Story scenes ---------------------------------------------------------------------------------

## The scene card before a story scene (source StoryFlow.showSub): LEVEL n, the ID and title, what
## happens; in a replay, that the campaign will not change. A tap starts the scene.
func show_story_card(id: String) -> void:
	var data := StoryLibrary.scene(id)
	clear_overlays()
	AudioService.play_music(&"intro")
	var paragraphs := [["%s %s" % [id, data.title.to_upper()], PixelText.YELLOW], [data.summary, PixelText.WHITE]]
	if AppState.replaying:
		paragraphs.append([TEXT.get_text("story_replay_note"), PixelText.CYAN])
	var m := MessageOverlay.new()
	m.setup(TEXT.get_text("story_level") % data.level, paragraphs, [], func() -> void:
		pop_overlay(m)
		_glitch(func() -> void: start_story.call_deferred(id)), 0.97)
	m.markup = MARKUP
	m.set_meta(&"story_card", id)
	push_overlay(m)


## Starts a story scene from the campaign (or the replay's copy, which is never committed).
func start_story(id: String) -> void:
	var data := StoryLibrary.scene(id)
	var scene: StoryScene = change_scene(STORY_SCENE, func(n: Node) -> void:
		(n as StoryScene).setup(data, AppState.story_entry_state(), AppState.persists()))
	scene.completed.connect(_on_story_completed)
	scene.quit_requested.connect(quit_to_title)
	scene.failed.connect(_on_story_failed)


## A story scene reached its completion boundary: a replay returns to its level's list and saves
## nothing; otherwise the scene is committed in one save (a failure stays on the scene's last
## screen with the save-error card: TRY AGAIN commits the same result, TITLE abandons the scene
## like a force-close), then the next scene, or the end of the level.
func _on_story_completed(result: Dictionary) -> void:
	var id := String(result["id"])
	if AppState.replaying:
		AppState.end_replay()
		var f := SaveService.CATALOG.find(id)
		transition.play(func() -> void:
			show_title.call_deferred()
			(func() -> void:
				open_levels()
				open_chapter(int(f["chapter"]["number"]) if not f.is_empty() else 1)).call_deferred())
		return
	var r := AppState.commit_scene(id, result["state"], float(result["play_time"]))
	if not r["saved"]:
		show_save_error("scene", String(r["error"]), func() -> void: _on_story_completed(result),
			[{"label": "TITLE", "color": PixelText.PINK, "action": quit_to_title}], false)
		return
	var next := _next_in_level(id)
	if next != "":
		transition.play(func() -> void: _play_scene.call_deferred(next))
	else:
		_level_end(id)


## The next scene of the same level ("" after its last).
func _next_in_level(id: String) -> String:
	var f := SaveService.CATALOG.find(id)
	var subs: Array = f["chapter"]["sub_levels"]
	for k in subs.size():
		if String(subs[k]["id"]) == id and k + 1 < subs.size():
			return String(subs[k + 1]["id"])
	return ""


## The end of a level (source StoryFlow.finishSub): the Supervillained snap over the frozen last
## stage, then the Professor's aside, then the next level's first scene (its card, or this
## build's boundary when it has no Resources yet).
func _level_end(id: String) -> void:
	var number := int(SaveService.CATALOG.find(id)["chapter"]["number"])
	AudioService.play_music(&"intro")
	var sv := SupervillainedOverlay.new()
	sv.catalog = (current_scene as StoryScene).world.catalog if current_scene is StoryScene else load("res://data/environment/green_zone_sprites.tres")
	sv.done.connect(func() -> void:
		pop_overlay(sv)
		_professor_aside(number))
	sv.set_meta(&"level_end", number)
	push_overlay(sv)


func _professor_aside(number: int) -> void:
	var chapter := StoryLibrary.chapter(number)
	var next_ch := SaveService.CATALOG.chapter(number + 1)
	var next_id := String((next_ch["sub_levels"] as Array)[0]["id"]) if not next_ch.is_empty() else ""
	var m := MessageOverlay.new()
	m.setup(TEXT.get_text("story_aside_title"), [[chapter.professor_aside if chapter else "", PixelText.WHITE]], [], func() -> void:
		pop_overlay(m)
		if next_id == "":
			_glitch(func() -> void: show_title.call_deferred())
		else:
			_glitch(func() -> void: _play_scene.call_deferred(next_id)), 0.97)
	m.markup = MARKUP
	m.set_meta(&"professor_aside", number)
	push_overlay(m)


## Content that cannot run (a missing marker, actor or resource) stops with an explicit card.
func _on_story_failed(message: String) -> void:
	show_title()
	var m := MessageOverlay.new()
	m.setup(TEXT.get_text("story_error_title"), [[message, PixelText.WHITE]], [{"label": "TITLE", "color": PixelText.PINK, "action": func() -> void: pop_overlay(m)}], Callable(), 0.96)
	m.set_meta(&"story_error", message)
	push_overlay(m)


## Where a story scene would start (M5): what the save holds and that the scene is not built yet;
## nothing is erased, no other run starts.
func show_boundary(id: String) -> void:
	var f := SaveService.CATALOG.find(id)
	var label := "LEVEL %d: %s %s" % [f["chapter"]["number"], id, String(f["sub"]["title"]).to_upper()] if not f.is_empty() else id
	show_title()
	var paragraphs := [[label, PixelText.YELLOW], [TEXT.get_text("boundary_body"), PixelText.WHITE]]
	if AppState.has_progress():
		paragraphs.append([TEXT.get_text("boundary_saved"), PixelText.GREEN])
	var m := MessageOverlay.new()
	m.setup(TEXT.get_text("boundary_title"), paragraphs, [{"label": "TITLE", "color": PixelText.PINK, "action": func() -> void: pop_overlay(m)}], Callable(), 0.96)
	push_overlay(m)


func open_couch() -> void:
	AudioService.play(&"click")
	var c := CouchOverlay.new()
	c.setup(SaveService.get_campaign(), SaveService.CATALOG, SaveService.get_record("level1"), TEXT, AppState.now_ms(),
		CampaignSummary.local_offset_minutes(), func() -> void: pop_overlay(c))
	push_overlay(c)


func open_glossary() -> void:
	AudioService.play(&"click")
	var g := GlossaryOverlay.new()
	g.setup(func() -> void: pop_overlay(g))
	push_overlay(g)


func open_options() -> void:
	var o := OptionsOverlay.new()
	o.setup({
		"controls": func() -> void:
			var c := ControlsOverlay.new()
			c.setup(func() -> void: pop_overlay(c))
			push_overlay(c),
		"levels": func() -> void:
			pop_overlay(o)
			open_levels(),
		"book": func() -> void: _book_boundary(),
		"back": func() -> void: pop_overlay(o),
	})
	push_overlay(o)


func _book_boundary() -> void:
	var m := MessageOverlay.new()
	m.setup("MERAVIGLIA BOOK", [[TEXT.get_text("book_body"), PixelText.WHITE]], [{"label": "BACK", "color": PixelText.WHITE, "action": func() -> void: pop_overlay(m)}], Callable(), 0.96)
	push_overlay(m)


## The level list (source StoryFlow.openMenu) over the title.
func open_levels() -> void:
	var l := LevelListOverlay.new()
	l.setup(SaveService.get_campaign(), SaveService.CATALOG, TEXT, {
		"cont": func() -> void:
			pop_overlay(l)
			continue_game(),
		"level": func(n: int) -> void: open_chapter(n),
		"book": func() -> void: _book_boundary(),
		"back": func() -> void: pop_overlay(l),
	})
	push_overlay(l)


## One level's scenes (source StoryFlow.openChapter): replay a finished scene on a copy, or go on.
func open_chapter(number: int) -> void:
	var c := ChapterListOverlay.new()
	c.setup(SaveService.get_campaign(), SaveService.CATALOG, number, TEXT, {
		"play": func(id: String) -> void: play_from_list(id),
		"back": func() -> void: pop_overlay(c),
	})
	push_overlay(c)


func play_from_list(id: String) -> void:
	if transition.running:
		return
	var s := CampaignFlow.start(SaveService.get_campaign(), SaveService.CATALOG, id)
	if s["mode"] == "locked":
		AudioService.play(&"empty")
		return
	if s["mode"] == "replay":
		AppState.begin_replay(id)
	_glitch(func() -> void: _play_scene.call_deferred(id))


## The save-error card: what could not be saved (`context`: "new_game", "continue", "notice",
## "settings"), that nothing changed, and what to do. A failed write offers TRY AGAIN (`retry`); a
## read-only session (a newer save format, or a save that could not be safely copied) says why
## nothing can be saved instead. `extra` buttons ({"label", "color", "action"}) close the card
## first; BACK closes it and returns to the screen below.
## With `back` false there is no BACK button and Android Back keeps the card (a finished story scene
## behind it has nothing to go back to: the choice is TRY AGAIN or TITLE).
func show_save_error(context: String, reason: String, retry: Callable = Callable(), extra: Array = [], back: bool = true) -> MessageOverlay:
	var why := "save_error_retry"
	if reason.begins_with("write_blocked_future"):
		why = "save_error_future"
	elif reason.begins_with("write_blocked_unpreserved"):
		why = "save_error_unpreserved"
	var m := MessageOverlay.new()
	var buttons: Array = []
	if why == "save_error_retry" and retry.is_valid():
		buttons.append({"label": "TRY AGAIN", "color": PixelText.GREEN, "action": func() -> void:
			pop_overlay(m)
			retry.call()})
	for b: Dictionary in extra:
		var act: Callable = b["action"]
		buttons.append({"label": b["label"], "color": b["color"], "action": func() -> void:
			pop_overlay(m)
			act.call()})
	if back:
		buttons.append({"label": "BACK", "color": PixelText.WHITE, "action": func() -> void: pop_overlay(m)})
	m.setup(TEXT.get_text("save_error_title"), [[TEXT.get_text("save_error_" + context), PixelText.YELLOW], [TEXT.get_text(why), PixelText.WHITE]], buttons, Callable(), 0.92)
	if not back:
		m.back_action = Callable()
	m.heading_color = PixelText.RED
	m.set_meta(&"save_error", {"context": context, "reason": reason})
	push_overlay(m)
	return m


## QUIT (source Flow.quit): the app closes where it can; otherwise the Goodbye card.
func quit() -> void:
	AudioService.play(&"click")
	if can_quit:
		quit_app.call()
		return
	var m := MessageOverlay.new()
	m.setup("THANKS FOR PLAYING", [["YOU CAN CLOSE THIS APP NOW.\nTAP TO GO BACK TO THE TITLE.", PixelText.WHITE]], [], func() -> void: pop_overlay(m), 0.85)
	push_overlay(m)


# --- The Green Zone -------------------------------------------------------------------------------

## Starts the Green Zone: with the briefing (a new or continued walk, a replay) or straight into
## play (source Flow.play: RESTART / RETRY).
func start_green_zone(briefing: bool = true, as_story: bool = true) -> void:
	var scene := change_scene(GREEN_ZONE_SCENE, func(n: Node) -> void:
		n.set("show_briefing", briefing)
		n.set("as_story_scene", as_story))
	scene.restart_requested.connect(restart_green_zone)
	scene.title_requested.connect(quit_to_title)
	scene.campaign_handoff.connect(_on_campaign_handoff)


## RESTART / RETRY (source Flow.restart): click, glitch, a clean run straight into play (a replay
## stays a replay).
func restart_green_zone() -> void:
	AudioService.play(&"click")
	var story: bool = current_scene.get("as_story_scene") if current_scene else true
	transition.play(func() -> void: start_green_zone.call_deferred(false, story))


## QUIT / TITLE (source Flow.quitToTitle). A replay ends without saving anything.
func quit_to_title() -> void:
	AudioService.play(&"click")
	transition.play(func() -> void: show_title.call_deferred())


## CONTINUE on the level end (source Flow.levelComplete next → StoryFlow.addWalk → finishSub):
## outside a replay the walk's coins and time go to the campaign and 1.0 is completed, in one
## atomic save; then the next scene. A failed or refused save stays on the result card with the
## save-error card (TRY AGAIN, TITLE, BACK): nothing was added, nothing moves on, and a retry
## counts the walk once. A repeated CONTINUE on the same card is ignored. A replay returns to its
## level's list and saves nothing.
func _on_campaign_handoff(data: Dictionary) -> void:
	var scene_id := current_scene.get_instance_id() if current_scene else 0
	if scene_id != 0 and scene_id == _handed_over:
		return
	if AppState.replaying:
		_handed_over = scene_id
		campaign.receive(data)
		var id := AppState.replay_id
		AppState.end_replay()
		var f := SaveService.CATALOG.find(id)
		transition.play(func() -> void:
			show_title.call_deferred()
			(func() -> void:
				open_levels()
				open_chapter(int(f["chapter"]["number"]) if not f.is_empty() else 1)).call_deferred())
		return
	var r := AppState.complete_walk(int(data["coins"]), float(data["time"]), String(data["from"]))
	if not r["saved"]:
		show_save_error("continue", String(r["error"]), func() -> void: _on_campaign_handoff(data),
			[{"label": "TITLE", "color": PixelText.PINK, "action": quit_to_title}])
		return
	_handed_over = scene_id
	campaign.receive(data)
	var target := AppState.continue_target()
	transition.play(func() -> void:
		if target.is_empty():
			show_title.call_deferred()
		else:
			_play_scene.call_deferred(String(target["id"])))


# --- Android Back --------------------------------------------------------------------------------

## Android Back (source Flow.back): the top overlay's Back; on the bare title, QUIT. The Green Zone
## handles its own (pause / resume).
func _notification(what: int) -> void:
	if what != NOTIFICATION_WM_GO_BACK_REQUEST:
		return
	var top := top_overlay()
	if top and top.has_method("back"):
		top.call("back")
	elif top == null and current_scene is TitleScreen:
		quit()
	elif top == null and current_scene is StoryScene:
		(current_scene as StoryScene).open_pause()
