# TraitManager.gd
# Autoload Singleton. Loads and manages all TraitResource files.
# Provides a central, efficient way to access trait data.

extends Node

signal trait_manager_ready

# Dictionary to hold all loaded traits, keyed by their trait_id.
var traits: Dictionary = {}

# Directories where your trait .tres files are stored.
const TRAIT_DIRECTORIES := [
	"res://Resources/Traits/Personality/",
	"res://Resources/Traits/Common/"
]

func _ready() -> void:
	_load_all_traits()
	emit_signal("ready") # Announce that the manager is ready.
# --- Public API ---

# Retrieves a trait resource by its ID.
static func get_trait(trait_id: StringName) -> TraitResource:
	if not Engine.has_singleton("TraitManager"): return null
	var manager = Engine.get_singleton("TraitManager")
	return manager.traits.get(trait_id, null)

# --- Internal Logic ---

# Scans the trait directories and loads all .tres files.
func _load_all_traits() -> void:
	# REASON FOR CHANGE:
	# This function is updated for the same reason as the CultivationManager.
	# It now manually extracts the trait_id from the filename to ensure it's always
	# correctly registered, as load() does not call the resource's _init() method.
	traits.clear()
	for dir_path in TRAIT_DIRECTORIES:
		var dir = DirAccess.open(dir_path)
		if dir:
			dir.list_dir_begin()
			var file_name = dir.get_next()
			while file_name != "":
				if not dir.current_is_dir() and file_name.ends_with(".tres"):
					var resource_path = dir_path.path_join(file_name)
					var trait_res: TraitResource = load(resource_path)
					# --- FIX: Manually get the ID from the filename ---
					var trait_id = file_name.get_basename()
					
					if trait_res and not trait_id.is_empty():
						trait_res.trait_id = trait_id # Assign ID back to the resource
						
						if traits.has(trait_id):
							push_warning("Duplicate trait_id '%s' found at '%s'. Overwriting." % [trait_id, resource_path])
						
						traits[trait_id] = trait_res
					# --- END FIX ---
				file_name = dir.get_next()
			dir.list_dir_end()
		else:
			push_warning("Could not open trait directory: %s" % dir_path)
	
	print("TraitManager: Loaded %d traits." % traits.size())
