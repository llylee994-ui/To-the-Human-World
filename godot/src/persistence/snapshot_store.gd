class_name SnapshotStore
extends RefCounted

## A/B committed snapshots. A commit is only reported as committed after the
## snapshot and marker are both read back; a marker write/read failure is
## reported as uncertain so the caller can lock and re-read the same slot.

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


func _read_marker(side: String) -> Dictionary:
	var path := _marker_path(side)
	if not io.exists(path):
		return {"ok": true, "marker": null}
	var loaded: Dictionary = io.read(path)
	if not loaded.get("ok", false):
		return {"ok": false, "error": _error("SAVE_READ_FAILED", path, str(loaded.get("error", "")))}
	var marker := _parse_marker(str(loaded.get("value", "")), side)
	if marker.is_empty():
		return {"ok": false, "error": _error("SAVE_CORRUPT", path, "invalid commit marker")}
	return {"ok": true, "marker": marker}


func _current_marker() -> Dictionary:
	var left: Dictionary = _read_marker("a")
	if not left.ok:
		return left
	var right: Dictionary = _read_marker("b")
	if not right.ok:
		return right
	var marker_a = left.marker
	var marker_b = right.marker
	if marker_a == null and marker_b == null:
		return {"ok": true, "marker": null}
	if marker_a != null and marker_b != null and int(marker_a.generation) == int(marker_b.generation):
		return {"ok": false, "error": _error("SAVE_CORRUPT", "commit", "duplicate commit generation")}
	if marker_b == null or (marker_a != null and int(marker_a.generation) > int(marker_b.generation)):
		return {"ok": true, "marker": marker_a}
	return {"ok": true, "marker": marker_b}


func commit(payload: Dictionary, content_version: String, revision: int) -> Dictionary:
	if not _ensure_directory():
		return {"status": "failed", "error": _error("SAVE_WRITE_FAILED", base_dir,
			"cannot create save directory")}
	var current: Dictionary = _current_marker()
	if not current.ok:
		return {"status": "failed", "error": current.error}
	var marker = current.marker
	var side := "b" if marker != null and marker.side == "a" else "a"
	var generation := int(marker.generation) + 1 if marker != null else 1
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


func _try_load(marker: Dictionary) -> Dictionary:
	var side := str(marker.side)
	var path := _snapshot_path(side)
	var loaded: Dictionary = io.read(path)
	if not loaded.get("ok", false):
		return {"ok": false, "error": _error("SAVE_READ_FAILED", path, str(loaded.get("error", "")))}
	var raw := str(loaded.get("value", ""))
	if raw.length() != int(marker.length) or SaveCodec.sha256(raw) != str(marker.checksum):
		return {"ok": false, "error": _error("SAVE_CORRUPT", path, "snapshot hash or length mismatch")}
	var parsed = JSON.parse_string(raw)
	if typeof(parsed) != TYPE_DICTIONARY:
		return {"ok": false, "error": _error("SAVE_CORRUPT", path, "snapshot is not a JSON object")}
	if int(parsed.get("generation", -1)) != int(marker.generation):
		return {"ok": false, "error": _error("SAVE_CORRUPT", path, "generation does not match marker")}
	var verified := SaveCodec.verify(parsed)
	if not verified.ok:
		return {"ok": false, "error": verified.error}
	return {
		"ok": true,
		"status": "loaded",
		"payload": verified.value,
		"content_version": str(parsed.get("content_version", "")),
		"generation": int(marker.generation),
		"side": side,
	}


func load_latest() -> Dictionary:
	var current: Dictionary = _current_marker()
	if not current.ok:
		return {"status": "corrupt", "error": current.error}
	var marker = current.marker
	if marker == null:
		return {"status": "new"}
	var primary := _try_load(marker)
	if primary.ok:
		return primary
	# The highest marker is authoritative, but if its snapshot is damaged the
	# other committed side is still a valid fallback.
	var other_side := "b" if marker.side == "a" else "a"
	var other: Dictionary = _read_marker(other_side)
	if other.ok and other.marker != null:
		var fallback := _try_load(other.marker)
		if fallback.ok:
			fallback["recovered_from"] = marker.side
			return fallback
	return {"status": "corrupt", "error": primary.error}


func slot_exists() -> bool:
	return io.exists(_marker_path("a")) or io.exists(_marker_path("b"))


func delete_slot() -> bool:
	var removed := true
	for side in ["a", "b"]:
		for path in [_snapshot_path(side), _marker_path(side)]:
			if io.exists(path) and not io.remove(path):
				removed = false
	return removed
