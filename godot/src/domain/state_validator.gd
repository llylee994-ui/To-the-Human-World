class_name StateValidator
extends RefCounted

## Structural and reference validation for the P1 foundation envelope.
## P2 will extend the letter/order/chapter branches; the P1 branches are kept
## deliberately strict so a malformed save cannot be installed.


static func _fail(code: String, path: String, message: String, details: Dictionary = {}) -> Dictionary:
	return DomainResult.fail(code, path, message, details)


static func _keys(value, allowed: Array, path: String, code: String = "STATE_INVALID") -> Dictionary:
	return DomainResult.keys(value, allowed, path, code)


static func initial_state(catalog: ContentCatalog) -> Dictionary:
	var stage1: Dictionary = catalog.stage1()
	var economy: Dictionary = (stage1.get("initialEconomy", {}) as Dictionary).duplicate(true)
	economy["ownedEquipmentIds"] = {str(stage1.get("initialEquipmentId", "")): true}
	economy["shopPurchases"] = []
	economy["itemPurchases"] = []
	var npcs: Dictionary = {}
	for npc_id in catalog.indexes["npcs"]:
		var npc: Dictionary = catalog.entry_ref("npcs", str(npc_id))
		npcs[npc_id] = (npc.get("initialState", {}) as Dictionary).duplicate(true)
	var state := {
		"contentVersion": catalog.content_version(),
		"revision": 0,
		"nextOrderSerial": 1,
		"live": {
			"gameFlow": {
				"day": 1,
				"phase": "day",
				"canSalvage": true,
				"mainStoryStage": "prologue",
				"deliveredOrders": 0,
				"salvageUsedToday": 0,
			},
			"letters": {"byId": {}, "bottleQueue": [], "directArchive": {}},
			"wordTokens": {"byId": {}},
			"economy": economy,
			"world": {"npcs": npcs, "flags": {}},
			"narrative": {"unlockedLetterIds": {}, "delayedQueue": [], "resolvedEventIds": {}},
			"orders": {"acceptedById": {}, "confirmedById": {}},
		},
		"currentOrder": false,
		"journal": {"byAttemptId": {}, "attemptIds": []},
		"chapter": {
			"phase": "operating",
			"wishDraftSourceIds": [],
			"ending": false,
			"endingTransactionId": false,
			"checkpoint": false,
		},
		"draft": RecipeDraft.empty(str(stage1.get("initialEquipmentId", ""))),
	}
	return {"ok": true, "value": state}


static func _validate_enum(value, values: Array, path: String) -> Dictionary:
	for allowed in values:
		if value == allowed:
			return {}
	return _fail("STATE_INVALID", path, "value is not in the declared enum")


static func _validate_value(value, schema, path: String) -> Dictionary:
	if typeof(schema) != TYPE_DICTIONARY:
		return _fail("STATE_INVALID", "%s.schema" % path, "field schema is missing")
	var kind = schema.get("type")
	match kind:
		"enum":
			if typeof(schema.get("values")) != TYPE_ARRAY:
				return _fail("STATE_INVALID", "%s.values" % path, "enum values are missing")
			return _validate_enum(value, schema["values"], path)
		"text":
			return {} if typeof(value) == TYPE_STRING and not value.is_empty() \
				else _fail("STATE_INVALID", path, "text must be non-empty")
		"number":
			return {} if DomainResult.is_number(value) else _fail("STATE_INVALID", path, "number is required")
		"integer":
			return {} if DomainResult.is_int(value) else _fail("STATE_INVALID", path, "integer is required")
		"boolean":
			return {} if typeof(value) == TYPE_BOOL else _fail("STATE_INVALID", path, "boolean is required")
		"map":
			if typeof(value) != TYPE_DICTIONARY:
				return _fail("STATE_INVALID", path, "map is required")
			if typeof(schema.get("keys")) != TYPE_ARRAY or typeof(schema.get("entry")) != TYPE_DICTIONARY:
				return _fail("STATE_INVALID", "%s.schema" % path, "map schema is incomplete")
			var allowed: Dictionary = {}
			for key in schema["keys"]:
				allowed[str(key)] = true
			var key_check := DomainResult.keys(value, allowed.keys(), path)
			if not key_check.is_empty():
				return {"ok": false, "error": key_check}
			for key in schema["keys"]:
				var checked := _validate_value(value.get(str(key)), schema["entry"], "%s.%s" % [path, str(key)])
				if not checked.is_empty():
					return {"ok": false, "error": checked}
			return {}
	return _fail("STATE_INVALID", "%s.type" % path, "unsupported field type")


static func _validate_npc_state(value, schema, path: String) -> Dictionary:
	if typeof(value) != TYPE_DICTIONARY or typeof(schema) != TYPE_DICTIONARY:
		return _fail("STATE_INVALID", path, "npc state and schema must be objects")
	var allowed: Array = []
	for key in schema:
		allowed.append(str(key))
	var checked := DomainResult.keys(value, allowed, path)
	if not checked.is_empty():
		return {"ok": false, "error": checked}
	for key in schema:
		var result := _validate_value(value.get(str(key)), schema[key], "%s.%s" % [path, str(key)])
		if not result.is_empty():
			return {"ok": false, "error": result}
	return {}


