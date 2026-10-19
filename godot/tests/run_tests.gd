extends SceneTree

## Headless entry point. Run from the repository root:
##   <godot> --headless --path godot --script res://tests/run_tests.gd -- --suite=foundation

const SUITES := {
	"content": "res://tests/unit/test_content.gd",
	"potion": "res://tests/parity/test_potion.gd",
	"oracle": "res://tests/parity/test_oracle.gd",
	"commands": "res://tests/unit/test_commands.gd",
	"faults": "res://tests/unit/test_save_faults.gd",
	"layout": "res://tests/integration/test_layout.gd",
	"scenes": "res://tests/integration/test_scenes.gd",
	"drag": "res://tests/integration/test_drag.gd",
	"readability": "res://tests/integration/test_readability.gd",
}
const FOUNDATION := ["content", "potion", "oracle", "commands", "faults"]


func _initialize() -> void:
	call_deferred("_run")


func _selected(suite: String) -> Array:
	if suite == "all":
		return SUITES.keys()
	if suite == "foundation":
		return FOUNDATION
	return [suite] if SUITES.has(suite) else []


func _run() -> void:
	var suite := "all"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--suite="):
			suite = argument.substr("--suite=".length())
	var selected := _selected(suite)
	var failures: Array[String] = []
	var assertions := 0
	for name in selected:
		var test = load(SUITES[name]).new()
		var result: Array[String] = await test.run(self)
		failures.append_array(result)
		assertions += int(test.assertions)
		if not test.completed:
			failures.append("%s suite did not complete" % name)
	if failures.is_empty():
		print("[GODOT] PASS suite=%s assertions=%d" % [suite, assertions])
		quit(0)
		return
	for failure in failures:
		push_error("[GODOT] FAIL " + failure)
	quit(1)
