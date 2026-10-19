extends RefCounted

## Simulates real viewport mouse input for the P0 word-slip drag demo.

const SCENE := "res://scenes/brew.tscn"

var assertions := 0
var completed := false


func _check(failures: Array[String], condition: bool, message: String) -> void:
	assertions += 1
	if not condition:
		failures.append(message)


func _press(tree: SceneTree, position: Vector2) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	event.button_mask = MOUSE_BUTTON_MASK_LEFT
	event.position = position
	event.global_position = position
	Input.warp_mouse(position)
	tree.root.push_input(event)
	await tree.process_frame


func _move(tree: SceneTree, from: Vector2, to: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = to
	event.global_position = to
	event.relative = to - from
	event.button_mask = MOUSE_BUTTON_MASK_LEFT
	tree.root.push_input(event)
	await tree.process_frame


func _release(tree: SceneTree, position: Vector2) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = false
	event.position = position
	event.global_position = position
	tree.root.push_input(event)
	await tree.process_frame


func run(tree: SceneTree) -> Array[String]:
	var failures: Array[String] = []
	tree.root.size = Vector2i(1920, 1080)
	var scene = load(SCENE).instantiate()
	tree.root.add_child(scene)
	await tree.process_frame
	await tree.process_frame
	var panel = scene.find_child("BrewWordPanel", true, false)
	var drop_zone = scene.find_child("PotDrop", true, false)
	var toast = scene.find_child("BrewToast", true, false)
	_check(failures, panel != null and drop_zone != null and toast != null, "drag fixtures exist")
	if panel == null or drop_zone == null or toast == null:
		scene.queue_free()
		completed = true
		return failures
	var slip: WordSlip = null
	for child in panel.get_children():
		if child is WordSlip:
			slip = child
			break
	_check(failures, slip != null, "word slip exists")
	if slip == null:
		scene.queue_free()
		completed = true
		return failures
	var start: Vector2 = slip.get_global_rect().get_center()
	var target: Vector2 = drop_zone.get_global_rect().get_center()
	await _press(tree, start)
	await _move(tree, start, start + Vector2(24.0, 0.0))
	_check(failures, tree.root.gui_is_dragging(), "drag starts after the movement threshold")
	var preview: WordSlip = null
	for node in tree.root.find_children("*", "Control", true, false):
		if node is WordSlip and node != slip and not panel.is_ancestor_of(node):
			preview = node
	_check(failures, preview != null, "drag creates a paper preview")
	if preview != null:
		_check(failures, preview.font_size == slip.font_size, "preview preserves the source font size")
		_check(failures, preview.size.is_equal_approx(slip.size), "preview preserves the source paper size")
		_check(failures, preview.line_count == slip.line_count, "preview preserves source wrapping")
	var data = tree.root.gui_get_drag_data()
	_check(failures, typeof(data) == TYPE_DICTIONARY, "drag data is a dictionary")
	if typeof(data) == TYPE_DICTIONARY:
		_check(failures, str(data.get("token_id", "")) == slip.token_id, "drag data carries token_id")
	await _move(tree, start + Vector2(24.0, 0.0), target)
	var visible_hitbox := false
	for node in drop_zone.find_children("*", "CanvasItem", true, false):
		visible_hitbox = visible_hitbox or node.is_visible_in_tree()
	_check(failures, not visible_hitbox, "pot accepts the drag without drawing its hitbox")
	await _release(tree, target)
	_check(failures, toast.visible and toast.text.contains("已拖入"), "drop over the pot reports success")

	await _press(tree, start)
	await _move(tree, start, start + Vector2(24.0, 0.0))
	await _move(tree, start + Vector2(24.0, 0.0), Vector2(20.0, 20.0))
	await _release(tree, Vector2(20.0, 20.0))
	_check(failures, toast.visible and toast.text.contains("已取消"), "release outside the pot reports cancellation")
	scene.queue_free()
	await tree.process_frame
	completed = true
	return failures
