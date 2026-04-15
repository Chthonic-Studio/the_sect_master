extends PlayerAction

func _init() -> void:
	id = "action_sway"
	display_name = "Sway"
	tooltip = "Attempt to flatter them. Success is guaranteed for the prototype."

func can_execute(_initiator: CharacterData, _target: CharacterData) -> bool:
	return true

func execute(initiator: CharacterData, target: CharacterData) -> void:
	# Add a decaying positive opinion (Lasts 1 in-game year)
	# TODO: Add an RNG roll based on initiator's Charisma vs target's Intelligence
	target.add_directed_opinion(initiator.char_id, "swayed", 20, 360)
	
	initiator.add_log("I successfully swayed " + target.get_full_name() + ".")
