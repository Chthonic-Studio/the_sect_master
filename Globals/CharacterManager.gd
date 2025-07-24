# CharacterManager.gd
# Singleton for managing CharacterResource instances by unique ID.
# Provides ID resolution, registration, and modular batch operations.
# Place in res://scripts/managers/ and autoload as "CharacterManager".

extends Node

# === Internal: Next unique character ID
var _next_id: int = 10000001

# === Internal: ID -> CharacterResource mapping
var _characters: Dictionary = {} # int: CharacterResource

const Character = preload("res://Scenes/Character.tscn")
const CharacterResource = preload("res://Resources/Characters/CharacterResource.gd")
const CultivatorResource = preload("res://Resources/Characters/CultivatorResource.gd")
const NameGenerator = preload("res://Scripts/Characters/NameGenerator.gd")

# Holds references to character nodes and resources
var all_character_nodes: Array = []
var all_character_resources: Array = []

# Generate a random stat (e.g., 10-30 for base stats)
func _roll_stat(min_val: int = 10, max_val: int = 30) -> int:
	return randi_range(min_val, max_val)

# Assign a few placeholder traits (extend this for real trait logic)
func _assign_placeholder_traits() -> Array[String]:
	var trait_pool = ["brave", "loyal", "curious", "ambitious", "honest", "cunning"]
	return [trait_pool[randi() % trait_pool.size()]]

# Creates a new mortal or cultivator character node, fully initialized
# type: "mortal" or "cultivator"
func create_character(type: String = "mortal", position: Vector2 = Vector2.ZERO) -> Node2D:
	var resource
	if type == "cultivator":
		resource = CultivatorResource.new()
	else:
		resource = CharacterResource.new()
	# Name and gender
	var gender = CharacterResource.Gender.values()[randi() % 2]
	var culture = CharacterResource.CultureGroup.values()[randi() % 2]
	var name_data = NameGenerator.generate_name(culture, gender)
	resource.first_name = name_data["first_name"]
	resource.last_name = name_data["last_name"]
	resource.gender = gender
	resource.culture = culture
	# --- Name display logic ---
	if culture == CharacterResource.CultureGroup.TRADITIONAL:
		resource.name_display = "%s %s" % [resource.last_name, resource.first_name]
	else:
		resource.name_display = "%s %s" % [resource.first_name, resource.last_name]
	# --- Random Age ---
	resource.age = randi_range(15, 30)
	# --- Random Spiritual Root ---
	resource.spiritual_root = _random_spiritual_root(type)
	# --- Stats ---
	resource.max_hp = _roll_stat()
	resource.max_qi = _roll_stat()
	resource.current_hp = resource.max_hp
	resource.current_qi = resource.max_qi
	resource.strength = _roll_stat()
	resource.intelligence = _roll_stat()
	resource.agility = _roll_stat()
	resource.perception = _roll_stat()
	resource.constitution = _roll_stat()
	resource.potential = _roll_stat(40, 80)
	# Traits
	resource.traits = _assign_placeholder_traits()
	# --- Randomize personality stats ---
	resource.randomize_personality_stats()
	
	# --- DELEGATE TO DESIRE MANAGER ---
	# Tell the new manager to set up the desires for this character.
	DesireManager.initialize_desires_for_character(resource)
	
	# Clamp stats (safe)
	if resource.has_method("clamp_stats"):
		resource.clamp_stats()
	if resource.has_method("clamp_cultivation_stats"):
		resource.clamp_cultivation_stats()
		
	var char_node = Character.instantiate()
	char_node.character_resource = resource
	char_node.position = position
	all_character_nodes.append(char_node)
	all_character_resources.append(resource)
	register_character(resource)
	return char_node

