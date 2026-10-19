class_name CommandLedger
extends RefCounted

## Persistent request identity and committed response. The ledger lives inside
## the business payload so a request id and its response are committed in the
## same A/B transaction as the state that produced them.


static func fingerprint(request: Dictionary) -> String:
	return SaveCodec.sha256(SaveCodec.encode({
		"command": str(request.get("command", "")),
		"payload": request.get("payload", {}),
	}))


static func lookup(state: Dictionary, request: Dictionary) -> Dictionary:
	var ledger = state.get("commandLedger", {})
	if typeof(ledger) != TYPE_DICTIONARY:
		return {"status": "missing"}
	var entries = (ledger as Dictionary).get("byRequestId", {})
	if typeof(entries) != TYPE_DICTIONARY:
		return {"status": "missing"}
	var request_id := str(request.get("request_id", ""))
	if not (entries as Dictionary).has(request_id):
		return {"status": "missing"}
	var row = (entries as Dictionary)[request_id]
	if typeof(row) != TYPE_DICTIONARY or typeof(row.get("fingerprint")) != TYPE_STRING \
			or typeof(row.get("response")) != TYPE_DICTIONARY:
		return {"status": "conflict",
			"error": DomainResult.fail("COMMAND_LEDGER_INVALID", "commandLedger.%s" % request_id,
				"ledger entry is malformed").error}
	if str(row["fingerprint"]) != fingerprint(request):
		return {"status": "conflict",
			"error": DomainResult.fail("REQUEST_ID_CONFLICT", "request_id",
				"the same request id was used with different command or payload").error}
	return {"status": "matched", "response": (row["response"] as Dictionary).duplicate(true)}


static func is_json_safe(value, path: String = "response") -> bool:
	match typeof(value):
		TYPE_NIL, TYPE_BOOL, TYPE_STRING, TYPE_INT:
			return true
		TYPE_FLOAT:
			return is_finite(float(value))
		TYPE_DICTIONARY:
			for key in value:
				if typeof(key) != TYPE_STRING:
					return false
				if not is_json_safe(value[key], "%s.%s" % [path, key]):
					return false
			return true
		TYPE_ARRAY:
			for index in (value as Array).size():
				if not is_json_safe(value[index], "%s[%d]" % [path, index]):
					return false
			return true
	return false


static func install(candidate: Dictionary, request: Dictionary, response: Dictionary) -> Dictionary:
	if not is_json_safe(response):
		return DomainResult.fail("COMMAND_LEDGER_INVALID", "response",
			"response contains a value that cannot be persisted")
	var next: Dictionary = candidate.duplicate(true)
	if typeof(next.get("commandLedger")) != TYPE_DICTIONARY:
		next["commandLedger"] = {"byRequestId": {}}
	var entries = next["commandLedger"].get("byRequestId", {})
	if typeof(entries) != TYPE_DICTIONARY:
		return DomainResult.fail("COMMAND_LEDGER_INVALID", "commandLedger.byRequestId",
			"ledger map must be an object")
	entries[str(request.get("request_id", ""))] = {
		"fingerprint": fingerprint(request),
		"response": response.duplicate(true),
	}
	next["commandLedger"]["byRequestId"] = entries
	return {"ok": true, "value": next}


static func validate(state: Dictionary) -> Dictionary:
	var ledger = state.get("commandLedger")
	if typeof(ledger) != TYPE_DICTIONARY:
		return DomainResult.fail("STATE_INVALID", "commandLedger", "command ledger must be an object")
	var keys := DomainResult.keys(ledger, ["byRequestId"], "commandLedger", "STATE_INVALID")
	if not keys.is_empty():
		return {"ok": false, "error": keys}
	if typeof(ledger.get("byRequestId")) != TYPE_DICTIONARY:
		return DomainResult.fail("STATE_INVALID", "commandLedger.byRequestId",
			"command ledger map must be an object")
	for request_id in ledger["byRequestId"]:
		var row = ledger["byRequestId"][request_id]
		var path := "commandLedger.byRequestId.%s" % str(request_id)
		if typeof(request_id) != TYPE_STRING or typeof(row) != TYPE_DICTIONARY \
				or typeof(row.get("fingerprint")) != TYPE_STRING \
				or typeof(row.get("response")) != TYPE_DICTIONARY:
			return DomainResult.fail("STATE_INVALID", path, "ledger entry is malformed")
		if not is_json_safe(row["response"], path + ".response"):
			return DomainResult.fail("STATE_INVALID", path + ".response",
				"ledger response is not persistable")
	return {"ok": true, "value": ledger.duplicate(true)}
