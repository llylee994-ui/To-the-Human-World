class_name Letter
extends RefCounted

## Real letter instances. Receive/read/cut derive sources from the frozen letter
## definition and span id; the UI never supplies wordId or sender.


static func parse_definition(letter_id: String, catalog: ContentCatalog) -> Dictionary:
	var definition: Dictionary = catalog.entry_ref("letters", letter_id)
	if definition.is_empty():
		return DomainResult.fail("UNKNOWN_ID", "letterId", "unknown letter %s" % letter_id)
	var kind := str(definition.get("kind", ""))
	var cuttable: bool = definition.get("cuttable") == true
	var segments: Array = catalog.letter_segments(letter_id).duplicate(true)
	var spans: Array = catalog.letter_spans(letter_id).duplicate(true)
	if kind == "direct_followup":
		return DomainResult.ok({
			"letterId": letter_id, "kind": kind, "cuttable": false,
			"selfIntro": "", "address": str(definition.get("address", "")),
			"segments": [], "spans": [],
		})
	if kind != "order" or typeof(definition.get("cuttable")) != TYPE_BOOL:
		return DomainResult.fail("CONFIG_INVALID", "letters.%s.kind" % letter_id,
			"invalid letter kind or cuttable flag")
	for field in ["selfIntro", "body", "address"]:
		if typeof(definition.get(field)) != TYPE_STRING or str(definition[field]).is_empty():
			return DomainResult.fail("CONFIG_INVALID", "letters.%s.%s" % [letter_id, field],
				"letter text is missing")
	return DomainResult.ok({
		"letterId": letter_id, "kind": kind, "cuttable": cuttable,
		"selfIntro": str(definition.get("selfIntro", "")),
		"address": str(definition.get("address", "")),
		"segments": segments, "spans": spans,
	})


static func validate_snapshot(snapshot_value, catalog: ContentCatalog) -> Dictionary:
	if typeof(snapshot_value) != TYPE_DICTIONARY:
		return DomainResult.fail("STATE_INVALID", "letters", "letters must be an object")
	var snapshot: Dictionary = snapshot_value
	var keys := DomainResult.keys(snapshot, ["byId", "bottleQueue", "directArchive"],
		"letters", "STATE_INVALID")
	if not keys.is_empty():
		return {"ok": false, "error": keys}
	if typeof(snapshot.get("byId")) != TYPE_DICTIONARY \
			or typeof(snapshot.get("directArchive")) != TYPE_DICTIONARY \
			or typeof(snapshot.get("bottleQueue")) != TYPE_ARRAY:
		return DomainResult.fail("STATE_INVALID", "letters", "letter collections are invalid")
	for instance_id in snapshot.byId:
		var item = snapshot.byId[instance_id]
		var path := "letters.byId.%s" % str(instance_id)
		var item_keys := DomainResult.keys(item,
			["letterId", "senderId", "received", "read", "cutSpans", "claimedAttachmentIds"],
			path, "STATE_INVALID")
		if not item_keys.is_empty():
			return {"ok": false, "error": item_keys}
		if typeof(item.get("letterId")) != TYPE_STRING or str(instance_id) != "letter:" + str(item["letterId"]):
			return DomainResult.fail("STATE_INVALID", path, "letter instance id does not match its definition")
		var definition: Dictionary = catalog.entry_ref("letters", str(item.get("letterId")))
		if definition.is_empty() or definition.get("kind") != "order" \
				or str(item.get("senderId")) != str(definition.get("senderId")) \
				or catalog.entry_ref("npcs", str(item.get("senderId"))).is_empty():
			return DomainResult.fail("STATE_INVALID", path, "letter sender or definition is invalid")
		if item.get("received") != true or typeof(item.get("read")) != TYPE_BOOL \
				or typeof(item.get("cutSpans")) != TYPE_DICTIONARY \
				or typeof(item.get("claimedAttachmentIds")) != TYPE_ARRAY:
			return DomainResult.fail("STATE_INVALID", path, "letter receipt state is invalid")
		var parsed := parse_definition(str(item["letterId"]), catalog)
		if not parsed.ok:
			return parsed
		var allowed: Dictionary = {}
		for span in parsed.value.spans:
			allowed[str(span["spanId"])] = true
		for span_id in item["cutSpans"]:
			if not allowed.has(str(span_id)) or item["cutSpans"][span_id] != true or not bool(item["read"]):
				return DomainResult.fail("STATE_INVALID", path + ".cutSpans",
					"cut span is invalid or the letter is unread")
		for attachment_id in item["claimedAttachmentIds"]:
			var known := false
			for attachment in definition.get("attachments", []):
				if str(attachment.get("id", "")) == str(attachment_id):
					known = true
					break
			if not known:
				return DomainResult.fail("UNKNOWN_ID", path + ".claimedAttachmentIds",
					"attachment does not belong to this letter")
	for queued in snapshot["bottleQueue"]:
		if typeof(queued) != TYPE_STRING or not (snapshot.byId as Dictionary).has(queued):
			return DomainResult.fail("STATE_INVALID", "letters.bottleQueue",
				"queued letter instance is missing")
	return DomainResult.ok((snapshot as Dictionary).duplicate(true))


