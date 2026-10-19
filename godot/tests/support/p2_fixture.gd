class_name P2Fixture
extends RefCounted

## Isolated P2 session factory. Each name gets its own user:// directory and
## never touches the P1/default slot.


static func open(name: String, onboarding: bool = false) -> Dictionary:
	var catalog := ContentCatalog.new()
	var loaded := catalog.load_catalog("res://content/generated/catalog.json")
	if not loaded.ok:
		return {"ok": false, "error": loaded.error}
	var directory := "user://godot_save_p2_%s" % name
	var store := SnapshotStore.new(directory, null, 2)
	store.delete_slot()
	var session := SessionService.new(catalog, store, {
		"schema_version": 2, "payload_version": 2, "onboarding": onboarding})
	var opened := session.load_or_new()
	if not opened.get("ok", false):
		return {"ok": false, "error": opened.get("error", {})}
	return {"ok": true, "session": session, "store": store, "catalog": catalog}


static func resume(name: String) -> Dictionary:
	var catalog := ContentCatalog.new()
	var loaded := catalog.load_catalog("res://content/generated/catalog.json")
	if not loaded.ok:
		return {"ok": false, "error": loaded.error}
	var store := SnapshotStore.new("user://godot_save_p2_%s" % name, null, 2)
	var session := SessionService.new(catalog, store, {"schema_version": 2, "payload_version": 2})
	var opened := session.load_or_new()
	if not opened.get("ok", false):
		return {"ok": false, "error": opened.get("error", {})}
	return {"ok": true, "session": session, "store": store, "catalog": catalog}


static func request(session: SessionService, request_id: String, command: String,
		payload: Dictionary = {}) -> Dictionary:
	return {
		"request_id": request_id,
		"expected_revision": int(session.snapshot().get("revision", 0)),
		"command": command,
		"payload": payload.duplicate(true),
	}
