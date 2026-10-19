class_name SnapshotStore
extends RefCounted

## A/B committed snapshots. A commit is only reported as committed after the
## snapshot and marker are both read back. Recovery independently inspects both
## sides so a truncated marker or damaged snapshot cannot hide the other side.

const FORMAT := "tthw-godot"


class FileIo:
	func exists(path: String) -> bool:
		return FileAccess.file_exists(path)

	func read(path: String) -> Dictionary:
		var file := FileAccess.open(path, FileAccess.READ)
		if file == null:
			return {"ok": false, "error": "cannot open %s" % path}
		var text := file.get_as_text()
		file.close()
		return {"ok": true, "value": text}

	func write(path: String, text: String) -> Dictionary:
		var file := FileAccess.open(path, FileAccess.WRITE)
		if file == null:
			return {"ok": false, "error": "cannot open %s for writing" % path}
		var written := file.store_string(text)
		file.flush()
		var error := file.get_error()
		file.close()
		return {"ok": written and error == OK, "error": "write error %d" % error}

	func remove(path: String) -> bool:
		return DirAccess.remove_absolute(ProjectSettings.globalize_path(path)) == OK


var base_dir: String
var io
var last_error: Dictionary = {}


func _init(directory: String = "user://godot_save", adapter = null) -> void:
	base_dir = directory
	io = adapter if adapter != null else FileIo.new()


func _error(code: String, path: String, message: String) -> Dictionary:
	last_error = {"code": code, "path": path, "message": message}
	return last_error


func _ensure_directory() -> bool:
	if not (io is FileIo):
		return true
	var absolute := ProjectSettings.globalize_path(base_dir)
	var error := DirAccess.make_dir_recursive_absolute(absolute)
	return error == OK or error == ERR_ALREADY_EXISTS


func _snapshot_path(side: String) -> String:
	return base_dir.path_join("state_%s.json" % side)


func _marker_path(side: String) -> String:
	return base_dir.path_join("state_%s.commit" % side)


func _marker_text(generation: int, side: String, length: int, checksum: String) -> String:
	return "%s|%d|%s|%d|%s|END" % [FORMAT, generation, side, length, checksum]


func _parse_marker(raw: String, expected_side: String) -> Dictionary:
	var parts := raw.strip_edges().split("|")
	if parts.size() != 6 or parts[0] != FORMAT or parts[2] != expected_side or parts[5] != "END":
		return {}
	if not parts[1].is_valid_int() or not parts[3].is_valid_int():
		return {}
	var generation := int(parts[1])
	var length := int(parts[3])
	if generation < 1 or length < 0 or parts[4].is_empty():
		return {}
	return {"generation": generation, "side": expected_side, "length": length, "checksum": parts[4]}


func _inspect_side(side: String) -> Dictionary:
	var marker_path := _marker_path(side)
	if not io.exists(marker_path):
		return {"side": side, "state": "empty"}
	var marker_read: Dictionary = io.read(marker_path)
	if not marker_read.get("ok", false):
		return {"side": side, "state": "marker_read_failed",
			"error": _error("SAVE_READ_FAILED", marker_path, str(marker_read.get("error", "")))}
	var marker := _parse_marker(str(marker_read.get("value", "")), side)
	if marker.is_empty():
		return {"side": side, "state": "corrupt_marker",
			"error": _error("SAVE_CORRUPT", marker_path, "invalid commit marker")}
	var snapshot_path := _snapshot_path(side)
	var snapshot_read: Dictionary = io.read(snapshot_path)
	if not snapshot_read.get("ok", false):
		return {"side": side, "state": "snapshot_read_failed", "marker": marker,
			"error": _error("SAVE_READ_FAILED", snapshot_path, str(snapshot_read.get("error", "")))}
	var raw := str(snapshot_read.get("value", ""))
	if raw.length() != int(marker.length) or SaveCodec.sha256(raw) != str(marker.checksum):
		return {"side": side, "state": "corrupt_snapshot", "marker": marker,
			"error": _error("SAVE_CORRUPT", snapshot_path, "snapshot hash or length mismatch")}
	var parsed = JSON.parse_string(raw)
	if typeof(parsed) != TYPE_DICTIONARY:
		return {"side": side, "state": "corrupt_snapshot", "marker": marker,
			"error": _error("SAVE_CORRUPT", snapshot_path, "snapshot is not a JSON object")}
	if int(parsed.get("generation", -1)) != int(marker.generation):
		return {"side": side, "state": "corrupt_snapshot", "marker": marker,
			"error": _error("SAVE_CORRUPT", snapshot_path, "generation does not match marker")}
	var verified := SaveCodec.verify(parsed)
	if not verified.ok:
		var code := str(verified.error.get("code", "SAVE_CORRUPT"))
		return {
			"side": side,
			"state": "unsupported" if code == "SAVE_UNSUPPORTED" else "corrupt_snapshot",
			"marker": marker,
			"error": verified.error,
		}
	return {
		"side": side,
		"state": "valid",
		"marker": marker,
		"payload": verified.value,
		"content_version": str(parsed.get("content_version", "")),
		"generation": int(marker.generation),
	}


func _inspect_sides() -> Dictionary:
	return {"a": _inspect_side("a"), "b": _inspect_side("b")}


func _max_marker_generation(inspection: Dictionary) -> int:
	var maximum := 0
	for side in ["a", "b"]:
		var row: Dictionary = inspection[side]
		var marker = row.get("marker")
		if typeof(marker) == TYPE_DICTIONARY:
			maximum = maxi(maximum, int(marker.get("generation", 0)))
	return maximum


