class_name ErrorCapture
extends Logger
## Collects engine errors and warnings so a test fails on any unexpected one.

var entries: Array = []
var _mutex := Mutex.new()


func _log_error(function: String, file: String, line: int, code: String, rationale: String, _editor_notify: bool, error_type: int, _script_backtrace: Array[ScriptBacktrace]) -> void:
	_mutex.lock()
	entries.append({"type": error_type, "code": code, "rationale": rationale, "where": "%s:%d %s" % [file, line, function]})
	_mutex.unlock()


func _log_message(_message: String, _error: bool) -> void:
	pass


func take() -> Array:
	_mutex.lock()
	var out := entries
	entries = []
	_mutex.unlock()
	return out
