extends VBoxContainer
class_name HierarchyPanel

@export var roster_item_scene: PackedScene
var active_sect: SectData

func setup_panel(sect: SectData) -> void:
	active_sect = sect
	_refresh_roster()

func _refresh_roster() -> void:
	if not active_sect: return
	
	%TotalMembersCount.text = "Total Disciples: " + str(active_sect.all_members.size())
	
	# Clean up old UI nodes
	for child in %RosterGrid.get_children():
		child.queue_free()
		
	# Populate new nodes
	for char_id in active_sect.all_members:
		var character = SimulationManager.get_character(char_id)
		if character and character.is_alive:
			_spawn_roster_item(character)

func _spawn_roster_item(character: CharacterData) -> void:
	var item = roster_item_scene.instantiate()
	%RosterGrid.add_child(item)
	
	var name_label = item.get_node("HBoxContainer/Name")
	var realm_label = item.get_node("HBoxContainer/Realm")
	
	name_label.text = character.get_full_name()
	realm_label.text = Definitions.MartialRealm.keys()[character.current_realm].capitalize()

	# Make the item clickable to open the character dashboard
	item.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	item.gui_input.connect(func(event: InputEvent):
		# We check for a Left Click release to trigger the panel
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
			UIManager.open_panel("character_dashboard", character)
	)
