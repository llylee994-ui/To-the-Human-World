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
	var ignored: Array = fallback.get("ignored", [])
	_check(failures, ignored.size() == 1 and str(ignored[0].get("side", "")) == "b",
		"fallback records the damaged side")
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


	# S01: after fallback to A, a new commit must write B and keep A intact.
	var s01_fake := FakeIo.new()
	var s01_store := SnapshotStore.new(BASE_DIR, s01_fake)
	_check(failures, s01_store.commit(_payload(1, "one"), catalog.content_version(), 1).get("status", "") == "committed",
		"S01 first commit")
	_check(failures, s01_store.commit(_payload(2, "two"), catalog.content_version(), 2).get("status", "") == "committed",
		"S01 second commit")
	var a_before := str(s01_fake.files["fake://p1/state_a.json"])
	s01_fake.files["fake://p1/state_b.json"] = "{}"
	_check(failures, s01_store.load_latest().get("status", "") == "loaded"
		and int(s01_store.load_latest().get("generation", 0)) == 1, "S01 falls back to A")
	var s01_next := s01_store.commit(_payload(3, "three"), catalog.content_version(), 3)
	_check(failures, s01_next.get("status", "") == "committed" and str(s01_next.get("side", "")) == "b",
		"S01 writes the inactive side B")
	_check(failures, str(s01_fake.files["fake://p1/state_a.json"]) == a_before,
		"S01 leaves the only valid A snapshot intact")
	_check(failures, s01_store.load_latest().get("status", "") == "loaded"
		and int(s01_store.load_latest().get("generation", 0)) == 3, "S01 loads the new B generation")
	s01_fake.files["fake://p1/state_b.json"] = "partial"
	s01_fake.fail_writes["fake://p1/state_b.json"] = true
	_check(failures, s01_store.commit(_payload(4, "four"), catalog.content_version(), 4).get("status", "") == "failed",
		"S01 short write on B fails")
	_check(failures, s01_store.load_latest().get("status", "") == "loaded"
		and int(s01_store.load_latest().get("generation", 0)) == 1, "S01 still recovers A after B short write")

	# S02: a complete future-version commit must not fall back to an older current save.
	var s02_fake := FakeIo.new()
	var s02_store := SnapshotStore.new(BASE_DIR, s02_fake)
	_check(failures, s02_store.commit(_payload(1, "current"), catalog.content_version(), 1).get("status", "") == "committed",
		"S02 current commit")
	var future := SaveCodec.wrap(_payload(2, "future"), catalog.content_version(), 2, 2)
	future["schema_version"] = 2
	var future_raw := SaveCodec.encode(future)
	s02_fake.files["fake://p1/state_b.json"] = future_raw
	s02_fake.files["fake://p1/state_b.commit"] = "tthw-godot|2|b|%d|%s|END" % [
		future_raw.length(), SaveCodec.sha256(future_raw)]
	_check(failures, str(s02_store.load_latest().get("status", "")) == "unsupported",
		"S02 future version is not silently downgraded")
	var s02_session := SessionService.new(catalog, s02_store)
	var s02_open := s02_session.load_or_new()
	_check(failures, not s02_open.get("ok", true)
		and str(s02_open.get("error", {}).get("code", "")) == "SAVE_UNSUPPORTED",
		"S02 session locks with SAVE_UNSUPPORTED")
	_check(failures, s02_session.is_recovery_locked(), "S02 session stays locked")
	var only_future := FakeIo.new()
	only_future.files["fake://p1/state_b.json"] = future_raw
	only_future.files["fake://p1/state_b.commit"] = s02_fake.files["fake://p1/state_b.commit"]
	_check(failures, str(SnapshotStore.new(BASE_DIR, only_future).load_latest().get("status", "")) == "unsupported",
		"S02 future-only slot is unsupported")

	# S03: a truncated marker on one side must not hide a valid other side.
	var s03_fake := FakeIo.new()
	var s03_store := SnapshotStore.new(BASE_DIR, s03_fake)
	_check(failures, s03_store.commit(_payload(1, "one"), catalog.content_version(), 1).get("status", "") == "committed",
		"S03 first commit")
	s03_fake.files["fake://p1/state_b.commit"] = "tthw-godot|2|b|"
	var s03_load := s03_store.load_latest()
	_check(failures, s03_load.get("status", "") == "loaded" and int(s03_load.get("generation", 0)) == 1,
		"S03 truncated B marker still loads A")
	s03_fake.files.erase("fake://p1/state_b.commit")
	_check(failures, s03_store.load_latest().get("status", "") == "loaded",
		"S03 missing B marker still loads A")
	s03_fake.files["fake://p1/state_b.commit"] = "unreadable"
	s03_fake.fail_reads["fake://p1/state_b.commit"] = true
	_check(failures, str(s03_store.load_latest().get("status", "")) == "read_failed",
		"S03 marker read failure is indeterminate and locks")
	var s03_session := SessionService.new(catalog, s03_store)
	var s03_open := s03_session.load_or_new()
	_check(failures, str(s03_open.get("error", {}).get("code", "")) == "SAVE_READ_FAILED",
		"S03 session reports SAVE_READ_FAILED")

	# S04: after reload, an uncertain request must reconcile instead of caching forever.
	var s04_source := _source(catalog)
	var s04_fake := FakeIo.new()
	var s04_store := SnapshotStore.new(BASE_DIR, s04_fake)
	var s04_session := SessionService.new(catalog, s04_store)
	check_open(failures, s04_session)
	s04_fake.corrupt_paths["fake://p1/state_a.commit"] = "broken"
	var s04_cut := s04_session.execute({
		"request_id": "s04-cut",
		"expected_revision": 0,
		"command": "cut_word",
		"payload": {"source": s04_source},
	})
	_check(failures, str(s04_cut.get("error", {}).get("code", "")) == "SAVE_COMMIT_UNCERTAIN",
		"S04 first attempt is uncertain")
	s04_fake.corrupt_paths.clear()
	var s04_reload := s04_session.reload()
	_check(failures, s04_reload.get("ok", false) and int(s04_reload.get("revision", -1)) == 1,
		"S04 reload succeeds")
	var s04_retry := s04_session.execute({
		"request_id": "s04-cut",
		"expected_revision": 0,
		"command": "cut_word",
		"payload": {"source": s04_source},
	})
	_check(failures, s04_retry.get("ok", false) and int(s04_retry.get("revision", -1)) == 1,
		"S04 retry reconciles to the committed result")
	_check(failures, not s04_session.is_recovery_locked(), "S04 reconciliation unlocks the session")

	# S04b: if the marker was not committed, reload allows a clean retry.
	var s04b_fake := FakeIo.new()
	var s04b_store := SnapshotStore.new(BASE_DIR, s04b_fake)
	var s04b_session := SessionService.new(catalog, s04b_store)
	check_open(failures, s04b_session)
	s04b_fake.fail_writes["fake://p1/state_a.commit"] = true
	var s04b_cut := s04b_session.execute({
		"request_id": "s04b-cut",
		"expected_revision": 0,
		"command": "cut_word",
		"payload": {"source": s04_source},
	})
	_check(failures, str(s04b_cut.get("error", {}).get("code", "")) == "SAVE_COMMIT_UNCERTAIN",
		"S04b marker failure is uncertain")
	s04b_fake.fail_writes.clear()
	var s04b_reload := s04b_session.reload()
	_check(failures, s04b_reload.get("ok", false) and int(s04b_reload.get("revision", -1)) == 0,
		"S04b reload returns the uncommitted revision")
	var s04b_retry := s04b_session.execute({
		"request_id": "s04b-cut",
		"expected_revision": 0,
		"command": "cut_word",
		"payload": {"source": s04_source},
	})
	_check(failures, s04b_retry.get("ok", false) and int(s04b_retry.get("revision", -1)) == 1,
		"S04b retry commits after reconciliation")

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


func _source(catalog: ContentCatalog) -> Dictionary:
	var letter: Dictionary = catalog.entry_ref("letters", "letter_pa_01")
	var span: Dictionary = catalog.letter_spans("letter_pa_01")[0]
	return {
		"wordId": span["wordId"],
		"sourceLetterInstanceId": "letter:letter_pa_01",
		"sourceSpanId": span["spanId"],
		"sourceNpcId": letter["senderId"],
	}


func check_open(failures: Array[String], session: SessionService) -> void:
	_check(failures, session.load_or_new().get("ok", false), "session opens for uncertainty test")
