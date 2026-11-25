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
## The glitch burst between scenes (source game.transition + Flow.glitch).
var transition: GlitchTransition
## Stub receiver of the Green Zone → 1.1 campaign handoff (the story arrives with M4/M5).
var campaign := CampaignHandoff.Receiver.new()


func _ready() -> void:
	transition = GlitchTransition.new()
	transition_host.add_child(transition)
	viewport_controller.viewport_changed.connect(_on_viewport_changed)
	_on_viewport_changed(viewport_controller.logical_size, viewport_controller.scale)
	start_green_zone()


func _on_viewport_changed(logical: Vector2i, _scale: int) -> void:
	underlay.color = UNDERLAY_COLOR
	underlay.size = Vector2(logical)
	overlay_host.size = Vector2(logical)
	transition_host.size = Vector2(logical)
	if transition:
		transition.size = Vector2(logical)
	if current_scene and current_scene.has_method("resize"):
		current_scene.resize(logical)


func change_scene(packed: PackedScene, configure: Callable = Callable()) -> Node:
	clear_overlays()
	if current_scene:
		scene_host.remove_child(current_scene)
		current_scene.queue_free()
	current_scene = packed.instantiate()
	if configure.is_valid():
		configure.call(current_scene)
	if current_scene.has_method("bind_main"):
		current_scene.bind_main(self)
	scene_host.add_child(current_scene)
	if current_scene.has_method("resize"):
		current_scene.resize(viewport_controller.logical_size)
	return current_scene


## Starts the Green Zone: with the briefing (start-up, the title stand-in) or straight into
## play (source Flow.play: RESTART / RETRY).
func start_green_zone(briefing: bool = true) -> void:
	var scene := change_scene(GREEN_ZONE_SCENE, func(n: Node) -> void: n.set("show_briefing", briefing))
	scene.restart_requested.connect(restart_green_zone)
	scene.title_requested.connect(quit_to_title)
	scene.campaign_handoff.connect(_on_campaign_handoff)


## RESTART / RETRY (source Flow.restart): click, glitch, a clean run straight into play. The
## replacement happens in the deferred flush after the transition's midpoint.
func restart_green_zone() -> void:
	AudioService.play(&"click")
	transition.play(func() -> void: start_green_zone.call_deferred(false))


## QUIT / TITLE (source Flow.quitToTitle). The title arrives with M4; until then the Green Zone
## briefing stands in for it.
func quit_to_title() -> void:
	AudioService.play(&"click")
	transition.play(func() -> void: start_green_zone.call_deferred(true))


## CONTINUE on the level end (source Flow.levelComplete next: glitch, then the story's 1.1). The
## receiver is a stub: it records the handoff; with no story yet the title stand-in follows.
func _on_campaign_handoff(data: Dictionary) -> void:
	campaign.receive(data)
	transition.play(func() -> void: start_green_zone.call_deferred(true))


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
