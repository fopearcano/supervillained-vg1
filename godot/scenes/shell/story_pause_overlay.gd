class_name StoryPauseOverlay
extends OverlayPanel
## The story pause (port of src/story/screens.ts StoryPauseScene, as M5R offers it): RESUME,
## RESTART SCENE (from the scene's entry state: nothing applied twice), QUIT TO TITLE (the scene's
## uncommitted progress is dropped). SKIP SCENE is not offered in M5R (decision RD-23). Back and
## Esc resume. Labels come from data/shell/shell_text.tres.

var heading := ""


func setup(text: ShellText, actions: Dictionary) -> StoryPauseOverlay:
	heading = text.get_text("story_pause_title")
	items = [
		{"label": text.get_text("story_resume"), "color": T.GREEN, "action": actions["resume"]},
		{"label": text.get_text("story_restart"), "color": T.YELLOW, "action": actions["restart"]},
		{"label": text.get_text("story_quit"), "color": T.PINK, "action": actions["quit"]},
	]
	back_action = actions["resume"]
	return self


func _ready() -> void:
	super._ready()
	dim = 0.6
	menu_item_width = 150.0
	menu_item_height = 18.0
	menu_gap = 6.0


func draw_content() -> void:
	var y := roundf(size.y * 0.32)
	T.draw_centered(self, size.x / 2.0, y, heading, T.YELLOW, 2, T.SHADOW)
	menu_top = y + 30
