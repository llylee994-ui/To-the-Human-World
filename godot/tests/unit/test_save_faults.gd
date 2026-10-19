extends RefCounted

## Fault-injection tests for the A/B snapshot store and command lock.

const BASE_DIR := "fake://p1"

var assertions := 0
var completed := false


class FakeIo:
	var files: Dictionary = {}
	var fail_writes: Dictionary = {}
	var fail_reads: Dictionary = {}
	var corrupt_paths: Dictionary = {}

	func exists(path: String) -> bool:
		return files.has(path)

	func read(path: String) -> Dictionary:
		if fail_reads.has(path):
			return {"ok": false, "error": "injected read failure"}
		if not files.has(path):
			return {"ok": false, "error": "missing"}
		if corrupt_paths.has(path):
			return {"ok": true, "value": str(corrupt_paths[path])}
		return {"ok": true, "value": str(files[path])}

	func write(path: String, text: String) -> Dictionary:
		if fail_writes.has(path) or fail_writes.has("*"):
			return {"ok": false, "error": "injected write failure"}
		files[path] = text
		return {"ok": true}

	func remove(path: String) -> bool:
		files.erase(path)
		return true


func _check(failures: Array[String], condition: bool, message: String) -> void:
	assertions += 1
	if not condition:
		failures.append(message)


func _payload(revision: int, marker: String) -> Dictionary:
	return {
		"contentVersion": "ordinary-release-v3",
		"revision": revision,
		"nextOrderSerial": 1,
		"live": {"marker": marker},
	}


