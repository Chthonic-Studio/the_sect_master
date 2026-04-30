extends Control
class_name ProvinceView

## Panel that shows detailed information about a single province.
## Tabs: Overview | Sects | Actions
## Opened by clicking a province on the map (PROVINCES layer).

enum SortMode { STRENGTH, SIZE, RELATIONSHIP, NAME }

var _province_id: String = ""
var _sort_mode: SortMode = SortMode.STRENGTH

# ── DRAG STATE ───────────────────────────────────────────────────
var _dragging: bool = false
var _drag_offset: Vector2 = Vector2.ZERO

# ── SORT BUTTON REFS ─────────────────────────────────────────────
var _btn_sort_strength: Button
var _btn_sort_size: Button
var _btn_sort_relation: Button
var _btn_sort_name: Button

# ── INTERNAL UI REFS ─────────────────────────────────────────────
var _title_label: Label
var _region_label: Label
var _sect_count_label: Label
var _desc_label: Label
var _sects_list: VBoxContainer
var _tab_container: TabContainer

## Bring this panel to the front whenever the player clicks anywhere on it.
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		move_to_front()

## Handles drag-and-drop input from the title bar.
func _on_drag_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			# Snapshot absolute position then clear anchors for free movement
			var abs_pos := get_global_rect().position
			anchor_left = 0.0
			anchor_top = 0.0
			anchor_right = 0.0
			anchor_bottom = 0.0
			position = abs_pos
			_drag_offset = event.global_position - abs_pos
			_dragging = true
			move_to_front()
			accept_event()
		else:
			_dragging = false
	elif event is InputEventMouseMotion and _dragging:
		var new_pos = event.global_position - _drag_offset
		var vp := get_viewport_rect().size
		var max_x = max(0.0, vp.x - size.x)
		var max_y = max(0.0, vp.y - size.y)
		new_pos.x = clamp(new_pos.x, 0.0, max_x)
		new_pos.y = clamp(new_pos.y, 0.0, max_y)
		position = new_pos
		accept_event()

func _ready() -> void:
	UIManager.register_panel("province_view", self, UIManager.Layer.PANELS)
	_build_ui()

## Called by UIManager when the panel is opened with a province_id payload.
func setup_panel(province_id: Variant = null) -> void:
	if province_id == null or not (province_id is String):
		return
	_province_id = province_id as String
	_refresh()

func _refresh() -> void:
	var prov_data: Dictionary = DataManager.provinces_registry.get(_province_id, {})
	if prov_data.is_empty():
		return

	var prov_name: String = prov_data.get("name", _province_id)
	var region_id: String = prov_data.get("region_id", "")
	var region_data: Dictionary = DataManager.regions_registry.get(region_id, {})
	var region_name: String = region_data.get("name", region_id)
	var description: String = prov_data.get("description", "No description available.")
	var sects: Array = MapManager.get_sects_in_province(_province_id)

	_title_label.text = prov_name
	_region_label.text = "Region: %s" % region_name
	_sect_count_label.text = "Sects: %d" % sects.size()
	_desc_label.text = description

	_rebuild_sects_list(sects)

func _rebuild_sects_list(sects: Array) -> void:
	for child in _sects_list.get_children():
		child.queue_free()
	var sect_objects: Array = []
	for s_id in sects:
		var s: SectData = SimulationManager.get_sect(s_id)
		if s:
			sect_objects.append(s)

	_sort_sects(sect_objects)

	for sect in sect_objects:
		_sects_list.add_child(_make_sect_row(sect))

func _sort_sects(arr: Array) -> void:
	match _sort_mode:
		SortMode.STRENGTH:
			arr.sort_custom(func(a: SectData, b: SectData) -> bool:
				return a.cached_sect_strength > b.cached_sect_strength)
		SortMode.SIZE:
			arr.sort_custom(func(a: SectData, b: SectData) -> bool:
				return a.all_members.size() > b.all_members.size())
		SortMode.RELATIONSHIP:
			var player_sect_id: String = GameManager.player_sect_id
			arr.sort_custom(func(a: SectData, b: SectData) -> bool:
				var rel_a: int = SimulationManager.get_sect_relationship(player_sect_id, a.sect_id)
				var rel_b: int = SimulationManager.get_sect_relationship(player_sect_id, b.sect_id)
				return rel_a > rel_b)
		SortMode.NAME:
			arr.sort_custom(func(a: SectData, b: SectData) -> bool:
				return a.sect_name < b.sect_name)

func _make_sect_row(sect: SectData) -> Control:
	var hbox := HBoxContainer.new()
	hbox.custom_minimum_size = Vector2(0, 28)

	var align_str: String = Definitions.SectAlignment.keys()[sect.alignment].capitalize()
	var player_sect_id: String = GameManager.player_sect_id
	var relation: int = SimulationManager.get_sect_relationship(player_sect_id, sect.sect_id)

	var name_btn := LinkButton.new()
	name_btn.text = sect.sect_name
	name_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var sect_capture: SectData = sect
	name_btn.pressed.connect(func(): UIManager.open_panel("sect_dashboard", sect_capture))
	hbox.add_child(name_btn)

	var align_lbl := Label.new()
	align_lbl.text = align_str
	align_lbl.custom_minimum_size = Vector2(90, 0)
	hbox.add_child(align_lbl)

	var str_lbl := Label.new()
	str_lbl.text = "Str: %d" % sect.cached_sect_strength
	str_lbl.custom_minimum_size = Vector2(70, 0)
	hbox.add_child(str_lbl)

	var size_lbl := Label.new()
	size_lbl.text = "Mbrs: %d" % sect.all_members.size()
	size_lbl.custom_minimum_size = Vector2(70, 0)
	hbox.add_child(size_lbl)

	var rel_lbl := Label.new()
	rel_lbl.text = "Rel: %+d" % relation
	rel_lbl.custom_minimum_size = Vector2(60, 0)
	if relation >= 30:
		rel_lbl.add_theme_color_override("font_color", Color(0.4, 0.9, 0.5))
	elif relation <= -30:
		rel_lbl.add_theme_color_override("font_color", Color(0.9, 0.3, 0.3))
	hbox.add_child(rel_lbl)

	return hbox