static func plan(state: Dictionary, action: String, payload: Dictionary,
		catalog: ContentCatalog) -> Dictionary:
	var letters = state.get("live", {}).get("letters", {})
	var checked := validate_snapshot(letters, catalog)
	if not checked.ok:
		return checked
	if action == "receive_letter":
		var keys := DomainResult.keys(payload, ["letterId"], "payload")
		if not keys.is_empty():
			return {"ok": false, "error": keys}
		if state.get("chapter", {}).get("started") != true:
			return DomainResult.fail("JOURNEY_NOT_STARTED", "chapter.started", "start the journey first")
		var letter_id := str(payload.get("letterId", ""))
		var available := DayFlow.available_letters(state, catalog)
		if not available.ok:
			return available
		if not (letter_id in available.value):
			return DomainResult.fail("LETTER_NOT_AVAILABLE", "letterId", "letter is not available")
		var instance_id := "letter:" + letter_id
		if (letters.byId as Dictionary).has(instance_id):
			return {"ok": true, "data": state, "changed": false,
				"value": {"letterInstanceId": instance_id, "changed": false}, "events": []}
		var parsed := parse_definition(letter_id, catalog)
		if not parsed.ok:
			return parsed
		var definition: Dictionary = catalog.entry_ref("letters", letter_id)
		var candidate: Dictionary = state.duplicate(true)
		candidate["live"]["letters"]["byId"][instance_id] = {
			"letterId": letter_id,
			"senderId": str(definition.get("senderId", "")),
			"received": true,
			"read": false,
			"cutSpans": {},
			"claimedAttachmentIds": [],
		}
		candidate["live"]["letters"]["bottleQueue"].append(instance_id)
		var limit := int(catalog.gameplay().get("salvageDailyLimit", 1))
		var flow: Dictionary = candidate["live"]["gameFlow"]
		flow["salvageUsedToday"] = int(flow.get("salvageUsedToday", 0)) + 1
		flow["canSalvage"] = bool(flow.get("phase") == "day" and int(flow["salvageUsedToday"]) < limit)
		candidate["revision"] = int(candidate.get("revision", 0)) + 1
		return {"ok": true, "data": candidate, "changed": true,
			"value": {"letterInstanceId": instance_id, "changed": true},
			"events": ["LetterReceived"]}

	if action == "read_letter":
		var keys := DomainResult.keys(payload, ["letterInstanceId"], "payload")
		if not keys.is_empty():
			return {"ok": false, "error": keys}
		var instance_id := str(payload.get("letterInstanceId", ""))
		var item = (letters.byId as Dictionary).get(instance_id)
		if typeof(item) != TYPE_DICTIONARY:
			return DomainResult.fail("LETTER_NOT_RECEIVED", "letterInstanceId", "letter was not received")
		if bool(item.get("read")):
			return {"ok": true, "data": state, "changed": false,
				"value": {"letterInstanceId": instance_id, "changed": false}, "events": []}
		var candidate: Dictionary = state.duplicate(true)
		candidate["live"]["letters"]["byId"][instance_id]["read"] = true
		candidate["revision"] = int(candidate.get("revision", 0)) + 1
		return {"ok": true, "data": candidate, "changed": true,
			"value": {"letterInstanceId": instance_id, "changed": true},
			"events": ["LetterRead"]}

	if action == "cut_word":
		var keys := DomainResult.keys(payload, ["letterInstanceId", "spanId"], "payload")
		if not keys.is_empty():
			return {"ok": false, "error": keys}
		var instance_id := str(payload.get("letterInstanceId", ""))
		var span_id := str(payload.get("spanId", ""))
		var item = (letters.byId as Dictionary).get(instance_id)
		if typeof(item) != TYPE_DICTIONARY:
			return DomainResult.fail("LETTER_NOT_RECEIVED", "letterInstanceId", "letter was not received")
		if not bool(item.get("read")):
			return DomainResult.fail("LETTER_NOT_READ", "letterInstanceId", "read the letter first")
		var parsed := parse_definition(str(item.get("letterId", "")), catalog)
		if not parsed.ok:
			return parsed
		var span = null
		for candidate_span in parsed.value.spans:
			if str(candidate_span.get("spanId", "")) == span_id:
				span = candidate_span
				break
		if span == null:
			return DomainResult.fail("UNKNOWN_ID", "spanId", "unknown cut position")
		var source := {
			"wordId": str(span["wordId"]),
			"sourceLetterInstanceId": instance_id,
			"sourceSpanId": span_id,
			"sourceNpcId": str(item["senderId"]),
		}
		var token_state = state.get("live", {}).get("wordTokens", {})
		var token := WordToken.plan_cut(token_state, source, catalog)
		if not token.ok:
			return token
		var candidate: Dictionary = state.duplicate(true)
		candidate["live"]["wordTokens"] = token.state
		candidate["live"]["letters"]["byId"][instance_id]["cutSpans"][span_id] = true
		var changed := not bool(item.get("cutSpans", {}).get(span_id, false))
		if changed:
			candidate["revision"] = int(candidate.get("revision", 0)) + 1
		var events: Array = []
		if changed:
			events = ["WordCut", "WordStored"]
		return {"ok": true, "data": candidate, "changed": changed,
			"value": {
				"letterInstanceId": instance_id, "tokenId": token.tokenId,
				"source": token.source, "changed": changed,
			},
			"events": events}
	return DomainResult.fail("INVALID_REQUEST", "action", "unknown letter action")


