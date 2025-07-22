# ItemResource.gd
# Base resource for all inventory items (weapons, artifacts, consumables, etc)
# Extensible for item-specific subtypes (WeaponResource, ArtifactResource, etc).
# Place at res://scripts/data/item_resource.gd

extends Resource
class_name ItemResource

# === Identity & Classification ===
@export_category("Itentity & Clasification")
@export var item_id: String = "" # Unique string ID for this item definition (e.g. "spirit_sword_01")
@export var display_name: String = "" # Name shown in UI
@export var description: String = "" # Flavor/tooltip text

# Use an enum or string for item type (expand as needed)
enum ItemType { GENERIC, WEAPON, ARTIFACT, CONSUMABLE, MATERIAL, TREASURE }
@export var item_type: ItemType = ItemType.GENERIC

# Rarity/Quality for loot, shop, sorting
enum Rarity { COMMON, UNCOMMON, RARE, EPIC, LEGENDARY }
@export var rarity: Rarity = Rarity.COMMON

# === Visuals ===
@export_category("Visuals")
@export var icon: Texture2D # Drag and drop texture in Inspector (optional)

# === Stackability & Value ===
@export_category("Stackability & Value")
@export var stackable: bool = true # Can multiple be held in one slot?
@export_range(1, 9999, 1)
var max_stack: int = 99
@export var value: int = 1 # For selling/trading

# === Special Properties ===
@export_category("Special Properties")
@export var tags: Array[String] = [] # For filtering/search (e.g. ["sword", "fire", "unique"])
@export var effect_id: String = "" # Reference to effect/skill/potion logic (handled elsewhere)
@export var custom_data: Dictionary = {} # For modding/future extensibility

# === Utility Functions ===

func get_summary() -> String:
	return "[%s] %s | %s | Type: %s | Rarity: %s | Value: %d" % [
		item_id,
		display_name,
		description,
		ItemType.keys()[item_type],
		Rarity.keys()[rarity],
		value
	]

# --- How & Where to Use ---
# 1. Place at res://scripts/data/item_resource.gd
# 2. Create items in Inspector as .tres files. Assign all fields.
# 3. Reference these resources in inventory systems, loot tables, shops, etc.
# 4. Extend this for specific item types (e.g., WeaponResource) if you need extra fields.
# 5. Use effect_id, tags, and custom_data for advanced item effects and filtering.
