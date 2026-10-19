class_name WordToken
extends RefCounted

## Source-aware word instances. Token identity is derived from the letter
## instance and span, never from the displayed text.


static func _fail(code: String, path: String, message: String, details: Dictionary = {}) -> Dictionary:
	return DomainResult.fail(code, path, message, details)


static func token_id(letter_instance_id: String, span_id: String) -> String:
	return "token:%d:%s:%d:%s" % [
		DomainResult.utf8_len(letter_instance_id), letter_instance_id,
		DomainResult.utf8_len(span_id), span_id,
	]


static func _letter_id(letter_instance_id: String) -> String:
	if not letter_instance_id.begins_with("letter:") or letter_instance_id.length() <= 7:
		return ""
	return letter_instance_id.substr(7)


static func validate_source(source_value, catalog: ContentCatalog) -> Dictionary:
	if typeof(source_value) != TYPE_DICTIONARY:
		return _fail("INVALID_REQUEST", "source", "source must be an object")
	var source: Dictionary = source_value
	var keys := DomainResult.keys(source,
		["wordId", "sourceLetterInstanceId", "sourceSpanId", "sourceNpcId"], "source")
	if not keys.is_empty():
		return {"ok": false, "error": keys}
	for key in ["wordId", "sourceLetterInstanceId", "sourceSpanId", "sourceNpcId"]:
		if typeof(source.get(key)) != TYPE_STRING or source[key].is_empty():
			return _fail("INVALID_REQUEST", "source.%s" % key, "source field must be non-empty")
	var word: Dictionary = catalog.entry_ref("words", source["wordId"])
	if word.is_empty():
		return _fail("UNKNOWN_ID", "source.wordId", "unknown word definition")
	if typeof(word.get("reusable")) != TYPE_BOOL:
		return _fail("CONFIG_INVALID", "words.%s.reusable" % source["wordId"], "reusable flag is missing")
	var letter_id := _letter_id(source["sourceLetterInstanceId"])
	var letter: Dictionary = catalog.entry_ref("letters", letter_id) if not letter_id.is_empty() else {}
	if letter.is_empty() or letter.get("kind") != "order" or letter.get("senderId") != source["sourceNpcId"] \
			or catalog.entry_ref("npcs", source["sourceNpcId"]).is_empty():
		return _fail("SOURCE_INVALID", "source", "source letter or sender does not match")
	for span in catalog.letter_spans(letter_id):
		if span.get("spanId") == source["sourceSpanId"] and span.get("wordId") == source["wordId"]:
			return {"ok": true, "value": source.duplicate(true)}
	return _fail("SOURCE_INVALID", "source.sourceSpanId",
		"source span does not match the word definition")


static func validate_snapshot(snapshot, catalog: ContentCatalog) -> Dictionary:
	if typeof(snapshot) != TYPE_DICTIONARY:
		return _fail("STATE_INVALID", "wordTokens", "word token state must be an object")
	var keys := DomainResult.keys(snapshot, ["byId"], "wordTokens", "STATE_INVALID")
	if not keys.is_empty():
		return {"ok": false, "error": keys}
	if typeof(snapshot.get("byId")) != TYPE_DICTIONARY:
		return _fail("STATE_INVALID", "wordTokens.byId", "word token map is missing")
	for identifier in snapshot["byId"]:
		var item = snapshot["byId"][identifier]
		var path := "wordTokens.byId.%s" % str(identifier)
		var item_keys := DomainResult.keys(item,
			["wordId", "sourceLetterInstanceId", "sourceSpanId", "sourceNpcId",
			 "available", "consumedByOrderId"], path, "STATE_INVALID")
		if not item_keys.is_empty():
			return {"ok": false, "error": item_keys}
		var source := {
			"wordId": item.get("wordId"),
			"sourceLetterInstanceId": item.get("sourceLetterInstanceId"),
			"sourceSpanId": item.get("sourceSpanId"),
			"sourceNpcId": item.get("sourceNpcId"),
		}
		var checked := validate_source(source, catalog)
		if not checked.ok:
			return checked
		if str(identifier) != token_id(str(source["sourceLetterInstanceId"]), str(source["sourceSpanId"])):
			return _fail("STATE_INVALID", path, "token id does not match its source")
		if typeof(item.get("available")) != TYPE_BOOL:
			return _fail("STATE_INVALID", path, "available must be boolean")
		var consumed = item.get("consumedByOrderId")
		var reusable := bool(catalog.entry_ref("words", str(item["wordId"])).get("reusable", false))
		if bool(item["available"]):
			if not DomainResult.is_false(consumed):
				return _fail("STATE_INVALID", path, "available token must not be consumed")
		elif typeof(consumed) != TYPE_STRING or consumed.is_empty() or reusable:
			return _fail("STATE_INVALID", path, "consumed token has an invalid record or is reusable")
	return {"ok": true, "value": (snapshot as Dictionary).duplicate(true)}