static func view(state: Dictionary, instance_id: String, catalog: ContentCatalog) -> Dictionary:
	var item = state.get("live", {}).get("letters", {}).get("byId", {}).get(instance_id)
	if typeof(item) != TYPE_DICTIONARY:
		return DomainResult.fail("LETTER_NOT_RECEIVED", "letterInstanceId", "letter was not received")
	var parsed := parse_definition(str(item.get("letterId", "")), catalog)
	if not parsed.ok:
		return parsed
	var definition: Dictionary = catalog.entry_ref("letters", str(item["letterId"]))
	var npc: Dictionary = catalog.entry_ref("npcs", str(item["senderId"]))
	var view: Dictionary = parsed.value.duplicate(true)
	view["instanceId"] = instance_id
	view["title"] = str(definition.get("title", ""))
	view["senderName"] = str(npc.get("name", ""))
	view["received"] = item.get("received")
	view["read"] = item.get("read")
	view["claimedAttachmentIds"] = (item.get("claimedAttachmentIds", []) as Array).duplicate(true)
	for list in [view["segments"], view["spans"]]:
		for segment in list:
			if segment.get("kind") == "word":
				segment["cut"] = item["cutSpans"].get(segment["spanId"], false) == true
				segment["canCut"] = bool(item.get("read")) and not bool(segment["cut"])
	return DomainResult.ok(view)
