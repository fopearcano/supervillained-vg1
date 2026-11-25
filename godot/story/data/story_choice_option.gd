class_name StoryChoiceOption
extends Resource
## One option of a ChoiceStep. Zampanò says `said` (or the label) when it is picked; then the
## option's effects apply and its follow-up steps run.

## Stable within its choice (metrics, tests, the scripted driver's policy).
@export var id := ""
@export var label := ""
## What Zampanò says when picked ("" = the label itself).
@export var said := ""
## Commozione this action spends; without enough the option is locked ("an unmoved Zampanò cannot act").
@export var cost := 0
## A permanent lock reason shown greyed ("" = not locked).
@export var locked_text := ""
@export var effects: Dictionary = {}
## Follow-up StoryStep Resources.
@export var then_steps: Array = []
