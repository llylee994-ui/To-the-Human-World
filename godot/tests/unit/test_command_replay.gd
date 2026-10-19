extends RefCounted

## Task 2: persistent request identity, cross-session replay and safe retry.

const P2FixtureScript = preload("res://tests/support/p2_fixture.gd")

var assertions := 0
var completed := false


class FakeIo:
	var files: Dictionary = {}
	var fail_writes: Dictionary = {}

	func exists(path: String) -> bool:
		return files.has(path)

	func read(path: String) -> Dictionary:
		return {"ok": files.has(path), "value": files.get(path, "")}

	func write(path: String, text: String) -> Dictionary:
		if fail_writes.has(path):
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


func run(_tree: SceneTree) -> Array[String]:
	var failures: Array[String] = []
	var ctx := P2FixtureScript.open("command-replay")
	_check(failures, ctx.get("ok", false), "P2 fixture opens")
	if not ctx.get("ok", false):
		completed = true
		return failures
	var session: SessionService = ctx.session
	var store: SnapshotStore = ctx.store
	var start := P2FixtureScript.request(session, "start-1", "start_journey", {})
	var first := session.execute(start)
	_check(failures, first.get("ok", false) and int(first.get("revision", -1)) == 1,
		"start_journey commits revision 1")
	_check(failures, session.snapshot().get("chapter", {}).get("started") == true,
		"start_journey marks the journey started")
	_check(failures, not session.snapshot().get("commandLedger", {}).get("byRequestId", {}).is_empty(),
		"start_journey records the request")
	var before_replay: Dictionary = session.snapshot()
	var replay := session.execute(start)
	_check(failures, DomainResult.equal(replay, first), "same session replay returns the same response")
	_check(failures, DomainResult.equal(session.snapshot(), before_replay),
		"same session replay does not change state")

	var conflict := session.execute({
		"request_id": "start-1",
		"expected_revision": 1,
		"command": "start_journey",
		"payload": {"unexpected": true},
	})
	_check(failures, not conflict.get("ok", true), "same id with different payload is rejected: %s" % str(conflict))
	_check(failures, str(conflict.get("error", {}).get("code", "")) == "REQUEST_ID_CONFLICT",
		"request id conflict code")
	_check(failures, DomainResult.equal(session.snapshot(), before_replay),
		"request id conflict does not mutate state")

	var resumed := P2FixtureScript.resume("command-replay")
	_check(failures, resumed.get("ok", false), "P2 fixture resumes the same slot: %s" % str(resumed))
	if resumed.get("ok", false):
		var resumed_session: SessionService = resumed.session
		var resumed_before: Dictionary = resumed_session.snapshot()
		var cross_session := resumed_session.execute(start)
		_check(failures, DomainResult.equal(cross_session, first),
			"cross-session committed request replays the original response")
		_check(failures, DomainResult.equal(resumed_session.snapshot(), resumed_before),
			"cross-session replay does not change state")
		var generation_after := int(resumed.store.load_latest().get("generation", -1))
		_check(failures, generation_after == 1, "cross-session replay does not add a generation")
		resumed.store.delete_slot()
	else:
		store.delete_slot()

	# A definite save failure must not install the ledger or block a same-id retry.
	var fake := FakeIo.new()
	var fake_store := SnapshotStore.new("fake://p2-retry", fake, 2)
	var fake_session := SessionService.new(ctx.catalog, fake_store,
		{"schema_version": 2, "payload_version": 2})
	_check(failures, fake_session.load_or_new().get("ok", false), "fake P2 session opens")
	fake.fail_writes["fake://p2-retry/state_a.json"] = true
	var failed := fake_session.execute(P2FixtureScript.request(fake_session, "retry-1",
		"start_journey", {}))
	_check(failures, not failed.get("ok", true), "save failure is reported")
	_check(failures, int(fake_session.snapshot().get("revision", -1)) == 0,
		"save failure leaves revision unchanged")
	_check(failures, fake_session.snapshot().get("commandLedger", {}).get("byRequestId", {}).is_empty(),
		"save failure does not install the ledger")
	fake.fail_writes.clear()
	var retried := fake_session.execute(P2FixtureScript.request(fake_session, "retry-1",
		"start_journey", {}))
	_check(failures, retried.get("ok", false) and int(retried.get("revision", -1)) == 1,
		"same request id retries safely after a definite save failure")
	completed = true
	return failures
