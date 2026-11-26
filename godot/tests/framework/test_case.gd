class_name TestCase
extends RefCounted
## Base class for first-party tests. Methods named `test_<ID>_<description>` are discovered in
## declaration order; they may `await`. Assertions record failures without aborting the method.

var failures: PackedStringArray = []
var tree: SceneTree


func fail(msg: String) -> void:
	failures.append(msg)


func assert_true(cond: bool, msg: String = "expected true") -> bool:
	if not cond:
		fail(msg)
	return cond


func assert_false(cond: bool, msg: String = "expected false") -> bool:
	return assert_true(not cond, msg)


## Distance in units in the last place between two doubles' magnitudes.
static func ulp_of(x: float) -> float:
	x = absf(x)
	if x == 0.0:
		return 4.9e-324
	return pow(2.0, floor(log(x) / log(2.0)) - 52.0)


## Structural equality where int and float compare by value (JSON fixtures parse as floats).
## Floats may differ by at most 64 ulps (~1.4e-14 relative): Godot 4.7.2's decimal parser (JSON,
## to_float, even literals) is not correctly rounded — up to 18 ulps were measured on fixture
## values (finding F-02). Bit-exact checks compare integer encodings instead (see RNG-001).
static func values_equal(a: Variant, b: Variant) -> bool:
	if typeof(a) in [TYPE_INT, TYPE_FLOAT] and typeof(b) in [TYPE_INT, TYPE_FLOAT]:
		var fa := float(a)
		var fb := float(b)
		return fa == fb or absf(fa - fb) <= 64.0 * ulp_of(maxf(absf(fa), absf(fb)))
	if a is Dictionary and b is Dictionary:
		if a.size() != b.size():
			return false
		for k: Variant in a:
			if not b.has(k) or not values_equal(a[k], b[k]):
				return false
		return true
	var arr_types := [TYPE_ARRAY, TYPE_PACKED_BYTE_ARRAY, TYPE_PACKED_INT32_ARRAY, TYPE_PACKED_INT64_ARRAY,
		TYPE_PACKED_FLOAT32_ARRAY, TYPE_PACKED_FLOAT64_ARRAY, TYPE_PACKED_STRING_ARRAY]
	if typeof(a) in arr_types and typeof(b) in arr_types:
		if a.size() != b.size():
			return false
		for i in a.size():
			if not values_equal(a[i], b[i]):
				return false
		return true
	return typeof(a) == typeof(b) and a == b


func assert_eq(actual: Variant, expected: Variant, msg: String = "") -> bool:
	if values_equal(actual, expected):
		return true
	fail("%s expected %s, got %s" % [msg, str(expected), str(actual)])
	return false


func assert_near(actual: float, expected: float, tol: float, msg: String = "") -> bool:
	if is_finite(actual) and absf(actual - expected) <= tol:
		return true
	fail("%s expected %s ±%s, got %s (Δ=%s)" % [msg, expected, tol, actual, absf(actual - expected)])
	return false


func assert_vec_near(actual: Vector2, expected: Vector2, tol: float, msg: String = "") -> bool:
	if actual.distance_to(expected) <= tol:
		return true
	fail("%s expected %s ±%s, got %s" % [msg, expected, tol, actual])
	return false


## Hook: called before/after each test method.
func before_each() -> void:
	pass


func after_each() -> void:
	pass
