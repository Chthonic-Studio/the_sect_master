# TraitManager.gd
# Autoload Singleton. Loads and manages all TraitResource files.
# Provides a central, efficient way to access trait data.

extends Node

signal manager_ready
var is_ready: bool = false

# Dictionary to hold all loaded traits, keyed by their trait_id.
var traits: Dictionary = {}

# Directories where your trait .tres files are stored.
const TRAIT_DIRECTORIES := [
	"res://Resources/Traits/Personality/",
	"res://Resources/Traits/Common/"
]

func _ready() -> void:
	_load_all_traits()
	is_ready = true
	emit_signal("manager_ready")

# --- Public API ---

# Retrieves a trait resource by its ID.
# This static function can be called from anywhere using TraitManager.get_trait("id").
func get_trait(trait_id: StringName) -> TraitResource:
	return traits.get(trait_id, null)

func get_traits_by_type(p_trait_type: TraitResource.TraitType) -> Array[TraitResource]:
	var filtered_traits: Array[TraitResource] = []
	for i in traits.values():
		if i.type == p_trait_type:
			filtered_traits.append(i)
	
	# REASON FOR CHANGE: This print will tell us exactly how many traits this function found and is about to return.
	print("TraitManager DEBUG: get_traits_by_type is returning %d traits of type %s." % [filtered_traits.size(), TraitResource.TraitType.keys()[p_trait_type]])
	return filtered_traits

# --- Internal Logic ---

# Scans the trait directories and loads all .tres files.
func _load_all_traits() -> void:
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
					var trait_id = file_name.get_basename()
					
					if trait_res and not trait_id.is_empty():
						trait_res.trait_id = trait_id # Assign ID back to the resource
						
						if traits.has(trait_id):
							push_warning("Duplicate trait_id '%s' found at '%s'. Overwriting." % [trait_id, resource_path])
						
						traits[trait_id] = trait_res
				file_name = dir.get_next()
			dir.list_dir_end()
		else:
			push_warning("Could not open trait directory: %s" % dir_path)
	
	# REASON FOR CHANGE: This print will confirm that the loading process has completed and show the total number of traits loaded into the dictionary.
	print("TraitManager DEBUG: Finished loading. Total traits in dictionary: %d" % traits.size())