func _select_valid(inspection: Dictionary) -> Dictionary:
	var valid: Array = []
	var unsupported: Array = []
	var marker_read_failed: Dictionary = {}
	var corrupt: Dictionary = {}
	var snapshot_read_failed: Dictionary = {}
	for side in ["a", "b"]:
		var row: Dictionary = inspection[side]
		match str(row.get("state", "")):
			"valid":
				valid.append(row)
			"unsupported":
				unsupported.append(row)
			"marker_read_failed":
				if marker_read_failed.is_empty():
					marker_read_failed = row
			"corrupt_marker", "corrupt_snapshot":
				if corrupt.is_empty():
					corrupt = row
			"snapshot_read_failed":
				if snapshot_read_failed.is_empty():
					snapshot_read_failed = row
	if not marker_read_failed.is_empty():
		# A failed marker read cannot tell us whether that side is newer.
		return {"status": "read_failed", "error": marker_read_failed.error}
	if not valid.is_empty():
		valid.sort_custom(func(left, right): return int(left.generation) > int(right.generation))
		if valid.size() > 1 and int(valid[0].generation) == int(valid[1].generation):
			return {"status": "corrupt", "error": _error("SAVE_CORRUPT", "commit",
				"duplicate committed generation")}
		var chosen: Dictionary = valid[0]
		var unsupported_max := 0
		var unsupported_error: Dictionary = {}
		for row in unsupported:
			var generation := int(row.marker.get("generation", 0))
			if generation >= unsupported_max:
				unsupported_max = generation
				unsupported_error = row.error
		if not unsupported_error.is_empty() and unsupported_max >= int(chosen.generation):
			return {"status": "unsupported", "error": unsupported_error}
		var ignored: Array = []
		for side in ["a", "b"]:
			var row: Dictionary = inspection[side]
			if row.state != "valid" and row.state != "empty":
				ignored.append({"side": side, "state": row.state})
		return {
			"status": "loaded",
			"side": chosen.side,
			"generation": int(chosen.generation),
			"payload": chosen.payload,
			"content_version": chosen.content_version,
			"ignored": ignored,
		}
	if not unsupported.is_empty():
		unsupported.sort_custom(func(left, right): return int(left.marker.generation) > int(right.marker.generation))
		return {"status": "unsupported", "error": unsupported[0].error}
	if not snapshot_read_failed.is_empty():
		return {"status": "read_failed", "error": snapshot_read_failed.error}
	if not corrupt.is_empty():
		return {"status": "corrupt", "error": corrupt.error}
	return {"status": "new"}


func commit(payload: Dictionary, content_version: String, revision: int) -> Dictionary:
	if not _ensure_directory():
		return {"status": "failed", "error": _error("SAVE_WRITE_FAILED", base_dir,
			"cannot create save directory")}
	var inspection := _inspect_sides()
	for side in ["a", "b"]:
		if str((inspection[side] as Dictionary).get("state", "")) == "unsupported":
			return {"status": "failed", "error": inspection[side].error}
	var selection := _select_valid(inspection)
	match str(selection.get("status", "")):
		"unsupported":
			return {"status": "failed", "error": selection.error}
		"read_failed":
			return {"status": "failed", "error": selection.error}
		"corrupt":
			return {"status": "failed", "error": selection.error}
		"loaded", "new":
			pass
		_:
			return {"status": "failed", "error": _error("SAVE_CORRUPT", "save", "unknown save state")}
	var side := "a"
	if selection.status == "loaded":
		side = "b" if str(selection.side) == "a" else "a"
	var generation := _max_marker_generation(inspection) + 1
	if generation < 1:
		generation = 1
	var envelope := SaveCodec.wrap(payload, content_version, revision, generation)
	var raw := SaveCodec.encode(envelope)
	var snapshot_path := _snapshot_path(side)
	var written: Dictionary = io.write(snapshot_path, raw)
	if not written.get("ok", false):
		return {"status": "failed", "error": _error("SAVE_WRITE_FAILED", snapshot_path,
			str(written.get("error", "snapshot write failed")))}
	var readback: Dictionary = io.read(snapshot_path)
	if not readback.get("ok", false) or str(readback.get("value", "")) != raw:
		return {"status": "failed", "error": _error("SAVE_VERIFY_FAILED", snapshot_path,
			"snapshot readback does not match")}
	var marker_path := _marker_path(side)
	var marker_text := _marker_text(generation, side, raw.length(), SaveCodec.sha256(raw))
	var marker_written: Dictionary = io.write(marker_path, marker_text)
	if not marker_written.get("ok", false):
		return {"status": "uncertain", "error": _error("SAVE_COMMIT_UNCERTAIN", marker_path,
			"snapshot written but commit marker write failed")}
	var marker_readback: Dictionary = io.read(marker_path)
	if not marker_readback.get("ok", false) or str(marker_readback.get("value", "")) != marker_text:
		return {"status": "uncertain", "error": _error("SAVE_COMMIT_UNCERTAIN", marker_path,
			"snapshot written but commit marker readback failed")}
	return {
		"status": "committed",
		"generation": generation,
		"side": side,
		"envelope": envelope,
	}


func load_latest() -> Dictionary:
	var selection := _select_valid(_inspect_sides())
	match str(selection.get("status", "")):
		"loaded":
			return selection
		"unsupported":
			return {"status": "unsupported", "error": selection.error}
		"read_failed":
			return {"status": "read_failed", "error": selection.error}
		"corrupt":
			return {"status": "corrupt", "error": selection.error}
	return {"status": "new"}


func slot_exists() -> bool:
	return io.exists(_marker_path("a")) or io.exists(_marker_path("b"))


func delete_slot() -> bool:
	var removed := true
	for side in ["a", "b"]:
		for path in [_snapshot_path(side), _marker_path(side)]:
			if io.exists(path) and not io.remove(path):
				removed = false
	return removed