static func validate(state_value, catalog: ContentCatalog) -> Dictionary:
	if typeof(state_value) != TYPE_DICTIONARY:
		return _fail("STATE_INVALID", "data", "state must be an object")
	var state: Dictionary = state_value
	var checked := DomainResult.keys(state,
		["contentVersion", "revision", "nextOrderSerial", "live", "currentOrder", "journal", "chapter",
		 "draft", "onboarding"], "data")
	if not checked.is_empty():
		return {"ok": false, "error": checked}
	if state.get("contentVersion") != catalog.content_version():
		return _fail("CONTENT_VERSION_MISMATCH", "contentVersion",
			"save content version does not match catalog")
	if not DomainResult.is_int(state.get("revision")) or int(state["revision"]) < 0:
		return _fail("STATE_INVALID", "revision", "revision must be a non-negative integer")
	if not DomainResult.is_int(state.get("nextOrderSerial")) or int(state["nextOrderSerial"]) < 1:
		return _fail("STATE_INVALID", "nextOrderSerial", "nextOrderSerial must be positive")
	var live = state.get("live")
	var live_keys := DomainResult.keys(live,
		["gameFlow", "letters", "wordTokens", "economy", "world", "narrative", "orders"], "live")
	if not live_keys.is_empty():
		return {"ok": false, "error": live_keys}
	var flow = live.get("gameFlow", {})
	var flow_keys := DomainResult.keys(flow,
		["day", "phase", "canSalvage", "mainStoryStage", "deliveredOrders", "salvageUsedToday"],
		"live.gameFlow")
	if not flow_keys.is_empty():
		return {"ok": false, "error": flow_keys}
	if not DomainResult.is_int(flow.get("day")) or int(flow["day"]) < 1 \
			or not DomainResult.is_int(flow.get("deliveredOrders")) or int(flow["deliveredOrders"]) < 0 \
			or not DomainResult.is_int(flow.get("salvageUsedToday")) or int(flow["salvageUsedToday"]) < 0 \
			or flow.get("phase") != "day" or typeof(flow.get("canSalvage")) != TYPE_BOOL \
			or typeof(flow.get("mainStoryStage")) != TYPE_STRING or flow["mainStoryStage"].is_empty():
		return _fail("STATE_INVALID", "live.gameFlow", "game flow fields are invalid")
	var limit := int(catalog.gameplay().get("salvageDailyLimit", 0))
	if bool(flow["canSalvage"]) != (int(flow["salvageUsedToday"]) < limit):
		return _fail("STATE_INVALID", "live.gameFlow.canSalvage",
			"salvage flag must follow the daily count")
	var letters = live.get("letters")
	var letter_keys := DomainResult.keys(letters, ["byId", "bottleQueue", "directArchive"],
		"live.letters")
	if not letter_keys.is_empty():
		return {"ok": false, "error": letter_keys}
	if typeof(letters.get("byId")) != TYPE_DICTIONARY or typeof(letters.get("directArchive")) != TYPE_DICTIONARY \
			or typeof(letters.get("bottleQueue")) != TYPE_ARRAY:
		return _fail("STATE_INVALID", "live.letters", "letter collections are invalid")
	var token_result := WordToken.validate_snapshot(live.get("wordTokens", {}), catalog)
	if not token_result.ok:
		return token_result
	var economy = live.get("economy", {})
	var economy_keys := DomainResult.keys(economy,
		["currency", "ingredients", "specialItems", "ownedEquipmentIds", "shopPurchases", "itemPurchases"],
		"live.economy")
	if not economy_keys.is_empty():
		return {"ok": false, "error": economy_keys}
	if not DomainResult.is_int(economy.get("currency")) or int(economy["currency"]) < 0 \
			or typeof(economy.get("ingredients")) != TYPE_DICTIONARY \
			or typeof(economy.get("specialItems")) != TYPE_ARRAY \
			or typeof(economy.get("ownedEquipmentIds")) != TYPE_DICTIONARY \
			or typeof(economy.get("shopPurchases")) != TYPE_ARRAY \
			or typeof(economy.get("itemPurchases")) != TYPE_ARRAY:
		return _fail("STATE_INVALID", "live.economy", "economy fields are invalid")
	for ingredient_id in economy["ingredients"]:
		if not catalog.has("ingredients", str(ingredient_id)):
			return _fail("UNKNOWN_ID", "live.economy.ingredients.%s" % str(ingredient_id),
				"unknown ingredient")
		if not DomainResult.is_int(economy["ingredients"][ingredient_id]) \
				or int(economy["ingredients"][ingredient_id]) < 0:
			return _fail("STATE_INVALID", "live.economy.ingredients.%s" % str(ingredient_id),
				"ingredient quantity must be a non-negative integer")
	for equipment_id in economy["ownedEquipmentIds"]:
		if not catalog.has("equipment", str(equipment_id)):
			return _fail("UNKNOWN_ID", "live.economy.ownedEquipmentIds.%s" % str(equipment_id),
				"unknown equipment")
		if typeof(economy["ownedEquipmentIds"][equipment_id]) != TYPE_BOOL:
			return _fail("STATE_INVALID", "live.economy.ownedEquipmentIds.%s" % str(equipment_id),
				"ownership must be boolean")
	var world = live.get("world", {})
	var world_keys := DomainResult.keys(world, ["npcs", "flags"], "live.world")
	if not world_keys.is_empty():
		return {"ok": false, "error": world_keys}
	if typeof(world.get("npcs")) != TYPE_DICTIONARY or typeof(world.get("flags")) != TYPE_DICTIONARY \
			or not (world["flags"] as Dictionary).is_empty():
		return _fail("STATE_INVALID", "live.world", "world fields are invalid")
	for npc_id in catalog.indexes["npcs"]:
		if not (world["npcs"] as Dictionary).has(npc_id):
			return _fail("STATE_INVALID", "live.world.npcs.%s" % npc_id, "npc state is missing")
		var npc: Dictionary = catalog.entry_ref("npcs", str(npc_id))
		var npc_result := _validate_npc_state(world["npcs"][npc_id], npc.get("initialStateSchema", {}),
			"live.world.npcs.%s" % str(npc_id))
		if not npc_result.is_empty():
			return {"ok": false, "error": npc_result}
	var narrative = live.get("narrative", {})
	var narrative_keys := DomainResult.keys(narrative,
		["unlockedLetterIds", "delayedQueue", "resolvedEventIds"], "live.narrative")
	if not narrative_keys.is_empty():
		return {"ok": false, "error": narrative_keys}
	if typeof(narrative.get("unlockedLetterIds")) != TYPE_DICTIONARY \
			or typeof(narrative.get("delayedQueue")) != TYPE_ARRAY \
			or typeof(narrative.get("resolvedEventIds")) != TYPE_DICTIONARY:
		return _fail("STATE_INVALID", "live.narrative", "narrative fields are invalid")
	var orders = live.get("orders", {})
	var order_keys := DomainResult.keys(orders, ["acceptedById", "confirmedById"], "live.orders")
	if not order_keys.is_empty():
		return {"ok": false, "error": order_keys}
	if typeof(orders.get("acceptedById")) != TYPE_DICTIONARY \
			or typeof(orders.get("confirmedById")) != TYPE_DICTIONARY:
		return _fail("STATE_INVALID", "live.orders", "order collections are invalid")
	if not DomainResult.is_false(state.get("currentOrder")):
		return _fail("NOT_IMPLEMENTED", "currentOrder",
			"P1 foundation only supports an empty current order")
	var journal = state.get("journal", {})
	var journal_keys := DomainResult.keys(journal, ["byAttemptId", "attemptIds"], "journal")
	if not journal_keys.is_empty():
		return {"ok": false, "error": journal_keys}
	if typeof(journal.get("byAttemptId")) != TYPE_DICTIONARY or typeof(journal.get("attemptIds")) != TYPE_ARRAY:
		return _fail("STATE_INVALID", "journal", "journal fields are invalid")
	var chapter = state.get("chapter", {})
	var chapter_keys := DomainResult.keys(chapter,
		["phase", "wishDraftSourceIds", "ending", "endingTransactionId", "checkpoint"], "chapter")
	if not chapter_keys.is_empty():
		return {"ok": false, "error": chapter_keys}
	if chapter.get("phase") != "operating" or typeof(chapter.get("wishDraftSourceIds")) != TYPE_ARRAY \
			or not DomainResult.is_false(chapter.get("ending")) \
			or not DomainResult.is_false(chapter.get("endingTransactionId")) \
			or not DomainResult.is_false(chapter.get("checkpoint")):
		return _fail("STATE_INVALID", "chapter", "chapter must be an operating chapter")
	var draft_result := RecipeDraft.validate(state.get("draft"), live, catalog)
	if not draft_result.ok:
		return draft_result
	if state.has("onboarding"):
		var onboard = state["onboarding"]
		var onboard_keys := DomainResult.keys(onboard,
			["version", "step", "completed", "skipped", "noteRead"], "onboarding")
		if not onboard_keys.is_empty():
			return {"ok": false, "error": onboard_keys}
		if not DomainResult.is_int(onboard.get("version")) or typeof(onboard.get("step")) != TYPE_STRING \
				or typeof(onboard.get("completed")) != TYPE_BOOL or typeof(onboard.get("skipped")) != TYPE_BOOL \
				or typeof(onboard.get("noteRead")) != TYPE_BOOL:
			return _fail("STATE_INVALID", "onboarding", "onboarding fields are invalid")
	return {"ok": true, "value": (state as Dictionary).duplicate(true)}
