class_name Potion
extends RefCounted

## Pure eight-step calculation translated from scripts/systems/Potion.lua.
## No engine state, no persistence and no UI references.

const MODS := ["intensity", "duration", "speed", "stability", "sideEffect"]


static func _fail(code: String, path: String, message: String, details: Dictionary = {}) -> Dictionary:
	return DomainResult.fail(code, path, message, details)


static func _known(catalog: ContentCatalog, collection: String, identifier, path: String) -> Dictionary:
	if typeof(identifier) != TYPE_STRING or identifier.is_empty():
		return _fail("INVALID_REQUEST", path, "id must be a non-empty string")
	var row: Dictionary = catalog.entry_ref(collection, identifier)
	if row.is_empty():
		return _fail("UNKNOWN_ID", path, "unknown id %s" % identifier, {"id": identifier})
	return {"ok": true, "value": row}


static func _weights(values, catalog: ContentCatalog, path: String, positive: bool = false) -> Dictionary:
	if typeof(values) != TYPE_DICTIONARY:
		return _fail("CONFIG_INVALID", path, "effect weights must be an object")
	for effect_id in values:
		var known := _known(catalog, "effects", effect_id, "%s.%s" % [path, effect_id])
		if not known.ok:
			return known
		var weight = values[effect_id]
		if not DomainResult.is_number(weight):
			return _fail("CONFIG_INVALID", "%s.%s" % [path, effect_id], "weight must be finite")
		if positive and float(weight) <= 0.0:
			return _fail("CONFIG_INVALID", "%s.%s" % [path, effect_id], "weight must be positive")
	return {}


static func _policy(catalog: ContentCatalog, key: String, repeated: bool) -> Dictionary:
	var policy = catalog.stage1().get("recipePolicy", {})
	var value = null
	if typeof(policy) == TYPE_DICTIONARY:
		value = policy.get(key)
	if repeated:
		if value == null:
			return _fail("DUPLICATE_POLICY_MISSING", "stage1.recipePolicy.%s" % key,
				"missing duplicate policy")
		if typeof(value) != TYPE_BOOL:
			return _fail("CONFIG_INVALID", "stage1.recipePolicy.%s" % key, "policy must be boolean")
		if not bool(value):
			return _fail("DUPLICATE_NOT_ALLOWED", "recipe", "duplicate input is not allowed",
				{"policy": key})
	elif value != null and typeof(value) != TYPE_BOOL:
		return _fail("CONFIG_INVALID", "stage1.recipePolicy.%s" % key, "policy must be boolean")
	return {}


static func _word_ref(ref, catalog: ContentCatalog, path: String,
		used_tokens: Dictionary, used_words: Dictionary) -> Dictionary:
	var checked := DomainResult.keys(ref, ["tokenId", "definition", "source"], path)
	if not checked.is_empty():
		return {"ok": false, "error": checked}
	if typeof(ref.get("tokenId")) != TYPE_STRING or ref["tokenId"].is_empty():
		return _fail("INVALID_REQUEST", path, "tokenId must be non-empty")
	if typeof(ref.get("definition")) != TYPE_DICTIONARY:
		return _fail("INVALID_REQUEST", path, "definition must be an object")
	var definition: Dictionary = ref["definition"]
	var definition_id = definition.get("id")
	var known := _known(catalog, "words", definition_id, "%s.definition.id" % path)
	if not known.ok:
		return known
	if not DomainResult.equal(known.value, definition):
		return _fail("INVALID_REQUEST", "%s.definition" % path, "definition does not match content")
	var source = ref.get("source")
	var source_keys := DomainResult.keys(source, ["wordId", "sourceLetterInstanceId", "sourceSpanId", "sourceNpcId"],
		"%s.source" % path)
	if not source_keys.is_empty():
		return {"ok": false, "error": source_keys}
	for key in ["wordId", "sourceLetterInstanceId", "sourceSpanId", "sourceNpcId"]:
		if typeof(source.get(key)) != TYPE_STRING or source[key].is_empty():
			return _fail("INVALID_REQUEST", "%s.source.%s" % [path, key], "source field must be non-empty")
	if source["wordId"] != definition_id:
		return _fail("SOURCE_INVALID", "%s.source.wordId" % path, "source word does not match definition")
	if used_tokens.has(ref["tokenId"]):
		return _fail("DUPLICATE_TOKEN", path, "the same token occupies more than one slot")
	used_tokens[ref["tokenId"]] = true
	var repeated := used_words.has(definition_id)
	var policy := _policy(catalog, "repeatWordDefinition", repeated)
	if not policy.is_empty():
		return {"ok": false, "error": policy}
	used_words[definition_id] = true
	var weights := _weights(definition.get("effects", {}), catalog, "%s.definition.effects" % path)
	if not weights.is_empty():
		return {"ok": false, "error": weights}
	return {"ok": true, "value": ref.duplicate(true)}


