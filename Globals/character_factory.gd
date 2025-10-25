extends Node

@export var name_pool: NamePoolDef = preload("res://Resources/Characters/name_pool.tres")
@export var root_spawn_table: RootSpawnTableDef = preload("res://Resources/Characters/root_table_def.tres")
@export var trait_pool: Resource = preload("res://Resources/Characters/trait_pool.tres")
@export var character_scene: PackedScene = preload("res://Scenes/character.tscn")

# Local RNG used for all randomization
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _rng_inited: bool = false

func _ready() -> void:
	_ensure_rng()

# Ensure RNG is seeded once per runtime
func _ensure_rng() -> void:
	if not _rng_inited:
		_rng.randomize()
		_rng_inited = true

func create_character(char_id: int, params: Dictionary = {}) -> Node:
	_ensure_rng()

	# Instantiate the character scene and guard
	var char_node: Node = character_scene.instantiate()
	if not char_node:
		push_error("CharacterFactory.create_character: failed to instantiate character scene.")
		return null

	# Get the Data node (CharacterData) and guard
	var data: CharacterData = char_node.get_node_or_null("Data") as CharacterData
	if not data:
		push_error("CharacterFactory.create_character: instantiated character missing 'Data' node.")
		char_node.queue_free()
		return null

	# Assign system id
	data.char_id = char_id

	# --- Gender: allow override, otherwise randomize ---
	var gender: int = int(params["gender"]) if params.has("gender") else _random_gender()
	data.char_gender = gender

	# --- Names: optional overrides, otherwise pick from name_pool ---
	var first_name: String = ""
	var last_name: String = ""
	if params.has("first_name"):
		first_name = String(params["first_name"])
	else:
		if name_pool and name_pool.has_method("get_random_first_name"):
			first_name = name_pool.get_random_first_name(gender)
		else:
			first_name = "Nameless"
	if params.has("last_name"):
		last_name = String(params["last_name"])
	else:
		if name_pool and name_pool.has_method("get_random_last_name"):
			last_name = name_pool.get_random_last_name()
		else:
			last_name = "Surname"
	data.char_first_name = first_name
	data.char_last_name = last_name
	data.char_fullname = "%s %s" % [last_name, first_name]

	# --- Spiritual root: allow override or choose from spawn table ---
	var root: SpiritualRoot = params["spiritual_root"] if params.has("spiritual_root") else root_spawn_table.get_random_root()
	data.spiritual_root = root

	# --- Potential (1..100) with optional override ---
	data.potential = int(params["potential"]) if params.has("potential") else _rng.randi_range(1, 100)

	# --- Starting traits: override or pick 3 from trait_pool (if available) ---
	var chosen_traits: Array = []
	if params.has("traits"):
		chosen_traits = params["traits"]
	else:
		if trait_pool and trait_pool.has_method("get_random_traits"):
			chosen_traits = trait_pool.get_random_traits(3)
		else:
			chosen_traits = []
	# Assign chosen_traits safely (CharacterData.starting_traits is an Array)
	data.starting_traits = chosen_traits

	# --- Primary combat attributes (1..20) ---
	data.strength = int(params["strength"]) if params.has("strength") else _rng.randi_range(1, 20)
	data.constitution = int(params["constitution"]) if params.has("constitution") else _rng.randi_range(1, 20)
	data.agility = int(params["agility"]) if params.has("agility") else _rng.randi_range(1, 20)
	data.intelligence = int(params["intelligence"]) if params.has("intelligence") else _rng.randi_range(1, 20)
	data.wisdom = int(params["wisdom"]) if params.has("wisdom") else _rng.randi_range(1, 20)
	data.charisma = int(params["charisma"]) if params.has("charisma") else _rng.randi_range(1, 20)

	# --- Personality bipolar axes (-100..100) ---
	data.morality = int(params["morality"]) if params.has("morality") else _rng.randi_range(-100, 100)
	data.candor = int(params["candor"]) if params.has("candor") else _rng.randi_range(-100, 100)
	data.assertiveness = int(params["assertiveness"]) if params.has("assertiveness") else _rng.randi_range(-100, 100)
	data.ego = int(params["ego"]) if params.has("ego") else _rng.randi_range(-100, 100)

	# --- Core unipolar personality (1..20) ---
	data.creativity = int(params["creativity"]) if params.has("creativity") else _rng.randi_range(1, 20)
	data.resourcefulness = int(params["resourcefulness"]) if params.has("resourcefulness") else _rng.randi_range(1, 20)
	data.empathy = int(params["empathy"]) if params.has("empathy") else _rng.randi_range(1, 20)
	data.resolve = int(params["resolve"]) if params.has("resolve") else _rng.randi_range(1, 20)
	data.ambition = int(params["ambition"]) if params.has("ambition") else _rng.randi_range(1, 20)
	data.loyalty = int(params["loyalty"]) if params.has("loyalty") else _rng.randi_range(1, 20)
	data.integrity = int(params["integrity"]) if params.has("integrity") else _rng.randi_range(1, 20)

	# --- Apply SpiritualRoot modifiers (Health/Qi/Potential/Lifespan) ---
	if root:
		data.max_hp = data.max_hp + int(root.health_modifier)
		data.current_hp = min(data.current_hp, data.max_hp)
		data.max_qi = data.max_qi + int(root.qi_modifier)
		data.current_qi = min(data.current_qi, data.max_qi)
		data.char_lifespan = data.char_lifespan + int(root.lifespan_modifier)
		data.potential = int(data.potential) + int(root.potential_modifier)

	# --- Apply Trait Modifiers (null-safe checks) ---
	# Use get(...) to probe trait fields because Resource doesn't provide has_property().
	var modifier_pairs: Array = [
		["strength", "strength_modifier"],
		["constitution", "constitution_modifier"],
		["agility", "agility_modifier"],
		["intelligence", "intelligence_modifier"],
		["wisdom", "wisdom_modifier"],
		["charisma", "charisma_modifier"],
		["morality", "morality_modifier"],
		["candor", "candor_modifier"],
		["assertiveness", "assertiveness_modifier"],
		["ego", "ego_modifier"],
		["creativity", "creativity_modifier"],
		["resourcefulness", "resourcefulness_modifier"],
		["empathy", "empathy_modifier"],
		["resolve", "resolve_modifier"],
		["ambition", "ambition_modifier"],
		["loyalty", "loyalty_modifier"],
		["integrity", "integrity_modifier"],
		["max_hp", "health_modifier"],
		["max_qi", "qi_modifier"],
		["potential", "potential_modifier"],
		["char_lifespan", "lifespan_modifier"]
	]
	for t in chosen_traits:
		if not t:
			continue
		# If the trait is a Resource, t.get(field_name) returns null when field doesn't exist.
		for pair in modifier_pairs:
			var prop: String = String(pair[0])
			var mod_name: String = String(pair[1])
			var trait_val = t.get(mod_name) # null if trait doesn't export this field
			if trait_val == null:
				continue
			var current_val = data.get(prop) # null if data doesn't have the property
			if current_val == null:
				continue
			var add_val: int = int(trait_val)
			if add_val == 0:
				continue
			# Apply modifier
			data.set(prop, current_val + add_val)

	# Clamp current hp/qi after modifiers
	if data.current_hp > data.max_hp:
		data.current_hp = data.max_hp
	if data.current_qi > data.max_qi:
		data.current_qi = data.max_qi

	# Return the fully initialized character node; CharacterManager will register it
	return char_node

# Helper: pick a random gender matching CharacterData.Gender enum
func _random_gender() -> int:
	var genders_count: int = 2 # CharacterData.Gender.MALE, FEMALE
	return _rng.randi_range(0, genders_count - 1)
