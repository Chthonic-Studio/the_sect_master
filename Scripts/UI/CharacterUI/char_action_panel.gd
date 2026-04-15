extends MarginContainer

var _actions_vbox: VBoxContainer

func _ready() -> void:
	# Dynamically build the UI containers to ensure it always looks correct
	# First, clear any placeholders you left in the editor
	for child in get_children():
		child.queue_free()

	# Create a scrolling container for when we have lots of actions
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(scroll)

	# Create the VBox that will hold our buttons
	_actions_vbox = VBoxContainer.new()
	_actions_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_actions_vbox.add_theme_constant_override("separation", 10)
	scroll.add_child(_actions_vbox)

func refresh_panel(character: CharacterData, dashboard: CharacterDashboard) -> void:
	if not is_instance_valid(_actions_vbox): return

	# Clear old buttons
	for child in _actions_vbox.get_children():
		child.queue_free()

	var player_char = SimulationManager.get_character(GameManager.player_char_id)

	# DEBUG FALLBACK: If no player is set (like in Testing Grounds), grab the first Sect Master we find
	if not player_char:
		for sect_id in SimulationManager.sect_repo:
			var sect = SimulationManager.sect_repo[sect_id]
			var masters = sect.members_by_rank.get(Definitions.SectRank.SECT_MASTER, [])
			if not masters.is_empty():
				player_char = SimulationManager.get_character(masters[0])
				GameManager.set_player_character(player_char.char_id)
				break

	# You cannot execute targeted actions on yourself
	if not player_char or player_char == character:
		var lbl = Label.new()
		lbl.text = "Cannot perform interpersonal actions on yourself." if player_char == character else "No player character assigned."
		lbl.add_theme_color_override("font_color", Color.DIM_GRAY)
		_actions_vbox.add_child(lbl)
		return

	# Ask the InteractionManager what we are legally allowed to do
	var valid_actions = InteractionManager.get_valid_actions(player_char, character)

	if valid_actions.is_empty():
		var lbl = Label.new()
		lbl.text = "No valid actions available."
		lbl.add_theme_color_override("font_color", Color.DIM_GRAY)
		_actions_vbox.add_child(lbl)
	else:
		for action in valid_actions:
			var btn = Button.new()
			btn.text = action.display_name
			btn.tooltip_text = action.tooltip
			btn.custom_minimum_size = Vector2(0, 45)
			
			# Use a lambda to pass the execution context safely
			btn.pressed.connect(func():
				action.execute(player_char, character)
				# Force the dashboard to refresh immediately to show the new logs/wealth changes
				dashboard._refresh_ui()
			)
			_actions_vbox.add_child(btn)