static func validate_resolved_recipe(resolved_recipe, catalog: ContentCatalog) -> Dictionary:
	if typeof(resolved_recipe) != TYPE_DICTIONARY:
		return _fail("INVALID_REQUEST", "resolvedRecipe", "recipe must be an object")
	var recipe: Dictionary = resolved_recipe
	var checked := DomainResult.keys(recipe,
		["orderId", "baselineId", "contentVersion", "equipment", "main", "aux", "ingredients", "specialItems"],
		"resolvedRecipe")
	if not checked.is_empty():
		return {"ok": false, "error": checked}
	if typeof(recipe.get("orderId")) != TYPE_STRING or recipe["orderId"].is_empty() \
			or typeof(recipe.get("baselineId")) != TYPE_STRING or recipe["baselineId"].is_empty():
		return _fail("INVALID_REQUEST", "resolvedRecipe", "orderId and baselineId must be non-empty")
	if recipe.get("contentVersion") != catalog.content_version():
		return _fail("CONTENT_VERSION_MISMATCH", "resolvedRecipe.contentVersion",
			"resolved recipe uses a different content version")
	if typeof(recipe.get("equipment")) != TYPE_DICTIONARY:
		return _fail("INVALID_REQUEST", "equipment", "equipment definition is required")
	var equipment: Dictionary = recipe["equipment"]
	var known_equipment := _known(catalog, "equipment", equipment.get("id"), "equipment.id")
	if not known_equipment.ok:
		return known_equipment
	if not DomainResult.equal(known_equipment.value, equipment):
		return _fail("INVALID_REQUEST", "equipment", "equipment does not match content")
	var slots = equipment.get("slots")
	if typeof(slots) != TYPE_DICTIONARY:
		return _fail("CONFIG_INVALID", "equipment.slots", "slots must be an object")
	var slot_keys := DomainResult.keys(slots, ["mainWord", "auxWord", "ingredient", "specialItem"],
		"equipment.slots", "CONFIG_INVALID")
	if not slot_keys.is_empty():
		return {"ok": false, "error": slot_keys}
	for key in ["mainWord", "auxWord", "ingredient", "specialItem"]:
		if not DomainResult.is_int(slots.get(key)):
			return _fail("CONFIG_INVALID", "equipment.slots.%s" % key, "slot must be an integer")
	if typeof(recipe.get("aux")) != TYPE_ARRAY:
		return _fail("INVALID_REQUEST", "aux", "aux must be an array")
	if typeof(recipe.get("ingredients")) != TYPE_ARRAY:
		return _fail("INVALID_REQUEST", "ingredients", "ingredients must be an array")
	if typeof(recipe.get("specialItems")) != TYPE_ARRAY:
		return _fail("INVALID_REQUEST", "specialItems", "specialItems must be an array")
	if int(slots["mainWord"]) < 1 or (recipe["aux"] as Array).size() > int(slots["auxWord"]):
		return _fail("SLOT_LIMIT", "words", "word slot limit exceeded")
	if (recipe["specialItems"] as Array).size() > int(slots["specialItem"]):
		return _fail("SLOT_LIMIT", "specialItems", "special item slot limit exceeded")
	var used_tokens: Dictionary = {}
	var used_words: Dictionary = {}
	var main_ref := _word_ref(recipe.get("main"), catalog, "main", used_tokens, used_words)
	if not main_ref.ok:
		return main_ref
	var aux_refs: Array = []
	for index in (recipe["aux"] as Array).size():
		var aux_ref := _word_ref(recipe["aux"][index], catalog, "aux.%d" % (index + 1),
			used_tokens, used_words)
		if not aux_ref.ok:
			return aux_ref
		aux_refs.append(aux_ref.value)
	var ingredient_rows: Array = []
	var used_ingredients: Dictionary = {}
	var total := 0
	for index in (recipe["ingredients"] as Array).size():
		var row = recipe["ingredients"][index]
		var path := "ingredients.%d" % (index + 1)
		var row_keys := DomainResult.keys(row, ["ingredientId", "quantity", "definition"], path)
		if not row_keys.is_empty():
			return {"ok": false, "error": row_keys}
		if not DomainResult.is_int(row.get("quantity")) or int(row["quantity"]) < 1:
			return _fail("INVALID_REQUEST", "%s.quantity" % path, "quantity must be a positive integer")
		if used_ingredients.has(row.get("ingredientId")):
			return _fail("INVALID_REQUEST", path, "ingredient ids must be aggregated")
		used_ingredients[row["ingredientId"]] = true
		var known_ingredient := _known(catalog, "ingredients", row.get("ingredientId"),
			"%s.ingredientId" % path)
		if not known_ingredient.ok:
			return known_ingredient
		if typeof(row.get("definition")) != TYPE_DICTIONARY \
				or not DomainResult.equal(row["definition"], known_ingredient.value):
			return _fail("INVALID_REQUEST", "%s.definition" % path,
				"ingredient definition does not match content")
		total += int(row["quantity"])
		if total > int(slots["ingredient"]):
			return _fail("SLOT_LIMIT", "ingredients", "ingredient slot limit exceeded",
				{"used": total, "limit": int(slots["ingredient"])})
		var repeated := int(row["quantity"]) > 1
		var policy := _policy(catalog, "repeatIngredient", repeated)
		if not policy.is_empty():
			return {"ok": false, "error": policy}
		var definition: Dictionary = row["definition"]
		var mods = definition.get("mods")
		if typeof(mods) != TYPE_DICTIONARY:
			return _fail("CONFIG_INVALID", "%s.mods" % path, "ingredient mods must be an object")
		var mod_keys := DomainResult.keys(mods, ["intensity", "duration", "speed", "stability", "sideEffect"],
			"%s.mods" % path, "CONFIG_INVALID")
		if not mod_keys.is_empty():
			return {"ok": false, "error": mod_keys}
		for key in mods:
			if not DomainResult.is_number(mods[key]) or float(mods[key]) < -4.0 or float(mods[key]) > 4.0:
				return _fail("CONFIG_INVALID", "%s.mods.%s" % [path, key],
					"ingredient mod must be between -4 and 4")
		var add_weights := _weights(definition.get("addTags", {}), catalog, "%s.addTags" % path)
		if not add_weights.is_empty():
			return {"ok": false, "error": add_weights}
		ingredient_rows.append(row.duplicate(true))
	if not (recipe["specialItems"] as Array).is_empty():
		return _fail("CONFIG_MISSING", "specialItems.synthesis",
			"special item synthesis is not configured")
	return {
		"ok": true,
		"value": {
			"orderId": recipe["orderId"],
			"baselineId": recipe["baselineId"],
			"contentVersion": recipe["contentVersion"],
			"equipment": equipment.duplicate(true),
			"main": main_ref.value.duplicate(true),
			"aux": aux_refs.duplicate(true),
			"ingredients": ingredient_rows,
			"specialItems": [],
		},
	}


