# Place in: res://Scripts/AI/action_plan.gd
class_name ActionPlan extends RefCounted 

## Base class for all character actions in the game.
## Exists as a lightweight data object in memory.

var id: String = "base_action"
var duration_remaining: int = 1

func _init(action_id: String, duration: int) -> void:
	id = action_id
	duration_remaining = duration

## Called every in-game day the character is performing this action.
## Override this in inherited scripts for daily chances (e.g., random events or stat gains).
func process_tick(_character: CharacterData) -> void:
	pass

## Called on the final day when duration_remaining hits 0.
## Override this to apply major rewards, modify needs, or apply cooldowns.
func on_complete(_character: CharacterData) -> void:
	pass
