extends PlayerAction

const GIFT_AMOUNT = 50

func _init() -> void:
	id = "action_gift_wealth"
	display_name = "Gift Wealth (50g)"
	tooltip = "Give them 50 gold from your personal stash to greatly improve their opinion."

func can_execute(initiator: CharacterData, _target: CharacterData) -> bool:
	# Hard Gate: Only shows up in the menu if you have the money
	return initiator.wealth >= GIFT_AMOUNT

func execute(initiator: CharacterData, target: CharacterData) -> void:
	initiator.wealth -= GIFT_AMOUNT
	target.wealth += GIFT_AMOUNT
	
	# Massive positive boost
	target.add_directed_opinion(initiator.char_id, "gifted_wealth", 50, 360)
	
	initiator.add_log("I gifted 50 gold to " + target.get_full_name() + ".")
	target.add_log(initiator.get_full_name() + " generously gifted me wealth.")
