class_name ShellText
extends Resource
## Display text of the non-story shell that depends on the story (edition title, meter names,
## costumes, endings, the save-migration notice) plus this build's boundary notes. Data, so a later
## story rewrite edits data/shell/shell_text.tres instead of the title, Couch or save code.

@export var strings: Dictionary = {}


func get_text(key: String) -> String:
	assert(strings.has(key), "ShellText: missing '%s'" % key)
	return String(strings.get(key, ""))
