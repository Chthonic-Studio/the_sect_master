extends PlayerAction

func _init() -> void:
	id = "action_insult"
	display_name = "Insult"
	tooltip = "Publicly demean this character. Lowers their opinion of you."

func can_execute(_initiator: CharacterData, _target: CharacterData) -> bool:
	return true # Anyone can be insulted

func execute(initiator: CharacterData, target: CharacterData) -> void:
	# Add a decaying negative opinion (Lasts 1 in-game year)
	target.add_directed_opinion(initiator.char_id, "insulted", -30, 360)
	
	# Update logs
	initiator.add_log("I insulted " + target.get_full_name() + ".")
	target.add_log("I was insulted by " + initiator.get_full_name() + ".")
	
	# Public actions hit the World Log
	WorldLogManager.add_log("Social", initiator.get_full_name() + " publicly insulted " + target.get_full_name() + ".")
