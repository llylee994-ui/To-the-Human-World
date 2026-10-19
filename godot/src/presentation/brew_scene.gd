extends Control

const LayoutService = preload("res://src/app/layout_service.gd")
const HomeLayersScript = preload("res://src/presentation/home_layers.gd")
const PaperPanelScript = preload("res://src/presentation/paper_panel.gd")
const WordSlipScript = preload("res://src/presentation/word_slip.gd")
const PotDropScript = preload("res://src/presentation/pot_drop.gd")
const PanelPageScript = preload("res://src/presentation/panel_page.gd")
const UiKit = preload("res://src/presentation/ui_kit.gd")

const POT_REGION := Rect2(97.0, 37.0, 1255.0, 1017.0)
const TRAY_REGION := Rect2(27.0, 122.0, 2034.0, 483.0)

const INGREDIENTS := [
	{"id": "ing_sea_salt", "name": "海盐", "stock": 2, "path": "res://media/image/原料_海盐_透明_v01_20261013032602.png",
		"region": Rect2(118.0, 224.0, 796.0, 646.0)},
	{"id": "ing_night_dew", "name": "夜露", "stock": 3, "path": "res://media/image/原料_夜露_透明_v01_20261013032602.png",
		"region": Rect2(268.0, 84.0, 486.0, 870.0)},
	{"id": "ing_ashen_herb", "name": "灰烬草", "stock": 3, "path": "res://media/image/原料_灰烬草_透明_v01_20261013032602.png",
		"region": Rect2(197.0, 29.0, 722.0, 939.0)},
	{"id": "ing_dried_petal", "name": "干花瓣", "stock": 3, "path": "res://media/image/原料_干花瓣_透明_v01_20261013032602.png",
		"region": Rect2(158.0, 90.0, 752.0, 858.0)},
]
const WORDS := [
	{"text": "合上眼", "token": "word_candidate_elias_sleep"},
	{"text": "困", "token": "word_candidate_elias_sleep_alt"},
	{"text": "神志不清", "token": "word_candidate_e01_c1"},
	{"text": "多问几句", "token": "word_candidate_n01_curiosity"},
	{"text": "掏心掏肺", "token": "word_candidate_n01_trust"},
	{"text": "骂骂咧咧", "token": "word_candidate_n01_a2"},
]
const CATEGORIES := ["关系", "情绪", "睡眠", "行为", "记忆"]

var _room: HomeLayers
var _left_panel: Control
var _right_panel: Control
var _toast: Label
var _toast_timer := 0.0
var _selected_slip: WordSlip
var _word_labels: Dictionary = {}
var _building := false
var safe_override := Rect2()


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	clip_contents = true
	get_viewport().size_changed.connect(_rebuild)
	call_deferred("_rebuild")


func _process(delta: float) -> void:
	if _toast != null and _toast_timer > 0.0:
		_toast_timer = maxf(0.0, _toast_timer - delta)
		if _toast_timer <= 0.0:
			_toast.visible = false


func _safe_rect(viewport: Vector2) -> Rect2:
	if safe_override.size.x > 0.0 and safe_override.size.y > 0.0:
		return safe_override
	return LayoutService.current_safe_rect(viewport)


func _rebuild() -> void:
	if _building:
		return
	_building = true
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_room = null
	_left_panel = null
	_right_panel = null
	_toast = null
	_selected_slip = null
	_word_labels.clear()
	var viewport := get_viewport_rect().size
	var safe := _safe_rect(viewport)
	var rects := _brew_layout(viewport, safe)
	var pages := PanelPageScript.new()
	pages.load_pages("res://media/panel-pages.json")
	_add_background(viewport)
	_add_room(viewport)
	_add_left_panel(rects["left_panel"], pages)
	_add_right_panel(rects["right_panel"], pages)
	_add_pot(rects["pot"])
	_add_summary(rects["summary"])
	_add_shelf(rects["shelf"])
	_add_controls(rects["controls"])
	_add_topbar(safe, rects["center"])
	_add_toast(safe)
	if viewport.x < viewport.y:
		UiKit.portrait_guard(self, viewport)
	_building = false


