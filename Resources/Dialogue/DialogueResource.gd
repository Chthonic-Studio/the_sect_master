# DialogueResource.gd
# The main container for a complete conversation or dialogue tree.
# Place in: res://Resources/Dialogue/
@tool
extends Resource
class_name DialogueResource

@export var dialogue_id: String = "" # A unique ID for this conversation.
@export var start_node_key: String = "start" # The key of the first node to display.

# The core of the dialogue tree. A dictionary mapping a string key to a dialogue node.
# This allows for non-linear conversations (e.g., jumping from "greeting" to "goodbye").
@export var nodes: Dictionary = {
	"start": DialogueNodeResource.new() 
}
