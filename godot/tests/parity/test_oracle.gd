extends RefCounted

## Replays Lua token-source and recipe-draft cases against the GDScript domain.

const ORACLE_PATH := "res://tests/fixtures/oracle_cases.json"

var assertions := 0
var completed := false


func _check(failures: Array[String], condition: bool, message: String) -> void:
	assertions += 1
	if not condition:
		failures.append(message)


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

	var token_cases: Array = oracle.get("token_cases", [])
	_check(failures, token_cases.size() >= 70, "token oracle covers every cut span")
	for case in token_cases:
		var case_id := str(case.get("id", ""))
		var source: Dictionary = case["source"]
		var expected: Dictionary = case["expected"]
		var checked := WordToken.validate_source(source, catalog)
		_check(failures, bool(checked.get("ok", false)) == bool(expected.get("ok", false)),
			"token source ok mismatch: %s" % case_id)
		if expected.get("ok", false):
			if checked.get("ok", false):
				var identifier := WordToken.token_id(str(source["sourceLetterInstanceId"]),
					str(source["sourceSpanId"]))
				_check(failures, identifier == str(expected.get("tokenId", "")),
					"token id mismatch: %s (%s)" % [case_id, identifier])
		elif not checked.get("ok", false):
			_check(failures, str(checked["error"].get("code", "")) == str(expected["error"].get("code", "")),
				"token error code mismatch: %s" % case_id)

	var live: Dictionary = oracle.get("draft_live", {})
	var draft_cases: Array = oracle.get("draft_cases", [])
	_check(failures, draft_cases.size() >= 8, "draft oracle covers success and failure paths")
	for case in draft_cases:
		var case_id := str(case.get("id", ""))
		var expected: Dictionary = case["expected"]
		var result := RecipeDraft.validate(case["draft"], live, catalog)
		_check(failures, bool(result.get("ok", false)) == bool(expected.get("ok", false)),
			"draft ok mismatch: %s" % case_id)
		if not expected.get("ok", false) and not result.get("ok", false):
			_check(failures, str(result["error"].get("code", "")) == str(expected["error"].get("code", "")),
				"draft error code mismatch: %s (got %s)" % [case_id, str(result["error"].get("code", ""))])

	completed = true
	return failures
