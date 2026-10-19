class_name ContentValidation
extends RefCounted

## Structural/reference validation for the generated catalog. This complements
## ContentCatalog's duplicate-id and count checks so a malformed catalog cannot
## be installed as "valid" merely because its top-level shape is present.


static func _error(code: String, path: String, message: String) -> Dictionary:
	return {"code": code, "path": path, "message": message}


static func _need(condition: bool, path: String, message: String) -> Dictionary:
	return {} if condition else _error("CONTENT_INVALID", path, message)


static func _is_dict(value) -> bool:
	return typeof(value) == TYPE_DICTIONARY


static func _is_array(value) -> bool:
	return typeof(value) == TYPE_ARRAY


static func _is_string(value) -> bool:
	return typeof(value) == TYPE_STRING and not value.is_empty()


static func _collection(data: Dictionary, name: String) -> Array:
	var collections = data.get("collections", {})
	if typeof(collections) != TYPE_DICTIONARY:
		return []
	var rows = (collections as Dictionary).get(name, [])
	return rows if typeof(rows) == TYPE_ARRAY else []


static func _has(indexes: Dictionary, collection: String, identifier) -> bool:
	if not indexes.has(collection):
		return false
	return (indexes[collection] as Dictionary).has(str(identifier))


static func _entry(indexes: Dictionary, collection: String, identifier) -> Dictionary:
	if not _has(indexes, collection, identifier):
		return {}
	return (indexes[collection] as Dictionary)[str(identifier)]


static func _ref(indexes: Dictionary, collection: String, identifier, path: String) -> Dictionary:
	return {} if _has(indexes, collection, identifier) else _error("UNKNOWN_REF", path,
		"unknown reference %s" % str(identifier))


static func _condition(condition, path: String) -> Dictionary:
	var err := _need(_is_dict(condition), path, "condition must be an object")
	if not err.is_empty():
		return err
	err = _need(str(condition.get("op", "")) in ["eq", "ne", "gte", "lte"], "%s.op" % path,
		"unknown condition operator")
	if not err.is_empty():
		return err
	return _need(_is_string(condition.get("path")), "%s.path" % path, "condition path is missing")


static func _recipe_refs(recipe, indexes: Dictionary, path: String) -> Dictionary:
	var err := _need(_is_dict(recipe), path, "recipe must be an object")
	if not err.is_empty():
		return err
	err = _ref(indexes, "words", recipe.get("mainWordId"), "%s.mainWordId" % path)
	if not err.is_empty():
		return err
	err = _need(_is_array(recipe.get("auxWordIds")), "%s.auxWordIds" % path,
		"auxWordIds must be an array")
	if not err.is_empty():
		return err
	for word_id in recipe["auxWordIds"]:
		err = _ref(indexes, "words", word_id, "%s.auxWordIds" % path)
		if not err.is_empty():
			return err
	err = _need(_is_array(recipe.get("ingredients")), "%s.ingredients" % path,
		"ingredients must be an array")
	if not err.is_empty():
		return err
	for row in recipe["ingredients"]:
		err = _need(_is_dict(row) and _has(indexes, "ingredients", row.get("ingredientId")),
			"%s.ingredients" % path, "unknown ingredient")
		if not err.is_empty():
			return err
		err = _need(DomainResult.is_int(row.get("quantity")) and int(row["quantity"]) > 0,
			"%s.ingredients.quantity" % path, "quantity must be positive")
		if not err.is_empty():
			return err
	err = _need(_is_array(recipe.get("specialItemIds")), "%s.specialItemIds" % path,
		"specialItemIds must be an array")
	if not err.is_empty():
		return err
	return _ref(indexes, "equipment", recipe.get("equipmentId"), "%s.equipmentId" % path)