func _brew_layout(viewport: Vector2, safe: Rect2) -> Dictionary:
	var top := safe.position.y
	var bottom := viewport.y - (safe.position.y + safe.size.y)
	var side := floorf(viewport.x * 0.225)
	var x := side + 8.0
	var width := maxf(0.0, viewport.x - side - 8.0 - x)
	var compact := (viewport.y - top - bottom) < 620.0
	var content_top := top + 100.0
	var shelf_h := minf(180.0, width * TRAY_REGION.size.y / TRAY_REGION.size.x)
	var shelf_w := shelf_h * TRAY_REGION.size.x / TRAY_REGION.size.y
	var recipe_h: float = _summary_metrics()["height"]
	var controls_y := viewport.y - bottom - 96.0
	var shelf_y := controls_y - 12.0 - shelf_h
	var summary_y := shelf_y - 12.0 - recipe_h
	var pot_top := content_top + 4.0
	var pot_h := minf(width * 0.85 / (1255.0 / 1017.0), maxf(44.0, summary_y - pot_top - 4.0))
	var pot_w := pot_h * (1255.0 / 1017.0)
	var pot_x := x + (width - pot_w) * 0.5
	return {
		"center": Rect2(x, content_top, width, controls_y + 84.0 - content_top),
		"left_panel": Rect2(0.0, viewport.y * 0.05, side, viewport.y * 0.90),
		"right_panel": Rect2(viewport.x - side, viewport.y * 0.05, side, viewport.y * 0.90),
		"pot": Rect2(pot_x, pot_top, pot_w, pot_h),
		"summary": Rect2(x, summary_y, width, recipe_h),
		"shelf": Rect2(x + (width - shelf_w) * 0.5, shelf_y, shelf_w, shelf_h),
		"controls": Rect2(x, controls_y, width, 84.0),
		"compact": compact,
	}


func _add_background(viewport: Vector2) -> void:
	var sea := TextureRect.new()
	sea.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sea.texture = load("res://media/image/misty-harbor-r1/sea-calm.png") as Texture2D
	sea.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	sea.position = Vector2.ZERO
	sea.size = viewport
	sea.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(sea)
	var wash := ColorRect.new()
	wash.color = Color(0.05, 0.035, 0.02, 0.18)
	wash.position = Vector2.ZERO
	wash.size = viewport
	wash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(wash)


func _add_room(viewport: Vector2) -> void:
	_room = HomeLayersScript.new()
	if not _room.load_manifest("res://media/home-layout.json"):
		return
	_room.hidden_keys = ["case-file", "stove", "net", "merchant-ship"]
	_room.backdrop_path = "res://media/image/misty-harbor-r1/sea-calm.png"
	_room.backdrop_rect = Rect2(0.0, -115.0, 1920.0, 1080.0)
	_room.build()
	var stove_center := _manifest_layer_center("stove", Vector2(1265.5, 498.9))
	var zoom := 1.5
	var origin := Vector2(viewport.x * 0.5, viewport.y * 0.42) - stove_center * zoom
	_room.set_zoom_transform(zoom, origin)
	add_child(_room)


func _manifest_layer_center(key: String, fallback: Vector2) -> Vector2:
	if _room == null:
		return fallback
	for row in _room.manifest.get("layers", []):
		if str(row.get("key", "")) == key:
			return Vector2(float(row.get("x", fallback.x)), float(row.get("y", fallback.y)))
	return fallback


