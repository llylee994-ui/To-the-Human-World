class_name QueryService
extends RefCounted

## Read-only projections for the UI. Every returned value is a deep copy; the
## UI never receives the mutable session state.


static func _letter_title(catalog: ContentCatalog, letter_instance_id: String) -> String:
	if not letter_instance_id.begins_with("letter:"):
		return ""
	var letter: Dictionary = catalog.entry_ref("letters", letter_instance_id.substr(7))
	return str(letter.get("title", ""))


static func project(state: Dictionary, name: String, catalog: ContentCatalog,
		args: Dictionary = {}, recovery_locked: bool = false) -> Dictionary:
	match name:
		"session_status":
			var flow: Dictionary = state.get("live", {}).get("gameFlow", {})
			return {"ok": true, "value": {
				"revision": int(state.get("revision", 0)),
				"contentVersion": str(state.get("contentVersion", "")),
				"day": int(flow.get("day", 0)),
				"phase": str(flow.get("phase", "")),
				"recoveryLocked": recovery_locked,
			}}
		"inventory":
			var economy: Dictionary = state.get("live", {}).get("economy", {})
			var tokens = state.get("live", {}).get("wordTokens", {}).get("byId", {})
			return {"ok": true, "value": {
				"currency": int(economy.get("currency", 0)),
				"ingredients": (economy.get("ingredients", {}) as Dictionary).duplicate(true),
				"ownedEquipmentIds": (economy.get("ownedEquipmentIds", {}) as Dictionary).duplicate(true),
				"wordCardCount": (tokens as Dictionary).size(),
			}}
		"word_tray":
			var result := WordToken.get_inventory(state, catalog)
			if not result.ok:
				return result
			var draft: Dictionary = state.get("draft", {})
			var selected := {}
			if not DomainResult.is_false(draft.get("mainTokenId", false)):
				selected[draft["mainTokenId"]] = "main"
			for token_id in draft.get("auxTokenIds", []):
				selected[token_id] = "aux"
			var cards: Array = []
			var groups: Dictionary = {}
			var available_count := 0
			for row in result.value:
				var role = selected.get(row["tokenId"], false)
				var category := str(row["definition"].get("category", ""))
				var card := {
					"tokenId": row["tokenId"],
					"wordId": row["wordId"],
					"text": str(row["definition"].get("displayText", "")),
					"categoryId": category,
					"sourceLetterInstanceId": row["source"]["sourceLetterInstanceId"],
					"sourceTitle": _letter_title(catalog, str(row["source"]["sourceLetterInstanceId"])),
					"available": bool(row["available"]),
					"selectedRole": role,
				}
				cards.append(card)
				if not groups.has(category):
					groups[category] = {"id": category, "title": category, "availableCount": 0}
				if bool(row["available"]):
					groups[category]["availableCount"] = int(groups[category]["availableCount"]) + 1
					available_count += 1
			var categories: Array = []
			for category in DomainResult.sorted_keys(groups):
				categories.append(groups[category])
			return {"ok": true, "value": {
				"cards": cards,
				"categories": categories,
				"availableCount": available_count,
			}}
		"draft":
			return {"ok": true, "value": (state.get("draft", {}) as Dictionary).duplicate(true)}
		"potion_preview":
			var draft = args.get("draft", state.get("draft", {}))
			var validated := RecipeDraft.validate(draft, state.get("live", {}), catalog)
			if not validated.ok:
				return validated
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
			return {"ok": true, "value": {
				"potion": calculated.value,
				"resolved": resolved.value,
			}}
		"content":
			var counts: Dictionary = {}
			for collection in ContentCatalog.COLLECTIONS:
				counts[collection] = catalog.count(collection)
			return {"ok": true, "value": {
				"contentVersion": catalog.content_version(),
				"counts": counts,
			}}
	return DomainResult.fail("UNKNOWN_QUERY", name, "unknown query")
