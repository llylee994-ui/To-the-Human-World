extends RefCounted

## Task 1 fixture self-check. Business replay against Godot commands begins in Task 4.

const MANIFEST_PATH := "res://tests/fixtures/first_order/manifest.json"
const TRACES_PATH := "res://tests/fixtures/first_order/traces.json"
const REQUIRED_RECIPES := [
	"recipe_v02_e01_1", "recipe_v02_e01_2", "recipe_v02_e01_3", "recipe_v02_e01_4",
	"recipe_v02_e01_5", "recipe_v02_e01_6", "recipe_v02_e01_7", "recipe_v02_e01_8",
]

var assertions := 0
var completed := false


func _check(failures: Array[String], condition: bool, message: String) -> void:
	assertions += 1
	if not condition:
		failures.append(message)


func _json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	return JSON.parse_string(FileAccess.get_file_as_string(path))


func run(_tree: SceneTree) -> Array[String]:
	var failures: Array[String] = []
	var manifest = _json(MANIFEST_PATH)
	var traces = _json(TRACES_PATH)
	_check(failures, typeof(manifest) == TYPE_DICTIONARY, "first-order manifest exists")
	_check(failures, typeof(traces) == TYPE_DICTIONARY, "first-order traces exist")
	if typeof(manifest) != TYPE_DICTIONARY or typeof(traces) != TYPE_DICTIONARY:
		completed = true
		return failures
	_check(failures, int(manifest.get("schema_version", 0)) == 1, "manifest schema version")
	_check(failures, int(traces.get("schema_version", 0)) == 1, "traces schema version")
	_check(failures, str(manifest.get("source_hash", "")) == str(traces.get("source_hash", "")),
		"manifest and traces source hash match")
	_check(failures, str(manifest.get("content_version", "")) == str(traces.get("content_version", "")),
		"manifest and traces content version match")
	_check(failures, (manifest.get("source_files", []) as Array).size() >= 50,
		"source inventory covers core/systems/data")
	var source_files: Array = manifest.get("source_files", [])
	var hashed := {}
	for row in source_files:
		hashed[str(row.get("path", ""))] = str(row.get("sha256", ""))
	_check(failures, hashed.has("scripts/core/GameState.lua"), "core GameState is in the source inventory")
	_check(failures, hashed.has("scripts/systems/OrderTrial.lua"), "OrderTrial is in the source inventory")
	_check(failures, hashed.has("scripts/data/content.lua"), "content.lua is in the source inventory")

	var recipes: Array = traces.get("recipes", [])
	_check(failures, recipes.size() == 8, "eight required recipes are frozen")
	var seen := {}
	for row in recipes:
		var case_id := str(row.get("case_id", ""))
		_check(failures, case_id == str(row.get("recipe_id", "")), "recipe id matches case id")
		_check(failures, case_id in REQUIRED_RECIPES, "recipe id is in the frozen list: %s" % case_id)
		seen[case_id] = true
		var steps: Array = row.get("steps", [])
		_check(failures, steps.size() >= 8, "recipe has production steps: %s" % case_id)
		var final: Dictionary = row.get("final", {})
		_check(failures, int(final.get("deliveredOrders", -1)) == 1,
			"recipe ships exactly one order: %s" % case_id)
		_check(failures, not (row.get("expected", {}) as Dictionary).is_empty(),
			"expected outcome is present: %s" % case_id)
		for step in steps:
			_check(failures, not str(step.get("id", "")).is_empty(), "step id: %s" % case_id)
			_check(failures, typeof(step.get("snapshot")) == TYPE_DICTIONARY, "step snapshot: %s" % case_id)
			var snapshot: Dictionary = step["snapshot"]
			for field in ["contentVersion", "revision", "live", "currentOrder", "journal", "chapter"]:
				_check(failures, snapshot.has(field), "snapshot field %s: %s" % [field, case_id])
			_check(failures, typeof(step.get("writes")) == TYPE_FLOAT or typeof(step.get("writes")) == TYPE_INT,
				"step write count: %s" % case_id)
	for recipe_id in REQUIRED_RECIPES:
		_check(failures, seen.has(recipe_id), "required recipe present: %s" % recipe_id)

	var failures_rows: Array = traces.get("failures", [])
	_check(failures, failures_rows.size() >= 6, "failure and boundary traces are present")
	for row in failures_rows:
		var case_id := str(row.get("case_id", ""))
		_check(failures, (row.get("steps", []) as Array).size() >= 1, "failure case has steps: %s" % case_id)
		_check(failures, typeof(row.get("result")) == TYPE_DICTIONARY, "failure case has a result: %s" % case_id)

	completed = true
	return failures
