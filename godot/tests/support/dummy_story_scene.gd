extends Node2D
## M2 dummy Story host (ARCH-001a). A minimal stand-in for the M5 story scene, kept under tests/
## (excluded from export): like GreenZoneScene it instantiates the shared IsoWorld scene as a child,
## configures a story-style map through IsoWorld's public setup(), and runs one logic tick in the
## order a story walk uses: InputService intent -> PlayableDog.update_movement on the map's grid
## solver -> IsoWorld.end_step (camera); IsoWorld.render (depth sorting) once per rendered frame.
## No gameplay rules. Freeing the host frees the world, the dog and every prop with it.

const WORLD_SCENE := preload("res://world/world_2d.tscn")

## A story-style map: no exit (the start stands in), named markers, water, props, a forest edge.
@export var rows := PackedStringArray([
	"###########",
	"#..T...1..#",
	"#.,,,.....#",
	"#..WW..B..#",
	"#S.WW...2.#",
	"#.........#",
	"###########",
])
@export var base := "."
## Tests tick by hand; the real host ticks in _physics_process.
@export var manual_ticks := false

var world: IsoWorld
var ticks := 0


func _ready() -> void:
	var parsed := AsciiMapLoader.parse(rows, base, false)
	assert(parsed["ok"], "dummy story map: %s" % parsed.get("error", ""))
	world = WORLD_SCENE.instantiate()
	add_child(world)
	world.setup(WorldMapModel.new(parsed["level"]))
	world.camera_rig.set_view_size(Vector2(216, 432))
	world.snap_camera()


func _physics_process(delta: float) -> void:
	if not manual_ticks:
		tick(delta)


## One logic tick: read the shared InputService, move through the shared controller and solver,
## then the world's end step (map timers, camera).
func tick(dt: float) -> void:
	ticks += 1
	world.player.set_intent(InputService.move_x, InputService.move_y, InputService.run_held)
	world.player.update_movement(dt, world.map)
	world.end_step(dt)


func _process(delta: float) -> void:
	world.render(delta)


## Grid centre of a named marker (digits; "S" is the start).
func marker(id: String) -> Vector2:
	var t: Vector2i = world.map.start_tile if id == "S" else world.map.markers[id]
	return Vector2(t.x + 0.5, t.y + 0.5)
