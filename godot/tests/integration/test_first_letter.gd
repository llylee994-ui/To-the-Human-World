extends RefCounted

## Task 3 integration: real receive/read/cut, duplicate actions and restart states.

const P2FixtureScript = preload("res://tests/support/p2_fixture.gd")
const PureLetterScript = preload("res://tests/unit/test_letter.gd")

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


func _start(session: SessionService) -> Dictionary:
	return session.execute(P2FixtureScript.request(session, "p2-start", "start_journey", {}))


func _tokens(session: SessionService) -> Dictionary:
	return session.snapshot().get("live", {}).get("wordTokens", {}).get("byId", {})


func run(tree: SceneTree) -> Array[String]:
	var failures: Array[String] = []
	var pure_test = PureLetterScript.new()
	var pure_failures: Array[String] = await pure_test.run(tree)
	failures.append_array(pure_failures)
	assertions += pure_test.assertions
	_check(failures, pure_test.completed, "pure letter suite completed")

	var unstarted := P2FixtureScript.open("letter-unstarted")
	_check(failures, unstarted.get("ok", false), "unstarted fixture opens")
	if unstarted.get("ok", false):
		var early: Dictionary = unstarted.session.execute(P2FixtureScript.request(unstarted.session, "early",
			"receive_letter", {"letterId": "letter_pa_01"}))
		_check(failures, str(early.get("error", {}).get("code", "")) == "JOURNEY_NOT_STARTED",
			"receive is rejected before start_journey")
		unstarted.store.delete_slot()

	var ctx := P2FixtureScript.open("first-letter")
	_check(failures, ctx.get("ok", false), "first-letter fixture opens")
	if not ctx.get("ok", false):
		completed = true
		return failures
	var session: SessionService = ctx.session
	var store: SnapshotStore = ctx.store
	_check(failures, _start(session).get("ok", false), "journey starts")
	var salvage := session.query("salvage")
	_check(failures, salvage.get("ok", false) and salvage.value.get("enabled", false),
		"salvage is available")
	var letter_id := str(salvage.value.get("availableLetterIds", [""])[0])
	_check(failures, letter_id == "letter_pa_01", "only the first order is available")
	var received := session.execute(P2FixtureScript.request(session, "receive-1",
		"receive_letter", {"letterId": letter_id}))
	_check(failures, received.get("ok", false), "receive commits")
	var instance_id := str(received.value.get("letterInstanceId", ""))
	_check(failures, instance_id == "letter:letter_pa_01", "received instance id")
	var after_receive: Dictionary = session.snapshot()
	_check(failures, int(after_receive["live"]["gameFlow"]["salvageUsedToday"]) == 1,
		"receive consumes one daily attempt")
	_check(failures, after_receive["live"]["gameFlow"]["canSalvage"] == false,
		"daily attempt is exhausted")
	var duplicate_receive := session.execute(P2FixtureScript.request(session, "receive-2",
		"receive_letter", {"letterId": letter_id}))
	_check(failures, not duplicate_receive.get("ok", true)
		and str(duplicate_receive.get("error", {}).get("code", "")) == "LETTER_NOT_AVAILABLE",
		"duplicate receive is rejected without a second attempt")
	_check(failures, int(session.snapshot()["live"]["gameFlow"]["salvageUsedToday"]) == 1,
		"duplicate receive does not consume another attempt")

	var unread_cut := P2FixtureScript.open("letter-cut-unread")
	if unread_cut.get("ok", false):
		_start(unread_cut.session)
		var unread_received: Dictionary = unread_cut.session.execute(P2FixtureScript.request(unread_cut.session,
			"receive-unread", "receive_letter", {"letterId": "letter_pa_01"}))
		if unread_received.get("ok", false):
			var before_read_cut: Dictionary = unread_cut.session.execute(P2FixtureScript.request(unread_cut.session,
				"cut-unread", "cut_word", {"letterInstanceId": unread_received.value.letterInstanceId,
				"spanId": "body:1"}))
			_check(failures, str(before_read_cut.get("error", {}).get("code", "")) == "LETTER_NOT_READ",
				"cut before read is rejected")
		unread_cut.store.delete_slot()

	var read := session.execute(P2FixtureScript.request(session, "read-1", "read_letter",
		{"letterInstanceId": instance_id}))
	_check(failures, read.get("ok", false), "read commits")
	var duplicate_read := session.execute(P2FixtureScript.request(session, "read-2", "read_letter",
		{"letterInstanceId": instance_id}))
	_check(failures, duplicate_read.get("ok", false) and not duplicate_read.get("changed", true),
		"duplicate read is idempotent")

	var cut := session.execute(P2FixtureScript.request(session, "cut-body-1", "cut_word",
		{"letterInstanceId": instance_id, "spanId": "body:1"}))
	_check(failures, cut.get("ok", false), "first cut commits")
	var token_id := str(cut.value.get("tokenId", ""))
	_check(failures, token_id.begins_with("token:"), "cut returns a source token")
	var duplicate_cut := session.execute(P2FixtureScript.request(session, "cut-body-1-again", "cut_word",
		{"letterInstanceId": instance_id, "spanId": "body:1"}))
	_check(failures, duplicate_cut.get("ok", false) and not duplicate_cut.get("changed", true),
		"duplicate cut is idempotent")
	_check(failures, (session.snapshot()["live"]["wordTokens"]["byId"] as Dictionary).size() == 1,
		"duplicate cut does not add another token")

	var view := session.query("letter", {"letterInstanceId": instance_id})
	_check(failures, view.get("ok", false), "letter query loads")
	var cut_span := {}
	for span in view.value.get("spans", []):
		if str(span.get("spanId", "")) == "body:1":
			cut_span = span
	_check(failures, cut_span.get("cut") == true, "letter view marks the cut span")

	var tokens: Dictionary = _tokens(session)
	for index in range(2, view.value.get("spans", []).size() + 1):
		var span: Dictionary = view.value["spans"][index - 1]
		var result := session.execute(P2FixtureScript.request(session,
			"cut-" + str(span["spanId"]), "cut_word",
			{"letterInstanceId": instance_id, "spanId": span["spanId"]}))
		_check(failures, result.get("ok", false), "cut %s commits" % span["spanId"])
		tokens = _tokens(session)
	_check(failures, tokens.size() == view.value["spans"].size(),
		"all first-letter spans produce distinct tokens")
	var letters := session.query("letters")
	_check(failures, letters.get("ok", false) and letters.value.size() == 1, "letters query lists one letter")
	_check(failures, letters.value[0].get("remainingCutCount") == 0, "letters query reports zero remaining cuts")
	store.delete_slot()

	# Restart states: unread, read, partial cut, all cut.
	var states := []
	var unread := P2FixtureScript.open("restart-unread")
	if unread.get("ok", false):
		_start(unread.session)
		unread.session.execute(P2FixtureScript.request(unread.session, "u-receive", "receive_letter",
			{"letterId": "letter_pa_01"}))
		states.append(["unread", unread, 0, false])
	var read_ctx := P2FixtureScript.open("restart-read")
	if read_ctx.get("ok", false):
		_start(read_ctx.session)
		read_ctx.session.execute(P2FixtureScript.request(read_ctx.session, "r-receive", "receive_letter",
			{"letterId": "letter_pa_01"}))
		read_ctx.session.execute(P2FixtureScript.request(read_ctx.session, "r-read", "read_letter",
			{"letterInstanceId": "letter:letter_pa_01"}))
		states.append(["read", read_ctx, 0, true])
	var partial := P2FixtureScript.open("restart-partial")
	if partial.get("ok", false):
		_start(partial.session)
		partial.session.execute(P2FixtureScript.request(partial.session, "p-receive", "receive_letter",
			{"letterId": "letter_pa_01"}))
		partial.session.execute(P2FixtureScript.request(partial.session, "p-read", "read_letter",
			{"letterInstanceId": "letter:letter_pa_01"}))
		for span_id in ["body:1", "body:2", "body:3"]:
			partial.session.execute(P2FixtureScript.request(partial.session, "p-cut-" + span_id,
				"cut_word", {"letterInstanceId": "letter:letter_pa_01", "spanId": span_id}))
		states.append(["partial", partial, 3, true])
	for entry in states:
		var name := str(entry[0])
		var fixture: Dictionary = entry[1]
		var resumed := P2FixtureScript.resume("restart-" + name)
		_check(failures, resumed.get("ok", false), "restart %s loads" % name)
		if resumed.get("ok", false):
			var restored: Dictionary = resumed.session.snapshot()
			var item = restored["live"]["letters"]["byId"].get("letter:letter_pa_01", {})
			_check(failures, item.get("read") == entry[3], "restart %s read state" % name)
			_check(failures, (restored["live"]["wordTokens"]["byId"] as Dictionary).size() == int(entry[2]),
				"restart %s token count" % name)
			_check(failures, int(restored["live"]["gameFlow"]["salvageUsedToday"]) == 1,
				"restart %s salvage count" % name)
			resumed.store.delete_slot()
		fixture.store.delete_slot()
	# Receive consumes the daily attempt only when the candidate commits.
	var fake := FakeIo.new()
	var fake_store := SnapshotStore.new("fake://p2-letter-save", fake, 2)
	var fake_session := SessionService.new(ctx.catalog, fake_store,
		{"schema_version": 2, "payload_version": 2})
	_check(failures, fake_session.load_or_new().get("ok", false), "fake letter session opens")
	_check(failures, _start(fake_session).get("ok", false), "fake journey starts")
	fake.fail_writes["fake://p2-letter-save/state_b.json"] = true
	var failed_receive: Dictionary = fake_session.execute(P2FixtureScript.request(fake_session,
		"fake-receive", "receive_letter", {"letterId": "letter_pa_01"}))
	_check(failures, not failed_receive.get("ok", true), "failed receive is reported")
	_check(failures, int(fake_session.snapshot()["live"]["gameFlow"]["salvageUsedToday"]) == 0,
		"failed receive does not consume the daily attempt")
	_check(failures, (fake_session.snapshot()["live"]["letters"]["byId"] as Dictionary).is_empty(),
		"failed receive does not install a letter")
	fake.fail_writes.clear()
	var retried_receive: Dictionary = fake_session.execute(P2FixtureScript.request(fake_session,
		"fake-receive", "receive_letter", {"letterId": "letter_pa_01"}))
	_check(failures, retried_receive.get("ok", false), "same receive request retries after save recovery")
	_check(failures, int(fake_session.snapshot()["live"]["gameFlow"]["salvageUsedToday"]) == 1,
		"retried receive consumes exactly one attempt")

	completed = true
	return failures