static func validate(data: Dictionary, indexes: Dictionary) -> Dictionary:
	for field in ["release", "releaseEndings", "stage1", "synthesis", "shop", "gameplay"]:
		var err := _need(_is_dict(data.get(field)), field, "must be an object")
		if not err.is_empty():
			return err
	var err := _need(_is_dict(data.get("letterSpans")), "letterSpans", "must be an object")
	if not err.is_empty():
		return err
	err = _need(_is_array(data.get("factExclusionGroups")), "factExclusionGroups", "must be an array")
	if not err.is_empty():
		return err

	var words := _collection(data, "words")
	var ingredients := _collection(data, "ingredients")
	var equipment_rows := _collection(data, "equipment")
	var npcs := _collection(data, "npcs")
	var letters := _collection(data, "letters")
	var templates := _collection(data, "followupTemplates")
	var fragments := _collection(data, "fragments")
	var rules := _collection(data, "directRules")
	var ratings := _collection(data, "orderRatings")
	var profiles := _collection(data, "attributeProfiles")

	for index in words.size():
		var row: Dictionary = words[index]
		var path := "collections.words[%d]" % index
		err = _need(_is_string(row.get("displayText")), "%s.displayText" % path, "displayText is missing")
		if not err.is_empty():
			return err
		err = _need(_is_string(row.get("category")), "%s.category" % path, "category is missing")
		if not err.is_empty():
			return err
		err = _need(typeof(row.get("reusable")) == TYPE_BOOL, "%s.reusable" % path, "reusable must be boolean")
		if not err.is_empty():
			return err
		err = _need(_is_dict(row.get("effects")), "%s.effects" % path, "effects must be an object")
		if not err.is_empty():
			return err
		for effect_id in row["effects"]:
			err = _ref(indexes, "effects", effect_id, "%s.effects.%s" % [path, str(effect_id)])
			if not err.is_empty():
				return err
		if row.has("attributeProfileId"):
			err = _need(_is_string(row["attributeProfileId"]), "%s.attributeProfileId" % path,
				"attributeProfileId must be a string")
			if not err.is_empty():
				return err
			err = _ref(indexes, "attributeProfiles", row["attributeProfileId"],
				"%s.attributeProfileId" % path)
			if not err.is_empty():
				return err

	for index in ingredients.size():
		var row: Dictionary = ingredients[index]
		var path := "collections.ingredients[%d]" % index
		err = _need(_is_dict(row.get("addTags")), "%s.addTags" % path, "addTags must be an object")
		if not err.is_empty():
			return err
		err = _need(_is_dict(row.get("mods")), "%s.mods" % path, "mods must be an object")
		if not err.is_empty():
			return err
		err = _need(DomainResult.is_int(row.get("price")), "%s.price" % path, "price must be an integer")
		if not err.is_empty():
			return err
		for effect_id in row["addTags"]:
			err = _ref(indexes, "effects", effect_id, "%s.addTags.%s" % [path, str(effect_id)])
			if not err.is_empty():
				return err
		for mod in row["mods"]:
			err = _need(str(mod) in ["intensity", "duration", "speed", "stability", "sideEffect"],
				"%s.mods.%s" % [path, str(mod)], "unknown mod key")
			if not err.is_empty():
				return err

	for index in equipment_rows.size():
		var row: Dictionary = equipment_rows[index]
		var path := "collections.equipment[%d]" % index
		err = _need(_is_dict(row.get("slots")), "%s.slots" % path, "slots must be an object")
		if not err.is_empty():
			return err
		for slot in ["mainWord", "auxWord", "ingredient", "specialItem"]:
			err = _need(DomainResult.is_int(row["slots"].get(slot)), "%s.slots.%s" % [path, slot],
				"slot must be an integer")
			if not err.is_empty():
				return err
		err = _need(typeof(row.get("owned")) == TYPE_BOOL, "%s.owned" % path, "owned must be boolean")
		if not err.is_empty():
			return err

	for index in npcs.size():
		var row: Dictionary = npcs[index]
		var path := "collections.npcs[%d]" % index
		err = _need(_is_string(row.get("name")), "%s.name" % path, "npc name is missing")
		if not err.is_empty():
			return err
		err = _need(_is_dict(row.get("initialState")), "%s.initialState" % path,
			"initialState must be an object")
		if not err.is_empty():
			return err
		err = _need(_is_dict(row.get("initialStateSchema")), "%s.initialStateSchema" % path,
			"initialStateSchema must be an object")
		if not err.is_empty():
			return err

	for index in letters.size():
		var row: Dictionary = letters[index]
		var path := "collections.letters[%d]" % index
		err = _need(_is_string(row.get("title")), "%s.title" % path, "title is missing")
		if not err.is_empty():
			return err
		err = _ref(indexes, "npcs", row.get("senderId"), "%s.senderId" % path)
		if not err.is_empty():
			return err
		err = _need(_is_array(row.get("attachments")), "%s.attachments" % path,
			"attachments must be an array")
		if not err.is_empty():
			return err
		var order_letter: bool = row.get("kind") == "order"
		if order_letter:
			err = _need(_is_string(row.get("body")), "%s.body" % path, "order body is missing")
			if not err.is_empty():
				return err
			err = _need(_is_array(row.get("cutWordIds")), "%s.cutWordIds" % path,
				"cutWordIds must be an array")
			if not err.is_empty():
				return err
			for word_id in row["cutWordIds"]:
				err = _ref(indexes, "words", word_id, "%s.cutWordIds" % path)
				if not err.is_empty():
					return err
			var requirement = row.get("requirement")
			err = _need(_is_dict(requirement), "%s.requirement" % path, "requirement must be an object")
			if not err.is_empty():
				return err
			err = _need(_is_dict(requirement.get("tags")), "%s.requirement.tags" % path,
				"requirement.tags must be an object")
			if not err.is_empty():
				return err
			for effect_id in requirement["tags"]:
				err = _ref(indexes, "effects", effect_id,
					"%s.requirement.tags.%s" % [path, str(effect_id)])
				if not err.is_empty():
					return err
			err = _need(_is_array(requirement.get("conditions")), "%s.requirement.conditions" % path,
				"conditions must be an array")
			if not err.is_empty():
				return err
			for condition in requirement["conditions"]:
				err = _need(_is_dict(condition), "%s.requirement.conditions" % path,
					"condition must be an object")
				if not err.is_empty():
					return err
				err = _need(str(condition.get("kind", "")) in ["duration", "onset", "workReady",
					"residualAt", "forbiddenEffect"], "%s.requirement.conditions.kind" % path,
					"unknown condition kind")
				if not err.is_empty():
					return err
			err = _need(_is_array(requirement.get("forbiddenEffects")),
				"%s.requirement.forbiddenEffects" % path, "forbiddenEffects must be an array")
			if not err.is_empty():
				return err
		elif row.has("cutWordIds"):
			err = _need(_is_array(row["cutWordIds"]), "%s.cutWordIds" % path,
				"cutWordIds must be an array")
			if not err.is_empty():
				return err
		var rule_set = row.get("directRuleSetId")
		if _is_string(rule_set):
			var found := false
			for rule in rules:
				if rule.get("ruleSetId") == rule_set:
					found = true
					break
			err = _need(found, "%s.directRuleSetId" % path, "unknown rule set")
			if not err.is_empty():
				return err
		var rating_set = row.get("ratingSetId")
		if _is_string(rating_set):
			var found := false
			for rating in ratings:
				if rating.get("ratingSetId") == rating_set:
					found = true
					break
			err = _need(found, "%s.ratingSetId" % path, "unknown rating set")
			if not err.is_empty():
				return err
		var template_id = row.get("followupTemplateId")
		if _is_string(template_id):
			err = _ref(indexes, "followupTemplates", template_id, "%s.followupTemplateId" % path)
			if not err.is_empty():
				return err

	for index in templates.size():
		var row: Dictionary = templates[index]
		var path := "collections.followupTemplates[%d]" % index
		err = _ref(indexes, "letters", row.get("letterId"), "%s.letterId" % path)
		if not err.is_empty():
			return err
		for field in ["fragmentIds", "baseFragmentIds", "fallbackFragmentIds"]:
			err = _need(_is_array(row.get(field)), "%s.%s" % [path, field], "must be an array")
			if not err.is_empty():
				return err
			for fragment_id in row[field]:
				err = _ref(indexes, "fragments", fragment_id, "%s.%s" % [path, field])
				if not err.is_empty():
					return err

	for index in fragments.size():
		var row: Dictionary = fragments[index]
		var path := "collections.fragments[%d]" % index
		err = _ref(indexes, "followupTemplates", row.get("templateId"), "%s.templateId" % path)
		if not err.is_empty():
			return err
		err = _need(_is_string(row.get("text")), "%s.text" % path, "fragment text is missing")
		if not err.is_empty():
			return err
		for field in ["coversFacts", "requiresFacts", "excludesFacts", "overrides"]:
			err = _need(_is_array(row.get(field)), "%s.%s" % [path, field], "must be an array")
			if not err.is_empty():
				return err

	for index in rules.size():
		var row: Dictionary = rules[index]
		var path := "collections.directRules[%d]" % index
		err = _need(_is_string(row.get("ruleSetId")), "%s.ruleSetId" % path, "ruleSetId is missing")
		if not err.is_empty():
			return err
		for field in ["when", "unless"]:
			err = _need(_is_array(row.get(field)), "%s.%s" % [path, field], "must be an array")
			if not err.is_empty():
				return err
			for cond_index in (row[field] as Array).size():
				err = _condition(row[field][cond_index], "%s.%s[%d]" % [path, field, cond_index])
				if not err.is_empty():
					return err
		err = _need(_is_array(row.get("changes")), "%s.changes" % path, "changes must be an array")
		if not err.is_empty():
			return err
		for change in row["changes"]:
			err = _need(_is_dict(change), "%s.changes" % path, "change must be an object")
			if not err.is_empty():
				return err
			err = _need(str(change.get("op", "")) in ["set", "add"], "%s.changes.op" % path,
				"unknown change operator")
			if not err.is_empty():
				return err
			err = _need(_is_string(change.get("path")), "%s.changes.path" % path,
				"change path is missing")
			if not err.is_empty():
				return err
		err = _need(_is_array(row.get("facts")), "%s.facts" % path, "facts must be an array")
		if not err.is_empty():
			return err
		for fact in row["facts"]:
			err = _need(_is_dict(fact) and _is_string(fact.get("id")), "%s.facts.id" % path,
				"fact id is missing")
			if not err.is_empty():
				return err

	for index in ratings.size():
		var row: Dictionary = ratings[index]
		var path := "collections.orderRatings[%d]" % index
		err = _need(_is_string(row.get("ratingSetId")), "%s.ratingSetId" % path, "ratingSetId is missing")
		if not err.is_empty():
			return err
		err = _need(DomainResult.is_int(row.get("stars")) and int(row["stars"]) >= 1
			and int(row["stars"]) <= 3, "%s.stars" % path, "stars must be 1..3")
		if not err.is_empty():
			return err
		err = _need(_is_string(row.get("feedback")), "%s.feedback" % path, "feedback is missing")
		if not err.is_empty():
			return err
		for field in ["requiresFacts", "excludesFacts"]:
			err = _need(_is_array(row.get(field)), "%s.%s" % [path, field], "must be an array")
			if not err.is_empty():
				return err

	for index in profiles.size():
		var row: Dictionary = profiles[index]
		var path := "collections.attributeProfiles[%d]" % index
		for field in ["baseDurationHours", "durationHoursPerPoint", "recoveryAfterEndHours"]:
			err = _need(DomainResult.is_number(row.get(field)), "%s.%s" % [path, field],
				"must be a finite number")
			if not err.is_empty():
				return err
		err = _need(_is_array(row.get("speedToDelayHours")), "%s.speedToDelayHours" % path,
			"speedToDelayHours must be an array")
		if not err.is_empty():
			return err
		err = _need(_is_array(row.get("residualRules")), "%s.residualRules" % path,
			"residualRules must be an array")
		if not err.is_empty():
			return err
		for rule in row["residualRules"]:
			err = _need(_is_dict(rule), "%s.residualRules" % path, "residual rule must be an object")
			if not err.is_empty():
				return err
			err = _ref(indexes, "effects", rule.get("effectId"), "%s.residualRules.effectId" % path)
			if not err.is_empty():
				return err
			err = _need(_is_array(rule.get("points")), "%s.residualRules.points" % path,
				"points must be an array")
			if not err.is_empty():
				return err

	var release: Dictionary = data["release"]
	err = _need(_is_array(release.get("requiredOrderIds")), "release.requiredOrderIds",
		"requiredOrderIds must be an array")
	if not err.is_empty():
		return err
	for order_id in release["requiredOrderIds"]:
		err = _ref(indexes, "letters", order_id, "release.requiredOrderIds")
		if not err.is_empty():
			return err
		err = _need(str(_entry(indexes, "letters", order_id).get("kind", "")) == "order",
			"release.requiredOrderIds", "required order must be an order letter")
		if not err.is_empty():
			return err
	err = _need(_is_array(release.get("homeItems")), "release.homeItems", "homeItems must be an array")
	if not err.is_empty():
		return err
	for item in release["homeItems"]:
		err = _need(_is_dict(item) and _has(indexes, "furniture", item.get("id")), "release.homeItems",
			"unknown furniture")
		if not err.is_empty():
			return err
	err = _need(_is_dict(release.get("ticket")), "release.ticket", "ticket must be an object")
	if not err.is_empty():
		return err
	err = _need(DomainResult.is_int(release.get("minThreeStarOrders")), "release.minThreeStarOrders",
		"minThreeStarOrders must be an integer")
	if not err.is_empty():
		return err

	var endings: Dictionary = data["releaseEndings"]
	for kind in ["departure", "apprentice", "wish"]:
		err = _need(_is_dict(endings.get(kind)), "releaseEndings.%s" % kind, "ending must be an object")
		if not err.is_empty():
			return err
		err = _need(_is_string(endings[kind].get("title")), "releaseEndings.%s.title" % kind,
			"ending title is missing")
		if not err.is_empty():
			return err
		err = _need(_is_string(endings[kind].get("text")), "releaseEndings.%s.text" % kind,
			"ending text is missing")
		if not err.is_empty():
			return err

	var stage1: Dictionary = data["stage1"]
	var economy = stage1.get("initialEconomy")
	err = _need(_is_dict(economy), "stage1.initialEconomy", "initialEconomy must be an object")
	if not err.is_empty():
		return err
	err = _need(DomainResult.is_int(economy.get("currency")), "stage1.initialEconomy.currency",
		"currency must be an integer")
	if not err.is_empty():
		return err
	err = _need(_is_dict(economy.get("ingredients")), "stage1.initialEconomy.ingredients",
		"ingredients must be an object")
	if not err.is_empty():
		return err
	for ingredient_id in economy["ingredients"]:
		err = _ref(indexes, "ingredients", ingredient_id,
			"stage1.initialEconomy.ingredients.%s" % str(ingredient_id))
		if not err.is_empty():
			return err
	err = _need(_is_array(economy.get("specialItems")), "stage1.initialEconomy.specialItems",
		"specialItems must be an array")
	if not err.is_empty():
		return err
	err = _ref(indexes, "equipment", stage1.get("initialEquipmentId"), "stage1.initialEquipmentId")
	if not err.is_empty():
		return err
	var policy = stage1.get("recipePolicy")
	err = _need(_is_dict(policy), "stage1.recipePolicy", "recipePolicy must be an object")
	if not err.is_empty():
		return err
	for key in ["repeatIngredient", "repeatWordDefinition"]:
		err = _need(typeof(policy.get(key)) == TYPE_BOOL, "stage1.recipePolicy.%s" % key,
			"policy must be boolean")
		if not err.is_empty():
			return err
	err = _need(_is_array(stage1.get("sampleCases")), "stage1.sampleCases", "sampleCases must be an array")
	if not err.is_empty():
		return err
	for case in stage1["sampleCases"]:
		err = _recipe_refs(case.get("recipe", {}), indexes, "stage1.sampleCases.recipe")
		if not err.is_empty():
			return err

	var recipes := _collection(data, "recipes")
	for index in recipes.size():
		var row: Dictionary = recipes[index]
		var path := "collections.recipes[%d]" % index
		err = _ref(indexes, "letters", row.get("letterId"), "%s.letterId" % path)
		if not err.is_empty():
			return err
		err = _recipe_refs(row.get("recipe", {}), indexes, "%s.recipe" % path)
		if not err.is_empty():
			return err

	var synthesis: Dictionary = data["synthesis"]
	err = _need(_is_array(synthesis.get("intensityTiers")), "synthesis.intensityTiers",
		"intensityTiers must be an array")
	if not err.is_empty():
		return err
	err = _need(_is_array(synthesis.get("sideEffectRules")), "synthesis.sideEffectRules",
		"sideEffectRules must be an array")
	if not err.is_empty():
		return err
	for rule in synthesis["sideEffectRules"]:
		err = _need(_is_dict(rule) and _is_dict(rule.get("addTags")),
			"synthesis.sideEffectRules.addTags", "addTags must be an object")
		if not err.is_empty():
			return err
		for effect_id in rule["addTags"]:
			err = _ref(indexes, "effects", effect_id,
				"synthesis.sideEffectRules.addTags.%s" % str(effect_id))
			if not err.is_empty():
				return err

	var decorations := _collection(data, "wishDecorations")
	for index in decorations.size():
		var row: Dictionary = decorations[index]
		var path := "collections.wishDecorations[%d]" % index
		err = _need(_is_string(row.get("path")), "%s.path" % path, "decor path is missing")
		if not err.is_empty():
			return err
		err = _need(DomainResult.is_number(row.get("width")) and DomainResult.is_number(row.get("height")),
			"%s.size" % path, "decor size is missing")
		if not err.is_empty():
			return err

	var spans: Dictionary = data["letterSpans"]
	for letter in letters:
		if letter.get("kind") != "order":
			continue
		var letter_id := str(letter.get("id", ""))
		err = _need(spans.has(letter_id), "letterSpans.%s" % letter_id, "order letter spans are missing")
		if not err.is_empty():
			return err
		var parsed = spans[letter_id]
		err = _need(_is_dict(parsed) and _is_array(parsed.get("spans")),
			"letterSpans.%s.spans" % letter_id, "spans must be an array")
		if not err.is_empty():
			return err
		var covered: Dictionary = {}
		for span in parsed["spans"]:
			err = _need(_is_dict(span) and _is_string(span.get("spanId")),
				"letterSpans.%s.spans" % letter_id, "span must have an id")
			if not err.is_empty():
				return err
			err = _ref(indexes, "words", span.get("wordId"),
				"letterSpans.%s.spans.%s.wordId" % [letter_id, str(span.get("spanId"))])
			if not err.is_empty():
				return err
			covered[str(span["wordId"])] = true
		for word_id in letter.get("cutWordIds", []):
			err = _need(covered.has(str(word_id)), "letterSpans.%s.spans" % letter_id,
				"cut word has no parsed span")
			if not err.is_empty():
				return err
	return {}