func _add_left_panel(rect: Rect2, pages: PanelPage) -> void:
	_left_panel = Control.new()
	_left_panel.name = "BrewWordPanel"
	_left_panel.position = rect.position
	_left_panel.size = rect.size
	_left_panel.clip_contents = true
	add_child(_left_panel)
	var fit := pages.fit(rect)
	fit["origin"].x = 0.0
	# The tray page's blank strips are placeholders; the real word cards are
	# auto-sized by WordSlip, so skip the fixed strips to avoid empty paper.
	pages.add_page(_left_panel, fit, "tray",
		["tray-slip-0", "tray-slip-1", "tray-slip-2", "tray-slip-3", "tray-slip-4", "tray-slip-5"])
	var scale := float(fit["scale"])
	var title_rect := pages.rect(fit, 12.0, 48.0, 200.0, 46.0)
	var safe := _safe_rect(get_viewport_rect().size)
	var text_left := maxf(title_rect.position.x, safe.position.x - rect.position.x + 12.0)
	title_rect.position.x = text_left
	title_rect.position.y = maxf(title_rect.position.y, safe.position.y - rect.position.y + 8.0)
	UiKit.label(_left_panel, "词条栏", title_rect.position, title_rect.size,
		24, UiKit.INK, UiKit.medium())
	var cards := pages.rect(fit, 10.0, 155.0, 378.0, 555.0)
	var cards_right := cards.end.x
	cards.position.x = maxf(cards.position.x, safe.position.x - rect.position.x + 12.0)
	cards.size.x = maxf(100.0, cards_right - cards.position.x)
	cards.position.y = maxf(cards.position.y, title_rect.position.y + 70.0)
	cards.size.y = maxf(60.0, cards.size.y - 48.0 * scale)
	var max_card_w := minf(300.0 * scale, cards.size.x - 20.0 * scale)
	var word_font := 22
	var gap := 10.0 * scale
	var cursor_x := cards.position.x + 10.0 * scale
	var cursor_y := cards.position.y + 6.0 * scale
	var row_start := cursor_x
	var row_height := 0.0
	_word_labels.clear()
	for index in WORDS.size():
		var text := str(WORDS[index]["text"])
		var token := str(WORDS[index]["token"])
		_word_labels[token] = text
		var slip := WordSlipScript.new()
		slip.configure(text, token, max_card_w, word_font)
		if cursor_x > row_start and cursor_x + slip.size.x > cards.position.x + cards.size.x - 10.0 * scale:
			cursor_x = row_start
			cursor_y += row_height + gap
			row_height = 0.0
		slip.position = Vector2(cursor_x, cursor_y)
		cursor_x += slip.size.x + gap
		row_height = maxf(row_height, slip.size.y)
		slip.selected.connect(_on_word_selected)
		slip.drag_cancelled.connect(_on_drag_cancelled)
		_left_panel.add_child(slip)
	var category_rect := pages.rect(fit, 438.0, 150.0, 78.0, 560.0)
	for index in CATEGORIES.size():
		var label := UiKit.label(_left_panel, CATEGORIES[index],
			Vector2(category_rect.position.x, category_rect.position.y + float(index) * 76.0 * scale),
			Vector2(category_rect.size.x, 46.0 * scale), 16,
			UiKit.INK, UiKit.regular(), HORIZONTAL_ALIGNMENT_CENTER)
		label.add_theme_stylebox_override("normal",
			UiKit.style_box(Color("efe0bf"), Color("b99463"), 1, 4, 2))


func _add_right_panel(rect: Rect2, pages: PanelPage) -> void:
	_right_panel = Control.new()
	_right_panel.name = "BrewBookPanel"
	_right_panel.position = rect.position
	_right_panel.size = rect.size
	_right_panel.clip_contents = true
	add_child(_right_panel)
	var fit := pages.fit(rect)
	fit["origin"].x = rect.size.x - float(fit["size"].x)
	pages.add_page(_right_panel, fit, "journal")
	var safe := _safe_rect(get_viewport_rect().size)
	var content := pages.rect(fit, 132.0, 162.0, 365.0, 570.0)
	content.position.y = maxf(content.position.y, safe.position.y - rect.position.y + 8.0)
	content.size.x = minf(content.size.x, safe.end.x - rect.position.x - content.position.x - 12.0)
	content.size.y = minf(content.size.y, safe.end.y - rect.position.y - content.position.y - 12.0)
	var journal := VBoxContainer.new()
	journal.name = "JournalContent"
	journal.position = content.position
	journal.size = content.size
	journal.add_theme_constant_override("separation", 8)
	_right_panel.add_child(journal)
	var header := VBoxContainer.new()
	header.name = "JournalHeader"
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_theme_constant_override("separation", 8)
	journal.add_child(header)
	for row in [["记录书",24],["铁锚巷的一夜",22],["已收集 0 / 8 支",15]]:
		var label := UiKit.label(header, row[0], Vector2.ZERO, Vector2.ZERO, row[1],
			UiKit.INK, UiKit.regular(), HORIZONTAL_ALIGNMENT_LEFT, true)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var scroll := ScrollContainer.new()
	scroll.name = "JournalText"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	journal.add_child(scroll)
	var column := VBoxContainer.new()
	column.name = "JournalEntries"
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 8)
	scroll.add_child(column)
	for row in [["1. ？？？",18],["未收集",14],["2. ？？？",18],["未收集",14],
		["3. ？？？",18],["未收集",14],["4. ？？？",18],["未收集",14]]:
		var label := UiKit.label(column, row[0], Vector2.ZERO, Vector2(0, 0), row[1],
			UiKit.INK, UiKit.regular(), HORIZONTAL_ALIGNMENT_LEFT, true)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL


