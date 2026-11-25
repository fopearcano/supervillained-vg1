class_name ObjectiveMarker
extends Area2D
## An objective spot on the stage (a goal, a pickup): an Area2D on the interaction layer with a
## pulsing isometric ring. Completion is decided on the authoritative grid distance
## (contains_grid), so it is deterministic under the tests' manual ticks; the Area2D makes the
## spot queryable by physics like the source's spot rings.

var gx := 0.0
var gy := 0.0
var radius := 0.8
var color := Color("#ffe23a")
var time := 0.0


func setup(p_gx: float, p_gy: float, p_radius: float, p_color: Color) -> ObjectiveMarker:
	gx = p_gx
	gy = p_gy
	radius = p_radius
	color = p_color
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = radius * GameConfig.Iso.TILE_W / 2.0
	shape.shape = circle
	add_child(shape)
	monitoring = false
	var at := IsoGrid.grid_to_screen_xy(gx, gy)
	position = Vector2(JsMath.round(at[0]), JsMath.round(at[1]))
	z_index = -1
	return self


## Whether the grid point (x, y) is inside the spot (within `r`, default the marker's radius).
func contains_grid(x: float, y: float, r: float = -1.0) -> bool:
	var rr := radius if r < 0.0 else r
	return Vector2(x - gx, y - gy).length() <= rr


func _process(delta: float) -> void:
	time += delta
	queue_redraw()


func _draw() -> void:
	var w := radius * GameConfig.Iso.TILE_W * (0.9 + 0.1 * sin(time * 4.0))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.5))
	draw_arc(Vector2.ZERO, w / 2.0, 0.0, TAU, 32, Color(color, 0.85), 1.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