# Helper for spiritual root probabilities
func _random_spiritual_root(type: String) -> int:
	var roots = [
		CharacterResource.SpiritualRootType.NONE,
		CharacterResource.SpiritualRootType.COMMON,
		CharacterResource.SpiritualRootType.SUPERIOR,
		CharacterResource.SpiritualRootType.HEAVENLY,
		CharacterResource.SpiritualRootType.MUTATED,
		CharacterResource.SpiritualRootType.DEMONIC,
		CharacterResource.SpiritualRootType.GHOSTLY
	]
	var probs = []
	if type == "cultivator":
		# Remove NONE, normalize others so sum is 100
		# Original: [0, 20, 10, 3, 3, 3, 1] (skip 0)
		probs = [20, 10, 3, 3, 3, 1]
		var total = 20 + 10 + 3 + 3 + 3 + 1
		var norm_probs = []
		for p in probs:
			norm_probs.append(p * 100 / total)
		var r = randf() * 100
		var acc = 0
		for i in range(len(norm_probs)):
			acc += norm_probs[i]
			if r < acc:
				return roots[i + 1] # +1 to skip NONE
		return roots[1] # default to COMMON
	else:
		# Mortals: [60, 20, 10, 3, 3, 3, 1]
		probs = [60, 20, 10, 3, 3, 3, 1]
		var r = randf() * 100
		var acc = 0
		for i in range(len(probs)):
			acc += probs[i]
			if r < acc:
				return roots[i]
		return roots[0] # default to NONE

# Utility: Get all characters, optionally filter by type
func get_characters(type: String = "") -> Array:
	var result := []
	if type == "cultivator":
		for c in all_character_nodes:
			if c.character_resource is CultivatorResource:
				result.append(c)
	elif type == "mortal":
		for c in all_character_nodes:
			if c.character_resource is CharacterResource and not (c.character_resource is CultivatorResource):
				result.append(c)
	else:
		result = all_character_nodes.duplicate()
	return result

# === Register a CharacterResource instance
# Call after creating/loading a CharacterResource to track it by ID.
func register_character(character: CharacterResource) -> void:
	if not character: return
	_characters[character.id] = character

# === Unregister a CharacterResource (e.g., on deletion)
func unregister_character(character_id: int) -> void:
	_characters.erase(character_id)

# === Create and register a new CharacterResource with stat overrides
func create_character_resource(stat_overrides := {}) -> CharacterResource:
	var char = CharacterResource.new()
	char.id = _next_id
	_next_id += 1
	for key in stat_overrides:
		if char.has_property(key):
			char.set(key, stat_overrides[key])
	char.clamp_stats()
	register_character(char)
	return char

# === Resolve a character ID to its CharacterResource, or null if not found
func get_character_by_id(character_id: int) -> CharacterResource:
	return _characters.get(character_id, null)

# === Batch member management function for modular operations
# Supported actions: "add", "remove", "get", "exists"
# Usage:
#	- op: String ("add", "remove", "get", "exists")
#	- ids: Array[int] (IDs to process)
# Returns array of results (per ID) for "get"/"exists", or the updated manager for "add"/"remove"
func batch_manage_members(op: String, ids: Array) -> Array:
	var results := []
	match op:
		"add":
			for id in ids:
				# Implement logic to add (register) a CharacterResource by ID if not present
				if not _characters.has(id):
					# If you have a loading mechanism, load/create CharacterResource here and register
					# For now, skip as we can't create from ID alone
					results.append(false)
				else:
					results.append(true)
		"remove":
			for id in ids:
				results.append(_characters.erase(id))
		"get":
			for id in ids:
				results.append(_characters.get(id, null))
		"exists":
			for id in ids:
				results.append(_characters.has(id))
		_:
			push_warning("Unsupported batch op: %s" % op)
	return results

# === Set next available ID (for loading from save)
func set_next_id(new_id: int) -> void:
	_next_id = new_id

# === On load: repopulate the manager with all CharacterResources in your game
# Call this after loading from save, passing in all character resources.
func repopulate_characters(characters: Array) -> void:
	_characters.clear()
	for char in characters:
		if char and char.has_method("get"): # Defensive check
			_characters[char.id] = char
