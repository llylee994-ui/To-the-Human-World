extends SceneTree

var failures: Array[String] = []

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)

func _initialize() -> void:
	call_deferred("run_checks")

func run_checks() -> void:
	var scene = load("res://main.tscn")
	if scene == null:
		push_error("Missing migration scene")
		quit(1)
		return
	var ui = scene.instantiate()
	ui.save_path = "user://scene-test-only.json"
	root.add_child(ui)
	await process_frame
	check(ui.current_screen == "title", "launch starts at title")
	var start = ui.find_child("StartGame", true, false)
	check(start != null, "title has a start button")
	start.pressed.emit()
	check(ui.current_screen == "home", "start button opens home")
	ui.find_child("OpenWorkbench", true, false).pressed.emit()
	check(ui.current_screen == "brew", "home hotspot opens workbench")
	ui.choose_item("word", "word_sleep")
	ui.choose_item("ingredient", "ing_sea_salt")
	ui.find_child("BrewButton", true, false).pressed.emit()
	check(ui.state.batch_count == 1, "actual brew button commits a sample batch")
	check(FileAccess.file_exists(ui.save_path), "batch saves in independent user directory")
	ui.find_child("BrewButton", true, false).pressed.emit()
	check(ui.state.batch_count == 1, "duplicate action does not consume twice")
	ui.show_screen("home")
	check(ui.current_screen == "home", "return home works")
	ui.queue_free()
	await process_frame
	var restored = scene.instantiate()
	restored.save_path = "user://scene-test-only.json"
	root.add_child(restored)
	await process_frame
	check(restored.state.batch_count == 1, "recreated root restores local progress")
	for dimensions in [Vector2(1280, 720), Vector2(800, 360), Vector2(1080, 1920)]:
		restored.fit_design(dimensions)
		var rect: Rect2 = restored.design.get_global_rect()
		check(rect.position.x >= -0.1 and rect.position.y >= -0.1, "design stays in viewport")
		check(rect.end.x <= dimensions.x + 0.1 and rect.end.y <= dimensions.y + 0.1, "design fits each viewport")
	restored.queue_free()
	await process_frame
	DirAccess.remove_absolute("user://scene-test-only.json")
	if failures.is_empty():
		print("[GodotScene] PASS actual buttons, local restore, duplicate action and 3 aspect ratios")
		quit(0)
	else:
		for message in failures:
			push_error(message)
		quit(1)
