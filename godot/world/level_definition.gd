class_name LevelDefinition
extends Resource
## Arcade level description (port of LevelDef in src/world/level.ts).

@export var id: String
@export var number: int
@export var zone_name: String
@export var seed: int
## Seconds; finishing faster earns a time bonus.
@export var par_time: float
## Colour Ink environment bank id (the arcade deliberately ignores the obsolete 1:arcade floor).
@export var environment: String
## {"treats": {count, maxOffset, minSpacing}, "cats": {...}, "balls": {...}}
@export var spawns: Dictionary
## {"underAttack": {...}, "pollutionWaves": [{progress, count, radius, strength, distance}]}
@export var events: Dictionary
@export var rows: PackedStringArray
@export var require_exit := true
