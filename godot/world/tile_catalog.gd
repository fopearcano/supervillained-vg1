class_name TileCatalog
extends RefCounted
## Ground types, prop kinds and the ASCII legend (port of src/world/tiles.ts).

enum Ground { VOID, GRASS, PATH, TALL_GRASS, WATER, FOREST, FLOOR, STONE, SAND, SNOW, DEEP, WALL, DOCK, CARPET }

## kind -> [solid, radius, tall, vertical]
const PROP_INFO := {
	"tree": [true, 0.32, true, true],
	"forestTree": [true, 0.4, true, true],
	"bush": [false, 0.0, true, true],
	"pole": [true, 0.16, true, true],
	"fountain": [true, 0.36, false, true],
	"column": [true, 0.25, true, true],
	"desk": [true, 0.45, false, false],
	"shelf": [true, 0.45, true, false],
	"house": [true, 0.5, true, true],
	"tent": [true, 0.42, true, true],
	"galley": [true, 0.5, true, false],
	"rock": [true, 0.35, false, true],
	"statue": [true, 0.3, true, true],
	"crate": [true, 0.35, false, true],
	"palm": [true, 0.25, true, true],
	"altar": [true, 0.4, false, false],
	"stall": [true, 0.45, true, false],
	"throne": [true, 0.4, true, false],
	"vine": [false, 0.0, true, true],
	"gate": [true, 0.5, true, true],
	"wicket": [true, 0.45, false, true],
	"bones": [false, 0.0, false, false],
	"table": [true, 0.42, false, false],
}

## Sprite key and variant count drawn for each prop kind (PROP_SPRITE).
const PROP_SPRITE := {
	"tree": ["tree", 3], "forestTree": ["forestTree", 2], "bush": ["bush", 2], "pole": ["pole", 1],
	"fountain": ["fountain", 1], "column": ["column", 1], "desk": ["desk", 1], "shelf": ["shelf", 1],
	"house": ["house", 2], "tent": ["tent", 2], "galley": ["galley", 2], "rock": ["rock", 1],
	"statue": ["statue", 1], "crate": ["crate", 1], "palm": ["palm", 1], "altar": ["altar", 1],
	"stall": ["stall", 1], "throne": ["throne", 1], "vine": ["vine", 1], "gate": ["gate", 1],
	"bones": ["bones", 1], "table": ["table", 1], "wicket": ["wicket", 1],
}

## Symbol -> [ground (int, or -1 for the map's base ground), prop kind or "", marker or ""].
const LEGEND := {
	".": [Ground.GRASS, "", ""],
	"=": [Ground.PATH, "", ""],
	",": [Ground.TALL_GRASS, "", ""],
	"T": [Ground.GRASS, "tree", ""],
	"B": [Ground.GRASS, "bush", ""],
	"P": [-1, "pole", ""],
	"W": [Ground.WATER, "", ""],
	"F": [-1, "fountain", ""],
	"S": [-1, "", "start"],
	"E": [-1, "", "exit"],
	"#": [Ground.FOREST, "", ""],
	" ": [Ground.VOID, "", ""],
	"_": [Ground.FLOOR, "", ""],
	":": [Ground.STONE, "", ""],
	"-": [Ground.SAND, "", ""],
	"*": [Ground.SNOW, "", ""],
	"~": [Ground.DEEP, "", ""],
	"%": [Ground.WALL, "", ""],
	"^": [Ground.DOCK, "", ""],
	"+": [Ground.CARPET, "", ""],
	"C": [-1, "column", ""],
	"D": [-1, "desk", ""],
	"K": [-1, "shelf", ""],
	"H": [-1, "house", ""],
	"N": [-1, "tent", ""],
	"G": [Ground.DEEP, "galley", ""],
	"R": [-1, "rock", ""],
	"U": [-1, "statue", ""],
	"X": [-1, "crate", ""],
	"Y": [-1, "palm", ""],
	"A": [-1, "altar", ""],
	"M": [-1, "stall", ""],
	"O": [-1, "throne", ""],
	"V": [-1, "vine", ""],
	"Q": [-1, "gate", ""],
	"J": [-1, "wicket", ""],
	"Z": [-1, "bones", ""],
	"L": [-1, "table", ""],
}


static func is_ground_walkable(g: int) -> bool:
	return g != Ground.VOID and g != Ground.FOREST and g != Ground.DEEP and g != Ground.WALL


static func prop_solid(kind: String) -> bool:
	return PROP_INFO[kind][0]


static func prop_radius(kind: String) -> float:
	return PROP_INFO[kind][1]


static func prop_tall(kind: String) -> bool:
	return PROP_INFO[kind][2]


static func prop_vertical(kind: String) -> bool:
	return PROP_INFO[kind][3]