func _add_pot(rect: Rect2) -> void:
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return
	var node := TextureRect.new()
	node.name = "Cauldron"
	node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	node.texture = _atlas("res://media/image/brew-topdown/cauldron-v01.png", POT_REGION)
	node.stretch_mode = TextureRect.STRETCH_SCALE
	node.position = rect.position
	node.size = rect.size
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(node)
	var drop := PotDropScript.new()
	drop.name = "PotDrop"
	drop.position = rect.position + Vector2(rect.size.x * 0.12, rect.size.y * 0.04)
	drop.size = Vector2(rect.size.x * 0.76, rect.size.y * 0.70)
	drop.dropped.connect(_on_word_dropped)
	add_child(drop)


func _summary_metrics() -> Dictionary:
	var regular := UiKit.regular()
	var title_h := ceilf(UiKit.medium().get_height(UiKit.scaled_font_size(16))) + 4.0
	var slot_h := ceilf(regular.get_height(UiKit.scaled_font_size(15)) * 2.0) + 10.0
	var note_h := ceilf(regular.get_height(UiKit.scaled_font_size(13))) + 4.0
	return {"title":title_h,"slot":slot_h,"note":note_h,
		"height":28.0 + title_h + slot_h + note_h + 16.0}


func _add_summary(rect: Rect2) -> void:
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return
	var panel := PaperPanelScript.new()
	panel.name = "BrewSummary"
	panel.position = rect.position
	panel.size = rect.size
	panel.configure(UiKit.PAPER, 14)
	add_child(panel)
	var inner := panel.content
	var metrics := _summary_metrics()
	var title_h: float = metrics["title"]
	var slot_h: float = metrics["slot"]
	var note_h: float = metrics["note"]
	UiKit.label(inner, "配方与药槽", Vector2.ZERO, Vector2(rect.size.x - 28.0, title_h),
		16, UiKit.INK, UiKit.medium())
	var labels := ["主词\n合上眼", "辅词\n+", "辅词\n+", "原料\n海盐", "原料\n+"]
	var gap := 6.0
	var cell_w := maxf(1.0, (rect.size.x - 28.0 - gap * 4.0) / 5.0)
	for index in labels.size():
		var slot := UiKit.label(inner, labels[index],
			Vector2(float(index) * (cell_w + gap), title_h + 8.0),
			Vector2(cell_w, slot_h), 15, UiKit.INK, UiKit.regular(), HORIZONTAL_ALIGNMENT_CENTER)
		slot.add_theme_stylebox_override("normal",
			UiKit.style_box(Color("f4e7c8"), Color("b99463"), 1, 4, 3))
	UiKit.label(inner, "原料 1/2 · 已满足炼制条件（演示）",
		Vector2(0.0, title_h + 8.0 + slot_h + 8.0), Vector2(rect.size.x - 28.0, note_h),
		13, Color("7b5b3d"), UiKit.regular())


