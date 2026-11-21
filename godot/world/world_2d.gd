class_name IsoWorld
extends Node2D
## A playable isometric world (port of src/world/world.ts): ground/pollution TileMapLayers,
## depth-sorted objects, the playable dog and the camera. Shared by the Green Zone and (from M5)
## every story stage: callers provide a WorldMapModel and optional entities; nothing here is
## Green-Zone specific.

const DOG_SCENE := preload("res://entities/playable_dog/playable_dog.tscn")
const CHUNK := 8
const GRASS_WIND_PHASES := 4

@export var tileset: TileSet
@export var catalog: SpriteCatalog

var map: WorldMapModel
var player: PlayableDog
## Extra vertical camera offset (px).
var camera_lift := 10.0
## Screen-space bounds of every drawn ground tile.
var map_bounds := Rect2()
var visible_count := 0

var _tile_coords: Dictionary = {}
var _dynamic: Array[IsoRenderable] = []
var _chunks: Dictionary = {}  # Vector2i -> {"items": Array[IsoRenderable], "rect": Rect2}
var _frame := 0
var _shown: Array[IsoRenderable] = []

@onready var ground_layer: GroundLayer = $GroundLayer
@onready var pollution_layer: OverlayLayer = $PollutionLayer
@onready var fresh_layer: OverlayLayer = $FreshLayer
@onready var decal_layer: Node2D = $DecalLayer
@onready var object_layer: Node2D = $ObjectLayer
@onready var fx_layer: Node2D = $FxLayer
@onready var camera_rig: CameraRig = $CameraRig


## Environment bank the tileset was built from (floor designs must target the same bank).
var environment := "ch01_greenzone"
## Why the last requested floor design was refused ("" = applied or none requested).
var floor_design_rejection := ""
var _floor_coords: Dictionary = {}


## Builds the world for a map. Options: `forest` (default true) adds decorative forest trees;
## `floor_design` (a Color Ink floor composition) changes ground VISUALS only — never the model,
## collision or markers (MAP-006). The Green Zone passes none (AST-014).
func setup(p_map: WorldMapModel, options: Dictionary = {}) -> void:
	map = p_map
	_tile_coords = tileset.get_meta(&"tile_coords")
	_floor_coords = tileset.get_meta(&"floor_art_coords", {})
	for layer: TileMapLayer in [ground_layer, pollution_layer, fresh_layer]:
		layer.tile_set = tileset
		layer.position = IsoGrid.TILE_LAYER_OFFSET
	pollution_layer.tiles = [_tile_coords["dirt_0"], _tile_coords["dirt_1"], _tile_coords["dirt_2"], _tile_coords["dirt_3"]]
	fresh_layer.tiles = [_tile_coords["fresh_0"]]
	_build_ground(options.get("floor_design", {}))
	for p in map.props:
		var sp: Array = TileCatalog.PROP_SPRITE[p.kind]
		var v := int(floor(DeterministicRng.hash2(p.i, p.j, 3) * int(sp[1])))
		var prop := IsoProp.new().setup(catalog, "%s_%d" % [sp[0], v], p.x, p.y, p, p.tall)
		if p.kind == "bush" or p.kind == "vine":
			prop.iso.depth_bias = 0.1
		add_static(prop, prop.iso)
	_spawn_wall_blocks()
	if options.get("forest", true):
		_spawn_forest()
	player = DOG_SCENE.instantiate()
	# The developer `--as=` profile (AppState.selected_profile, Zampanò by default); a caller may
	# pass options.profile (a PROFILES id) instead.
	var profile_id: StringName = options.get("profile", AppState.selected_profile)
	player.profile = load(AppState.PROFILES[profile_id])
	object_layer.add_child(player)
	player.set_grid_position(map.start.x, map.start.y)
	player.face("N")
	add_dynamic(player.iso)
	camera_rig.model.set_bounds(walkable_bounds(4))


func _tile(name: String) -> Vector2i:
	assert(_tile_coords.has(name), "tileset lacks " + name)
	return _tile_coords[name]


## A floor design applies only to the exact map size and the same environment bank (source
## floorDesignForMap); otherwise it is refused and the native ground choices are kept.
func _validate_floor_design(design: Dictionary) -> bool:
	floor_design_rejection = ""
	if design.is_empty():
		return false
	if String(design.get("environment", "")) != environment:
		floor_design_rejection = "environment"
	elif int(design.get("width", -1)) != map.width or int(design.get("height", -1)) != map.height:
		floor_design_rejection = "dimensions"
	elif not design.get("tiles") is Dictionary:
		floor_design_rejection = "tiles"
	return floor_design_rejection == ""


