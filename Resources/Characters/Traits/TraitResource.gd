# TraitResource.gd
# Defines a single character trait, its effects, and its appearance.
# Place at: res://Resources/Traits/TraitResource.gd
# HOW & WHERE TO USE:
# 1. Create new .tres files in `res://Resources/Traits/Personality/` or `res://Resources/Traits/Common/`.
# 2. In the Inspector for each .tres file, fill out its properties.
# 3. The TraitManager will automatically load these at runtime.

@tool
extends Resource
class_name TraitResource

# Enum to categorize traits for organization and logic.
enum TraitType { PERSONALITY, COMMON, SPECIAL, HIDDEN }

@export_category("Identification")
@export var trait_id: StringName ## Unique ID, e.g., "Righteous" or "BodyOfIron". MUST MATCH THE FILE NAME.
@export var display_name: String ## Name for UI, e.g., "Righteous".
@export_multiline var description: String ## Tooltip description.
@export var icon: Texture2D ## Icon to display in the UI.
@export var type: TraitType = TraitType.PERSONALITY

@export_category("Stat Modifications")
## Direct stat changes. Use stat names from CharacterResource.
## Example: {"strength": 10, "loyalty": -5, "qi_deviation_risk": -5}
@export var stat_effects: Dictionary = {}

@export_category("AI & Behavior")
## Modifiers for the Utility AI desire growth rates.
## Example: {"Training": 0.5, "Socialize": -0.2}
@export var desire_growth_modifiers: Dictionary = {}

## Flags that can be checked by other systems.
## Example: ["IS_INFAMOUS", "CANNOT_BE_EXPELLED"]
@export var flags: Array[StringName] = []

func _init():
	# Ensure the trait_id is automatically set from the resource path when a new trait is created.
	# This is a helpful trick for data management.
	if not Engine.is_editor_hint():
		return
	
	# Connect to the signal that's emitted when the resource's path changes.
	if not changed.is_connected(_on_resource_path_changed):
		changed.connect(_on_resource_path_changed)

# When the resource is saved, automatically update its trait_id based on its file name.
func _on_resource_path_changed():
	if resource_path.is_empty():
		return
	trait_id = resource_path.get_file().get_basename()