func _add_shelf(rect: Rect2) -> void:
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return
	var tray := TextureRect.new()
	tray.name = "IngredientTray"
	tray.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tray.texture = _atlas("res://media/image/brew-topdown/four-cell-tray-v01.png", TRAY_REGION)
	tray.stretch_mode = TextureRect.STRETCH_SCALE
	tray.position = rect.position
	tray.size = rect.size
	tray.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(tray)
	var cell_w := rect.size.x / 4.0
	for index in INGREDIENTS.size():
		var item: Dictionary = INGREDIENTS[index]
		var icon_size := Vector2(cell_w * 0.90, rect.size.y * 0.72)
		var icon := TextureRect.new()
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.texture = _atlas(str(item["path"]), item["region"])
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.position = Vector2(
			rect.position.x + cell_w * (float(index) + 0.5) - icon_size.x * 0.5,
			rect.position.y + 2.0
		)
		icon.size = icon_size
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(icon)
		UiKit.label(self, str(item["name"]) + "×" + str(item["stock"]),
			Vector2(rect.position.x + cell_w * float(index), rect.position.y + rect.size.y - 38.0),
			Vector2(cell_w, 28.0), 14, UiKit.INK, UiKit.regular(), HORIZONTAL_ALIGNMENT_CENTER)


func _add_controls(rect: Rect2) -> void:
	var button_width := minf(420.0, maxf(260.0, rect.size.x - 190.0))
	var start := UiKit.button(self, "开始熬制",
		Vector2(rect.position.x + (rect.size.x - button_width) * 0.5, rect.position.y),
		Vector2(button_width, 84.0), _on_start, true)
	start.name = "BrewStart"
	var clear := UiKit.button(self, "清空",
		Vector2(rect.position.x + rect.size.x - 148.0, rect.position.y),
		Vector2(140.0, 84.0), _on_clear)
	clear.name = "BrewClear"


func _add_topbar(safe: Rect2, center: Rect2) -> void:
	var back_width := 240.0
	var back := UiKit.button(self, "返回主页",
		Vector2(safe.position.x + safe.size.x - back_width - 8.0, safe.position.y + 8.0),
		Vector2(back_width, 76.0), _go_home)
	back.name = "BrewBack"
	var toggle_width := 220.0
	var center_x := center.position.x + center.size.x * 0.5
	var words := UiKit.button(self, "收起词条", Vector2(center_x - toggle_width - 6.0, safe.position.y + 8.0),
		Vector2(toggle_width, 76.0), _toggle_left)
	words.name = "BrewToggleWords"
	var journal := UiKit.button(self, "收起记录", Vector2(center_x + 6.0, safe.position.y + 8.0),
		Vector2(toggle_width, 76.0), _toggle_right)
	journal.name = "BrewToggleJournal"


func _add_toast(safe: Rect2) -> void:
	_toast = UiKit.tag(self, "", Vector2(safe.position.x + 12.0, safe.position.y + safe.size.y - 108.0),
		Vector2(minf(680.0, safe.size.x - 24.0), 52.0), 15)
	_toast.name = "BrewToast"
	_toast.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_toast.visible = false


func _atlas(path: String, region: Rect2) -> AtlasTexture:
	var source := load(path) as Texture2D
	var atlas := AtlasTexture.new()
	atlas.atlas = source
	atlas.region = region
	return atlas


func _on_word_selected(slip: WordSlip) -> void:
	if _selected_slip != null and _selected_slip != slip:
		_selected_slip.set_selected(false)
	_selected_slip = slip
	slip.set_selected(true)
	_show_toast("已选中词条「" + slip.display_text + "」（P0 演示）")


func _on_word_dropped(token_id: String) -> void:
	_show_toast("已拖入「" + str(_word_labels.get(token_id, token_id)) + "」；P0 只演示落锅反馈，不消耗库存。")


func _on_drag_cancelled(slip: WordSlip) -> void:
	_show_toast("已取消拖拽「" + slip.display_text + "」；松在锅外不会消耗词条。")


func _on_start() -> void:
	_show_toast("P0 不执行熬制；正式订单事务在 P2 接入。")


func _on_clear() -> void:
	_show_toast("清空与库存变更在 P2 接入；P0 不修改任何业务状态。")


func _toggle_left() -> void:
	if _left_panel != null:
		_left_panel.visible = not _left_panel.visible


func _toggle_right() -> void:
	if _right_panel != null:
		_right_panel.visible = not _right_panel.visible


func _show_toast(text: String) -> void:
	if _toast == null:
		return
	_toast.text = text
	_toast.visible = true
	_toast_timer = 3.2


func _go_home() -> void:
	get_tree().change_scene_to_file("res://scenes/home.tscn")
