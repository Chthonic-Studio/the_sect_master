class_name ActionPlan extends RefCounted 

var id: String = "base_action"
var duration_remaining: int = 1

func _init(duration: int = 1) -> void:
	duration_remaining = duration

func process_tick(_character: CharacterData) -> void:
	pass

func on_complete(_character: CharacterData) -> void:
	pass
