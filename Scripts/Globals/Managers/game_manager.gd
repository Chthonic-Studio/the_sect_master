extends Node

signal player_character_changed(new_char_id: String)
signal player_died(dead_char_id: String)
signal player_succession_required(heir_char_id: String)

var player_char_id: String = ""
var player_sect_id: String = ""

## Returns true if the provided character is the player.
func is_player(char_id: String) -> bool:
	return char_id == player_char_id

## Safely binds the player to a new character (used during start or succession).
func set_player_character(char_id: String) -> void:
	var character = SimulationManager.get_character(char_id)
	if not character:
		printerr("GameManager: Attempted to set player to invalid character ID: ", char_id)
		return
		
	player_char_id = char_id
	player_sect_id = character.sect_id
	player_character_changed.emit(player_char_id)

## Called by CharacterData or SimulationManager when the active player entity dies.
func trigger_player_death() -> void:
	# This will be picked up by the UIManager to pause the game and open the Succession/Game Over UI.
	player_died.emit(player_char_id)

## Evaluates if the player has authorization to issue commands to a given sect.
func can_manage_sect(sect_id: String) -> bool:
	return sect_id == player_sect_id

## Called by SectData when the player's Sect Master dies.
func trigger_player_succession(proposed_heir_id: String) -> void:
	# This will be picked up by the UIManager to open the SuccessionPopup.
	# The player will click "Play as Heir", which will then call GameManager.set_player_character(heir_id)
	# and SectData.execute_succession(heir_id).
	player_succession_required.emit(proposed_heir_id)
