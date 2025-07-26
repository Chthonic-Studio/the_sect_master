# SectResource.gd
# Resource for storing sect data: name, prestige, extensible resources, member list (by ID), and future placeholders.
# Compatible with serialization and future expansion.

extends Resource
class_name SectResource

# --- NEW: Enum for cultural naming conventions ---
enum CultureGroup { WESTERN, TRADITIONAL }

# === Basic Info ===
@export_category("Basic Info")
@export var sect_name: String = ""
@export_range(0, 1000, 1)
var prestige: int = 0
@export var description: String = ""
@export var culture: CultureGroup = CultureGroup.TRADITIONAL # NEW: Sect's cultural origin

# === Extensible Resources ===
# Dictionary: resource_name (String) -> amount (int)
@export var resources: Dictionary = {
	"spirit_qi": 0,
	"materials": 0,
	"food": 0
}
# Add/remove resource types by modifying this dictionary as needed.

# === Member List (IDs) ===
# Store CharacterResource IDs (int) instead of direct references for safe serialization.
@export var member_ids: Array = [] # Array[int]

# === Placeholders for future systems ===
@export var belief_id: int = 0 # Placeholder for beliefs system
@export var sect_type: String = "" # Placeholder for sect type

# === Utility Functions ===

# Add a member by ID (if not already present)
func add_member_id(member_id: int) -> void:
	if not member_ids.has(member_id):
		member_ids.append(member_id)

# Remove a member by ID
func remove_member_id(member_id: int) -> void:
	member_ids.erase(member_id)

# Get member count
func get_member_count() -> int:
	return member_ids.size()

# Clamp prestige and all resource values to non-negative, and to valid range.
func clamp_sect_stats() -> void:
	prestige = clamp(prestige, 0, 1000)
	for key in resources.keys():
		resources[key] = max(0, int(resources[key]))

# Get summary string for UI/debug
func get_summary() -> String:
	return "%s | Prestige: %d | Members: %d | Resources: %s" % [
		sect_name, prestige, get_member_count(), str(resources)
	]

# --- How & Where to Use ---
# Place in res://scripts/data/sect_resource.gd
# Use for all sect data (player, AI, etc.)
# Create via script or in the Godot inspector, but manage member_ids via your CharacterManager.
# Example:
#	var sect = SectResource.new()
#	sect.sect_name = "Azure Cloud Sect"
#	sect.add_member_id(10000001)
#	sect.resources["spirit_qi"] += 50
