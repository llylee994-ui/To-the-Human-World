extends Control
## Independent migration slice, deliberately labelled and separate from production.

const State = preload("res://src/spike_state.gd")
const DragCard = preload("res://src/drag_card.gd")
const PotDrop = preload("res://src/pot_drop.gd")
const SAVE_PATH := "user://migration-progress.json"
const INK := Color("493321")
const CREAM := Color("f7e8c6")
const INGREDIENT_ART := {
	"ing_sea_salt": "image/原料_海盐_透明_v01_20261013032602.png",
	"ing_night_dew": "image/原料_夜露_透明_v01_20261013032602.png",
	"ing_ashen_herb": "image/原料_灰烬草_透明_v01_20261013032602.png",
	"ing_dried_petal": "image/原料_干花瓣_透明_v01_20261013032602.png"}
var state = State.new()
var save_path := SAVE_PATH
var current_screen := "title"
var design: Control
var screens: Dictionary = {}
var recipe_label: Label
var progress_label: Label
var result_label: Label
var status_label: Label
var brew_button: Button
var cards: Array[Button] = []
var music: AudioStreamPlayer
var font: Font
var manifest: Dictionary

func _ready() -> void:
	font = load("res://media/fonts/HarborHand-Regular.ttf")
	var custom_theme := Theme.new()
	custom_theme.default_font = font
	custom_theme.default_font_size = 28
	theme = custom_theme
	manifest = JSON.parse_string(FileAccess.get_file_as_string("res://media/home-layout.json"))
	state.load_from(save_path)
	design = Control.new()
	design.name = "DesignCanvas"
	design.size = Vector2(1920, 1080)
	design.clip_contents = true
	add_child(design)
	build_title()
	build_home()
	build_workbench()
	status_label = label(design, "Godot 迁移验证版 · 本地资源 · 示例流程", Rect2(28, 1030, 1350, 42), 23, CREAM)
	status_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	status_label.add_theme_constant_override("shadow_outline_size", 5)
	button(design, "保存进度", Rect2(1450, 1008, 190, 52), save_progress)
	button(design, "重新读取", Rect2(1655, 1008, 190, 52), restore_progress)
	music = AudioStreamPlayer.new()
	var sources: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://media/sources.json"))
	music.stream = load("res://" + sources.bgm)
	music.volume_db = -12
	add_child(music)
	resized.connect(func(): fit_design(size))
	fit_design(size)
	show_screen("title")
	refresh_workbench()
	print("[GodotSpike] ready; local user directory: " + OS.get_user_data_dir())
	if "--smoke-test" in OS.get_cmdline_user_args():
		call_deferred("run_smoke_test")

func fit_design(viewport_size: Vector2) -> void:
	var factor := minf(viewport_size.x / 1920.0, viewport_size.y / 1080.0)
	design.scale = Vector2.ONE * factor
	design.position = (viewport_size - design.size * factor) / 2.0

func picture(parent: Node, path: String, rect: Rect2, contain := false) -> TextureRect:
	var node := TextureRect.new()
	node.texture = load("res://media/" + path)
	node.position = rect.position
	node.size = rect.size
	node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	node.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED if contain else TextureRect.STRETCH_SCALE
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(node)
	return node

func label(parent: Node, text: String, rect: Rect2, font_size := 28, color := INK) -> Label:
	var node := Label.new()
	node.text = text
	node.position = rect.position
	node.size = rect.size
	node.add_theme_font_size_override("font_size", font_size)
	node.add_theme_color_override("font_color", color)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(node)
	return node

