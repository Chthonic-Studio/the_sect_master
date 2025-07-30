# CultivationManager.gd
# Autoload Singleton.
# Centralizes data and logic related to cultivation, such as realm progression and breakthrough chances.

extends Node

signal manager_ready
var is_ready: bool = false

# Directory where your CultivationRealmResource .tres files are stored.
const REALM_RESOURCE_DIR = "res://Resources/Cultivation/Realms/"

# --- Data ---
var _realms: Dictionary = {} # Stores all loaded realm resources, keyed by realm_id.
var _first_realm_id: StringName # The starting point of the cultivation journey.

func _ready() -> void:
	_load_all_realms()
	is_ready = true
	emit_signal("manager_ready")

# --- Public API ---

# REASON FOR CHANGE: Removed 'static'. Functions are now instance methods on the
# singleton, giving them direct access to '_realms' and '_first_realm_id'.
# This is the standard and correct way to implement singletons in Godot.

# Gets a realm resource by its ID.
func get_realm(realm_id: StringName) -> CultivationRealmResource:
	return _realms.get(realm_id, null)

# Gets the very first realm in the progression.
func get_first_realm() -> CultivationRealmResource:
	if not is_ready or _first_realm_id.is_empty():
		push_error("CultivationManager: Cannot get first realm. Manager not ready or first realm not identified.")
		return null
	return get_realm(_first_realm_id)

# Gets the next realm in the sequence for a given character.
func get_next_realm(character_res: CultivatorResource) -> CultivationRealmResource:
	if not character_res: return null
	var current_realm = get_realm(character_res.cultivation_realm)
	if current_realm and not current_realm.next_realm_id.is_empty():
		return get_realm(current_realm.next_realm_id)
	return null

# Calculates the final breakthrough chance for a character.
func calculate_breakthrough_chance(character_res: CultivatorResource) -> float:
	var next_realm = get_next_realm(character_res)
	if not next_realm:
		return 0.0 # No next realm to break through to.

	var base_chance = next_realm.base_breakthrough_chance
	var total_modifier = character_res.breakthrough_modifier / 100.0 # Convert from percentage
	
	return clamp(base_chance + total_modifier, 0.0, 1.0)

# --- Internal Logic ---

# Loads all realm resources from the specified directory.
func _load_all_realms() -> void:
	_realms.clear()
	var dir = DirAccess.open(REALM_RESOURCE_DIR)
	if not dir:
		push_error("CultivationManager: Failed to open directory: " + REALM_RESOURCE_DIR)
		return

	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".tres"):
			var realm_id = file_name.get_basename()
			var res: CultivationRealmResource = load(REALM_RESOURCE_DIR + file_name)
			
			if res and not realm_id.is_empty():
				res.realm_id = realm_id
				_realms[realm_id] = res
		file_name = dir.get_next()
	
	dir.list_dir_end()

	var found_first_realm = false
	for realm in _realms.values():
		if realm.realm_tier == 0:
			_first_realm_id = realm.realm_id
			found_first_realm = true
			break
			
	if not found_first_realm:
		push_error("CultivationManager: Could not find a realm with tier 0! Please set one.")
	else:
		print("CultivationManager: First realm identified as '%s'." % _first_realm_id)

	print("CultivationManager: Finished loading %d cultivation realms." % _realms.size())
