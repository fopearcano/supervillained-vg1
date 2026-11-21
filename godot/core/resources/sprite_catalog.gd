class_name SpriteCatalog
extends Resource
## Editor-generated catalogue of static sprites (props, items, HUD icons): key -> texture and
## anchor (pixels from the texture's top-left to the contact point). Built by
## tools/build_resources.gd from the source manifests; never assembled at runtime.

## key ("tree_0", "treat_0", ...) -> {"texture": Texture2D, "anchor": Vector2i, "size": Vector2i}
@export var entries: Dictionary = {}


func has_key(key: String) -> bool:
	return entries.has(key)


func texture(key: String) -> Texture2D:
	assert(entries.has(key), "SpriteCatalog: missing sprite '%s'" % key)
	return entries[key]["texture"]


func anchor(key: String) -> Vector2i:
	return entries[key]["anchor"]


func size_of(key: String) -> Vector2i:
	return entries[key]["size"]
