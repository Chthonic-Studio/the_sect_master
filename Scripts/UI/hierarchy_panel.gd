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
	
	# Assuming your roster_item.tscn has labels named Name, Realm, CurrentPosition
	var name_label = item.get_node("HBoxContainer/Name")
	var realm_label = item.get_node("HBoxContainer/Realm")
	
	name_label.text = character.get_full_name()
	
	# Convert Enum to String representation
	var realm_string = Definitions.MartialRealm.keys()[character.current_realm].capitalize()
	realm_label.text = realm_string
