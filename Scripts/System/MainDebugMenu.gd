# MainDebugMenu.gd
# Provides buttons to spawn Mortal or Cultivator characters using CharacterManager.

extends MarginContainer
class_name MainDebugMenu

# Where to spawn new characters in world (offset to avoid overlap)
@export var spawn_position_base: Vector2 = Vector2(200, 200)
@export var spawn_offset: Vector2 = Vector2(40, 0)
var spawn_count: int = 0

func _ready() -> void:
	pass

# Called by the Mortal button
func _on_spawn_mortal_pressed() -> void:
	var pos = spawn_position_base + spawn_offset * spawn_count
	_spawn_character("mortal", pos)
	spawn_count += 1

# Called by the Cultivator button
func _on_spawn_cultivator_pressed() -> void:
	var pos = spawn_position_base + spawn_offset * spawn_count
	_spawn_character("cultivator", pos)
	spawn_count += 1

# Internal: Spawns a character using CharacterManager, adds to scene
func _spawn_character(type: String, pos: Vector2) -> void:
	var char_node = CharManager.create_character(type, pos)
	if char_node:
		# Assumes MainDebugMenu is in the same scene as the game world
		get_tree().current_scene.add_child(char_node)
	else:
		push_error("Failed to create character of type: %s" % type)

# --- How & Where to Use ---
# 1. Attach this script to your VBoxContainer debug menu node in your main scene.
# 2. Add two Buttons as children: "SpawnMortalButton" and "SpawnCultivatorButton".
# 3. Optionally connect the buttons in the editor, or let _ready() auto-connect by node name.
# 4. Pressing a button spawns a character at an offset position and adds it to the current scene.
# 5. Use for debugging character generation and stat/trait display.
