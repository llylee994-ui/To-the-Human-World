class_name SessionService
extends RefCounted

## The single command boundary. Every mutation validates a deep candidate,
## commits it through SnapshotStore, and only then installs it in memory.

var catalog: ContentCatalog
var store: SnapshotStore
var state: Dictionary = {}
var recovery_locked := false
var last_error: Dictionary = {}
var status := "new"
var results: Dictionary = {}
var uncertain_requests: Dictionary = {}
var schema_version: int = 1
var payload_version: int = 1
var onboarding: bool = false


func _init(content: ContentCatalog, snapshot_store: SnapshotStore = null,
		options: Dictionary = {}) -> void:
	catalog = content
	schema_version = int(options.get("schema_version", 1))
	payload_version = int(options.get("payload_version", 1))
	onboarding = options.get("onboarding", false) == true
	store = snapshot_store if snapshot_store != null else SnapshotStore.new(
		"user://godot_save", null, schema_version)


func _is_p2() -> bool:
	return schema_version >= 2 or payload_version >= 2


func _fail(code: String, path: String, message: String) -> Dictionary:
	last_error = {"code": code, "path": path, "message": message}
	return {"ok": false, "error": last_error.duplicate(true)}


func _lock(code: String, path: String, message: String) -> Dictionary:
	recovery_locked = true
	status = "recovery_required"
	return _fail(code, path, message)


func _initial_state() -> Dictionary:
	if _is_p2():
		return P2State.initial(catalog, onboarding)
	return StateValidator.initial_state(catalog)


func _validate_state(value: Dictionary) -> Dictionary:
	if _is_p2():
		return StateAudit.validate(value, catalog)
	return StateValidator.validate(value, catalog)


func _request_meta(request_id: String) -> Dictionary:
	var meta: Dictionary = uncertain_requests.get(request_id, {})
	return {
		"request_id": request_id,
		"expected_revision": int(meta.get("expected_revision", -1)),
		"command": str(meta.get("command", "")),
		"payload": meta.get("payload", {}),
	}


func _reconcile_uncertain() -> void:
	if uncertain_requests.is_empty() or state.is_empty():
		return
	var unresolved := false
	for request_id in uncertain_requests.keys():
		var request := _request_meta(request_id)
		var expected := int(request.get("expected_revision", -1))
		var actual := int(state.get("revision", 0))
		if _is_p2():
			var ledger := CommandLedger.lookup(state, request)
			if ledger.status == "matched":
				results[request_id] = (ledger.response as Dictionary).duplicate(true)
				uncertain_requests.erase(request_id)
				continue
			if ledger.status == "conflict":
				var conflict := {"ok": false, "error": (ledger.error as Dictionary).duplicate(true)}
				results[request_id] = conflict
				unresolved = true
				continue
			if actual == expected:
				uncertain_requests.erase(request_id)
				results.erase(request_id)
				continue
			if actual > expected:
				var failure := DomainResult.fail("RECONCILIATION_REQUIRED", "request_id",
					"reloaded state has no ledger record for the uncertain request")
				results[request_id] = {"ok": false, "error": failure.error}
				unresolved = true
				continue
			unresolved = true
			continue
		if actual == expected:
			uncertain_requests.erase(request_id)
			results.erase(request_id)
			continue
		if actual < expected:
			unresolved = true
			continue
		var dispatched := CommandRouter.dispatch(state, str(request.get("command", "")),
			request.get("payload", {}), catalog)
		if dispatched.get("ok", false) and not dispatched.get("changed", false):
			var success := {
				"ok": true,
				"revision": actual,
				"changed": true,
				"value": (dispatched.get("value", {}) as Dictionary).duplicate(true),
				"events": [],
			}
			results[request_id] = success
			uncertain_requests.erase(request_id)
		else:
			var failure := DomainResult.fail("RECONCILIATION_REQUIRED", "request_id",
				"reloaded state does not match the uncertain request")
			results[request_id] = {"ok": false, "error": failure.error}
			unresolved = true
	if not unresolved:
		recovery_locked = false
		status = "loaded"


