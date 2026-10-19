class_name StateAudit
extends RefCounted

## P2 envelope audit. The live/economy/world/token branches reuse the validated
## P1 foundation; P2 adds payload_version, currentOrder shape, chapter.started
## and the persistent command ledger.


static func validate(state_value, catalog: ContentCatalog) -> Dictionary:
	if typeof(state_value) != TYPE_DICTIONARY:
		return DomainResult.fail("STATE_INVALID", "data", "state must be an object")
	var state: Dictionary = state_value
	var keys := DomainResult.keys(state,
		["contentVersion", "payload_version", "revision", "nextOrderSerial", "live",
		 "currentOrder", "journal", "chapter", "onboarding", "commandLedger"], "data")
	if not keys.is_empty():
		return {"ok": false, "error": keys}
	if not DomainResult.is_int(state.get("payload_version")) or int(state["payload_version"]) != 2:
		return DomainResult.fail("STATE_INVALID", "payload_version", "unsupported payload version")
	if not DomainResult.is_false(state.get("currentOrder")):
		return DomainResult.fail("NOT_IMPLEMENTED", "currentOrder",
			"P2 accepted/pending order is implemented in Task 4")
	var chapter = state.get("chapter", {})
	if typeof(chapter) != TYPE_DICTIONARY or typeof(chapter.get("started")) != TYPE_BOOL:
		return DomainResult.fail("STATE_INVALID", "chapter.started", "chapter.started must be boolean")
	var ledger := CommandLedger.validate(state)
	if not ledger.ok:
		return ledger
	var projection: Dictionary = state.duplicate(true)
	projection.erase("payload_version")
	projection.erase("commandLedger")
	projection["draft"] = RecipeDraft.empty(str(catalog.stage1().get("initialEquipmentId", "")))
	projection["chapter"].erase("started")
	var base := StateValidator.validate(projection, catalog)
	if not base.ok:
		return base
	return {"ok": true, "value": state.duplicate(true)}
