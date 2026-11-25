class_name FaultyFileOps
extends SaveFileOps
## Test double of SaveFileOps: fails chosen operations on paths containing a substring, or alters
## what a read returns, and records every call. Never used by the game.

## op ("write_bytes", "rename", "remove", "make_dir", "read_bytes") -> path substring that fails.
var fail: Dictionary = {}
## Reads of paths containing this substring return one byte less (a short read-back).
var short_read := ""
## Writes to paths containing this substring store only half of the bytes and report success.
var torn_write := ""
var calls: Array = []


func _hit(op: String, path: String) -> bool:
	return fail.has(op) and path.contains(String(fail[op]))


func read_bytes(path: String) -> Dictionary:
	calls.append(["read_bytes", path])
	if _hit("read_bytes", path):
		return {"ok": false, "bytes": PackedByteArray()}
	var r := super.read_bytes(path)
	if short_read != "" and path.contains(short_read) and r["ok"]:
		var b: PackedByteArray = r["bytes"]
		r["bytes"] = b.slice(0, maxi(0, b.size() - 1))
	return r


func write_bytes(path: String, bytes: PackedByteArray) -> bool:
	calls.append(["write_bytes", path])
	if _hit("write_bytes", path):
		return false
	if torn_write != "" and path.contains(torn_write):
		return super.write_bytes(path, bytes.slice(0, bytes.size() / 2))
	return super.write_bytes(path, bytes)


func rename(from: String, to: String) -> Error:
	calls.append(["rename", from, to])
	if _hit("rename", from) or _hit("rename", to):
		return ERR_CANT_CREATE
	return super.rename(from, to)


func remove(path: String) -> Error:
	calls.append(["remove", path])
	if _hit("remove", path):
		return ERR_CANT_OPEN
	return super.remove(path)


func make_dir(path: String) -> Error:
	calls.append(["make_dir", path])
	if _hit("make_dir", path):
		return ERR_CANT_CREATE
	return super.make_dir(path)


func ops_on(substring: String) -> Array:
	return calls.filter(func(c: Array) -> bool: return String(c[1]).contains(substring))
