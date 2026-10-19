extends SceneTree

var failures: Array[String] = []

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)

func _initialize() -> void:
	var implementation = load("res://src/spike_state.gd")
	if implementation == null:
		push_error("Missing SpikeState implementation")
		quit(1)
		return
	var state = implementation.new()
	check(not state.brew().ok, "empty recipe cannot brew")
	check(state.select_word("word_sleep"), "available word can be selected")
	check(state.select_ingredient("ing_sea_salt"), "available ingredient can be selected")
	var before: Dictionary = state.snapshot()
	var result: Dictionary = state.brew()
	check(result.ok, "selected recipe brews")
	check(state.batch_count == 1, "one completed batch")
	check(state.words.word_sleep == before.words.word_sleep - 1, "one source word consumed")
	check(state.ingredients.ing_sea_salt == before.ingredients.ing_sea_salt - 1, "one ingredient consumed")
	check(not state.brew().ok and state.batch_count == 1, "repeated click cannot brew the cleared recipe")
	check(not state.select_word("unknown"), "unknown word is rejected")
	check(not state.select_ingredient("unknown"), "unknown ingredient is rejected")
	var save_path := "user://migration-test-only.json"
	check(state.save_to(save_path), "save is written")
	var restored = implementation.new()
	check(restored.load_from(save_path), "a new instance restores the save")
	check(restored.snapshot() == state.snapshot(), "all saved state is restored")
	var persisted: Dictionary = restored.snapshot()
	var malformed := FileAccess.open(save_path, FileAccess.WRITE)
	malformed.store_string('{"schema":1,"words":{"word_sleep":-8}}')
	malformed.close()
	check(not restored.load_from(save_path), "invalid saved state is rejected")
	check(restored.snapshot() == persisted, "invalid save leaves current state intact")
	DirAccess.remove_absolute(save_path)
	if failures.is_empty():
		print("[GodotState] PASS recipe, inventory, duplicate click, restore, invalid save isolation")
		quit(0)
	else:
		for message in failures:
			push_error(message)
		quit(1)
