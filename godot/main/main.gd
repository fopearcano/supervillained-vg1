extends Node
## Persistent root: owns scene replacement and the overlay stack inside the pixel viewport.
## Scenes and overlays are instanced into GameViewport; nothing renders outside it except the
## black letterbox.

const GREEN_ZONE_SCENE := preload("res://scenes/green_zone/green_zone_scene.tscn")

@onready var viewport_controller: PixelViewportController = $ViewportController
@onready var game_viewport: SubViewport = %GameViewport
@onready var scene_host: Node = %SceneHost
@onready var overlay_host: Control = %OverlayHost
@onready var transition_host: Control = %TransitionHost
## The game's own background inside the pixel viewport (source renderer background 0x0c3a10);
## everything outside the viewport stays the black clear colour (the source's black page).
@onready var underlay: ColorRect = %Underlay

const UNDERLAY_COLOR := Color8(0x0c, 0x3a, 0x10)

var current_scene: Node = null


func _ready() -> void:
	viewport_controller.viewport_changed.connect(_on_viewport_changed)
	_on_viewport_changed(viewport_controller.logical_size, viewport_controller.scale)
	start_green_zone()


func _on_viewport_changed(logical: Vector2i, _scale: int) -> void:
	underlay.color = UNDERLAY_COLOR
	underlay.size = Vector2(logical)
	overlay_host.size = Vector2(logical)
	transition_host.size = Vector2(logical)
	if current_scene and current_scene.has_method("resize"):
		current_scene.resize(logical)


func change_scene(packed: PackedScene) -> Node:
	clear_overlays()
	if current_scene:
		scene_host.remove_child(current_scene)
		current_scene.queue_free()
	current_scene = packed.instantiate()
	if current_scene.has_method("bind_main"):
		current_scene.bind_main(self)
	scene_host.add_child(current_scene)
	if current_scene.has_method("resize"):
		current_scene.resize(viewport_controller.logical_size)
	return current_scene


func start_green_zone() -> void:
	var scene := change_scene(GREEN_ZONE_SCENE)
	scene.restart_requested.connect(start_green_zone, CONNECT_DEFERRED)


func push_overlay(overlay: Control) -> void:
	overlay_host.add_child(overlay)
	overlay.size = overlay_host.size


func pop_overlay(overlay: Control) -> void:
	if overlay and overlay.get_parent() == overlay_host:
		overlay_host.remove_child(overlay)
		overlay.queue_free()


func clear_overlays() -> void:
	for child in overlay_host.get_children():
		overlay_host.remove_child(child)
		child.queue_free()


func logical_size() -> Vector2i:
	return viewport_controller.logical_size
