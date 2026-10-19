extends RefCounted

## P2 state and persistent ledger audit tests. The replay suite is included so
## `verify.py --suite p2-state` covers the Task 2 gate.

const CatalogScript = preload("res://src/content/content_catalog.gd")
const P2StateScript = preload("res://src/domain/p2_state.gd")
const StateAuditScript = preload("res://src/domain/state_audit.gd")
const CommandLedgerScript = preload("res://src/domain/command_ledger.gd")
const CommandReplayScript = preload("res://tests/unit/test_command_replay.gd")

var assertions := 0
var completed := false


func _check(failures: Array[String], condition: bool, message: String) -> void:
	assertions += 1
	if not condition:
		failures.append(message)


func _catalog() -> Dictionary:
	var catalog = CatalogScript.new()
	var loaded: Dictionary = catalog.load_catalog("res://content/generated/catalog.json")
	return {"ok": loaded.get("ok", false), "catalog": catalog}


func run(tree: SceneTree) -> Array[String]:
	var failures: Array[String] = []
	var loaded := _catalog()
	_check(failures, loaded.ok, "catalog loads")
	if not loaded.ok:
		completed = true
		return failures
	var catalog: ContentCatalog = loaded.catalog
	var initial: Dictionary = P2StateScript.initial(catalog, false)
	_check(failures, initial.get("ok", false), "P2 initial state builds")
	if not initial.get("ok", false):
		completed = true
		return failures
	var state: Dictionary = initial.value
	_check(failures, int(state.get("payload_version", 0)) == 2, "payload version is 2")
	_check(failures, state.get("currentOrder") == false, "initial currentOrder is false")
	_check(failures, state.get("chapter", {}).get("started") == false, "journey is not started")
	_check(failures, typeof(state.get("commandLedger")) == TYPE_DICTIONARY, "command ledger exists")
	_check(failures, not state.has("draft"), "P2 has no top-level draft")
	var audited: Dictionary = StateAuditScript.validate(state, catalog)
	_check(failures, audited.get("ok", false), "P2 initial state passes audit: %s" % str(audited.get("error", {})))

	var onboarding: Dictionary = P2StateScript.initial(catalog, true).value
	_check(failures, onboarding.get("onboarding", {}).get("step") == "intro.paper",
		"onboarding initial step")

	var bad_version: Dictionary = state.duplicate(true)
	bad_version["payload_version"] = 99
	var version_audit: Dictionary = StateAuditScript.validate(bad_version, catalog)
	_check(failures, not version_audit.get("ok", true), "unknown payload version is rejected")
	_check(failures, str(version_audit.get("error", {}).get("path", "")) == "payload_version",
		"unknown payload version path")

	for shape in [{"phase": "accepted"}, {"phase": "pending"}]:
		var bad_order: Dictionary = state.duplicate(true)
		bad_order["currentOrder"] = shape
		var order_audit: Dictionary = StateAuditScript.validate(bad_order, catalog)
		_check(failures, not order_audit.get("ok", true), "unsupported currentOrder shape is rejected")
		_check(failures, str(order_audit.get("error", {}).get("path", "")).contains("currentOrder"),
			"currentOrder error path")

	var forged: Dictionary = state.duplicate(true)
	forged["live"]["wordTokens"]["byId"]["token:fake"] = {
		"wordId": "word_candidate_elias_sleep",
		"sourceLetterInstanceId": "letter:letter_pa_01",
		"sourceSpanId": "body:1",
		"sourceNpcId": "npc_passerby_a",
		"available": true,
		"consumedByOrderId": false,
	}
	# The source span/word pair must match; body:1 belongs to another word.
	var forged_audit: Dictionary = StateAuditScript.validate(forged, catalog)
	_check(failures, not forged_audit.get("ok", true), "forged token source is rejected")
	var forged_path := str(forged_audit.get("error", {}).get("path", ""))
	_check(failures, forged_path.contains("wordTokens") or forged_path.contains("source"),
		"forged token path: %s" % str(forged_audit))

	var bad_ledger: Dictionary = state.duplicate(true)
	bad_ledger["commandLedger"]["byRequestId"]["bad"] = {
		"fingerprint": "x",
		"response": {"callable": func(): pass},
	}
	var ledger_audit: Dictionary = StateAuditScript.validate(bad_ledger, catalog)
	_check(failures, not ledger_audit.get("ok", true), "non-persistable ledger response is rejected")
	_check(failures, str(ledger_audit.get("error", {}).get("path", "")).contains("commandLedger"),
		"ledger error path")

	var replay_test = CommandReplayScript.new()
	var replay_failures: Array[String] = await replay_test.run(tree)
	failures.append_array(replay_failures)
	assertions += replay_test.assertions
	_check(failures, replay_test.completed, "command replay suite completed")
	completed = true
	return failures
