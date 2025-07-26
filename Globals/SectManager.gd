extends Node

const SectResource = preload("res://Resources/SectResource.gd")
const SectNameGenerator = preload("res://Scripts/Sects/SectNameGenerator.gd") # NEW

var _sects: Dictionary = {} # Maps sect_id (int) to SectResource
var _next_sect_id: int = 1

# --- API ---

# Creates a new sect with specific details, registers it, and returns its ID.
func create_sect(name: String, culture: int, initial_resources: Dictionary = {}) -> int:
	var sect_res := SectResource.new()
	var sect_id = _get_new_sect_id()
	
	sect_res.sect_name = name
	sect_res.culture = culture
	sect_res.resources = initial_resources
	# Set some default resources if none were provided
	if not "spirit_qi" in sect_res.resources: sect_res.resources["spirit_qi"] = 500
	if not "materials" in sect_res.resources: sect_res.resources["materials"] = 500
	if not "food" in sect_res.resources: sect_res.resources["food"] = 100
	
	_sects[sect_id] = sect_res
	print("Created sect '%s' with ID: %d" % [name, sect_id])
	return sect_id

# Creates a sect with a random name and culture.
func create_random_sect() -> int:
	var culture = SectResource.CultureGroup.values()[randi() % SectResource.CultureGroup.values().size()]
	var name = SectNameGenerator.generate_sect_name(culture)
	# For now, random sects start with default resources.
	return create_sect(name, culture, {})

# Retrieves a sect's resource by its ID.
func get_sect_by_id(sect_id: int) -> SectResource:
	return _sects.get(sect_id, null)

# Adds a character ID to a specific sect.
func add_member_to_sect(sect_id: int, character_id: int) -> void:
	var sect = get_sect_by_id(sect_id)
	if sect:
		sect.add_member_id(character_id)
	else:
		push_warning("SectManager: Tried to add member to non-existent sect ID: %d" % sect_id)

# --- Internal ---

# Generates a new unique ID for a sect.
func _get_new_sect_id() -> int:
	var id = _next_sect_id
	_next_sect_id += 1
	return id

# --- How & Where to Use ---
# 1. Add as an Autoload singleton named "SectManager".
# 2. Call `SectManager.create_random_sect()` to create a new AI sect.
# 3. Use `SectManager.get_sect_by_id(id)` to retrieve sect data.
