extends Control

## System Menu — Save, Load, and return to Main Menu.
## Registered as a panel with UIManager on the SYSTEM layer.
## All static UI is defined in system_menu.tscn — no nodes are built in code.

func _ready() -> void:
	UIManager.register_panel("system_menu", self, UIManager.Layer.SYSTEM)
	%BtnSave.pressed.connect(_on_save_pressed)
	%BtnMainMenu.pressed.connect(_on_main_menu_pressed)
	%BtnQuit.pressed.connect(func(): get_tree().quit())
	%BtnResume.pressed.connect(func(): UIManager.close_panel("system_menu"))

func setup_panel(_payload: Variant = null) -> void:
	_refresh_save_list()

func _refresh_save_list() -> void:
	for child in %SaveListVBox.get_children():
		child.queue_free()

	var headers: Array[Dictionary] = SaveManager.get_all_save_headers()

	if headers.is_empty():
		var lbl := Label.new()
		lbl.text = "No saves found."
		lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		%SaveListVBox.add_child(lbl)
		return

	for header in headers:
		var row := HBoxContainer.new()
		%SaveListVBox.add_child(row)

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

