extends RefCounted

## Validates the generated content catalog against the frozen counts, text
## hashes and reference shape exported from the Lua runtime.

const CatalogScript = preload("res://src/content/content_catalog.gd")
const CATALOG_PATH := "res://content/generated/catalog.json"
const CHECKS_PATH := "res://tests/fixtures/content_checks.json"

var assertions := 0
var completed := false


func _check(failures: Array[String], condition: bool, message: String) -> void:
	assertions += 1
	if not condition:
		failures.append(message)


func _sha256(text: String) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(text.to_utf8_buffer())
	return context.finish().hex_encode()


func _load_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	return JSON.parse_string(FileAccess.get_file_as_string(path))


func run(_tree: SceneTree) -> Array[String]:
	var failures: Array[String] = []
	var catalog = CatalogScript.new()
	var loaded: Dictionary = catalog.load_catalog(CATALOG_PATH)
	_check(failures, bool(loaded.get("ok", false)), "catalog loads: %s" % str(loaded.get("error", {})))
	if not loaded.get("ok", false):
		completed = true
		return failures

	var checks = _load_json(CHECKS_PATH)
	_check(failures, typeof(checks) == TYPE_DICTIONARY, "content checks fixture loads")
	if typeof(checks) != TYPE_DICTIONARY:
		completed = true
		return failures

	_check(failures, catalog.content_version() == "ordinary-release-v3",
		"content version is ordinary-release-v3")
	_check(failures, catalog.save_slot_id() == "ordinary_release_v3",
		"save slot id is preserved")
	_check(failures, str(checks.get("content_version", "")) == catalog.content_version(),
		"fixture content version matches catalog")
	_check(failures, str(checks.get("source_hash", "")) == str(catalog.data.get("source_hash", "")),
		"fixture source hash matches catalog")

	var expected_counts := {
		"effects": 22, "words": 77, "ingredients": 4, "equipment": 2,
		"furniture": 4, "npcs": 11, "letters": 22, "attributeProfiles": 6,
		"followupTemplates": 11, "fragments": 58, "directRules": 196,
		"orderRatings": 58, "recipes": 58, "wishDecorations": 11,
	}
	for name in expected_counts:
		_check(failures, catalog.count(name) == int(expected_counts[name]),
			"count %s = %d (got %d)" % [name, int(expected_counts[name]), catalog.count(name)])
	var fixture_counts = checks.get("counts", {})
	var declared_counts: Dictionary = catalog.data.get("counts", {})
	for name in fixture_counts:
		var actual := catalog.count(name) if name in CatalogScript.COLLECTIONS else int(declared_counts.get(name, -1))
		_check(failures, actual == int(fixture_counts[name]),
			"fixture count %s matches catalog" % name)

	var release: Dictionary = catalog.release()
	var required: Array = release.get("requiredOrderIds", [])
	_check(failures, required.size() == 11, "eleven required orders")
	for letter_id in required:
		var entry: Dictionary = catalog.entry("letters", str(letter_id))
		_check(failures, bool(entry.get("ok", false)), "required letter exists: %s" % letter_id)
		if entry.get("ok", false):
			_check(failures, str((entry["value"] as Dictionary).get("kind", "")) == "order",
				"required letter is an order: %s" % letter_id)

	var endings: Dictionary = catalog.release_endings()
	for kind in ["departure", "apprentice", "wish"]:
		var row = endings.get(kind)
		_check(failures, typeof(row) == TYPE_DICTIONARY, "ending exists: %s" % kind)
		if typeof(row) == TYPE_DICTIONARY:
			_check(failures, not str(row.get("title", "")).is_empty(), "ending title: %s" % kind)
			_check(failures, not str(row.get("text", "")).is_empty(), "ending text: %s" % kind)

	var text_hashes = checks.get("text_hashes", {})
	_check(failures, typeof(text_hashes) == TYPE_DICTIONARY, "text hashes fixture exists")
	if typeof(text_hashes) == TYPE_DICTIONARY:
		for letter_id in text_hashes:
			var expected: Dictionary = text_hashes[letter_id]
			var entry: Dictionary = catalog.entry("letters", str(letter_id))
			_check(failures, bool(entry.get("ok", false)), "text letter exists: %s" % letter_id)
			if not entry.get("ok", false):
				continue
			var letter: Dictionary = entry["value"]
			_check(failures, _sha256(str(letter.get("title", ""))) == str(expected.get("title_sha256", "")),
				"title text unchanged: %s" % letter_id)
			_check(failures, _sha256(str(letter.get("body", ""))) == str(expected.get("body_sha256", "")),
				"body text unchanged: %s" % letter_id)
			var spans: Array = catalog.letter_spans(str(letter_id))
			_check(failures, spans.size() == int(checks.get("span_counts", {}).get(letter_id, -1)),
				"span count unchanged: %s" % letter_id)
			for span in spans:
				_check(failures, span.get("wordId", "") in (catalog.indexes["words"] as Dictionary),
					"span word reference exists: %s/%s" % [letter_id, span.get("spanId", "")])

	var missing: Dictionary = catalog.entry("words", "word_does_not_exist")
	_check(failures, not missing.get("ok", true), "unknown word is rejected")
	_check(failures, str(missing.get("error", {}).get("code", "")) == "UNKNOWN_ID",
		"unknown word error code")

	var duplicate_catalog: Dictionary = catalog.data.duplicate(true)
	var words: Array = duplicate_catalog["collections"]["words"]
	words.append((words[0] as Dictionary).duplicate(true))
	var duplicate_loader = CatalogScript.new()
	var duplicate_result: Dictionary = duplicate_loader.load_data(duplicate_catalog)
	_check(failures, not duplicate_result.get("ok", true), "duplicate id is rejected")
	_check(failures, str(duplicate_result.get("error", {}).get("code", "")) == "DUPLICATE_ID",
		"duplicate id error code")
	_check(failures, str(duplicate_result.get("error", {}).get("path", "")).begins_with("collections.words["),
		"duplicate error points at the collection entry")

	var bad_counts: Dictionary = catalog.data.duplicate(true)
	bad_counts["counts"]["words"] = 999
	var count_loader = CatalogScript.new()
	var count_result: Dictionary = count_loader.load_data(bad_counts)
	_check(failures, not count_result.get("ok", true), "count mismatch is rejected")
	_check(failures, str(count_result.get("error", {}).get("code", "")) == "CONTENT_COUNT_MISMATCH",
		"count mismatch error code")

	completed = true
	return failures