func button(parent: Node, text: String, rect: Rect2, action: Callable, node_name := "") -> Button:
	var node := Button.new()
	node.text = text
	node.position = rect.position
	node.size = rect.size
	if node_name != "":
		node.name = node_name
	node.add_theme_color_override("font_color", CREAM)
	node.add_theme_color_override("font_hover_color", Color.WHITE)
	for type in ["normal", "hover", "pressed", "disabled"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color("745035") if type == "hover" else Color("513b29")
		style.border_color = Color("c59c61")
		style.set_border_width_all(2)
		style.set_corner_radius_all(6)
		node.add_theme_stylebox_override(type, style)
	node.pressed.connect(action)
	parent.add_child(node)
	return node

func screen(name: String) -> Control:
	var node := Control.new()
	node.name = name.capitalize() + "Screen"
	node.size = design.size
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	design.add_child(node)
	screens[name] = node
	return node

func build_title() -> void:
	var node := screen("title")
	picture(node, "image/title-screen-r1/shop-doorway-soft.png", Rect2(0, 0, 1920, 1080))
	label(node, "寄往人间", Rect2(150, 220, 750, 150), 100, CREAM)
	label(node, "TO THE HUMAN WORLD", Rect2(160, 390, 650, 50), 25, CREAM)
	button(node, "走进药铺", Rect2(160, 510, 330, 80), func():
		show_screen("home")
		if not music.playing:
			music.play(), "StartGame")
	label(node, "Godot 离线迁移 · 技术验证", Rect2(160, 620, 690, 55), 29, CREAM)

func draw_room(parent: Node, skip_stove := false) -> Control:
	var room := Control.new()
	room.size = design.size
	room.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(room)
	picture(room, "image/misty-harbor-r1/sea-calm.png", Rect2(0, -115, 1920, 1080))
	for row in manifest.layers:
		if not row.visible or row.key == "case-file" or (skip_stove and row.key == "stove"):
			continue
		var art := picture(room, row.path, Rect2(row.x - row.width / 2, row.y - row.height / 2, row.width, row.height))
		art.pivot_offset = art.size / 2.0
		art.rotation_degrees = row.rotation
	return room

func build_home() -> void:
	var node := screen("home")
	draw_room(node)
	button(node, "炼药工作台", Rect2(1090, 430, 270, 70), func(): show_screen("brew"), "OpenWorkbench")
	button(node, "返回标题", Rect2(1660, 30, 220, 62), func(): show_screen("title"))
	label(node, "点药炉，试一份配方。", Rect2(50, 925, 750, 65), 36, CREAM)

func paper(parent: Node, rect: Rect2) -> void:
	picture(parent, "image/wish-collage-r1/soft-scrollwork-letter-paper.png", rect)

func build_workbench() -> void:
	var node := screen("brew")
	var room := draw_room(node, true)
	room.scale = Vector2(1.35, 1.35)
	room.position = Vector2(-540, -170)
	button(node, "返回主页", Rect2(1655, 28, 225, 65), func(): show_screen("home"))
	label(node, "药铺工作台", Rect2(55, 30, 620, 65), 44, CREAM)
	paper(node, Rect2(25, 120, 410, 845))
	label(node, "词条托盘", Rect2(90, 160, 280, 60), 43)
	label(node, "点选或拖入药锅", Rect2(70, 245, 340, 55), 27)
	var row_index := 0
	for id in State.WORD_LABELS:
		create_card(node, "word", id, Rect2(80, 340 + row_index * 150, 300, 95))
		row_index += 1
	var pot = PotDrop.new()
	pot.texture = load("res://media/image/brew-topdown/cauldron-v01.png")
	pot.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pot.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pot.position = Vector2(610, 115)
	pot.size = Vector2(760, 490)
	pot.item_dropped.connect(choose_item)
	node.add_child(pot)
	paper(node, Rect2(475, 600, 960, 145))
	recipe_label = label(node, "", Rect2(525, 635, 860, 72), 35)
	recipe_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	picture(node, "image/brew-topdown/four-cell-tray-v01.png", Rect2(475, 755, 960, 190))
	row_index = 0
	for id in State.INGREDIENT_LABELS:
		picture(node, INGREDIENT_ART[id], Rect2(510 + row_index * 225, 748, 160, 120), true)
		create_card(node, "ingredient", id, Rect2(495 + row_index * 225, 878, 200, 58))
		row_index += 1
	brew_button = button(node, "开始熬制", Rect2(740, 948, 410, 62), complete_brew, "BrewButton")
	paper(node, Rect2(1470, 120, 425, 845))
	label(node, "验证记录", Rect2(1535, 175, 310, 70), 44)
	progress_label = label(node, "", Rect2(1520, 290, 325, 70), 33)
	result_label = label(node, "", Rect2(1520, 390, 325, 235), 31)
	result_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var note := label(node, "本轮只验证选料、\n资源呈现与存档。\n\n示例配方不等同于\n正式订单和药效。", Rect2(1520, 690, 330, 200), 25)
	note.modulate.a = 0.8

func create_card(parent: Node, kind: String, id: String, rect: Rect2) -> void:
	var node = DragCard.new()
	node.kind = kind
	node.item_id = id
	node.position = rect.position
	node.size = rect.size
	node.add_theme_color_override("font_color", INK)
	node.add_theme_color_override("font_hover_color", Color("7d4220"))
	for type in ["normal", "hover", "pressed", "disabled"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color("f2dfb9") if type != "hover" else Color("fff1d2")
		style.border_color = Color("af8450")
		style.set_border_width_all(2)
		style.set_corner_radius_all(4)
		node.add_theme_stylebox_override(type, style)
	node.pressed.connect(func(): choose_item(kind, id))
	parent.add_child(node)
	cards.append(node)

func choose_item(kind: String, id: String) -> void:
	var accepted: bool = state.select_word(id) if kind == "word" else state.select_ingredient(id) if kind == "ingredient" else false
	if accepted:
		save_progress()
		refresh_workbench()

func complete_brew() -> void:
	var result: Dictionary = state.brew()
	if result.ok:
		save_progress()
	refresh_workbench()
	status_label.text = result.message + " · 迁移验证版"

func refresh_workbench() -> void:
	for card in cards:
		var stock: Dictionary = state.words if card.kind == "word" else state.ingredients
		var labels: Dictionary = State.WORD_LABELS if card.kind == "word" else State.INGREDIENT_LABELS
		card.text = "%s  × %d" % [labels[card.item_id], stock[card.item_id]]
		card.disabled = stock[card.item_id] <= 0
		var selected: bool = state.selected_word == card.item_id or state.selected_ingredient == card.item_id
		card.modulate = Color("ffdf94") if selected else Color.WHITE
	var word: String = State.WORD_LABELS.get(state.selected_word, "选择主词")
	var ingredient: String = State.INGREDIENT_LABELS.get(state.selected_ingredient, "辅料可选")
	recipe_label.text = word + "     +     " + ingredient
	brew_button.disabled = state.selected_word.is_empty()
	progress_label.text = "已完成 %d 份" % state.batch_count
	result_label.text = "最近一份\n\n" + (state.last_result if not state.last_result.is_empty() else "还没有记录。")

func show_screen(target: String) -> void:
	if not screens.has(target):
		return
	current_screen = target
	for key in screens:
		screens[key].visible = key == target

func save_progress() -> void:
	var success: bool = state.save_to(save_path)
	if status_label != null:
		status_label.text = "进度已存入本机 · Godot 迁移验证版" if success else "保存未完成，请检查存储空间。"

func restore_progress() -> void:
	if state.load_from(save_path):
		refresh_workbench()
		status_label.text = "已重新读取本机进度 · Godot 迁移验证版"
	else:
		status_label.text = "没有有效验证存档，当前状态保留。"

func run_smoke_test() -> void:
	show_screen("home")
	show_screen("brew")
	print("[GodotSpike] smoke PASS: title/home/workbench resources assembled")
	get_tree().quit()
