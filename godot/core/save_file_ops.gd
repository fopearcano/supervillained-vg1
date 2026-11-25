class_name SaveFileOps
extends RefCounted
## The file operations SaveService and the legacy importer use (one seam for tests): read, write
## with flush/close, rename, remove, directory creation. Tests replace it with a subclass that fails
## or truncates chosen operations (tests/support/faulty_file_ops.gd); the game uses this one.


func exists(path: String) -> bool:
	return FileAccess.file_exists(path)


## {"ok": bool, "bytes": PackedByteArray}
func read_bytes(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"ok": false, "bytes": PackedByteArray()}
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {"ok": false, "bytes": PackedByteArray()}
	var b := f.get_buffer(f.get_length())
	f.close()
	return {"ok": true, "bytes": b}


## Writes, flushes and closes; true when every byte was stored.
func write_bytes(path: String, bytes: PackedByteArray) -> bool:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return false
	var ok := f.store_buffer(bytes)
	f.flush()
	f.close()
	return ok


func rename(from: String, to: String) -> Error:
	return DirAccess.rename_absolute(from, to)


func remove(path: String) -> Error:
	return DirAccess.remove_absolute(path)


func make_dir(path: String) -> Error:
	return DirAccess.make_dir_recursive_absolute(path)
