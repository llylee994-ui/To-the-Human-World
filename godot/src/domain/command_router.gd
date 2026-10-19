class_name CommandRouter
extends RefCounted

## Commands operate on a deep copy; the caller commits the returned candidate
## through the snapshot store. Preview is pure and never changes the state.


static func dispatch(state: Dictionary, command: String, payload: Dictionary,
		catalog: ContentCatalog) -> Dictionary:
	if int(state.get("payload_version", 1)) >= 2:
		if command == "start_journey":
			var keys := DomainResult.keys(payload, [], "payload")
			if not keys.is_empty():
				return {"ok": false, "error": keys}
			if typeof(state.get("chapter")) != TYPE_DICTIONARY:
				return DomainResult.fail("STATE_INVALID", "chapter", "chapter is missing")
			if state["chapter"].get("started") == true:
				return {"ok": true, "data": state, "changed": false,
					"value": {"started": true, "phase": str(state["chapter"].get("phase", ""))},
					"events": []}
			var candidate: Dictionary = state.duplicate(true)
			candidate["chapter"]["started"] = true
			candidate["revision"] = int(candidate.get("revision", 0)) + 1
			return {"ok": true, "data": candidate, "changed": true,
				"value": {"started": true, "phase": str(candidate["chapter"].get("phase", ""))},
				"events": ["JourneyStarted"]}
		return DomainResult.fail("INVALID_REQUEST", "command",
			"P2 command is not implemented in this task")
	match command:
		"cut_word":
			var keys := DomainResult.keys(payload, ["source"], "payload")
			if not keys.is_empty():
				return {"ok": false, "error": keys}
			var planned := WordToken.plan_cut(state.get("live", {}).get("wordTokens", {}),
				payload.get("source"), catalog)
			if not planned.ok:
				return planned
			if not planned.changed:
				return {
					"ok": true,
					"data": state,
					"changed": false,
					"value": {"tokenId": planned.tokenId, "changed": false},
					"events": [],
				}
			var candidate: Dictionary = state.duplicate(true)
			candidate["live"]["wordTokens"] = planned.state
			candidate["revision"] = int(candidate.get("revision", 0)) + 1
			return {
				"ok": true,
				"data": candidate,
				"changed": true,
				"value": {"tokenId": planned.tokenId, "token": planned.token, "changed": true},
				"events": ["WordCut", "WordStored"],
			}
		"update_draft":
			var keys := DomainResult.keys(payload, ["draft"], "payload")
			if not keys.is_empty():
				return {"ok": false, "error": keys}
			var validated := RecipeDraft.validate(payload.get("draft"), state.get("live", {}), catalog)
			if not validated.ok:
				return validated
			if DomainResult.equal(validated.value, state.get("draft", {})):
				return {
					"ok": true,
					"data": state,
					"changed": false,
					"value": {"draft": validated.value, "changed": false},
					"events": [],
				}
			var candidate: Dictionary = state.duplicate(true)
			candidate["draft"] = validated.value
			candidate["revision"] = int(candidate.get("revision", 0)) + 1
			return {
				"ok": true,
				"data": candidate,
				"changed": true,
				"value": {"draft": validated.value, "changed": true},
				"events": ["DraftChanged"],
			}
		"preview":
			var keys := DomainResult.keys(payload, ["draft"], "payload")
			if not keys.is_empty():
				return {"ok": false, "error": keys}
			var validated := RecipeDraft.validate(payload.get("draft"), state.get("live", {}), catalog)
			if not validated.ok:
				return validated
			if DomainResult.is_false(validated.value.get("mainTokenId", false)):
				return DomainResult.fail("INVALID_REQUEST", "mainTokenId", "place a main word first")
			var recipe: Dictionary = {
				"orderId": "foundation-preview",
				"baselineId": "foundation-preview:baseline",
				"equipmentId": validated.value["equipmentId"],
				"mainTokenId": validated.value["mainTokenId"],
				"auxTokenIds": validated.value["auxTokenIds"],
				"ingredients": validated.value["ingredients"],
				"specialItemIds": validated.value["specialItemIds"],
			}
			var resolved := WordToken.resolve_recipe(state, recipe, catalog)
			if not resolved.ok:
				return resolved
			var calculated := Potion.evaluate(resolved.value, catalog)
			if not calculated.ok:
				return calculated
			return {
				"ok": true,
				"data": state,
				"changed": false,
				"value": {"potion": calculated.value, "resolved": resolved.value},
				"events": [],
			}
	return DomainResult.fail("INVALID_REQUEST", "command", "unknown command %s" % command)
