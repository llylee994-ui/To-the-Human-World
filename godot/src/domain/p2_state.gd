class_name P2State
extends RefCounted

## P2 production state. It starts from the validated P1 foundation and moves the
## draft under currentOrder, adds the persistent command ledger and the
## onboarding payload.


static func initial(catalog: ContentCatalog, onboarding: bool = false) -> Dictionary:
	var foundation := StateValidator.initial_state(catalog)
	if not foundation.ok:
		return foundation
	var state: Dictionary = foundation.value
	state.erase("draft")
	state["payload_version"] = 2
	state["commandLedger"] = {"byRequestId": {}}
	state["chapter"]["started"] = false
	if onboarding:
		state["onboarding"] = {
			"version": 1,
			"step": "intro.paper",
			"completed": false,
			"skipped": false,
			"noteRead": false,
		}
	return {"ok": true, "value": state}