func run(_tree: SceneTree) -> Array[String]:
	var failures: Array[String] = []
	var catalog := ContentCatalog.new()
	var loaded: Dictionary = catalog.load_catalog("res://content/generated/catalog.json")
	_check(failures, loaded.get("ok", false), "catalog loads")
	if not loaded.get("ok", false):
		completed = true
		return failures

	var fake := FakeIo.new()
	var store := SnapshotStore.new(BASE_DIR, fake)
	_check(failures, store.load_latest().get("status", "") == "new", "empty slot is new")
	var first := store.commit(_payload(1, "one"), catalog.content_version(), 1)
	_check(failures, first.get("status", "") == "committed", "first commit succeeds")
	var loaded_first := store.load_latest()
	_check(failures, loaded_first.get("status", "") == "loaded"
		and int(loaded_first.get("generation", 0)) == 1, "first commit loads")
	var second := store.commit(_payload(2, "two"), catalog.content_version(), 2)
	_check(failures, second.get("status", "") == "committed", "second commit succeeds")
	var loaded_second := store.load_latest()
	_check(failures, int(loaded_second.get("generation", 0)) == 2
		and str(loaded_second["payload"].get("live", {}).get("marker", "")) == "two",
		"highest committed generation wins")

	# Corrupting the newest snapshot must fall back to the previous committed side.
	fake.corrupt_paths["fake://p1/state_b.json"] = "{}"
	var fallback := store.load_latest()
	_check(failures, fallback.get("status", "") == "loaded" and int(fallback.get("generation", 0)) == 1,
		"corrupt newest snapshot falls back to the previous generation")
	_check(failures, str(fallback.get("recovered_from", "")) == "b", "fallback records the damaged side")
	fake.corrupt_paths.clear()

	# Snapshot write failure: no marker, load stays on the previous state.
	var write_fake := FakeIo.new()
	var write_store := SnapshotStore.new(BASE_DIR, write_fake)
	write_fake.fail_writes["fake://p1/state_a.json"] = true
	var failed := write_store.commit(_payload(1, "failed"), catalog.content_version(), 1)
	_check(failures, failed.get("status", "") == "failed", "snapshot write failure is reported")
	_check(failures, write_store.load_latest().get("status", "") == "new",
		"failed snapshot never becomes committed")

	# Marker write failure: snapshot exists but the commit is uncertain.
	var marker_fake := FakeIo.new()
	var marker_store := SnapshotStore.new(BASE_DIR, marker_fake)
	marker_fake.fail_writes["fake://p1/state_a.commit"] = true
	var uncertain := marker_store.commit(_payload(1, "uncertain"), catalog.content_version(), 1)
	_check(failures, uncertain.get("status", "") == "uncertain", "marker write failure is uncertain")
	_check(failures, marker_store.load_latest().get("status", "") == "new",
		"uncertain commit is not loaded as committed")

	# Marker readback failure after a successful write is also uncertain.
	var read_fake := FakeIo.new()
	var read_store := SnapshotStore.new(BASE_DIR, read_fake)
	read_fake.corrupt_paths["fake://p1/state_a.commit"] = "broken"
	var read_uncertain := read_store.commit(_payload(1, "readback"), catalog.content_version(), 1)
	_check(failures, read_uncertain.get("status", "") == "uncertain", "marker readback failure is uncertain")

	# Check codec tamper detection.
	var envelope := SaveCodec.wrap(_payload(1, "checksum"), catalog.content_version(), 1, 1)
	envelope["payload"]["live"]["marker"] = "tampered"
	_check(failures, not SaveCodec.verify(envelope).get("ok", true), "checksum detects payload tampering")

	# Command-level failure must not install a candidate or consume a token.
	var command_fake := FakeIo.new()
	command_fake.fail_writes["fake://p1/state_a.json"] = true
	var command_store := SnapshotStore.new(BASE_DIR, command_fake)
	var session := SessionService.new(catalog, command_store)
	_check(failures, session.load_or_new().get("ok", false), "session opens for save-failure test")
	var letter: Dictionary = catalog.entry_ref("letters", "letter_pa_01")
	var span: Dictionary = catalog.letter_spans("letter_pa_01")[0]
	var source := {
		"wordId": span["wordId"],
		"sourceLetterInstanceId": "letter:letter_pa_01",
		"sourceSpanId": span["spanId"],
		"sourceNpcId": letter["senderId"],
	}
	var before: Dictionary = session.snapshot()
	var save_failed := session.execute({
		"request_id": "save-fails",
		"expected_revision": 0,
		"command": "cut_word",
		"payload": {"source": source},
	})
	_check(failures, not save_failed.get("ok", true), "command fails when the snapshot cannot be written")
	_check(failures, DomainResult.equal(session.snapshot(), before),
		"failed save does not install the candidate")
	_check(failures, int(session.snapshot()["revision"]) == 0, "failed save does not advance revision")

	# Uncertain commit locks the session; another command cannot proceed.
	var uncertain_fake := FakeIo.new()
	uncertain_fake.fail_writes["fake://p1/state_a.commit"] = true
	var uncertain_store := SnapshotStore.new(BASE_DIR, uncertain_fake)
	var uncertain_session := SessionService.new(catalog, uncertain_store)
	check_open(failures, uncertain_session)
	var uncertain_result := uncertain_session.execute({
		"request_id": "uncertain",
		"expected_revision": 0,
		"command": "cut_word",
		"payload": {"source": source},
	})
	_check(failures, not uncertain_result.get("ok", true), "uncertain commit is reported")
	_check(failures, str(uncertain_result.get("error", {}).get("code", "")) == "SAVE_COMMIT_UNCERTAIN",
		"uncertain commit error code")
	_check(failures, uncertain_session.is_recovery_locked(), "uncertain commit locks the session")
	var locked := uncertain_session.execute({
		"request_id": "locked",
		"expected_revision": 0,
		"command": "cut_word",
		"payload": {"source": source},
	})
	_check(failures, str(locked.get("error", {}).get("code", "")) == "RECOVERY_LOCKED",
		"locked session rejects further commands")

	completed = true
	return failures


func check_open(failures: Array[String], session: SessionService) -> void:
	_check(failures, session.load_or_new().get("ok", false), "session opens for uncertainty test")