static func _synthesis_config(catalog: ContentCatalog) -> Dictionary:
	var config = catalog.synthesis()
	if typeof(config) != TYPE_DICTIONARY:
		return _fail("CONFIG_MISSING", "synthesis", "synthesis config is required")
	for key in ["auxWeight", "sameTagBonus", "intensityScale", "unstableThreshold"]:
		if not DomainResult.is_number(config.get(key)):
			return _fail("CONFIG_MISSING", "synthesis.%s" % key, "missing finite value")
	if not DomainResult.is_int(config.get("version")):
		if typeof(config.get("version")) != TYPE_STRING or config["version"].is_empty():
			return _fail("CONFIG_MISSING", "synthesis.version", "missing synthesis version")
	var tiers = config.get("intensityTiers")
	if typeof(tiers) != TYPE_ARRAY or (tiers as Array).is_empty():
		return _fail("CONFIG_MISSING", "synthesis.intensityTiers", "intensity tiers are required")
	var previous := -INF
	for index in (tiers as Array).size():
		var tier = tiers[index]
		if typeof(tier) != TYPE_DICTIONARY or not DomainResult.is_number(tier.get("max")) \
				or typeof(tier.get("label")) != TYPE_STRING:
			return _fail("CONFIG_INVALID", "synthesis.intensityTiers.%d" % (index + 1),
				"tier must have finite max and label")
		var maximum := float(tier["max"])
		if maximum <= previous:
			return _fail("CONFIG_INVALID", "synthesis.intensityTiers.%d" % (index + 1),
				"tier max must strictly increase")
		previous = maximum
	var rules = config.get("sideEffectRules")
	if typeof(rules) != TYPE_ARRAY:
		return _fail("CONFIG_MISSING", "synthesis.sideEffectRules", "side effect rules are required")
	var seen: Dictionary = {}
	for index in (rules as Array).size():
		var rule = rules[index]
		var path := "synthesis.sideEffectRules.%d" % (index + 1)
		if typeof(rule) != TYPE_DICTIONARY or typeof(rule.get("id")) != TYPE_STRING \
				or rule["id"].is_empty() or seen.has(rule["id"]) \
				or not DomainResult.is_number(rule.get("minSideEffect")):
			return _fail("CONFIG_INVALID", path, "side effect rule is invalid")
		seen[rule["id"]] = true
		var weights := _weights(rule.get("addTags", {}), catalog, "%s.addTags" % path)
		if not weights.is_empty():
			return {"ok": false, "error": weights}
	return {"ok": true, "value": config}


