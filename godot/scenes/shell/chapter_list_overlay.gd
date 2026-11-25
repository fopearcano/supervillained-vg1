class_name ChapterListOverlay
extends OverlayPanel
## One level's scenes (source StoryChapterScene): replay any finished scene (on a copy, nothing
## saved) or go on with the first unfinished one; later scenes are locked ("? ? ?"). Labels are cut
## to fit the 200 px row like the source.

var state: Dictionary
var chapter: Dictionary
var text: ShellText
## {"play"(id), "back"} -> Callable
var actions: Dictionary


static func fit_label(id: String, title: String) -> String:
	var label := "%s %s" % [id, title.to_upper()]
	if label.length() > 24:
		var cut := label.substr(0, 22)
		if label[22] != " ":
			var i := cut.rfind(" ")
			cut = cut.substr(0, i) if i > 0 else cut
		label = cut.strip_edges(false, true) + ".."
	return label


func setup(p_state: Dictionary, catalog: StoryCatalog, number: int, p_text: ShellText, p_actions: Dictionary) -> ChapterListOverlay:
	state = p_state
	chapter = catalog.chapter(number)
	text = p_text
	actions = p_actions
	back_action = actions["back"]
	items = []
	for s: Dictionary in chapter["sub_levels"]:
		var id := String(s["id"])
		var open := CampaignFlow.scene_open(state, catalog, id)
		var done := (state["completed"] as Array).has(id)
		items.append({
			"label": fit_label(id, String(s["title"])) if open else "%s ? ? ?" % id,
			"color": Color("#5a5a6a") if not open else (T.CYAN if done else T.YELLOW),
			"action": (func() -> void: actions["play"].call(id)) if open else (func() -> void: AudioService.play(&"empty")),
			"id": id, "open": open,
		})
	items.append({"label": "BACK", "color": T.WHITE, "action": actions["back"]})
	return self


func _ready() -> void:
	super._ready()
	dim = 1.0
	menu_item_width = 200.0
	menu_item_height = 14.0
	menu_gap = 3.0


func draw_content() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color8(0x14, 0x0a, 0x24))
	T.draw_centered(self, size.x / 2.0, 12, "LEVEL %d\n%s" % [chapter["number"], String(chapter["title"]).to_upper()], T.YELLOW, 1, T.SHADOW)
	var note := T.wrap(text.get_text("replay_note"), int(size.x - 16))
	T.draw_centered(self, size.x / 2.0, 42, "\n".join(note), Color("#9aa4c0"), 1, Color.BLACK)
	menu_top = 42 + note.size() * 11 + 10
