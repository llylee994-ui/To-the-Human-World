extends SceneTree

## Second process: load the save written by restart_seed.gd and verify it.

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
		print("[RestartVerify] FAIL catalog: " + str(loaded))
		quit(1)
		return
	var store := SnapshotStore.new(BASE_DIR)
	var session := SessionService.new(catalog, store)
	var opened := session.load_or_new()
	if not opened.get("ok", false) or str(opened.get("status", "")) != "loaded":
		print("[RestartVerify] FAIL load: " + str(opened))
		quit(1)
		return
	if int(opened.get("revision", -1)) != 2:
		print("[RestartVerify] FAIL revision: " + str(opened))
		quit(1)
		return
	var source := _source(catalog)
	var expected_token := WordToken.token_id(str(source["sourceLetterInstanceId"]),
		str(source["sourceSpanId"]))
	var state: Dictionary = session.snapshot()
	if not (state["live"]["wordTokens"]["byId"] as Dictionary).has(expected_token):
		print("[RestartVerify] FAIL token missing: " + expected_token)
		quit(1)
		return
	if str(state["draft"].get("mainTokenId", "")) != expected_token:
		print("[RestartVerify] FAIL draft: " + str(state["draft"]))
		quit(1)
		return
	store.delete_slot()
	print("[RestartVerify] PASS separate-process revision=2 token=%s" % expected_token)
	quit(0)