static func plan_cut(state_snapshot: Dictionary, source_value, catalog: ContentCatalog) -> Dictionary:
	var checked := validate_snapshot(state_snapshot, catalog)
	if not checked.ok:
		return checked
	var source_result := validate_source(source_value, catalog)
	if not source_result.ok:
		return source_result
	var source: Dictionary = source_result.value
	var identifier := token_id(source["sourceLetterInstanceId"], source["sourceSpanId"])
	var tokens: Dictionary = checked.value
	var existing = tokens["byId"].get(identifier)
	if typeof(existing) == TYPE_DICTIONARY:
		return {
			"ok": true,
			"changed": false,
			"tokenId": identifier,
			"token": existing.duplicate(true),
			"source": source.duplicate(true),
			"state": tokens.duplicate(true),
		}
	var item := source.duplicate(true)
	item["available"] = true
	item["consumedByOrderId"] = false
	tokens["byId"][identifier] = item
	return {
		"ok": true,
		"changed": true,
		"tokenId": identifier,
		"token": item.duplicate(true),
		"source": source.duplicate(true),
		"state": tokens.duplicate(true),
	}


static func _token_state(snapshot: Dictionary) -> Dictionary:
	if snapshot.has("byId"):
		return snapshot
	var live = snapshot.get("live", {})
	if typeof(live) == TYPE_DICTIONARY:
		var value = live.get("wordTokens", {})
		if typeof(value) == TYPE_DICTIONARY:
			return value
	return {}