static func _grade(effects: Dictionary, config: Dictionary) -> Dictionary:
	var tiers: Dictionary = {}
	for effect_id in DomainResult.sorted_keys(effects):
		var value := float(effects[effect_id])
		if not is_finite(value):
			return _fail("CONFIG_INVALID", "effects.%s" % effect_id, "effect weight overflow")
		if value <= 0.0:
			effects.erase(effect_id)
			continue
		var found := false
		for tier in config.get("intensityTiers", []):
			if value <= float(tier["max"]):
				tiers[effect_id] = tier["label"]
				found = true
				break
		if not found:
			return _fail("CONFIG_INVALID", "synthesis.intensityTiers",
				"intensity tiers do not cover result", {"effectId": effect_id, "weight": value})
	return {"ok": true, "value": tiers}


static func _time_values(main_ref: Dictionary, mods: Dictionary, effects: Dictionary,
		catalog: ContentCatalog) -> Dictionary:
	var definition: Dictionary = main_ref.get("definition", {})
	var profile_id = definition.get("attributeProfileId")
	if typeof(profile_id) != TYPE_STRING or profile_id.is_empty():
		return _fail("CONFIG_MISSING", "words.%s.attributeProfileId" % str(definition.get("id")),
			"main word has no attribute profile")
	var known_profile := _known(catalog, "attributeProfiles", profile_id, "attributeProfileId")
	if not known_profile.ok:
		return known_profile
	var profile: Dictionary = known_profile.value
	for key in ["baseDurationHours", "durationHoursPerPoint", "recoveryAfterEndHours"]:
		if not DomainResult.is_number(profile.get(key)) or float(profile[key]) < 0.0:
			return _fail("CONFIG_INVALID", "attributeProfiles.%s.%s" % [profile_id, key],
				"profile value must be non-negative")
	var duration := float(profile["baseDurationHours"]) \
		+ float(mods["duration"]) * float(profile["durationHoursPerPoint"])
	if not is_finite(duration) or duration < 0.0:
		return _fail("CONFIG_INVALID", "durationHours", "duration became negative or overflowed")
	var speed_map = profile.get("speedToDelayHours")
	if typeof(speed_map) != TYPE_ARRAY:
		return _fail("CONFIG_MISSING", "attributeProfiles.%s.speedToDelayHours" % profile_id,
			"speed mapping is required")
	var delay = null
	var seen_speeds: Dictionary = {}
	for index in (speed_map as Array).size():
		var item = speed_map[index]
		var path := "attributeProfiles.%s.speedToDelayHours.%d" % [profile_id, index + 1]
		if typeof(item) != TYPE_DICTIONARY or not DomainResult.is_number(item.get("speed")) \
				or not DomainResult.is_number(item.get("delayHours")) or float(item["delayHours"]) < 0.0:
			return _fail("CONFIG_INVALID", path, "speed mapping is invalid")
		var speed := float(item["speed"])
		if seen_speeds.has(speed):
			return _fail("CONFIG_INVALID", path, "duplicate speed mapping")
		seen_speeds[speed] = true
		if speed == float(mods["speed"]):
			delay = float(item["delayHours"])
	if delay == null:
		return _fail("CONFIG_MISSING", "attributeProfiles.%s.speedToDelayHours" % profile_id,
			"speed has no exact mapping", {"speed": mods["speed"]})
	var ending := float(delay) + duration
	if not is_finite(ending) or ending < 0.0:
		return _fail("CONFIG_INVALID", "time", "effect end overflow")
	var residual_rules = profile.get("residualRules")
	if typeof(residual_rules) != TYPE_ARRAY:
		return _fail("CONFIG_MISSING", "attributeProfiles.%s.residualRules" % profile_id,
			"residual rules are required")
	var residuals: Array = []
	var known_effects: Dictionary = {}
	for rule_index in (residual_rules as Array).size():
		var rule = residual_rules[rule_index]
		var path := "attributeProfiles.%s.residualRules.%d" % [profile_id, rule_index + 1]
		if typeof(rule) != TYPE_DICTIONARY:
			return _fail("CONFIG_INVALID", path, "residual rule must be an object")
		var known_effect := _known(catalog, "effects", rule.get("effectId"), "%s.effectId" % path)
		if not known_effect.ok:
			return known_effect
		if known_effects.has(rule["effectId"]):
			return _fail("CONFIG_INVALID", path, "duplicate residual effect")
		known_effects[rule["effectId"]] = true
		var points = rule.get("points")
		if typeof(points) != TYPE_ARRAY or (points as Array).is_empty():
			return _fail("CONFIG_MISSING", "%s.points" % path, "residual points are empty")
		var previous := 1.0
		for point_index in (points as Array).size():
			var point = points[point_index]
			var point_path := "%s.points.%d" % [path, point_index + 1]
			if typeof(point) != TYPE_DICTIONARY or not DomainResult.is_number(point.get("ratio")) \
					or not DomainResult.is_number(point.get("hoursAfterEnd")):
				return _fail("CONFIG_INVALID", point_path, "residual point is invalid")
			if not DomainResult.is_int(point["hoursAfterEnd"]) \
					or int(point["hoursAfterEnd"]) != point_index:
				return _fail("CONFIG_INVALID", point_path,
					"residual points must start at 0 and increase by one hour")
			var ratio := float(point["ratio"])
			if ratio < 0.0 or ratio > previous:
				return _fail("CONFIG_INVALID", point_path,
					"residual ratio must be between 0 and the previous ratio")
			previous = ratio
			var weight := float(effects.get(rule["effectId"], 0.0)) * ratio
			var at := ending + float(point["hoursAfterEnd"])
			if not is_finite(weight) or not is_finite(at) or weight < 0.0 or at < 0.0:
				return _fail("CONFIG_INVALID", path, "residual calculation overflowed")
			residuals.append({
				"effectId": rule["effectId"],
				"weight": weight,
				"untilAfterDoseHours": at,
			})
	residuals.sort_custom(_residual_order)
	return {
		"ok": true,
		"value": {
			"durationHours": duration,
			"onsetDelayHours": float(delay),
			"recoveryAfterEndHours": float(profile["recoveryAfterEndHours"]),
			"residuals": residuals,
		},
	}


