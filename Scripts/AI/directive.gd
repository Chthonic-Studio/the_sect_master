class_name Directive extends RefCounted

## A high-level override state that bypasses standard Utility AI.
## Used for assignments, missions, or forced states (e.g., Imprisonment).

var id: String = "base_directive"
var duration_remaining: int = 1
var decay_modifiers: Dictionary = {}

func _init(duration: int = 1, modifiers: Dictionary = {}) -> void:
	duration_remaining = duration
	decay_modifiers = modifiers

func process_tick(_character: CharacterData) -> void:
	# Overridden by specific directives
	pass

func is_complete() -> bool:
	return duration_remaining <= 0

func on_complete(_character: CharacterData) -> void:
	# Overridden by specific directives to grant rewards or consequences
	pass
