class_name StoryChoiceOption
extends Resource
## One option of a ChoiceStep. Zampanò says `said` (or the label) when it is picked; then the
## option's effects apply and its follow-up steps run.

## Stable within its choice (metrics, tests, the scripted driver's policy).
@export var id := ""
@export var label := ""
## What Zampanò says when picked ("" = the label itself).
@export var said := ""
## True: he says nothing (an action; its follow-up steps narrate it).
@export var silent := false
## Commozione this action spends; without enough the option is locked ("an unmoved Zampanò cannot act").
@export var cost := 0
## A permanent lock reason shown greyed ("" = not locked).
@export var locked_text := ""
## 8.2: the option is open only while this condition holds (StoryConditions); otherwise it shows
## locked with `locked_text`. Empty: a non-empty `locked_text` locks it for good.
@export var requires: Dictionary = {}
@export var effects: Dictionary = {}
## Follow-up StoryStep Resources.
@export var then_steps: Array = []