# ── UI CONSTRUCTION ───────────────────────────────────────────────

func _build_ui() -> void:
	custom_minimum_size = Vector2(680, 560)
	set_anchors_preset(Control.PRESET_CENTER)

	var bg := ColorRect.new()
	bg.color = Color(0.08, 0.08, 0.11, 0.97)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	# PASS so clicks propagate to the root Control's _gui_input for bring-to-front
	bg.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 10)
	add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	margin.add_child(vbox)

	# Title row — used as drag handle
	var title_row := HBoxContainer.new()
	title_row.mouse_filter = Control.MOUSE_FILTER_STOP
	title_row.mouse_default_cursor_shape = Control.CURSOR_DRAG
	title_row.gui_input.connect(_on_drag_input)
	vbox.add_child(title_row)

	_title_label = Label.new()
	_title_label.text = "Province"
	_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title_label.add_theme_font_size_override("font_size", 22)
	title_row.add_child(_title_label)

	var btn_close := Button.new()
	btn_close.text = "X"
	btn_close.custom_minimum_size = Vector2(36, 36)
	btn_close.pressed.connect(func(): UIManager.close_panel("province_view"))
	title_row.add_child(btn_close)

	vbox.add_child(HSeparator.new())

	# Info row
	var info_row := HBoxContainer.new()
	info_row.add_theme_constant_override("separation", 20)
	vbox.add_child(info_row)

	_region_label = Label.new()
	_region_label.text = "Region: —"
	info_row.add_child(_region_label)

	_sect_count_label = Label.new()
	_sect_count_label.text = "Sects: 0"
	info_row.add_child(_sect_count_label)

	# Description
	_desc_label = Label.new()
	_desc_label.text = ""
	_desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_desc_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	vbox.add_child(_desc_label)

	vbox.add_child(HSeparator.new())

	# TabContainer
	_tab_container = TabContainer.new()
	_tab_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(_tab_container)

	_build_overview_tab()
	_build_sects_tab()
	_build_actions_tab()

func _build_overview_tab() -> void:
	var tab := VBoxContainer.new()
	tab.name = "Overview"
	_tab_container.add_child(tab)
	var lbl := Label.new()
	lbl.text = "Select the Sects tab to see all factions active in this province."
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.add_theme_color_override("font_color", Color(0.75, 0.75, 0.75))
	tab.add_child(lbl)

func _build_sects_tab() -> void:
	var tab := VBoxContainer.new()
	tab.name = "Sects"
	_tab_container.add_child(tab)

	# Sort controls
	var sort_row := HBoxContainer.new()
	sort_row.add_theme_constant_override("separation", 6)
	tab.add_child(sort_row)

	var sort_lbl := Label.new()
	sort_lbl.text = "Sort by:"
	sort_row.add_child(sort_lbl)

	_btn_sort_strength = _make_sort_button("Strength", SortMode.STRENGTH, sort_row)
	_btn_sort_size     = _make_sort_button("Size",     SortMode.SIZE,     sort_row)
	_btn_sort_relation = _make_sort_button("Relation", SortMode.RELATIONSHIP, sort_row)
	_btn_sort_name     = _make_sort_button("Name",     SortMode.NAME,    sort_row)
	_update_sort_buttons()

	# Column headers
	var header := HBoxContainer.new()
	tab.add_child(header)
	_add_header_label(header, "Name", true)
	_add_header_label(header, "Alignment", false, 90)
	_add_header_label(header, "Strength",  false, 70)
	_add_header_label(header, "Members",   false, 70)
	_add_header_label(header, "Relation",  false, 60)

	tab.add_child(HSeparator.new())

	# Scrollable list
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tab.add_child(scroll)

	_sects_list = VBoxContainer.new()
	_sects_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_sects_list.add_theme_constant_override("separation", 2)
	scroll.add_child(_sects_list)

func _update_sort_buttons() -> void:
	_btn_sort_strength.disabled = (_sort_mode == SortMode.STRENGTH)
	_btn_sort_size.disabled     = (_sort_mode == SortMode.SIZE)
	_btn_sort_relation.disabled = (_sort_mode == SortMode.RELATIONSHIP)
	_btn_sort_name.disabled     = (_sort_mode == SortMode.NAME)

func _make_sort_button(label: String, mode: SortMode, parent: Control) -> Button:
	var btn := Button.new()
	btn.text = label
	btn.custom_minimum_size = Vector2(80, 28)
	btn.pressed.connect(func():
		_sort_mode = mode
		_update_sort_buttons()
		_rebuild_sects_list(MapManager.get_sects_in_province(_province_id)))
	parent.add_child(btn)
	return btn

func _add_header_label(parent: Control, text: String, expand: bool, min_w: float = 0.0) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.9))
	if expand:
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	else:
		lbl.custom_minimum_size = Vector2(min_w, 0)
	parent.add_child(lbl)

func _build_actions_tab() -> void:
	var tab := VBoxContainer.new()
	tab.name = "Actions"
	_tab_container.add_child(tab)
	var lbl := Label.new()
	lbl.text = "Province actions will be available in a future update."
	lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tab.add_child(lbl)