static func resolve_recipe(state_snapshot: Dictionary, recipe_value, catalog: ContentCatalog) -> Dictionary:
	if typeof(recipe_value) != TYPE_DICTIONARY:
		return _fail("INVALID_REQUEST", "recipe", "recipe must be an object")
	var recipe: Dictionary = recipe_value
	var keys := DomainResult.keys(recipe,
		["orderId", "baselineId", "equipmentId", "mainTokenId", "auxTokenIds", "ingredients", "specialItemIds"],
		"recipe")
	if not keys.is_empty():
		return {"ok": false, "error": keys}
	if typeof(recipe.get("orderId")) != TYPE_STRING or recipe["orderId"].is_empty() \
			or typeof(recipe.get("mainTokenId")) != TYPE_STRING or recipe["mainTokenId"].is_empty() \
			or typeof(recipe.get("auxTokenIds")) != TYPE_ARRAY:
		return _fail("INVALID_REQUEST", "recipe", "orderId, main word or auxiliary array is missing")
	var tokens := _token_state(state_snapshot)
	if typeof(tokens.get("byId")) != TYPE_DICTIONARY:
		return _fail("STATE_INVALID", "wordTokens", "word token state is missing")
	var by_id: Dictionary = tokens["byId"]
	var seen: Dictionary = {}
	var aux: Array = []
	var main_ref := {}
	for token_id in ([recipe["mainTokenId"]] as Array) + (recipe["auxTokenIds"] as Array):
		if typeof(token_id) != TYPE_STRING or token_id.is_empty():
			return _fail("INVALID_REQUEST", "tokenId", "token id is invalid")
		if seen.has(token_id):
			return _fail("DUPLICATE_TOKEN", "tokenId", "the same token occupies more than one slot")
		seen[token_id] = true
		var item = by_id.get(token_id)
		if typeof(item) != TYPE_DICTIONARY or not bool(item.get("available", false)):
			return _fail("TOKEN_UNAVAILABLE", "tokenId", "token is missing or consumed",
				{"tokenId": token_id})
		var definition: Dictionary = catalog.entry_ref("words", str(item.get("wordId")))
		if definition.is_empty():
			return _fail("UNKNOWN_ID", "tokenId", "token word definition is missing")
		var ref := {
			"tokenId": token_id,
			"definition": definition.duplicate(true),
			"source": {
				"wordId": item.get("wordId"),
				"sourceLetterInstanceId": item.get("sourceLetterInstanceId"),
				"sourceSpanId": item.get("sourceSpanId"),
				"sourceNpcId": item.get("sourceNpcId"),
			},
		}
		if main_ref.is_empty():
			main_ref = ref
		else:
			aux.append(ref)
	var ingredients: Array = []
	for row in recipe.get("ingredients", []):
		if typeof(row) != TYPE_DICTIONARY:
			return _fail("INVALID_REQUEST", "ingredients", "ingredient row must be an object")
		var definition: Dictionary = catalog.entry_ref("ingredients", str(row.get("ingredientId")))
		if definition.is_empty():
			return _fail("UNKNOWN_ID", "ingredients", "ingredient definition is missing")
		ingredients.append({
			"ingredientId": row.get("ingredientId"),
			"quantity": row.get("quantity"),
			"definition": definition.duplicate(true),
		})
	ingredients.sort_custom(func(a, b): return str(a["ingredientId"]) < str(b["ingredientId"]))
	var equipment: Dictionary = catalog.entry_ref("equipment", str(recipe.get("equipmentId")))
	if equipment.is_empty():
		return _fail("UNKNOWN_ID", "recipe.equipmentId", "equipment definition is missing")
	return {
		"ok": true,
		"value": {
			"orderId": recipe["orderId"],
			"baselineId": recipe.get("baselineId", ""),
			"contentVersion": catalog.content_version(),
			"equipment": equipment.duplicate(true),
			"main": main_ref,
			"aux": aux,
			"ingredients": ingredients,
			"specialItems": [],
		},
	}


static func get_inventory(state_snapshot: Dictionary, catalog: ContentCatalog) -> Dictionary:
	var tokens := _token_state(state_snapshot)
	if typeof(tokens.get("byId")) != TYPE_DICTIONARY:
		return _fail("STATE_NOT_READY", "wordTokens", "word token state is not restored")
	var rows: Array = []
	var ids: Array = (tokens["byId"] as Dictionary).keys()
	ids.sort()
	for token_id in ids:
		var item: Dictionary = tokens["byId"][token_id]
		var definition: Dictionary = catalog.entry_ref("words", str(item.get("wordId")))
		if definition.is_empty():
			return _fail("STATE_INVALID", "wordTokens.byId.%s" % str(token_id),
				"token word definition is missing")
		rows.append({
			"tokenId": token_id,
			"wordId": item.get("wordId"),
			"definition": definition.duplicate(true),
			"source": {
				"wordId": item.get("wordId"),
				"sourceLetterInstanceId": item.get("sourceLetterInstanceId"),
				"sourceSpanId": item.get("sourceSpanId"),
				"sourceNpcId": item.get("sourceNpcId"),
			},
			"available": item.get("available"),
			"consumedByOrderId": item.get("consumedByOrderId"),
		})
	return {"ok": true, "value": rows}
