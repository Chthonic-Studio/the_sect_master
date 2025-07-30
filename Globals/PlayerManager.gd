# PlayerManager.gd
# Manages the player's character, sect, and related high-level state.
# Place in res://Globals/PlayerManager.gd and add as "PlayerManager" in Autoloads.

extends Node

# This signal is emitted after the player character and sect are created.
signal player_initialized

# References to the player's core assets.
var player_sect_id: int = -1
var player_character_node: Node2D = null
var player_character_resource: CharacterResource = null

# --- API ---

# Sets up the initial player character and sect. Called by Game.gd at start.
func setup_initial_player(parent_node: Node) -> void:
	# 1. Create the Player's Sect using the new random generator.
	player_sect_id = SectManager.create_random_sect()

	# 2. Create the Sect Master Character
	# --- FIX ---
	# We now use a StringName for the realm_id, not an enum.
	# The StringName must match the .tres file name of the realm resource (e.g., "GoldenCore.tres").
	var overrides = {
		"cultivation_realm": &"golden_core", # Using StringName literal `&"..."` for the ID.
		"age": randi_range(80, 150) # Golden Core cultivators are older
	}
	player_character_node = CharManager.create_character("cultivator", Vector2(100, 200), overrides)
	
	if not player_character_node:
		push_error("PlayerManager: Failed to create the Sect Master character.")
		return
		
	player_character_resource = player_character_node.character_resource
	
	# 3. Link the Sect Master to the Sect
	SectManager.add_member_to_sect(player_sect_id, player_character_resource.id)
	
	# 4. Add the character to the scene
	parent_node.add_child(player_character_node)
	
	var player_sect = get_player_sect()
	print("Player setup complete. Sect Master: %s, Sect: %s (ID: %d)" % [player_character_resource.name_display, player_sect.sect_name, player_sect_id])
	
	# 5. Announce that the setup is complete.
	emit_signal("player_initialized")

# Retrieves the player's SectResource.
func get_player_sect() -> SectResource:
	if player_sect_id != -1:
		return SectManager.get_sect_by_id(player_sect_id)
	return null

# --- How & Where to Use ---
# 1. Add as an Autoload singleton named "PlayerManager".
# 2. Call `PlayerManager.setup_initial_player(self)` from your main game scene's _ready() function.
# 3. Access player data from anywhere: `PlayerManager.player_character_resource` or `PlayerManager.get_player_sect()`.
# 4. Connect to the `player_initialized` signal to trigger UI updates or other logic.
