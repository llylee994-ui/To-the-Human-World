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


static func collect_first(session: SessionService) -> Dictionary:
	var salvage := session.query("salvage")
	if not salvage.get("ok", false):
		return salvage
	var ids: Array = salvage.value.get("availableLetterIds", [])
	if ids.is_empty():
		return DomainResult.fail("LETTER_NOT_AVAILABLE", "salvage", "no letter is available")
	var letter_id := str(ids[0])
	var received := session.execute(request(session, "p2-receive", "receive_letter",
		{"letterId": letter_id}))
	if not received.get("ok", false):
		return received
	var instance_id := str(received.value.get("letterInstanceId", ""))
	var read := session.execute(request(session, "p2-read", "read_letter",
		{"letterInstanceId": instance_id}))
	if not read.get("ok", false):
		return read
	var letter := session.query("letter", {"letterInstanceId": instance_id})
	if not letter.get("ok", false):
		return letter
	var tokens: Dictionary = {}
	for span in letter.value.get("spans", []):
		var cut := session.execute(request(session, "p2-cut-" + str(span["spanId"]),
			"cut_word", {"letterInstanceId": instance_id, "spanId": span["spanId"]}))
		if not cut.get("ok", false):
			return cut
		tokens[str(span["wordId"])] = str(cut.value.get("tokenId", ""))
	return {"ok": true, "letterInstanceId": instance_id, "tokensByWordId": tokens}


static func request(session: SessionService, request_id: String, command: String,
		payload: Dictionary = {}) -> Dictionary:
	return {
		"request_id": request_id,
		"expected_revision": int(session.snapshot().get("revision", 0)),
		"command": command,
		"payload": payload.duplicate(true),
	}
