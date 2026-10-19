class_name DayFlow
extends RefCounted

## P2 salvage eligibility. Only the first required order is open in P2; P3
## expands the schedule without changing the command boundary.


static func available_letters(state: Dictionary, catalog: ContentCatalog) -> Dictionary:
	var release: Dictionary = catalog.release()
	var required: Array = release.get("requiredOrderIds", [])
	if required.is_empty():
		return DomainResult.ok([])
	var letter_id := str(required[0])
	var definition: Dictionary = catalog.entry_ref("letters", letter_id)
	if definition.is_empty() or definition.get("kind") != "order":
		return DomainResult.fail("CONFIG_INVALID", "release.requiredOrderIds",
			"first required order is not an order letter")
	var flow: Dictionary = state.get("live", {}).get("gameFlow", {})
	var day := int(flow.get("day", 0))
	var condition: Dictionary = definition.get("appearCondition", {})
	var day_min := int(condition.get("dayMin", 1))
	var received = state.get("live", {}).get("letters", {}).get("byId", {}).has("letter:" + letter_id)
	if day < day_min or received:
		return DomainResult.ok([])
	return DomainResult.ok([letter_id])


static func salvage_view(state: Dictionary, catalog: ContentCatalog) -> Dictionary:
	var limit := int(catalog.gameplay().get("salvageDailyLimit", 1))
	var flow: Dictionary = state.get("live", {}).get("gameFlow", {})
	var used := int(flow.get("salvageUsedToday", 0))
	var available := available_letters(state, catalog)
	if not available.ok:
		return available
	var ids: Array = available.value
	var enabled := bool(flow.get("phase") == "day") and bool(flow.get("canSalvage")) \
		and used < limit and not ids.is_empty()
	var reason := ""
	var message := ""
	if not bool(flow.get("phase") == "day") or not bool(flow.get("canSalvage")) or used >= limit:
		reason = "SALVAGE_DISABLED"
		message = "今日捕捞次数已用完"
	elif ids.is_empty():
		reason = "LETTER_NOT_AVAILABLE"
		message = "目前没有可打捞的新信"
	return DomainResult.ok({
		"dailyLimit": limit,
		"usedToday": used,
		"remaining": maxi(0, limit - used),
		"availableLetterIds": ids,
		"enabled": enabled,
		"reasonCode": reason,
		"message": message,
	})