## Source floorFrameForGround: authored frames replace only flat grounds; wet, tall, blocked and
## void cues always keep their native tiles.
static func floor_design_applies(ground: int) -> bool:
	var G := TileCatalog.Ground
	return ground in [G.GRASS, G.PATH, G.FLOOR, G.STONE, G.SAND, G.SNOW, G.DOCK, G.CARPET]


## Port of MapRenderer.makeTile: the same deterministic variant hashes per cell.
func _build_ground(design: Dictionary = {}) -> void:
	var G := TileCatalog.Ground
	var use_design := _validate_floor_design(design)
	var design_tiles: Dictionary = design.get("tiles", {}) if use_design else {}
	var min_p := Vector2(INF, INF)
	var max_p := Vector2(-INF, -INF)
	for j in map.height:
		for i in map.width:
			var g := map.ground_at(i, j)
			var h := DeterministicRng.hash2(i, j, 1)
			var name := ""
			match g:
				G.VOID:
					continue
				G.GRASS:
					name = "grass_%d" % (3 if h < 0.1 else int(floor(DeterministicRng.hash2(j, i, 2) * 3)))
				G.TALL_GRASS:
					name = "tallGrass_phase%d" % int(floor(DeterministicRng.hash2(i, j, 72) * GRASS_WIND_PHASES))
				G.PATH:
					var mask := (1 if map.ground_at(i, j - 1) != G.PATH else 0) | (2 if map.ground_at(i + 1, j) != G.PATH else 0) \
						| (4 if map.ground_at(i, j + 1) != G.PATH else 0) | (8 if map.ground_at(i - 1, j) != G.PATH else 0)
					name = "path_%d_%d" % [mask, int(floor(h * 2))]
				G.WATER:
					name = "water_phase%d" % int(floor(DeterministicRng.hash2(i, j, 73) * 2))
				G.FOREST:
					name = "forest_%d" % int(floor(h * 3))
				G.DEEP:
					name = "deep_phase%d" % int(floor(DeterministicRng.hash2(i, j, 74) * 2))
				G.WALL:
					name = "wallBase_0"
				G.FLOOR, G.STONE, G.SAND, G.SNOW, G.DOCK, G.CARPET:
					var kind: String = {G.FLOOR: "floor", G.STONE: "stone", G.SAND: "sand", G.SNOW: "snow", G.DOCK: "dock", G.CARPET: "carpet"}[g]
					name = "%s_%d" % [kind, int(floor(h * 3))]
				_:
					push_error("IsoWorld: unknown ground %d" % g)
					continue
			var cell := Vector2i(i, j)
			var authored: String = design_tiles.get(str(map.index(i, j)), "")
			if authored != "" and floor_design_applies(g) and _floor_coords.has(authored):
				ground_layer.set_cell(cell, 1, _floor_coords[authored])
			else:
				ground_layer.set_cell(cell, 0, _tile(name))
			var top := IsoGrid.grid_to_screen(i, j)
			min_p = Vector2(minf(min_p.x, top.x - 16), minf(min_p.y, top.y - 6))
			max_p = Vector2(maxf(max_p.x, top.x + 16), maxf(max_p.y, top.y + 16))
	map_bounds = Rect2(min_p, max_p - min_p)


## Wall tiles near walkable ground are drawn as depth-sorted blocks (source spawnWallBlocks).
func _spawn_wall_blocks() -> void:
	for j in map.height:
		for i in map.width:
			if map.ground_at(i, j) != TileCatalog.Ground.WALL:
				continue
			var near := false
			for b in range(-2, 3):
				for a in range(-2, 3):
					if map.is_walkable(i + a, j + b):
						near = true
						break
				if near:
					break
			if not near:
				continue
			var v := int(floor(DeterministicRng.hash2(i, j, 5) * 2))
			var block := IsoProp.new().setup(catalog, "wallBlock_%d" % v, i + 0.5, j + 0.5, null, true)
			add_static(block, block.iso)