func load_or_new() -> Dictionary:
	var loaded := store.load_latest()
	match str(loaded.get("status", "")):
		"new":
			var initial := _initial_state()
			if not initial.ok:
				return _lock("STATE_INVALID", "initial", "cannot build initial state")
			state = initial.value
			recovery_locked = false
			status = "new"
			_reconcile_uncertain()
			return {"ok": true, "status": "new", "revision": int(state.get("revision", 0)),
				"recovery_locked": recovery_locked}
		"loaded":
			if str(loaded.get("content_version", "")) != catalog.content_version():
				return _lock("CONTENT_VERSION_MISMATCH", "contentVersion",
					"save content version does not match catalog")
			var validated := _validate_state(loaded.get("payload", {}))
			if not validated.ok:
				return _lock(str(validated.error.get("code", "SAVE_CORRUPT")),
					str(validated.error.get("path", "data")), "saved state is invalid")
			state = validated.value
			recovery_locked = false
			status = "loaded"
			_reconcile_uncertain()
			return {
				"ok": true,
				"status": "loaded",
				"revision": int(state.get("revision", 0)),
				"generation": int(loaded.get("generation", 0)),
				"ignored": (loaded.get("ignored", []) as Array).duplicate(true),
				"recovery_locked": recovery_locked,
			}
		"unsupported":
			var unsupported: Dictionary = loaded.get("error", {})
			return _lock("SAVE_UNSUPPORTED", str(unsupported.get("path", "save")),
				str(unsupported.get("message", "save version is unsupported")))
		"read_failed":
			var read_error: Dictionary = loaded.get("error", {})
			return _lock("SAVE_READ_FAILED", str(read_error.get("path", "save")),
				str(read_error.get("message", "save could not be read")))
		"corrupt":
			var error: Dictionary = loaded.get("error", {})
			return _lock(str(error.get("code", "SAVE_CORRUPT")), str(error.get("path", "save")),
				str(error.get("message", "save is corrupt")))
	return _lock("SAVE_UNSUPPORTED", "save", "unsupported save status")


func _validate_request(request) -> Dictionary:
	if typeof(request) != TYPE_DICTIONARY:
		return _fail("INVALID_REQUEST", "request", "request must be an object")
	var keys := DomainResult.keys(request,
		["request_id", "expected_revision", "command", "payload"], "request")
	if not keys.is_empty():
		return {"ok": false, "error": keys}
	if typeof(request.get("request_id")) != TYPE_STRING or request["request_id"].is_empty():
		return _fail("INVALID_REQUEST", "request_id", "request_id must be a non-empty string")
	if not DomainResult.is_int(request.get("expected_revision")):
		return _fail("INVALID_REQUEST", "expected_revision", "expected_revision must be an integer")
	if typeof(request.get("command")) != TYPE_STRING or request["command"].is_empty():
		return _fail("INVALID_REQUEST", "command", "command must be a non-empty string")
	if request.has("payload") and typeof(request["payload"]) != TYPE_DICTIONARY:
		return _fail("INVALID_REQUEST", "payload", "payload must be an object")
	return {"ok": true, "value": request}


