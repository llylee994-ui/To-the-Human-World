extends SceneTree

## Headless entry point. Run from the repository root:
##   <godot> --headless --path godot --script res://tests/run_tests.gd -- --suite=layout

func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var suite := "all"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--suite="):
			suite = argument.substr("--suite=".length())
	var failures: Array[String] = []
	var assertions := 0
	if suite == "all" or suite == "layout":
		var layout_test = preload("res://tests/integration/test_layout.gd").new()
		var result: Array[String] = await layout_test.run(self)
		failures.append_array(result)
		assertions += layout_test.assertions
		if not layout_test.completed:
			failures.append("layout suite did not complete")
	if suite == "all" or suite == "scenes":
		var scene_test = preload("res://tests/integration/test_scenes.gd").new()
		var result: Array[String] = await scene_test.run(self)
		failures.append_array(result)
		assertions += scene_test.assertions
		if not scene_test.completed:
			failures.append("scene suite did not complete")
	if suite == "all" or suite == "drag":
		var drag_test = preload("res://tests/integration/test_drag.gd").new()
		var result: Array[String] = await drag_test.run(self)
		failures.append_array(result)
		assertions += drag_test.assertions
		if not drag_test.completed:
			failures.append("drag suite did not complete")
	if suite == "all" or suite == "readability":
		var readability_test = preload("res://tests/integration/test_readability.gd").new()
		var result: Array[String] = await readability_test.run(self)
		failures.append_array(result)
		assertions += readability_test.assertions
		if not readability_test.completed:
			failures.append("readability suite did not complete")
	if failures.is_empty():
		print("[P0] PASS suite=%s assertions=%d" % [suite, assertions])
		quit(0)
		return
	for failure in failures:
		push_error("[P0] FAIL " + failure)
	quit(1)