## Decorative trees on forest tiles near the playable area (and a few deeper ones).
func _spawn_forest() -> void:
	for j in map.height:
		for i in map.width:
			if map.ground_at(i, j) != TileCatalog.Ground.FOREST:
				continue
			var near := false
			for b in range(-2, 3):
				for a in range(-2, 3):
					if map.is_walkable(i + a, j + b):
						near = true
						break
				if near:
					break
			var h := DeterministicRng.hash2(i, j, 21)
			if (near and h < 0.42) or (not near and h < 0.05):
				var v := 0 if DeterministicRng.hash2(i, j, 22) < 0.5 else 1
				var prop := IsoProp.new().setup(catalog, "forestTree_%d" % v, i + 0.5, j + 0.5, null, true)
				add_static(prop, prop.iso)


## Screen-space bounds of the walkable area grown by margin tiles (camera clamp).
func walkable_bounds(margin_tiles: int) -> Rect2:
	var x0 := INF
	var y0 := INF
	var x1 := -INF
	var y1 := -INF
	for j in map.height:
		for i in map.width:
			if not map.is_walkable(i, j):
				continue
			var c := IsoGrid.grid_to_screen_xy(i + 0.5, j + 0.5)
			x0 = minf(x0, c[0])
			x1 = maxf(x1, c[0])
			y0 = minf(y0, c[1])
			y1 = maxf(y1, c[1])
	var mx := margin_tiles * 16.0
	var my := margin_tiles * 8.0
	var b := map_bounds
	var x := maxf(b.position.x, x0 - mx)
	var y := maxf(b.position.y, y0 - my - 40.0)
	return Rect2(x, y, minf(b.end.x, x1 + mx) - x, minf(b.end.y, y1 + my + 40.0) - y)


## Objects that never move are bucketed by map chunk so culling only scans nearby chunks.
func add_static(node: Node2D, iso: IsoRenderable) -> void:
	object_layer.add_child(node)
	var key := Vector2i(int(floor(iso.gx / CHUNK)), int(floor(iso.gy / CHUNK)))
	if not _chunks.has(key):
		_chunks[key] = {"items": [] as Array[IsoRenderable], "rect": iso.screen_rect()}
	var chunk: Dictionary = _chunks[key]
	(chunk["items"] as Array[IsoRenderable]).append(iso)
	chunk["rect"] = (chunk["rect"] as Rect2).merge(iso.screen_rect())


func add_dynamic(iso: IsoRenderable) -> void:
	_dynamic.append(iso)


func add_dynamic_node(node: Node2D, iso: IsoRenderable) -> void:
	object_layer.add_child(node)
	_dynamic.append(iso)


func remove_dynamic(iso: IsoRenderable) -> void:
	_dynamic.erase(iso)
	_shown.erase(iso)
	if is_instance_valid(iso.node):
		iso.node.queue_free()


func snap_camera() -> void:
	var s := IsoGrid.grid_to_screen_xy(player.gx, player.gy)
	camera_rig.snap(s[0], s[1] - camera_lift)
	player.reset_physics_interpolation()


## End of a logic tick: map timers and the camera (port of World.endStep).
func end_step(dt: float) -> void:
	map.update(dt)
	var ps := IsoGrid.grid_to_screen_xy(player.gx, player.gy)
	var v := IsoGrid.grid_vec_to_screen(player.vx, player.vy)
	camera_rig.step(dt, ps[0], ps[1] - camera_lift, v.x, v.y)


## Presentation pass (port of World.render + MapRenderer.update): pollution layers, culling,
## occlusion fade and painter ranks. Called once per rendered frame.
func render(frame_dt: float) -> void:
	_frame += 1
	if not map.changed.is_empty():
		var changed: Array = map.changed.keys()
		map.changed.clear()
		ground_layer.apply_changes(map, changed)
		pollution_layer.apply_changes(map, changed)
		fresh_layer.apply_changes(map, changed)
	var view := camera_rig.view_rect()
	var cull := Rect2(view.position + IsoDepthSorter.CULL_MARGIN.position, view.size + IsoDepthSorter.CULL_MARGIN.size)
	var candidates: Array[IsoRenderable] = _dynamic.duplicate()
	for key: Vector2i in _chunks:
		var chunk: Dictionary = _chunks[key]
		if IsoRenderable.rects_overlap(chunk["rect"], cull):
			candidates.append_array(chunk["items"])
	visible_count = IsoDepthSorter.apply(candidates, view, player.iso, frame_dt)
	var stamp := {}
	for r in candidates:
		stamp[r] = true
	for r in _shown:
		if not stamp.has(r) and is_instance_valid(r.node):
			r.node.visible = false
	_shown = candidates
