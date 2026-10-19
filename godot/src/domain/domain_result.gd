class_name DomainResult
extends RefCounted

## Small shared Result/deep-copy helpers for the pure domain layer.


static func ok(value = null) -> Dictionary:
	return {"ok": true, "value": value}


static func fail(code: String, path: String, message: String, details: Dictionary = {}) -> Dictionary:
	return {
		"ok": false,
		"error": {"code": code, "path": path, "message": message, "details": details},
	}


static func error(result: Dictionary) -> Dictionary:
	var value = result.get("error", {})
	return value if typeof(value) == TYPE_DICTIONARY else {}


static func copy(value):
	if typeof(value) == TYPE_DICTIONARY:
		return (value as Dictionary).duplicate(true)
	if typeof(value) == TYPE_ARRAY:
		return (value as Array).duplicate(true)
	return value


static func equal(a, b) -> bool:
	var type_a := typeof(a)
	var type_b := typeof(b)
	if (type_a == TYPE_INT or type_a == TYPE_FLOAT) and (type_b == TYPE_INT or type_b == TYPE_FLOAT):
		return float(a) == float(b)
	if type_a != type_b:
		return false
	if type_a == TYPE_DICTIONARY:
		var left: Dictionary = a
		var right: Dictionary = b
		if left.size() != right.size():
			return false
		for key in left:
			if not right.has(key) or not equal(left[key], right[key]):
				return false
		return true
	if type_a == TYPE_ARRAY:
		var left_array: Array = a
		var right_array: Array = b
		if left_array.size() != right_array.size():
			return false
		for index in left_array.size():
			if not equal(left_array[index], right_array[index]):
				return false
		return true
	return a == b


static func is_false(value) -> bool:
	return typeof(value) == TYPE_BOOL and value == false


static func is_int(value) -> bool:
	if typeof(value) == TYPE_INT:
		return true
	return typeof(value) == TYPE_FLOAT and is_finite(float(value)) and float(value) == floor(float(value))


static func is_number(value) -> bool:
	return (typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT) and is_finite(float(value))


static func keys(value, allowed: Array, path: String, code: String = "INVALID_REQUEST") -> Dictionary:
	if typeof(value) != TYPE_DICTIONARY:
		return error(fail("STATE_INVALID", path, "must be an object"))
	var dictionary: Dictionary = value
	for key in dictionary:
		if not (key in allowed):
			return error(fail(code, "%s.%s" % [path, str(key)], "unknown field"))
	return {}


static func need(condition: bool, code: String, path: String, message: String,
		details: Dictionary = {}) -> Dictionary:
	return {} if condition else error(fail(code, path, message, details))


static func sorted_keys(value: Dictionary) -> Array:
	var keys: Array = value.keys()
	keys.sort()
	return keys


static func utf8_len(text: String) -> int:
	return text.to_utf8_buffer().size()
