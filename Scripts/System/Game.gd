class_name Game extends Node

# --- Initialization ---
func _ready() -> void:
	initialize_game_world()

func initialize_game_world() -> void:
	# If we are in test mode, automatically set up the player's sect and sect master.
	if GameManager.test_mode:
		PlayerManager.setup_initial_player(self)
		_spawn_test_characters()
		
		var debug_menu = find_child("MainDebugMenu", true, false)
		if debug_menu:
			debug_menu.last_spawned_character = PlayerManager.player_character_node
			debug_menu._update_info_panel()

# --- GLOBAL INPUT DEBUGGER ---
# The _input function is called for every input event, before _unhandled_input.
# This allows us to see what's happening globally.
func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.is_pressed():
		# This will print every time you click, regardless of where.
		print("--- GLOBAL CLICK DETECTED ---")
		# The 'is_handled()' method tells us if a node (usually UI) has already processed and "stopped" this event.
		if get_viewport().is_input_handled():
			print("Input was handled by the UI tree. It will not reach the game world.")
		else:
			print("Input was NOT handled by the UI tree. It should reach game world nodes.")
		print("--------------------------")

# --- Test Character Spawning Logic ---
# Creates the specific set of characters needed for testing the UI.
func _spawn_test_characters() -> void:
	var player_sect_id = PlayerManager.player_sect_id
	if player_sect_id == -1:
		push_error("Game: Cannot spawn test characters, player sect not initialized.")
		return

	# 1. Spawn 2 members for the player's sect
	var member1 = CharManager.create_character("cultivator", Vector2(150, 100))
	SectManager.add_member_to_sect(player_sect_id, member1.character_resource.id)
	add_child(member1)
	
	var member2 = CharManager.create_character("cultivator", Vector2(200, 100))
	SectManager.add_member_to_sect(player_sect_id, member2.character_resource.id)
	add_child(member2)

	# 2. Create a rival sect and spawn one member for it
	var rival_sect_id = SectManager.create_random_sect()
	var rival_member = CharManager.create_character("cultivator", Vector2(150, 300))
	SectManager.add_member_to_sect(rival_sect_id, rival_member.character_resource.id)
	add_child(rival_member)

	# 3. Spawn an unaffiliated mortal
	var mortal = CharManager.create_character("mortal", Vector2(300, 200))
	add_child(mortal)

	# 4. Spawn an unaffiliated cultivator
	var cultivator = CharManager.create_character("cultivator", Vector2(350, 200))
	add_child(cultivator)
	
	print("Spawned 5 test characters.")
