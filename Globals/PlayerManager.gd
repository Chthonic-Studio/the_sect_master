extends Node

var player_sect_id: int = -1
var player_character_node: Node2D = null
var player_character_resource: CharacterResource = null

# --- API ---

# Sets up the initial player character and sect. Called by Game.gd at start.
func setup_initial_player(parent_node: Node) -> void:
	# 1. Create the Player's Sect
	var player_sect_res = SectManager.create_sect("Player's Sect")
	# This is a bit of a workaround to get the ID, since the resource itself doesn't store it.
	# In a real implementation, create_sect would likely return the ID or a dictionary.
	# For now, we assume the first sect created is the player's.
	player_sect_id = 1 

	# 2. Create the Sect Master Character
	var overrides = {
		"cultivation_realm": Definitions.CultivationRealm.GOLDEN_CORE,
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
	
	print("Player setup complete. Sect Master: %s, Sect ID: %d" % [player_character_resource.name_display, player_sect_id])

# Retrieves the player's SectResource.
func get_player_sect() -> SectResource:
	if player_sect_id != -1:
		return SectManager.get_sect_by_id(player_sect_id)
	return null

# --- How & Where to Use ---
# 1. Add as an Autoload singleton named "PlayerManager".
# 2. Call `PlayerManager.setup_initial_player(self)` from your main game scene's _ready() function.
# 3. Access player data from anywhere: `PlayerManager.player_character_resource` or `PlayerManager.get_player_sect()`.
