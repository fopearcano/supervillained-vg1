class_name LevelListOverlay
extends OverlayPanel
## The level list (source StoryMenuScene, from OPTIONS > LEVELS (REPLAY) or a finished story):
## CONTINUE / BEGIN THE DREAM, one row per level (open levels show done/total; locked ones "? ? ?"),
## MERAVIGLIA BOOK, BACK. Built from StoryCatalog and the saved campaign; replays run on a copy.

var state: Dictionary
var catalog: StoryCatalog
var text: ShellText
## {"cont", "level"(number), "book", "back"} -> Callable
var actions: Dictionary


func setup(p_state: Dictionary, p_catalog: StoryCatalog, p_text: ShellText, p_actions: Dictionary) -> LevelListOverlay:
	state = p_state
	catalog = p_catalog
	text = p_text
	actions = p_actions
	back_action = actions["back"]
	items = [{"label": "CONTINUE" if not (state["completed"] as Array).is_empty() else "BEGIN THE DREAM", "color": T.GREEN, "action": actions["cont"]}]
	for ch: Dictionary in catalog.chapters:
		var n := int(ch["number"])
		var subs: Array = ch["sub_levels"]
		var done := subs.filter(func(s: Dictionary) -> bool: return (state["completed"] as Array).has(s["id"])).size()
		var open := CampaignFlow.level_unlocked(state, catalog, n)
		items.append({
			"label": "%d %s %d/%d" % [n, String(ch["menu_title"]).to_upper(), done, subs.size()] if open else "%d ? ? ?" % n,
			"color": Color("#5a5a6a") if not open else (T.CYAN if done == subs.size() else T.YELLOW),
			"action": (func() -> void: actions["level"].call(n)) if open else (func() -> void: AudioService.play(&"empty")),
			"open": open,
		})
	items.append({"label": "MERAVIGLIA BOOK", "color": T.PINK, "action": actions["book"]})
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
	T.draw_centered(self, size.x / 2.0, 10, "LEVELS", T.YELLOW, 1, T.SHADOW)
	T.draw_centered(self, size.x / 2.0, 22, text.get_text("levels_subtitle"), Color("#9aa4c0"), 1, Color.BLACK)
	var m: Dictionary = state["meters"]
	T.draw_centered(self, size.x / 2.0, 34, "%s %d  %s %d\n%s %d  COINS %d" % [text.get_text("meter_commozione"), m["commozione"],
		text.get_text("meter_grace"), m["grace"], text.get_text("meter_supervillain"), m["supervillain"], state["coins"]], T.WHITE, 1, Color.BLACK)
	menu_top = 58
