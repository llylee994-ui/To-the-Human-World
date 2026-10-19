extends RefCounted

## Replays the Lua-generated potion cases through Potion.evaluate and compares
## every behavioral field. The trace is checked for shape, not deep-compared.

const ORACLE_PATH := "res://tests/fixtures/oracle_cases.json"
const ORACLE_LETTER := "letter_pa_01"

var assertions := 0
var completed := false


func _check(failures: Array[String], condition: bool, message: String) -> void:
	assertions += 1
	if not condition:
		failures.append(message)


func _approx_equal(a, b) -> bool:
	if typeof(a) == TYPE_INT or typeof(a) == TYPE_FLOAT:
		if typeof(b) != TYPE_INT and typeof(b) != TYPE_FLOAT:
			return false
		var left := float(a)
		var right := float(b)
		return absf(left - right) <= 1e-9 * maxf(1.0, maxf(absf(left), absf(right)))
	if typeof(a) == TYPE_DICTIONARY:
		if typeof(b) != TYPE_DICTIONARY or (a as Dictionary).size() != (b as Dictionary).size():
			return false
		for key in a:
			if not (b as Dictionary).has(key) or not _approx_equal(a[key], b[key]):
				return false
		return true
	if typeof(a) == TYPE_ARRAY:
		if typeof(b) != TYPE_ARRAY or (a as Array).size() != (b as Array).size():
			return false
		for index in (a as Array).size():
			if not _approx_equal(a[index], b[index]):
				return false
		return true
	return DomainResult.equal(a, b)


func _number_text(value) -> String:
	if typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT:
		return String.num(float(value), 17)
	if typeof(value) == TYPE_DICTIONARY:
		var parts: Array = []
		for key in (value as Dictionary).keys():
			parts.append("%s=%s" % [key, _number_text(value[key])])
		parts.sort()
		return "{%s}" % ", ".join(parts)
	if typeof(value) == TYPE_ARRAY:
		var parts: Array = []
		for item in value:
			parts.append(_number_text(item))
		return "[%s]" % ", ".join(parts)
	return str(value)


func _build_resolved(recipe: Dictionary, catalog: ContentCatalog) -> Dictionary:
	var letter: Dictionary = catalog.entry_ref("letters", ORACLE_LETTER)
	var letter_instance := "letter:" + ORACLE_LETTER
	var sender := str(letter.get("senderId", ""))
	var main_word: Dictionary = catalog.entry_ref("words", str(recipe["mainWordId"]))
	var main_ref := {
		"tokenId": "oracle:main",
		"definition": main_word.duplicate(true),
		"source": {
			"wordId": recipe["mainWordId"],
			"sourceLetterInstanceId": letter_instance,
			"sourceSpanId": "fixture:main",
			"sourceNpcId": sender,
		},
	}
	var aux: Array = []
	for index in (recipe.get("auxWordIds", []) as Array).size():
		var word_id := str(recipe["auxWordIds"][index])
		aux.append({
			"tokenId": "oracle:aux:%d" % index,
			"definition": catalog.entry_ref("words", word_id).duplicate(true),
			"source": {
				"wordId": word_id,
				"sourceLetterInstanceId": letter_instance,
				"sourceSpanId": "fixture:aux:%d" % index,
				"sourceNpcId": sender,
			},
		})
	var ingredients: Array = []
	for index in (recipe.get("ingredients", []) as Array).size():
		var row: Dictionary = recipe["ingredients"][index]
		ingredients.append({
			"ingredientId": row["ingredientId"],
			"quantity": row["quantity"],
			"definition": catalog.entry_ref("ingredients", str(row["ingredientId"])).duplicate(true),
		})
	return {
		"orderId": "oracle",
		"baselineId": "oracle:baseline",
		"contentVersion": catalog.content_version(),
		"equipment": catalog.entry_ref("equipment", str(recipe["equipmentId"])).duplicate(true),
		"main": main_ref,
		"aux": aux,
		"ingredients": ingredients,
		"specialItems": [],
	}


func run(_tree: SceneTree) -> Array[String]:
	var failures: Array[String] = []
	var catalog := ContentCatalog.new()
	var loaded: Dictionary = catalog.load_catalog("res://content/generated/catalog.json")
	_check(failures, loaded.get("ok", false), "catalog loads")
	if not loaded.get("ok", false):
		completed = true
		return failures
	var oracle = JSON.parse_string(FileAccess.get_file_as_string(ORACLE_PATH))
	_check(failures, typeof(oracle) == TYPE_DICTIONARY, "oracle fixture loads")
	if typeof(oracle) != TYPE_DICTIONARY:
		completed = true
		return failures
	_check(failures, str(oracle.get("source_hash", "")) == str(catalog.data.get("source_hash", "")),
		"oracle source hash matches catalog")
	var cases: Array = oracle.get("potion_cases", [])
	_check(failures, cases.size() >= 100, "potion oracle covers the content (got %d)" % cases.size())
	for case in cases:
		var case_id := str(case.get("id", ""))
		var resolved := _build_resolved(case["recipe"], catalog)
		var validation := Potion.validate_resolved_recipe(resolved, catalog)
		var result := Potion.evaluate(resolved, catalog)
		var expected: Dictionary = case["expected"]
		_check(failures, bool(result.get("ok", false)) == bool(expected.get("ok", false)),
			"potion ok mismatch: %s result_ok=%s expected_ok=%s result=%s validation=%s expected=%s" % [case_id, str(result.get("ok")), str(expected.get("ok")), str(result), str(validation), str(expected.get("error", {}))])
		if not expected.get("ok", false):
			if not result.get("ok", false):
				_check(failures, str(result["error"].get("code", "")) == str(expected["error"].get("code", "")),
					"potion error code mismatch: %s" % case_id)
			continue
		if not result.get("ok", false):
			continue
		var actual: Dictionary = result["value"]
		var wanted: Dictionary = expected["value"]
		for key in ["synthesisVersion", "contentVersion", "durationHours", "onsetDelayHours",
				"recoveryAfterEndHours", "stability", "unstable", "effects", "intensityByEffect",
				"mods", "residuals", "sideEffects"]:
			var equal := DomainResult.equal(actual.get(key), wanted.get(key))
			if key in ["durationHours", "onsetDelayHours", "recoveryAfterEndHours", "stability",
					"effects", "mods", "residuals", "sideEffects"]:
				equal = _approx_equal(actual.get(key), wanted.get(key))
			_check(failures, equal,
				"potion %s mismatch: %s\nactual=%s\nexpected=%s" % [case_id, key,
					_number_text(actual.get(key)), _number_text(wanted.get(key))])
		_check(failures, (actual.get("trace", []) as Array).size() == 8,
			"potion trace has eight steps: %s" % case_id)
	completed = true
	return failures
