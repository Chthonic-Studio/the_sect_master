class_name PlayerAction extends Resource

## Base Resource for actions the Player can take against an NPC.

@export var id: String = "base_action"
@export var display_name: String = "Action"
@export var tooltip: String = ""

## Returns true if this action should appear in the context menu for this target.
func can_execute(initiator: CharacterData, target: CharacterData) -> bool:
	return false

## The logic that runs when the player clicks the button.
func execute(initiator: CharacterData, target: CharacterData) -> void:
	pass
