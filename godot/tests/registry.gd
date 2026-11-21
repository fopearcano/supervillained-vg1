class_name TestRegistry
extends RefCounted
## Explicit registry of test scripts per suite (no filesystem discovery).

const SUITES := {
	"unit": [
		"res://tests/unit/test_core.gd",
		"res://tests/unit/test_map.gd",
		"res://tests/unit/test_needs_rules.gd",
		"res://tests/unit/test_dog.gd",
		"res://tests/unit/test_save.gd",
		"res://tests/unit/test_isolation.gd",
	],
	"content": [
		"res://tests/content/test_assets.gd",
	],
	"integration": [
		"res://tests/integration/test_world.gd",
		"res://tests/integration/test_green_zone.gd",
		"res://tests/integration/test_collision_decision.gd",
		"res://tests/integration/test_main_and_rates.gd",
	],
}
