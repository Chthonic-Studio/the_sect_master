# Character.gd
# This version uses a direct physics query, which is the most reliable way to handle game world clicks.
# Attach to Node2D instances representing characters in the world.

extends Node2D
class_name Character

@export var character_resource: Resource # Reference to CharacterResource or CultivatorResource
@export var collider_area: Area2D

# --- HOW & WHERE TO USE ---
# 1. Attach this script to your Character scene's root node.
# 2. In the Inspector, drag the "Collider" (Area2D) node from the scene tree
#    into the "Collider Area" slot that now appears in the script variables.
# 3. In the Inspector for the "Collider" (Area2D) node, ensure "Input Pickable" is CHECKED.

func _ready() -> void:
	if not collider_area:
		push_warning("Character node '%s' is missing its Collider Area reference." % self.name)

# _input is called for all input. We use it to check for clicks.
func _input(event: InputEvent) -> void:
	# We only care about the moment the left mouse button is pressed.
	if not (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed()):
		return

	# If this click was already handled by the UI, do nothing.
	if get_viewport().is_input_handled():
		return

	# --- CORRECTED LOGIC ---
	# We directly call our helper function. It returns true only if the mouse
	# is over this specific character's collider and it's the topmost one.
	if _is_topmost_collider():
		print("SUCCESS: Click on '%s' confirmed by physics query. Opening menu." % self.name)
		UIManager.show_character_menu(character_resource)
		# Mark the event as handled so no other node processes it.
		get_viewport().set_input_as_handled()

# Helper function to check if this character is the one on top.
func _is_topmost_collider() -> bool:
	# This function is correct and needs no changes.
	var space = get_world_2d().direct_space_state
	var query = PhysicsPointQueryParameters2D.new()
	query.position = get_global_mouse_position()
	query.collide_with_areas = true
	# We only care about our own collision layer for this check.
	query.collision_mask = collider_area.collision_layer
	
	var results = space.intersect_point(query)
	
	# If the query hit something, check if the first result (the topmost) is our own collider.
	if not results.is_empty():
		return results[0].collider == collider_area
	
	return false

# Utility: Returns the display name for this character (uses resource)
func get_display_name() -> String:
	if character_resource == null:
		return "Unknown"
	var first = character_resource.first_name if "first_name" in character_resource else ""
	var last = character_resource.last_name if "last_name" in character_resource else ""
	return "%s %s" % [first, last]
