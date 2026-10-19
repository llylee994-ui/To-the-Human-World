extends SceneTree

## First process: create a real user:// save with a cut token and draft, then exit.

const BASE_DIR := "user://p1_process_restart"


func _initialize() -> void:
	call_deferred("_run")


func _source(catalog: ContentCatalog) -> Dictionary:
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
	return {}


func _run() -> void:
	var catalog := ContentCatalog.new()
	var loaded: Dictionary = catalog.load_catalog("res://content/generated/catalog.json")
	if not loaded.get("ok", false):
		print("[RestartSeed] FAIL catalog: " + str(loaded))
		quit(1)
		return
	var store := SnapshotStore.new(BASE_DIR)
	store.delete_slot()
	var session := SessionService.new(catalog, store)
	var opened := session.load_or_new()
	if not opened.get("ok", false):
		print("[RestartSeed] FAIL open: " + str(opened))
		quit(1)
		return
	var source := _source(catalog)
	var cut := session.execute({
		"request_id": "restart-seed-cut",
		"expected_revision": 0,
		"command": "cut_word",
		"payload": {"source": source},
	})
	if not cut.get("ok", false) or not cut.get("changed", false):
		print("[RestartSeed] FAIL cut: " + str(cut))
		quit(1)
		return
	var token_id := str(cut["value"]["tokenId"])
	var draft := {
		"equipmentId": str(catalog.stage1().get("initialEquipmentId", "")),
		"mainTokenId": token_id,
		"auxTokenIds": [],
		"ingredients": [],
		"specialItemIds": [],
	}
	var update := session.execute({
		"request_id": "restart-seed-draft",
		"expected_revision": 1,
		"command": "update_draft",
		"payload": {"draft": draft},
	})
	if not update.get("ok", false) or int(update.get("revision", -1)) != 2:
		print("[RestartSeed] FAIL draft: " + str(update))
		quit(1)
		return
	print("[RestartSeed] PASS revision=2 token=%s" % token_id)
	quit(0)
