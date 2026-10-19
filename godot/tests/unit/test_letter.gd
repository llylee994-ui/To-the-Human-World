extends RefCounted

## Pure letter definition/state validation for Task 3.

const CatalogScript = preload("res://src/content/content_catalog.gd")
const P2StateScript = preload("res://src/domain/p2_state.gd")
const LetterScript = preload("res://src/domain/letter.gd")

var assertions := 0
var completed := false


func _check(failures: Array[String], condition: bool, message: String) -> void:
	assertions += 1
	if not condition:
		failures.append(message)


func run(_tree: SceneTree) -> Array[String]:
	var failures: Array[String] = []
	var catalog = CatalogScript.new()
	var loaded: Dictionary = catalog.load_catalog("res://content/generated/catalog.json")
	_check(failures, loaded.get("ok", false), "catalog loads")
	if not loaded.get("ok", false):
		completed = true
		return failures
	var state: Dictionary = P2StateScript.initial(catalog, false).value
	var parsed: Dictionary = LetterScript.parse_definition("letter_pa_01", catalog)
	_check(failures, parsed.get("ok", false), "first letter definition parses")
	_check(failures, (parsed.value.get("spans", []) as Array).size() == 9, "first letter has nine spans")
	_check(failures, (parsed.value.get("segments", []) as Array).size() >= 9,
		"first letter has ordered segments")
	_check(failures, not str(parsed.value.get("selfIntro", "")).is_empty(),
		"first letter keeps selfIntro")
	_check(failures, not str(parsed.value.get("address", "")).is_empty(),
		"first letter keeps address")

	var empty := LetterScript.validate_snapshot({"byId": {}, "bottleQueue": [], "directArchive": {}}, catalog)
	_check(failures, empty.get("ok", false), "empty letter state is valid")

	var instance_id := "letter:letter_pa_01"
	var item := {
		"letterId": "letter_pa_01",
		"senderId": "npc_passerby_a",
		"received": true,
		"read": false,
		"cutSpans": {},
		"claimedAttachmentIds": [],
	}
	var candidates = [
		["bad id", "letter:wrong", item],
		["bad sender", instance_id, {"letterId": "letter_pa_01", "senderId": "npc_unknown",
			"received": true, "read": false, "cutSpans": {}, "claimedAttachmentIds": []}],
		["cut before read", instance_id, {"letterId": "letter_pa_01", "senderId": "npc_passerby_a",
			"received": true, "read": false, "cutSpans": {"body:1": true}, "claimedAttachmentIds": []}],
		["unknown span", instance_id, {"letterId": "letter_pa_01", "senderId": "npc_passerby_a",
			"received": true, "read": true, "cutSpans": {"body:99": true}, "claimedAttachmentIds": []}],
	]
	for case in candidates:
		var mutated: Dictionary = state.duplicate(true)
		mutated["live"]["letters"]["byId"][case[1]] = case[2]
		var checked: Dictionary = LetterScript.validate_snapshot(mutated["live"]["letters"], catalog)
		_check(failures, not checked.get("ok", true), "invalid letter state rejected: %s" % case[0])
		_check(failures, str(checked.get("error", {}).get("path", "")).contains("letters"),
			"letter error path: %s" % case[0])
	completed = true
	return failures
