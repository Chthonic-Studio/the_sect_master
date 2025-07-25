class_name Game extends Node

# --- Initialization ---
func _ready() -> void:
	# If we are in test mode, automatically set up the player's sect and sect master.
	if GameManager.test_mode:
		# We need a reference to a node in the scene tree to be the parent
		# of the new character node. We pass `self` for this purpose.
		PlayerManager.setup_initial_player(self)
		
		# You can also add a call here to update any UI elements with the new player data.
		# For example, if your debug menu is in this scene:
		var debug_menu = find_child("MainDebugMenu", true, false)
		if debug_menu:
			debug_menu.last_spawned_character = PlayerManager.player_character_node
			debug_menu._update_info_panel()
