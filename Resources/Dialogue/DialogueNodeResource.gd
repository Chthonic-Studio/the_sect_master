# DialogueNodeResource.gd
# Represents one "beat" or piece of dialogue from an NPC.
# Place in: res://Resources/Dialogue/
@tool
extends Resource
class_name DialogueNodeResource

@export_multiline var text: String = "" # The dialogue text spoken by the NPC.
@export var options: Array[DialogueOptionResource] # The list of player choices.

# --- Future-proofing for dynamic dialogue ---
@export_group("Speaker Details")
@export var speaker_animation: String # e.g., "happy", "angry"
@export var speaker_sound: AudioStream # Sound to play with the dialogue
