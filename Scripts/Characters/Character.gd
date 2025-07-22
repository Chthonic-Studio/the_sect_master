# Character.gd
# Attach to Node2D instances representing characters in the world.
# Holds reference to base CharacterResource or CultivatorResource.
# Extend with sprite, AI, etc. as needed.

extends Node2D
class_name Character

@export var character_resource: Resource # Reference to CharacterResource or CultivatorResource

func _ready() -> void:
	# Future: Display name, sprite, or other data from resource.
	pass

# Utility: Returns the display name for this character (uses resource)
func get_display_name() -> String:
	if character_resource == null:
		return "Unknown"
	var first = character_resource.first_name if character_resource.has_property("first_name") else ""
	var last = character_resource.last_name if character_resource.has_property("last_name") else ""
	return "%s %s" % [first, last]