static func _residual_order(a: Dictionary, b: Dictionary) -> bool:
	if a["effectId"] == b["effectId"]:
		return float(a["untilAfterDoseHours"]) < float(b["untilAfterDoseHours"])
	return str(a["effectId"]) < str(b["effectId"])


static func _trace(step: int, inputs: Dictionary, outputs: Dictionary, source_ids: Array) -> Dictionary:
	return {
		"step": step,
		"inputs": inputs.duplicate(true),
		"outputs": outputs.duplicate(true),
		"sourceIds": source_ids.duplicate(true),
	}


static func evaluate(resolved_recipe, catalog: ContentCatalog) -> Dictionary:
	var validation := validate_resolved_recipe(resolved_recipe, catalog)
	if not validation.ok:
		return validation
	var recipe: Dictionary = validation.value
	var config_result := _synthesis_config(catalog)
	if not config_result.ok:
		return config_result
	var config: Dictionary = config_result.value
	var effects: Dictionary = (recipe["main"]["definition"]["effects"] as Dictionary).duplicate(true)
	var trace: Array = []
	trace.append(_trace(1, {"main": recipe["main"]}, effects, [recipe["main"]["definition"]["id"]]))
	var before := effects.duplicate(true)
	var source_ids: Array = []
	for ref in recipe["aux"]:
		source_ids.append(ref["definition"]["id"])
		for effect_id in DomainResult.sorted_keys(ref["definition"]["effects"]):
			var bonus := float(config["sameTagBonus"]) if effects.has(effect_id) else 0.0
			effects[effect_id] = float(effects.get(effect_id, 0.0)) \
				+ float(ref["definition"]["effects"][effect_id]) * float(config["auxWeight"]) + bonus
	trace.append(_trace(2, {
		"effects": before,
		"aux": recipe["aux"],
		"auxWeight": config["auxWeight"],
		"sameTagBonus": config["sameTagBonus"],
	}, effects, source_ids))
	before = effects.duplicate(true)
	source_ids = []
	for row in recipe["ingredients"]:
		source_ids.append(row["ingredientId"])
		for effect_id in DomainResult.sorted_keys(row["definition"]["addTags"]):
			effects[effect_id] = float(effects.get(effect_id, 0.0)) \
				+ float(row["definition"]["addTags"][effect_id]) * float(config["auxWeight"]) \
				* float(row["quantity"])
	trace.append(_trace(3, {
		"effects": before,
		"ingredients": recipe["ingredients"],
		"auxWeight": config["auxWeight"],
	}, effects, source_ids))
	var mods := {"intensity": 0.0, "duration": 0.0, "speed": 0.0, "stability": 0.0, "sideEffect": 0.0}
	for row in recipe["ingredients"]:
		for key in row["definition"]["mods"]:
			mods[key] = float(mods[key]) + float(row["definition"]["mods"][key]) * float(row["quantity"])
	for key in MODS:
		if not is_finite(float(mods[key])):
			return _fail("CONFIG_INVALID", "mods.%s" % key, "modifier overflowed")
	trace.append(_trace(4, {"ingredients": recipe["ingredients"]}, mods, source_ids))
	before = effects.duplicate(true)
	var scale := 1.0 + float(mods["intensity"]) * float(config["intensityScale"])
	if not is_finite(scale) or scale < 0.0:
		return _fail("CONFIG_INVALID", "synthesis.intensityScale", "intensity scale is negative or overflowed")
	for effect_id in effects.keys():
		var scaled := float(effects[effect_id]) * scale
		if not is_finite(scaled):
			return _fail("CONFIG_INVALID", "effects.%s" % effect_id, "effect weight overflowed")
		if scaled > 0.0:
			effects[effect_id] = scaled
		else:
			effects.erase(effect_id)
	trace.append(_trace(5, {
		"effects": before,
		"intensity": mods["intensity"],
		"intensityScale": config["intensityScale"],
		"scale": scale,
	}, effects, []))
	var graded := _grade(effects, config)
	if not graded.ok:
		return graded
	var tiers: Dictionary = graded.value
	trace.append(_trace(6, {"effects": effects, "intensityTiers": config["intensityTiers"]}, tiers, []))
	before = effects.duplicate(true)
	source_ids = []
	var side_effects: Array = []
	for rule in config["sideEffectRules"]:
		if float(mods["sideEffect"]) >= float(rule["minSideEffect"]):
			source_ids.append(rule["id"])
			side_effects.append({"ruleId": rule["id"], "addTags": rule["addTags"].duplicate(true)})
			for effect_id in DomainResult.sorted_keys(rule["addTags"]):
				effects[effect_id] = float(effects.get(effect_id, 0.0)) + float(rule["addTags"][effect_id])
	graded = _grade(effects, config)
	if not graded.ok:
		return graded
	tiers = graded.value
	trace.append(_trace(7, {
		"effects": before,
		"sideEffect": mods["sideEffect"],
		"rules": config["sideEffectRules"],
	}, {"effects": effects, "intensityByEffect": tiers, "sideEffects": side_effects}, source_ids))
	var unstable := float(mods["stability"]) < float(config["unstableThreshold"])
	trace.append(_trace(8, {
		"stability": mods["stability"],
		"unstableThreshold": config["unstableThreshold"],
	}, {"stability": mods["stability"], "unstable": unstable}, []))
	var time_result := _time_values(recipe["main"], mods, effects, catalog)
	if not time_result.ok:
		return time_result
	var times: Dictionary = time_result.value
	return {
		"ok": true,
		"value": {
			"synthesisVersion": config["version"],
			"contentVersion": catalog.content_version(),
			"effects": effects,
			"intensityByEffect": tiers,
			"mods": mods,
			"durationHours": times["durationHours"],
			"onsetDelayHours": times["onsetDelayHours"],
			"recoveryAfterEndHours": times["recoveryAfterEndHours"],
			"residuals": times["residuals"],
			"stability": mods["stability"],
			"unstable": unstable,
			"sideEffects": side_effects,
			"trace": trace,
		},
	}


