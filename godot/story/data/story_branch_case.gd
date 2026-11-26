class_name StoryBranchCase
extends Resource
## One case of a BranchStep: the steps that run when `when` holds of the campaign working copy.
## `when` is a Dictionary of conditions, all of which must hold (StoryConditions.holds):
##   {"flag": name, "eq": value}   a flag equal to a value ("eq": null = the flag is absent);
##   {"meter": name, "gte": n} / {"meter": name, "lt": n}
##   {"ability": id}               an ability held;
##   {"book": kind, "has": entry} / {"book": kind, "gte": n}   a book entry present / a count.
## Several conditions combine with "all": [{...}, {...}].

@export var id := ""
@export var when: Dictionary = {}
@export var steps: Array = []
