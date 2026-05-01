extends Control

## System Menu — Save, Load, and return to Main Menu.
## Registered as a panel with UIManager on the SYSTEM layer.

var _save_list_vbox: VBoxContainer

func _ready() -> void:
	UIManager.register_panel("system_menu", self, UIManager.Layer.SYSTEM)
	_build_ui()

func setup_panel(_payload: Variant = null) -> void:
	_refresh_save_list()

func _build_ui() -> void:
	custom_minimum_size = Vector2(420, 560)
	set_anchors_preset(Control.PRESET_CENTER)

	var bg := ColorRect.new()
	bg.color = Color(0.06, 0.06, 0.09, 0.98)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
		margin.add_theme_constant_override(side, 18)
	add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	margin.add_child(vbox)

	# Title
	var title := Label.new()
	title.text = "Menu"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	vbox.add_child(title)
	vbox.add_child(HSeparator.new())

	# Quick-save button
	var btn_save := Button.new()
	btn_save.text = "Save Game"
	btn_save.custom_minimum_size = Vector2(0, 42)
	btn_save.pressed.connect(_on_save_pressed)
	vbox.add_child(btn_save)

	# Save list header
	var saves_lbl := Label.new()
	saves_lbl.text = "Load a Save:"
	saves_lbl.add_theme_color_override("font_color", Color(0.75, 0.75, 0.75))
	vbox.add_child(saves_lbl)

	# Scrollable save list
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 200)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)

	_save_list_vbox = VBoxContainer.new()
	_save_list_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_save_list_vbox.add_theme_constant_override("separation", 4)
	scroll.add_child(_save_list_vbox)

	vbox.add_child(HSeparator.new())

	# Main menu / quit
	var btn_menu := Button.new()
	btn_menu.text = "Return to Main Menu"
	btn_menu.custom_minimum_size = Vector2(0, 42)
	btn_menu.pressed.connect(_on_main_menu_pressed)
	vbox.add_child(btn_menu)

	var btn_quit := Button.new()
	btn_quit.text = "Quit to Desktop"
	btn_quit.custom_minimum_size = Vector2(0, 42)
	btn_quit.pressed.connect(func(): get_tree().quit())
	vbox.add_child(btn_quit)

	vbox.add_child(HSeparator.new())

	var btn_close := Button.new()
	btn_close.text = "Resume"
	btn_close.custom_minimum_size = Vector2(0, 42)
	btn_close.pressed.connect(func(): UIManager.close_panel("system_menu"))
	vbox.add_child(btn_close)

func _refresh_save_list() -> void:
	for child in _save_list_vbox.get_children():
		child.queue_free()

	var headers: Array[Dictionary] = SaveManager.get_all_save_headers()

	if headers.is_empty():
		var lbl := Label.new()
		lbl.text = "No saves found."
		lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		_save_list_vbox.add_child(lbl)
		return

	for header in headers:
		var row := HBoxContainer.new()
		_save_list_vbox.add_child(row)

		var info_lbl := Label.new()
		info_lbl.text = "%s  —  Year %d/%d/%d" % [
			header.get("player_name", "?"),
			header.get("year", 0),
			header.get("month", 1),
			header.get("day", 1)
		]
		info_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(info_lbl)

		var load_btn := Button.new()
		load_btn.text = "Load"
		load_btn.custom_minimum_size = Vector2(60, 28)
		var filename_capture: String = header.get("filename", "")
		load_btn.pressed.connect(func():
			SaveManager.load_game(filename_capture)
			UIManager.close_panel("system_menu")
			SceneManager.goto_game_scene()
		)
		row.add_child(load_btn)

func _on_save_pressed() -> void:
	var save_name: String = "save_" + str(TimeManager.year) + "_" + str(TimeManager.month) + "_" + str(TimeManager.day)
	SaveManager.save_game(save_name)
	_refresh_save_list()

func _on_main_menu_pressed() -> void:
	UIManager.close_panel("system_menu")
	SceneManager.goto_main_menu()
