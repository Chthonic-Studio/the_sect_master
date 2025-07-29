# DialogueOptionResource.gd
# Represents a single choice a player can make in a conversation.
# Place in: res://Resources/Dialogue/
@tool
extends Resource
class_name DialogueOptionResource

@export var text: String = "" # The text displayed for this option.
@export var destination_node_key: String = "" # The key of the DialogueNodeResource to go to if this option is chosen.
@export var closes_dialogue: bool = false # If true, selecting this option ends the conversation.

# --- Future-proofing for dynamic dialogue ---
@export_group("Conditions")
@export var required_traits: Array[String] # e.g., ["Brave", "Cunning"]
@export var required_relationship_level: int = -101 # e.g., 50 (must be > 50)
# Add more conditions as needed (items, stats, etc.)

# --- Future-proofing for effects ---
@export_group("Effects")
@export var relationship_change: int = 0 # How much this option changes the relationship with the NPC.
# Add more effects as needed (give item, start quest, etc.)
