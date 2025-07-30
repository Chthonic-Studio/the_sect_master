extends Node

const SectResource = preload("res://Resources/SectResource.gd")
const SectNameGenerator = preload("res://Scripts/Sects/SectNameGenerator.gd")
const CharacterResource = preload("res://Resources/Characters/CharacterResource.gd")
const CultivatorResource = preload("res://Resources/Characters/CultivatorResource.gd")

var _sects: Dictionary = {} # Maps sect_id (int) to SectResource
var _next_sect_id: int = 1

# Signal emitted when any sect's resources change.
signal sect_resources_updated(sect_id, resource_name, new_value)

# --- Initialization ---
func _ready() -> void:
	# Connect to TimeManager to run economic updates.
	# We use period_passed for consumption as requested (monthly).
	TimeManager.connect("period_passed", Callable(self, "_on_period_passed"))
	# Note: Daily production from buildings will be handled later once the building system is in place.

# --- API ---

# Creates a new sect with a random name and culture.
func create_random_sect() -> int:
	var culture = SectResource.CultureGroup.values()[randi() % SectResource.CultureGroup.values().size()]
	var name = SectNameGenerator.generate_sect_name(culture)
	return create_sect(name, culture, {})

# Creates a new sect with specific details, registers it, and returns its ID.
func create_sect(name: String, culture: int, initial_resources: Dictionary = {}) -> int:
	var sect_res := SectResource.new()
	var sect_id = _get_new_sect_id()
	
	sect_res.sect_name = name
	sect_res.culture = culture
	
	# Use provided resources or the defaults from SectResource.
	if not initial_resources.is_empty():
		sect_res.resources = initial_resources
	
	_sects[sect_id] = sect_res
	print("Created sect '%s' with ID: %d" % [name, sect_id])
	return sect_id

# Retrieves a sect's resource by its ID.
func get_sect_by_id(sect_id: int) -> SectResource:
	return _sects.get(sect_id, null)

# NEW: Utility to find which sect a character belongs to.
func get_sect_by_character_id(character_id: int) -> SectResource:
	for sect in _sects.values():
		if sect.member_ids.has(character_id):
			return sect
	return null

# Adds a character ID to a specific sect.
func add_member_to_sect(sect_id: int, character_id: int) -> void:
	var sect = get_sect_by_id(sect_id)
	if sect:
		sect.add_member_id(character_id)
	else:
		push_warning("SectManager: Tried to add member to non-existent sect ID: %d" % sect_id)

# --- Resource Management ---

# Safely adds an amount to a resource and emits a signal.
func add_resource(sect_id: int, resource_name: String, amount: int) -> void:
	var sect = get_sect_by_id(sect_id)
	if sect and sect.resources.has(resource_name):
		sect.resources[resource_name] += amount
		emit_signal("sect_resources_updated", sect_id, resource_name, sect.resources[resource_name])

# Safely removes an amount from a resource and emits a signal.
func remove_resource(sect_id: int, resource_name: String, amount: int) -> void:
	add_resource(sect_id, resource_name, -amount) # Removing is just adding a negative amount.

# --- Signal Handlers ---

# Called once per in-game month (a "period").
func _on_period_passed(_year: int, _season: int, _period: int) -> void:
	# Iterate through all sects and calculate consumption.
	for sect_id in _sects.keys():
		_calculate_and_apply_consumption(sect_id)

# --- Internal Logic ---

# Calculates total monthly consumption for a sect and applies it.
func _calculate_and_apply_consumption(sect_id: int) -> void:
	var sect = get_sect_by_id(sect_id)
	if not sect: return

	var total_food_consumption = 0
	var total_gold_consumption = 0
	
	for member_id in sect.member_ids:
		var char_res = CharManager.get_character_by_id(member_id)
		if not char_res: continue
		
		var food_cost = 1
		var gold_cost = 1
		
		# For cultivators, increase cost based on realm.
		if char_res is CultivatorResource:
			# REASON FOR CHANGE: No code change needed, but this now correctly calls
			# the instance method on the CultivationManager singleton.
			var realm_res: CultivationRealmResource = CultivationManager.get_realm(char_res.cultivation_realm)
			
			if realm_res:
				var realm_level = realm_res.realm_tier
				var multiplier = pow(2, realm_level)
				food_cost *= multiplier
				gold_cost *= multiplier
		
		total_food_consumption += food_cost
		total_gold_consumption += gold_cost

	# Apply the total consumption.
	remove_resource(sect_id, "food", total_food_consumption)
	remove_resource(sect_id, "gold", total_gold_consumption)
	
	# print("Sect %d consumed %d food and %d gold." % [sect_id, total_food_consumption, total_gold_consumption])

# Generates a new unique ID for a sect.
func _get_new_sect_id() -> int:
	var id = _next_sect_id
	_next_sect_id += 1
	return id
