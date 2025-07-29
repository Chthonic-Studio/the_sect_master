# CultivationRealmResource.gd
# Defines a single cultivation realm, its properties, and its place in the progression.
# Place at: res://Resources/Cultivation/CultivationRealmResource.gd
# HOW & WHERE TO USE:
# 1. Create new .tres files for each realm in `res://Resources/Cultivation/Realms/`.
# 2. In the Inspector, fill out the properties for each realm.
# 3. Link realms together using the "Next Realm ID" property to create the progression chain.

@tool
extends Resource
class_name CultivationRealmResource

@export_category("Identification")
@export var realm_id: StringName # Unique ID, e.g., "GoldenCore". Should match the filename.
@export var display_name: String # Name for UI, e.g., "Golden Core".
@export var icon: Texture2D # UI Icon for this realm.

@export_category("Progression & Stats")
# The ID of the next realm in the sequence. Leave empty for the final realm.
@export var next_realm_id: StringName 
# --- NEW ---
# The numerical tier of this realm for calculations (0 for the first, 1 for the second, etc.).
@export var realm_tier: int = 0
@export_range(0.0, 1.0, 0.01) var base_breakthrough_chance: float = 0.8 # Base success chance (e.g., 0.8 = 80%).
@export var lifespan_bonus: int = 50 # Additional years of life this realm grants.

# Stat bonuses granted upon entering this realm. These are CUMULATIVE.
# Example: {"max_qi": 100, "strength": 5}
@export var stat_bonuses: Dictionary = {}

func _init():
	# Automatically set the realm_id from the resource path when a new realm is created.
	if not Engine.is_editor_hint():
		return
	if not changed.is_connected(_on_resource_path_changed):
		changed.connect(_on_resource_path_changed)

# When the resource is saved, automatically update its realm_id based on its file name.
func _on_resource_path_changed():
	if resource_path.is_empty():
		return
	realm_id = resource_path.get_file().get_basename()
