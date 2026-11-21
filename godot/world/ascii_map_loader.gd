class_name AsciiMapLoader
extends RefCounted
## Port of the implemented ASCII branch of src/world/level.ts (the reserved Tiled branch is not
## ported). Rows are gy (top to bottom), columns gx (left to right); short rows pad with void.
## Returns {"ok": true, "level": {...}} or {"ok": false, "error": String} with the source's text.


static func parse(rows: PackedStringArray, base: String = ".", require_exit: bool = true) -> Dictionary:
	var base_entry: Variant = TileCatalog.LEGEND.get(base)
	if base_entry == null or int(base_entry[0]) == -1:
		return {"ok": false, "error": "Bad base ground '%s'" % base}
	var base_ground: int = base_entry[0]
	var height := rows.size()
	if height == 0:
		return {"ok": false, "error": "Empty map"}
	var width := 0
	for r in rows:
		width = maxi(width, r.length())
	var ground := PackedByteArray()
	ground.resize(width * height)
	var props: Array = []
	var markers := {}
	var start: Variant = null
	var exit: Variant = null
	for j in height:
		var row := rows[j]
		for i in width:
			var ch := row[i] if i < row.length() else " "
			if ch >= "0" and ch <= "9":
				ground[j * width + i] = base_ground
				markers[ch] = Vector2i(i, j)
				continue
			var entry: Variant = TileCatalog.LEGEND.get(ch)
			if entry == null:
				return {"ok": false, "error": "Unknown map symbol '%s' at row %d, column %d" % [ch, j, i]}
			ground[j * width + i] = base_ground if int(entry[0]) == -1 else int(entry[0])
			if entry[1] != "":
				props.append({"kind": entry[1], "i": i, "j": j})
			if entry[2] == "start":
				if start != null:
					return {"ok": false, "error": "Duplicate start 'S' at row %d, column %d" % [j, i]}
				start = Vector2i(i, j)
			elif entry[2] == "exit":
				if exit != null:
					return {"ok": false, "error": "Duplicate exit 'E' at row %d, column %d" % [j, i]}
				exit = Vector2i(i, j)
	if start == null:
		return {"ok": false, "error": "Map has no start 'S'"}
	if exit == null and require_exit:
		return {"ok": false, "error": "Map has no exit 'E'"}
	return {"ok": true, "level": {
		"width": width, "height": height, "ground": ground, "props": props,
		"start": start, "exit": exit if exit != null else start, "markers": markers,
	}}