static func _residual_points(potion: Dictionary, effect_id: String) -> Dictionary:
	var points: Array = []
	var ending := float(potion["onsetDelayHours"]) + float(potion["durationHours"])
	for point in potion["residuals"]:
		if point["effectId"] == effect_id:
			points.append(point)
	points.sort_custom(_residual_order)
	var previous := float(potion["effects"].get(effect_id, 0.0))
	for index in points.size():
		var point: Dictionary = points[index]
		if float(point["weight"]) < 0.0 or float(point["weight"]) > previous \
				or not is_equal_approx(float(point["untilAfterDoseHours"]), ending + float(index)):
			return _fail("INVALID_REQUEST", "potion.residuals",
				"residual points are not continuous or non-increasing")
		previous = float(point["weight"])
	return {"ok": true, "value": points}


static func validate_result(potion, catalog: ContentCatalog) -> Dictionary:
	if typeof(potion) != TYPE_DICTIONARY:
		return _fail("INVALID_REQUEST", "potion", "potion result must be an object")
	var checked := DomainResult.keys(potion, [
		"synthesisVersion", "contentVersion", "effects", "intensityByEffect", "mods",
		"durationHours", "onsetDelayHours", "recoveryAfterEndHours", "residuals",
		"stability", "unstable", "sideEffects", "trace",
	], "potion")
	if not checked.is_empty():
		return {"ok": false, "error": checked}
	if potion.get("contentVersion") != catalog.content_version():
		return _fail("CONTENT_VERSION_MISMATCH", "potion.contentVersion", "content version mismatch")
	var config_result := _synthesis_config(catalog)
	if not config_result.ok:
		return config_result
	var config: Dictionary = config_result.value
	if potion.get("synthesisVersion") != config.get("version"):
		return _fail("CONTENT_VERSION_MISMATCH", "potion.synthesisVersion", "synthesis version mismatch")
	var weights := _weights(potion.get("effects"), catalog, "potion.effects", true)
	if not weights.is_empty():
		return {"ok": false, "error": weights}
	var graded := _grade((potion["effects"] as Dictionary).duplicate(true), config)
	if not graded.ok:
		return graded
	if not DomainResult.equal(graded.value, potion.get("intensityByEffect")):
		return _fail("INVALID_REQUEST", "potion.intensityByEffect",
			"intensity tiers do not match final weights")
	var mods = potion.get("mods")
	var mod_keys := DomainResult.keys(mods, MODS, "potion.mods")
	if not mod_keys.is_empty():
		return {"ok": false, "error": mod_keys}
	for key in MODS:
		if not DomainResult.is_number(mods.get(key)):
			return _fail("INVALID_REQUEST", "potion.mods.%s" % key, "missing finite modifier")
	for key in ["durationHours", "onsetDelayHours", "recoveryAfterEndHours"]:
		if not DomainResult.is_number(potion.get(key)) or float(potion[key]) < 0.0:
			return _fail("INVALID_REQUEST", "potion.%s" % key, "time must be non-negative")
	if not is_finite(float(potion["onsetDelayHours"]) + float(potion["durationHours"])
			+ float(potion["recoveryAfterEndHours"])):
		return _fail("INVALID_REQUEST", "potion.time", "time sum overflowed")
	if not DomainResult.equal(potion.get("stability"), mods.get("stability")) \
			or bool(potion.get("unstable")) != (float(mods["stability"]) < float(config["unstableThreshold"])):
		return _fail("INVALID_REQUEST", "potion.stability", "stability marker does not match modifiers")
	if typeof(potion.get("residuals")) != TYPE_ARRAY:
		return _fail("INVALID_REQUEST", "potion.residuals", "residuals must be an array")
	var sampled: Dictionary = {}
	for point in potion["residuals"]:
		var point_keys := DomainResult.keys(point, ["effectId", "weight", "untilAfterDoseHours"],
			"potion.residuals")
		if not point_keys.is_empty():
			return {"ok": false, "error": point_keys}
		var known := _known(catalog, "effects", point.get("effectId"), "potion.residuals.effectId")
		if not known.ok:
			return known
		if not DomainResult.is_number(point.get("weight")) or float(point["weight"]) < 0.0 \
				or not DomainResult.is_number(point.get("untilAfterDoseHours")) \
				or float(point["untilAfterDoseHours"]) < 0.0:
			return _fail("INVALID_REQUEST", "potion.residuals", "residual value is invalid")
		sampled[point["effectId"]] = true
	for effect_id in sampled:
		var points := _residual_points(potion, effect_id)
		if not points.ok:
			return points
	if typeof(potion.get("sideEffects")) != TYPE_ARRAY:
		return _fail("INVALID_REQUEST", "potion.sideEffects", "sideEffects must be an array")
	var rules: Dictionary = {}
	for rule in potion["sideEffects"]:
		var rule_keys := DomainResult.keys(rule, ["ruleId", "addTags"], "potion.sideEffects")
		if not rule_keys.is_empty():
			return {"ok": false, "error": rule_keys}
		if rules.has(rule.get("ruleId")):
			return _fail("INVALID_REQUEST", "potion.sideEffects", "duplicate side effect rule")
		rules[rule["ruleId"]] = true
		var found = null
		for definition in config["sideEffectRules"]:
			if definition["id"] == rule["ruleId"]:
				found = definition
				break
		if found == null or not DomainResult.equal(rule.get("addTags"), found["addTags"]):
			return _fail("INVALID_REQUEST", "potion.sideEffects", "side effect definition mismatch")
	if typeof(potion.get("trace")) != TYPE_ARRAY or (potion["trace"] as Array).size() != 8:
		return _fail("INVALID_REQUEST", "potion.trace", "trace must contain eight steps")
	for index in 8:
		var row = potion["trace"][index]
		var row_keys := DomainResult.keys(row, ["step", "inputs", "outputs", "sourceIds"], "potion.trace")
		if not row_keys.is_empty():
			return {"ok": false, "error": row_keys}
		if int(row.get("step", 0)) != index + 1 or typeof(row.get("inputs")) != TYPE_DICTIONARY \
				or typeof(row.get("outputs")) != TYPE_DICTIONARY:
			return _fail("INVALID_REQUEST", "potion.trace.%d" % (index + 1), "trace step is invalid")
		if typeof(row.get("sourceIds")) != TYPE_ARRAY:
			return _fail("INVALID_REQUEST", "potion.trace.%d" % (index + 1), "sourceIds must be an array")
		var seen: Dictionary = {}
		for source_id in row["sourceIds"]:
			if typeof(source_id) != TYPE_STRING or source_id.is_empty() or seen.has(source_id):
				return _fail("INVALID_REQUEST", "potion.trace.sourceIds", "source ids must be unique strings")
			seen[source_id] = true
	return {"ok": true, "value": (potion as Dictionary).duplicate(true)}


