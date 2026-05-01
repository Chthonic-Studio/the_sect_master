extends PlayerAction

const COMBAT_RESULT_POPUP = preload("res://Scenes/UI/combat_result_popup.tscn")

func _init() -> void:
	id = "action_challenge_duel"
	display_name = "Challenge to Duel"
	tooltip = "Issue a formal duel challenge. Both participants will fight based on their martial stats."

func can_execute(initiator: CharacterData, target: CharacterData) -> bool:
	# Both must be martial artists
	if not initiator.is_martial_artist or not target.is_martial_artist:
		return false
	# Cannot duel yourself or a sect member from the same sect (use sparring for that)
	if initiator.sect_id != "" and initiator.sect_id == target.sect_id:
		return false
	return true

func execute(initiator: CharacterData, target: CharacterData) -> void:
	# Fire the combat manager and spawn the result popup
	var result: Dictionary = CombatManager.resolve_duel(initiator.char_id, target.char_id)
	if result.is_empty():
		return

	# Spawn the combat result popup
	UIManager.spawn_popup(COMBAT_RESULT_POPUP, result)
