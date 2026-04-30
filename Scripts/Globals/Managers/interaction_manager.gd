extends Node

## Central registry for all right-click Player Actions.

var registered_actions: Array[PlayerAction] = []

func _ready() -> void:
	# In a full build, we would use DataManager's script scanner to load these dynamically
	# For now, we will hardcode the load to get the MVP running safely.
	_load_core_actions()

func _load_core_actions() -> void:
	registered_actions.append(load("res://Scripts/Interactions/Actions/action_insult.gd").new())
	registered_actions.append(load("res://Scripts/Interactions/Actions/action_sway.gd").new())
	registered_actions.append(load("res://Scripts/Interactions/Actions/action_gift_wealth.gd").new())
	registered_actions.append(load("res://Scripts/Interactions/Actions/action_challenge_duel.gd").new())
	registered_actions.append(load("res://Scripts/Interactions/Actions/action_recruit.gd").new())

## Retrieves all valid actions the player can take against the target right now.
func get_valid_actions(initiator: CharacterData, target: CharacterData) -> Array[PlayerAction]:
	var valid: Array[PlayerAction] = []
	if not initiator or not target or initiator == target:
		return valid
		
	for action in registered_actions:
		if action.can_execute(initiator, target):
			valid.append(action)
			
	return valid
