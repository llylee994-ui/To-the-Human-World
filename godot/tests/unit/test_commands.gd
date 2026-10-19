extends RefCounted

## Exercises the command boundary, idempotency, query projections and restart
## recovery against a real user:// snapshot store.

const BASE_DIR := "user://p1_commands_test"

var assertions := 0
var completed := false


func _check(failures: Array[String], condition: bool, message: String) -> void:
	assertions += 1
	if not condition:
		failures.append(message)


func _main_source(catalog: ContentCatalog) -> Dictionary:
	var letter: Dictionary = catalog.entry_ref("letters", "letter_pa_01")
	for span in catalog.letter_spans("letter_pa_01"):
		var word: Dictionary = catalog.entry_ref("words", str(span["wordId"]))
		if word.has("attributeProfileId"):
			return {
				"wordId": span["wordId"],
				"sourceLetterInstanceId": "letter:letter_pa_01",
				"sourceSpanId": span["spanId"],
				"sourceNpcId": letter["senderId"],
			}
	return {
		"wordId": catalog.letter_spans("letter_pa_01")[0]["wordId"],
		"sourceLetterInstanceId": "letter:letter_pa_01",
		"sourceSpanId": catalog.letter_spans("letter_pa_01")[0]["spanId"],
		"sourceNpcId": letter["senderId"],
	}


func run(_tree: SceneTree) -> Array[String]:
	var failures: Array[String] = []
	var catalog := ContentCatalog.new()
	var loaded: Dictionary = catalog.load_catalog("res://content/generated/catalog.json")
	_check(failures, loaded.get("ok", false), "catalog loads")
	if not loaded.get("ok", false):
		completed = true
		return failures
	var store := SnapshotStore.new(BASE_DIR)
	store.delete_slot()
	var session := SessionService.new(catalog, store)
	var opened := session.load_or_new()
	_check(failures, opened.get("ok", false) and opened.get("status", "") == "new", "new session opens")
	var source := _main_source(catalog)
	var token_id := WordToken.token_id(str(source["sourceLetterInstanceId"]),
		str(source["sourceSpanId"]))

	var cut_request := {
		"request_id": "cut-1",
		"expected_revision": 0,
		"command": "cut_word",
		"payload": {"source": source},
	}
	var cut := session.execute(cut_request)
	_check(failures, cut.get("ok", false) and cut.get("changed", false), "cut_word commits: %s" % str(cut))
	_check(failures, int(cut.get("revision", -1)) == 1, "cut_word revision increments")
	_check(failures, str(cut.get("value", {}).get("tokenId", "")) == token_id, "cut_word returns source token")
	var after_cut: Dictionary = session.snapshot()
	_check(failures, (after_cut["live"]["wordTokens"]["byId"] as Dictionary).has(token_id),
		"token is installed in memory")
	_check(failures, (session.query("word_tray").get("value", {}).get("cards", []) as Array).size() == 1,
		"word tray query sees the token")

	var cut_replay := session.execute(cut_request)
	_check(failures, cut_replay.get("ok", false), "same request id returns success")
	_check(failures, int(cut_replay.get("revision", -1)) == 1, "same request id does not increment revision")
	_check(failures, DomainResult.equal(session.snapshot(), after_cut),
		"same request id does not change state")

	var cut_again := session.execute({
		"request_id": "cut-2",
		"expected_revision": 1,
		"command": "cut_word",
		"payload": {"source": source},
	})
	_check(failures, cut_again.get("ok", false) and not cut_again.get("changed", true),
		"re-cutting the same source is idempotent")
	_check(failures, int(cut_again.get("revision", -1)) == 1, "idempotent cut does not save")

	var equipment_id := str(catalog.stage1().get("initialEquipmentId", ""))
	var draft := {
		"equipmentId": equipment_id,
		"mainTokenId": token_id,
		"auxTokenIds": [],
		"ingredients": [],
		"specialItemIds": [],
	}
	var update := session.execute({
		"request_id": "draft-1",
		"expected_revision": 1,
		"command": "update_draft",
		"payload": {"draft": draft},
	})
	_check(failures, update.get("ok", false) and update.get("changed", false), "draft commits")
	_check(failures, int(update.get("revision", -1)) == 2, "draft revision increments")
	_check(failures, DomainResult.equal(session.snapshot()["draft"], draft), "draft is installed")

	var draft_replay := session.execute({
		"request_id": "draft-2",
		"expected_revision": 2,
		"command": "update_draft",
		"payload": {"draft": draft},
	})
	_check(failures, draft_replay.get("ok", false) and not draft_replay.get("changed", true),
		"same draft is idempotent")
	_check(failures, int(draft_replay.get("revision", -1)) == 2, "idempotent draft does not save")

	var preview := session.execute({
		"request_id": "preview-1",
		"expected_revision": 2,
		"command": "preview",
		"payload": {"draft": draft},
	})
	_check(failures, preview.get("ok", false), "preview calculates")
	_check(failures, preview.get("value", {}).has("potion"), "preview returns a potion")
	_check(failures, int(session.snapshot()["revision"]) == 2, "preview does not change revision")
	_check(failures, DomainResult.equal(session.snapshot()["draft"], draft),
		"preview does not change the draft")
	var preview_potion: Dictionary = preview.get("value", {}).get("potion", {})
	var validated_potion := Potion.validate_result(preview_potion, catalog)
	_check(failures, validated_potion.get("ok", false), "preview potion passes result validation")

	var stale := session.execute({
		"request_id": "stale-1",
		"expected_revision": 999,
		"command": "cut_word",
		"payload": {"source": source},
	})
	_check(failures, not stale.get("ok", true), "stale revision is rejected")
	_check(failures, str(stale.get("error", {}).get("code", "")) == "STALE_REVISION",
		"stale revision error code")
	_check(failures, int(session.snapshot()["revision"]) == 2, "stale command does not mutate")

	var status := session.query("session_status")
	_check(failures, status.get("ok", false) and int(status["value"]["revision"]) == 2,
		"session status query")

	var restarted_store := SnapshotStore.new(BASE_DIR)
	var restarted := SessionService.new(catalog, restarted_store)
	var reopened := restarted.load_or_new()
	_check(failures, reopened.get("ok", false) and reopened.get("status", "") == "loaded",
		"restarted session loads the committed snapshot")
	_check(failures, int(reopened.get("revision", -1)) == 2, "restarted revision is preserved")
	var restored: Dictionary = restarted.snapshot()
	_check(failures, not restored.is_empty(), "restarted snapshot is not empty; reopened=%s" % str(reopened))
	if not restored.has("draft") or not restored.has("live"):
		failures.append("restarted snapshot keys=%s reopened=%s" % [str(restored.keys()), str(reopened)])
		completed = true
		return failures
	_check(failures, DomainResult.equal(restored["draft"], draft), "restarted draft is preserved")
	_check(failures, (restored["live"]["wordTokens"]["byId"] as Dictionary).has(token_id),
		"restarted token is preserved")

	restarted_store.delete_slot()
	completed = true
	return failures
