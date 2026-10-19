class_name SaveCodec
extends RefCounted

## Canonical JSON, checksum and the Godot save envelope. The checksum covers
## the canonical payload so an interrupted write cannot be mistaken for a
## committed snapshot.


const FORMAT := "tthw-godot"
const SCHEMA_VERSION := 1
const MAX_SCHEMA_VERSION := 2


static func canonical(value):
	if typeof(value) == TYPE_FLOAT and is_finite(float(value)) and float(value) == floor(float(value)):
		return int(value)
	if typeof(value) == TYPE_DICTIONARY:
		var result: Dictionary = {}
		var keys: Array = (value as Dictionary).keys()
		keys.sort()
		for key in keys:
			result[key] = canonical(value[key])
		return result
	if typeof(value) == TYPE_ARRAY:
		var result: Array = []
		for item in value:
			result.append(canonical(item))
		return result
	return value


static func encode(value) -> String:
	return JSON.stringify(canonical(value), "", false, true)


static func sha256(text: String) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(text.to_utf8_buffer())
	return context.finish().hex_encode()


static func wrap(payload: Dictionary, content_version: String, revision: int, generation: int,
		schema_version: int = SCHEMA_VERSION) -> Dictionary:
	return {
		"format": FORMAT,
		"schema_version": schema_version,
		"content_version": content_version,
		"revision": revision,
		"generation": generation,
		"checksum": sha256(encode(payload)),
		"payload": payload.duplicate(true),
	}


static func verify(envelope_value, max_schema_version: int = SCHEMA_VERSION) -> Dictionary:
	if typeof(envelope_value) != TYPE_DICTIONARY:
		return DomainResult.fail("SAVE_CORRUPT", "envelope", "save envelope must be an object")
	var envelope: Dictionary = envelope_value
	var keys := DomainResult.keys(envelope,
		["format", "schema_version", "content_version", "revision", "generation", "checksum", "payload"],
		"envelope", "SAVE_CORRUPT")
	if not keys.is_empty():
		return {"ok": false, "error": keys}
	if envelope.get("format") != FORMAT:
		return DomainResult.fail("SAVE_UNSUPPORTED", "format", "unexpected save format")
	if not DomainResult.is_int(envelope.get("schema_version")) \
			or int(envelope["schema_version"]) < 1 \
			or int(envelope["schema_version"]) > max_schema_version:
		return DomainResult.fail("SAVE_UNSUPPORTED", "schema_version", "unsupported save schema")
	if typeof(envelope.get("content_version")) != TYPE_STRING or envelope["content_version"].is_empty():
		return DomainResult.fail("SAVE_CORRUPT", "content_version", "content version is missing")
	if not DomainResult.is_int(envelope.get("revision")) or int(envelope["revision"]) < 0:
		return DomainResult.fail("SAVE_CORRUPT", "revision", "revision must be a non-negative integer")
	if not DomainResult.is_int(envelope.get("generation")) or int(envelope["generation"]) < 1:
		return DomainResult.fail("SAVE_CORRUPT", "generation", "generation must be positive")
	if typeof(envelope.get("payload")) != TYPE_DICTIONARY:
		return DomainResult.fail("SAVE_CORRUPT", "payload", "payload must be an object")
	if typeof(envelope.get("checksum")) != TYPE_STRING:
		return DomainResult.fail("SAVE_CORRUPT", "checksum", "checksum is missing")
	var actual := sha256(encode(envelope["payload"]))
	if actual != envelope["checksum"]:
		return DomainResult.fail("SAVE_CHECKSUM_MISMATCH", "checksum", "payload checksum does not match")
	if int(envelope["payload"].get("revision", -1)) != int(envelope["revision"]):
		return DomainResult.fail("SAVE_CORRUPT", "revision", "payload revision does not match envelope")
	return {"ok": true, "value": (envelope["payload"] as Dictionary).duplicate(true),
		"schema_version": int(envelope["schema_version"])}
