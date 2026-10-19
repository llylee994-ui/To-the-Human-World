class_name ContentCatalog
extends RefCounted

## Read-only projection of the Lua content export. The generated JSON is the
## only content source for the Godot runtime; no Lua parser is embedded.

const SCHEMA_VERSION := 1
const ContentValidationScript = preload("res://src/content/content_validation.gd")
const COLLECTIONS := [
	"effects", "words", "ingredients", "equipment", "furniture", "npcs",
	"letters", "attributeProfiles", "followupTemplates", "fragments",
	"directRules", "orderRatings", "recipes", "wishDecorations",
]
const REQUIRED_TOP_LEVEL := [
	"contentVersion", "saveSlotId", "release", "releaseEndings", "stage1",
	"synthesis", "shop", "gameplay", "letterSpans", "factExclusionGroups",
]

var data: Dictionary = {}
var indexes: Dictionary = {}
var last_error: Dictionary = {}


func _error(code: String, path: String, message: String) -> Dictionary:
	return {"code": code, "path": path, "message": message}


func _fail(code: String, path: String, message: String) -> Dictionary:
	last_error = _error(code, path, message)
	return {"ok": false, "error": last_error.duplicate(true)}


func load_catalog(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return _fail("CONTENT_MISSING", path, "catalog file does not exist")
	var text := FileAccess.get_file_as_string(path)
	if text.is_empty():
		return _fail("CONTENT_MISSING", path, "catalog file is empty")
	var parsed = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return _fail("CONTENT_DECODE_FAILED", path, "catalog must be a JSON object")
	return load_data(parsed)


func load_data(parsed: Dictionary) -> Dictionary:
	data = {}
	indexes = {}
	last_error = {}
	if int(parsed.get("schema_version", -1)) != SCHEMA_VERSION:
		return _fail("CONTENT_SCHEMA_UNSUPPORTED", "schema_version",
			"expected %d, got %s" % [SCHEMA_VERSION, str(parsed.get("schema_version"))])
	var version = parsed.get("contentVersion")
	if typeof(version) != TYPE_STRING or version.is_empty():
		return _fail("CONTENT_INVALID", "contentVersion", "contentVersion must be a non-empty string")
	for field in REQUIRED_TOP_LEVEL:
		if not parsed.has(field):
			return _fail("CONTENT_MISSING", field, "required top-level field is missing")
	var collections = parsed.get("collections")
	if typeof(collections) != TYPE_DICTIONARY:
		return _fail("CONTENT_INVALID", "collections", "collections must be an object")
	for name in COLLECTIONS:
		var rows = collections.get(name)
		if typeof(rows) != TYPE_ARRAY:
			return _fail("CONTENT_MISSING", "collections.%s" % name, "collection must be an array")
		var index: Dictionary = {}
		for row_index in rows.size():
			var row = rows[row_index]
			if typeof(row) != TYPE_DICTIONARY:
				return _fail("CONTENT_INVALID", "collections.%s[%d]" % [name, row_index],
					"entry must be an object")
			var identifier = row.get("id")
			if typeof(identifier) != TYPE_STRING or identifier.is_empty():
				return _fail("CONTENT_INVALID", "collections.%s[%d].id" % [name, row_index],
					"id must be a non-empty string")
			if index.has(identifier):
				return _fail("DUPLICATE_ID", "collections.%s[%d].id" % [name, row_index],
					"duplicate id %s" % identifier)
			index[identifier] = row
		indexes[name] = index
	var declared_counts = parsed.get("counts", {})
	if typeof(declared_counts) == TYPE_DICTIONARY:
		for name in COLLECTIONS:
			var actual: int = (indexes[name] as Dictionary).size()
			if declared_counts.has(name) and int(declared_counts[name]) != actual:
				return _fail("CONTENT_COUNT_MISMATCH", "counts.%s" % name,
					"declared %d, loaded %d" % [int(declared_counts[name]), actual])
	data = parsed.duplicate(true)
	var structural: Dictionary = ContentValidationScript.validate(data, indexes)
	if not structural.is_empty():
		return {"ok": false, "error": structural}
	return {"ok": true, "value": data}


func content_version() -> String:
	return str(data.get("contentVersion", ""))


func save_slot_id() -> String:
	return str(data.get("saveSlotId", ""))


func count(collection: String) -> int:
	if not indexes.has(collection):
		return 0
	return (indexes[collection] as Dictionary).size()


func has(collection: String, identifier: String) -> bool:
	return indexes.has(collection) and (indexes[collection] as Dictionary).has(identifier)


func entry(collection: String, identifier: String) -> Dictionary:
	if not indexes.has(collection):
		return _fail("UNKNOWN_COLLECTION", collection, "unknown content collection")
	var row = (indexes[collection] as Dictionary).get(identifier)
	if row == null:
		return _fail("UNKNOWN_ID", "%s.%s" % [collection, identifier],
			"unknown id in %s" % collection)
	return {"ok": true, "value": row.duplicate(true)}


func entries(collection: String) -> Array:
	var value = data.get("collections", {}).get(collection)
	if typeof(value) != TYPE_ARRAY:
		return []
	return value.duplicate(true)


func sorted_ids(collection: String) -> Array:
	if not indexes.has(collection):
		return []
	var ids: Array = (indexes[collection] as Dictionary).keys()
	ids.sort()
	return ids


func collection_ref(collection: String) -> Array:
	# Internal domain lookups only. Callers must not mutate the returned rows.
	var value = data.get("collections", {}).get(collection)
	return value if typeof(value) == TYPE_ARRAY else []


func entry_ref(collection: String, identifier: String) -> Dictionary:
	# Internal domain lookups only. Callers must not mutate the returned row.
	if not indexes.has(collection):
		return {}
	var row = (indexes[collection] as Dictionary).get(identifier)
	return row if typeof(row) == TYPE_DICTIONARY else {}


func release() -> Dictionary:
	var value = data.get("release", {})
	return value if typeof(value) == TYPE_DICTIONARY else {}


func release_endings() -> Dictionary:
	var value = data.get("releaseEndings", {})
	return value if typeof(value) == TYPE_DICTIONARY else {}


func stage1() -> Dictionary:
	var value = data.get("stage1", {})
	return value if typeof(value) == TYPE_DICTIONARY else {}


func synthesis() -> Dictionary:
	var value = data.get("synthesis", {})
	return value if typeof(value) == TYPE_DICTIONARY else {}


func gameplay() -> Dictionary:
	var value = data.get("gameplay", {})
	return value if typeof(value) == TYPE_DICTIONARY else {}


func letter_spans(letter_id: String) -> Array:
	var rows = data.get("letterSpans", {})
	if typeof(rows) != TYPE_DICTIONARY:
		return []
	var row = rows.get(letter_id, {})
	if typeof(row) != TYPE_DICTIONARY or typeof(row.get("spans")) != TYPE_ARRAY:
		return []
	return row["spans"]


func letter_segments(letter_id: String) -> Array:
	var rows = data.get("letterSpans", {})
	if typeof(rows) != TYPE_DICTIONARY:
		return []
	var row = rows.get(letter_id, {})
	if typeof(row) != TYPE_DICTIONARY or typeof(row.get("segments")) != TYPE_ARRAY:
		return []
	return row["segments"]


func get_word(identifier: String) -> Dictionary:
	return entry_ref("words", identifier)


func get_letter(identifier: String) -> Dictionary:
	return entry_ref("letters", identifier)


func get_ingredient(identifier: String) -> Dictionary:
	return entry_ref("ingredients", identifier)


func get_equipment(identifier: String) -> Dictionary:
	return entry_ref("equipment", identifier)


func get_effect(identifier: String) -> Dictionary:
	return entry_ref("effects", identifier)
