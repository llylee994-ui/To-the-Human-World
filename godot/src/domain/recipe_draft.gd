class_name RecipeDraft
extends RefCounted

## Persistent recipe draft projection. Mirrors scripts/systems/RecipeDraft.lua:
## the main word may be empty; no inventory is consumed by validation.


static func _fail(code: String, path: String, message: String, details: Dictionary = {}) -> Dictionary:
	return DomainResult.fail(code, path, message, details)


static func empty(equipment_id: String) -> Dictionary:
	return {
		"equipmentId": equipment_id,
		"mainTokenId": false,
		"auxTokenIds": [],
		"ingredients": [],
		"specialItemIds": [],
	}


static func project(recipe: Dictionary) -> Dictionary:
	var draft := {}
	for key in ["equipmentId", "mainTokenId", "auxTokenIds", "ingredients", "specialItemIds"]:
		draft[key] = DomainResult.copy(recipe.get(key))
	return draft


static func is_empty(draft: Dictionary) -> bool:
	return DomainResult.is_false(draft.get("mainTokenId", false)) \
		and (draft.get("auxTokenIds", []) as Array).is_empty() \
		and (draft.get("ingredients", []) as Array).is_empty() \
		and (draft.get("specialItemIds", []) as Array).is_empty()


static func validate(draft_value, live: Dictionary, catalog: ContentCatalog) -> Dictionary:
	if typeof(draft_value) != TYPE_DICTIONARY:
		return _fail("INVALID_REQUEST", "draft", "draft must be an object")
	var draft: Dictionary = draft_value
	var keys := DomainResult.keys(draft,
		["equipmentId", "mainTokenId", "auxTokenIds", "ingredients", "specialItemIds"], "draft")
	if not keys.is_empty():
		return {"ok": false, "error": keys}
	var equipment_id = draft.get("equipmentId")
	if typeof(equipment_id) != TYPE_STRING or equipment_id.is_empty():
		return _fail("INVALID_REQUEST", "draft.equipmentId", "equipmentId must be non-empty")
	var equipment: Dictionary = catalog.entry_ref("equipment", equipment_id)
	if equipment.is_empty():
		return _fail("UNKNOWN_ID", "draft.equipmentId", "unknown equipment %s" % equipment_id)
	var economy = live.get("economy", {})
	if typeof(economy) != TYPE_DICTIONARY \
			or not (economy.get("ownedEquipmentIds", {}) as Dictionary).get(equipment_id, false):
		return _fail("INVALID_REQUEST", "equipmentId", "equipment is not owned")
	var main_token = draft.get("mainTokenId")
	if not DomainResult.is_false(main_token) and (typeof(main_token) != TYPE_STRING or main_token.is_empty()):
		return _fail("INVALID_REQUEST", "mainTokenId", "mainTokenId must be a card id or false")
	if typeof(draft.get("auxTokenIds")) != TYPE_ARRAY:
		return _fail("INVALID_REQUEST", "auxTokenIds", "auxTokenIds must be an array")
	if typeof(draft.get("ingredients")) != TYPE_ARRAY:
		return _fail("INVALID_REQUEST", "ingredients", "ingredients must be an array")
	if typeof(draft.get("specialItemIds")) != TYPE_ARRAY:
		return _fail("INVALID_REQUEST", "specialItemIds", "specialItemIds must be an array")
	if not (draft["specialItemIds"] as Array).is_empty():
		return _fail("NOT_IMPLEMENTED", "specialItemIds", "special items are not implemented")
	var slots: Dictionary = equipment.get("slots", {})
	if (draft["auxTokenIds"] as Array).size() > int(slots.get("auxWord", 0)):
		return _fail("SLOT_OVERFLOW", "auxTokenIds", "aux word slots are full")
	var tokens = live.get("wordTokens", {})
	if typeof(tokens) != TYPE_DICTIONARY:
		return _fail("STATE_INVALID", "wordTokens", "word token state is missing")
	var by_id = tokens.get("byId", {})
	if typeof(by_id) != TYPE_DICTIONARY:
		return _fail("STATE_INVALID", "wordTokens.byId", "word token map is missing")
	var ids: Array = (draft["auxTokenIds"] as Array).duplicate(true)
	if not DomainResult.is_false(main_token):
		ids.append(main_token)
	var seen: Dictionary = {}
	var definitions: Dictionary = {}
	var policy_value = catalog.stage1().get("recipePolicy", {})
	if typeof(policy_value) != TYPE_DICTIONARY:
		return _fail("CONFIG_INVALID", "stage1.recipePolicy", "recipe policy must be an object")
	var policy: Dictionary = policy_value
	for token_id in ids:
		if typeof(token_id) != TYPE_STRING or token_id.is_empty():
			return _fail("INVALID_REQUEST", "tokenId", "card id is invalid")
		var token = by_id.get(token_id)
		if typeof(token) != TYPE_DICTIONARY or not bool(token.get("available", false)):
			return _fail("TOKEN_UNAVAILABLE", "tokenId", "card is missing or consumed", {"tokenId": token_id})
		if seen.has(token_id):
			return _fail("DUPLICATE_TOKEN", "tokenId", "the same card cannot occupy two slots")
		var word_id = token.get("wordId")
		if definitions.has(word_id) and policy.get("repeatWordDefinition") != true:
			return _fail("DUPLICATE_NOT_ALLOWED", "wordId", "duplicate word definition is not allowed")
		seen[token_id] = true
		definitions[word_id] = true
	var used_ingredients: Dictionary = {}
	var total := 0
	for row in draft["ingredients"]:
		var row_keys := DomainResult.keys(row, ["ingredientId", "quantity"], "ingredients")
		if not row_keys.is_empty():
			return {"ok": false, "error": row_keys}
		var ingredient_id = row.get("ingredientId")
		if ingredient_id not in catalog.indexes["ingredients"]:
			return _fail("UNKNOWN_ID", "ingredientId", "unknown ingredient %s" % str(ingredient_id))
		if not DomainResult.is_int(row.get("quantity")) or int(row["quantity"]) < 1:
			return _fail("INVALID_REQUEST", "quantity", "quantity must be a positive integer")
		if used_ingredients.has(ingredient_id):
			return _fail("DUPLICATE_NOT_ALLOWED", "ingredients",
				"the same ingredient must be merged into one row")
		if int(row["quantity"]) != 1 and policy.get("repeatIngredient") != true:
			return _fail("DUPLICATE_NOT_ALLOWED", "quantity", "duplicate ingredient is not allowed")
		var available := int((economy.get("ingredients", {}) as Dictionary).get(ingredient_id, 0))
		if int(row["quantity"]) > available:
			return _fail("INVENTORY_SHORT", "quantity", "ingredient stock is insufficient")
		used_ingredients[ingredient_id] = true
		total += int(row["quantity"])
	if total > int(slots.get("ingredient", 0)):
		return _fail("SLOT_OVERFLOW", "ingredients", "ingredient slots are full")
	return {"ok": true, "value": draft.duplicate(true)}