func _commit_candidate(candidate: Dictionary, request: Dictionary, response: Dictionary) -> Dictionary:
	var validated := _validate_state(candidate)
	if not validated.ok:
		return {"ok": false, "error": (validated["error"] as Dictionary).duplicate(true)}
	candidate = validated.value
	if _is_p2():
		var installed := CommandLedger.install(candidate, request, response)
		if not installed.ok:
			return {"ok": false, "error": (installed["error"] as Dictionary).duplicate(true)}
		candidate = installed.value
		validated = _validate_state(candidate)
		if not validated.ok:
			return {"ok": false, "error": (validated["error"] as Dictionary).duplicate(true)}
		candidate = validated.value
	var committed := store.commit(candidate, catalog.content_version(), int(candidate["revision"]))
	match str(committed.get("status", "")):
		"committed":
			state = candidate
			status = "loaded"
			recovery_locked = false
			uncertain_requests.erase(str(request.get("request_id", "")))
			results[str(request.get("request_id", ""))] = response.duplicate(true)
			return response.duplicate(true)
		"uncertain":
			uncertain_requests[str(request.get("request_id", ""))] = {
				"expected_revision": int(request["expected_revision"]),
				"command": str(request["command"]),
				"payload": (request.get("payload", {}) as Dictionary).duplicate(true),
			}
			var uncertain := _lock("SAVE_COMMIT_UNCERTAIN", "save",
				"save result is uncertain; re-read the same slot")
			results[str(request.get("request_id", ""))] = uncertain
			return uncertain.duplicate(true)
	var commit_error: Dictionary = committed.get("error", {})
	var code := str(commit_error.get("code", "SAVE_WRITE_FAILED"))
	if code in ["SAVE_UNSUPPORTED", "SAVE_READ_FAILED", "SAVE_CORRUPT", "SAVE_CHECKSUM_MISMATCH"]:
		var fatal := _lock(code, str(commit_error.get("path", "save")),
			str(commit_error.get("message", "save cannot be used")))
		results[str(request.get("request_id", ""))] = fatal
		return fatal.duplicate(true)
	var failed := {"ok": false, "error": commit_error.duplicate(true)}
	if not (_is_p2() and code in ["SAVE_WRITE_FAILED", "SAVE_VERIFY_FAILED"]):
		results[str(request.get("request_id", ""))] = failed
	return failed.duplicate(true)


func execute(request) -> Dictionary:
	var checked := _validate_request(request)
	if not checked.ok:
		return checked
	var request_id := str(request["request_id"])
	if recovery_locked:
		return _fail("RECOVERY_LOCKED", "save", "re-read the same slot before continuing")
	if state.is_empty():
		return _fail("STATE_NOT_READY", "session", "load a session before executing commands")
	if _is_p2():
		var ledger := CommandLedger.lookup(state, request)
		if ledger.status == "matched":
			return (ledger.response as Dictionary).duplicate(true)
		if ledger.status == "conflict":
			return {"ok": false, "error": (ledger.error as Dictionary).duplicate(true)}
	if results.has(request_id):
		return (results[request_id] as Dictionary).duplicate(true)
	if int(request["expected_revision"]) != int(state.get("revision", 0)):
		return _fail("STALE_REVISION", "expected_revision", "the session changed; refresh the view")
	var dispatched := CommandRouter.dispatch(state, str(request["command"]),
		request.get("payload", {}), catalog)
	if not dispatched.ok:
		var failed := {"ok": false, "error": (dispatched["error"] as Dictionary).duplicate(true)}
		results[request_id] = failed
		return failed.duplicate(true)
	if not dispatched.get("changed", false):
		var unchanged := {
			"ok": true,
			"revision": int(state.get("revision", 0)),
			"changed": false,
			"value": (dispatched.get("value", {}) as Dictionary).duplicate(true),
			"events": [],
		}
		if _is_p2():
			var candidate: Dictionary = state.duplicate(true)
			return _commit_candidate(candidate, request, unchanged)
		results[request_id] = unchanged
		return unchanged.duplicate(true)
	var candidate: Dictionary = dispatched.data
	var response := {
		"ok": true,
		"revision": int(candidate.get("revision", 0)),
		"changed": true,
		"value": (dispatched.get("value", {}) as Dictionary).duplicate(true),
		"events": (dispatched.get("events", []) as Array).duplicate(true),
	}
	return _commit_candidate(candidate, request, response)


func snapshot() -> Dictionary:
	return state.duplicate(true) if not state.is_empty() else {}


func is_recovery_locked() -> bool:
	return recovery_locked


func reload() -> Dictionary:
	return load_or_new()


func query(name: String, args: Dictionary = {}) -> Dictionary:
	if state.is_empty():
		return _fail("STATE_NOT_READY", "session", "load a session before querying")
	return QueryService.project(state, name, catalog, args, recovery_locked)


func preview(draft: Dictionary) -> Dictionary:
	if state.is_empty():
		return _fail("STATE_NOT_READY", "session", "load a session before calculating")
	return QueryService.project(state, "potion_preview", catalog, {"draft": draft}, recovery_locked)
