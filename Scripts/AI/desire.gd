class_name Desire extends Resource

## Base resource for evaluating Utility AI choices.
## Modders will extend this script to create new behaviors.

@export var id: String = "base_desire"

## Returns a score based on the character's stats, traits, and needs.
## A score <= 0 means the action is currently invalid or on cooldown.
func evaluate(_character: CharacterData) -> float:
	return 0.0

## Factory function to generate the state object if this desire wins the evaluation.
func generate_action(_character: CharacterData) -> ActionPlan:
	return null