static func sample_residual(potion: Dictionary, effect_id: String, at_after_dose_hours: float,
		catalog: ContentCatalog) -> Dictionary:
	var validation := validate_result(potion, catalog)
	if not validation.ok:
		return validation
	var known := _known(catalog, "effects", effect_id, "effectId")
	if not known.ok:
		return known
	if not is_finite(at_after_dose_hours) or at_after_dose_hours < 0.0:
		return _fail("INVALID_REQUEST", "atAfterDoseHours", "sample time must be non-negative")
	var points_result := _residual_points(potion, effect_id)
	if not points_result.ok:
		return points_result
	var points: Array = points_result.value
	if points.is_empty():
		return _fail("CONFIG_MISSING", "residuals.%s" % effect_id, "no residual configuration")
	if at_after_dose_hours < float(points[0]["untilAfterDoseHours"]):
		return {"ok": true, "value": float(potion["effects"].get(effect_id, 0.0))}
	if at_after_dose_hours > float(points[points.size() - 1]["untilAfterDoseHours"]):
		return {"ok": true, "value": 0.0}
	for point in points:
		if is_equal_approx(at_after_dose_hours, float(point["untilAfterDoseHours"])):
			return {"ok": true, "value": float(point["weight"])}
	return _fail("CONFIG_MISSING", "residuals.%s" % effect_id,
		"sample time is not a declared point", {"atAfterDoseHours": at_after_dose_hours})
