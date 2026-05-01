extends Control

## Spawns when GameManager.player_succession_required is emitted.

var heir_id: String = ""

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP

func setup_popup(payload: Dictionary) -> void:
	heir_id = payload.get("heir_id", "")
	var heir = SimulationManager.get_character(heir_id)
	
	if not heir:
		%DescLabel.text = "Your Sect Master has fallen... and there is no one left to take the mantle. The Sect has collapsed."
		%ConfirmButton.text = "Game Over"
		%ConfirmButton.pressed.connect(_on_game_over)
		return
		
	%DescLabel.text = "The Sect Master has fallen.\n\nAccording to the Sect's Succession Laws, %s is the rightful heir and will now ascend to the position of Sect Master." % heir.get_full_name()
	%ConfirmButton.text = "Play as Heir"
	%ConfirmButton.pressed.connect(_on_accept_succession)

func _on_accept_succession() -> void:
	# 1. Bind the player to the new character
	GameManager.set_player_character(heir_id)
	
	# 2. Command the Sect to execute the crowning
	var sect = SimulationManager.get_sect(GameManager.player_sect_id)
	if sect:
		sect.execute_succession(heir_id)
		
	# 3. Resume the game
	TimeManager.set_time_speed(TimeManager.Speed.NORMAL)
	queue_free()

func _on_game_over() -> void:
	queue_free()
	# Show a brief summary before returning to the main menu
	_show_game_over_screen()

func _show_game_over_screen() -> void:
	# Build a fullscreen game-over overlay on the SYSTEM layer
	var overlay := Control.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	UIManager._layers[UIManager.Layer.SYSTEM].add_child(overlay)

	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.02, 0.04, 0.98)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 18)
	vbox.custom_minimum_size = Vector2(640, 0)
	center.add_child(vbox)

	var title := Label.new()
	title.text = "THE SECT HAS FALLEN"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color", Color(0.8, 0.2, 0.2))
	vbox.add_child(title)

	vbox.add_child(HSeparator.new())

	# Show last 10 world log entries as a chronicle summary
	var summary_lbl := RichTextLabel.new()
	summary_lbl.bbcode_enabled = false
	summary_lbl.fit_content = true
	summary_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	summary_lbl.custom_minimum_size = Vector2(600, 200)
	var log_lines: Array[String] = []
	for entry in WorldLogManager.global_logs.slice(0, mini(20, WorldLogManager.global_logs.size())):
		log_lines.append("[%s] %s" % [entry.get("date", "?"), entry.get("message", "")])
	summary_lbl.text = "\n".join(log_lines)
	vbox.add_child(summary_lbl)

	vbox.add_child(HSeparator.new())

	var btn := Button.new()
	btn.text = "Return to Main Menu"
	btn.custom_minimum_size = Vector2(240, 50)
	btn.pressed.connect(func():
		overlay.queue_free()
		SceneManager.goto_main_menu()
	)

	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_child(btn)
	vbox.add_child(btn_row)
