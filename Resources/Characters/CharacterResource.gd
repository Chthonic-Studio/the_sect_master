# CharacterResource.gd
# Generic resource for all characters in the game (player, NPCs, sect members, rivals)
# - Use as the base for all character data. Extend for specialized types if needed.

class_name CharacterResource extends Resource

## === ENUMS ===
enum CultureGroup { WESTERN, TRADITIONAL }
enum SpiritualRootType { NONE, COMMON, SUPERIOR, HEAVENLY, MUTATED, DEMONIC, GHOSTLY }
enum Gender { MALE, FEMALE, OTHER }

# === Unique ID (assigned automatically by CharacterManager) ===
@export var id: int = 0 ## DO NOT assign manually; always use CharacterManager for creation.

# === Basic Info ===
@export_category("Basic Info")
@export var first_name: String = "" ## Character's display first name
@export var last_name: String = ""## Character's display last name
@export var name_display: String = "" # Display name for UI, set at creation
@export var culture: CultureGroup = CultureGroup.TRADITIONAL
@export var gender: Gender = Gender.MALE
@export var age: int = 18
@export var title: String = ""
@export var renown: int = 0
@export var renown_title: String = "Unknown"
@export var reputation: String = "None"
@export var spiritual_root: SpiritualRootType = SpiritualRootType.NONE ## Enum dropdown

# --- NEW: Trait System ---
# This array holds the StringName IDs of the traits this character has.
# Example: ["Righteous", "BodyOfIron"]
@export var traits: Array[StringName] = []

# --- NEW: Flag System ---
# Dynamic flags for temporary states (e.g., "OnMission", "Imprisoned").
@export var flags: Array[StringName] = []


# === NEW: Social Relationships ===
@export_category("Social")
@export var relationships: Dictionary = {} # {character_id: int, relationship_value: int}

# === Core Stats ===
@export_category("Core Stats")
# --- NEW: Desire Modifier System ---
@export var desire_modifiers: Dictionary = {} # Stores current desire values, e.g., {"Training": -50.0}
@export var desire_growth_rates: Dictionary = {} # Stores calculated growth rates, e.g., {"Training": 1.5}
@export_range(0, 99000000, 1)
var max_hp: int = 100
@export_range(0, 99000000, 1)
var max_qi: int = 100
@export_range(0, 99000000, 1)
var current_hp: int = 100
@export_range(0, 99000000, 1)
var current_qi: int = 100
@export_range(0, 100, 1)
var potential: int = 50
@export_range(0, 100, 1)
var strength: int = 10
@export_range(0, 100, 1)
var intelligence: int = 10
@export_range(0, 100, 1)
var agility: int = 10
@export_range(0, 100, 1)
var perception: int = 10
@export_range(0, 100, 1)
var constitution: int = 10

# === Hidden Personality Values ===
@export_category("Hidden Personality Values")
@export_range(-100, 100, 1)
var ambition: int = 0
@export_range(-100, 100, 1)
var loyalty: int = 0
@export_range(-100, 100, 1)
var greed: int = 0
@export_range(-100, 100, 1)
var patience: int = 0
@export_range(-100, 100, 1)
var aggression: int = 0
@export_range(-100, 100, 1)
var cunning: int = 0
@export_range(-100, 100, 1)
var diligence: int = 0
@export_range(-100, 100, 1)
var courage: int = 0
@export_range(-100, 100, 1)
var spirituality: int = 0
@export_range(-100, 100, 1)
var resourcefulness: int = 0
@export_range(-100, 100, 1)
var humility: int = 0
@export_range(-100, 100, 1)
var charisma: int = 0
@export_range(-100, 100, 1)
var empathy: int = 0
@export_range(-100, 100, 1)
var discipline: int = 0
@export_range(-100, 100, 1)
var curiosity: int = 0

# Add more personality stats as needed...

# === Utility Functions ===

# --- NEW: Trait & Flag Helpers ---
func has_trait(trait_id: StringName) -> bool:
	return traits.has(trait_id)

func has_flag(flag_name: StringName) -> bool:
	return flags.has(flag_name)

func add_trait(trait_id: StringName) -> void:
	if has_trait(trait_id):
		return

	var trait_res: TraitResource = TraitManager.get_trait(trait_id)
	if not trait_res:
		push_warning("Attempted to add non-existent trait '%s' to character %d." % [trait_id, id])
		return

	traits.append(trait_id)
	_apply_trait_effects(trait_res)

func remove_trait(trait_id: StringName) -> void:
	if not has_trait(trait_id):
		return

	var trait_res: TraitResource = TraitManager.get_trait(trait_id)
	if not trait_res:
		push_warning("Attempted to remove non-existent trait '%s' from character %d. Effects will not be reversed." % [trait_id, id])
		traits.erase(trait_id)
		return

	traits.erase(trait_id)
	_remove_trait_effects(trait_res)

func _apply_trait_effects(trait_res: TraitResource) -> void:
	for stat_name in trait_res.stat_effects:
		var current_value = get(stat_name)
		if stat_name and current_value != null:
			set(stat_name, current_value + trait_res.stat_effects[stat_name])
		else:
			push_warning("Character %d: Trait '%s' trying to modify non-existent or Nil stat '%s'." % [id, trait_res.trait_id, stat_name])

	for flag_name in trait_res.flags:
		if not flags.has(flag_name):
			flags.append(flag_name)

func _remove_trait_effects(trait_res: TraitResource) -> void:
	for stat_name in trait_res.stat_effects:
		# REASON FOR CHANGE:
		# Applying the same defensive check here ensures that removing a trait
		# with a typo in its data won't crash the game.
		var current_value = get(stat_name)
		if stat_name and current_value != null:
			set(stat_name, current_value - trait_res.stat_effects[stat_name])
		else:
			push_warning("Character %d: Trait '%s' trying to reverse non-existent or Nil stat '%s'." % [id, trait_res.trait_id, stat_name])

	for flag_name in trait_res.flags:
		if flags.has(flag_name):
			flags.erase(flag_name)

func clamp_stats() -> void:
	max_hp = clamp(max_hp, 0, 99000000)
	max_qi = clamp(max_qi, 0, 99000000)
	current_hp = clamp(current_hp, 0, max_hp)
	current_qi = clamp(current_qi, 0, max_qi)
	potential = clamp(potential, 0, 100)
	strength = clamp(strength, 0, 100)
	intelligence = clamp(intelligence, 0, 100)
	agility = clamp(agility, 0, 100)
	perception = clamp(perception, 0, 100)
	constitution = clamp(constitution, 0, 100)
	ambition = clamp(ambition, -100, 100)
	loyalty = clamp(loyalty, -100, 100)
	greed = clamp(greed, -100, 100)
	patience = clamp(patience, -100, 100)
	aggression = clamp(aggression, -100, 100)
	cunning = clamp(cunning, -100, 100)
	diligence = clamp(diligence, -100, 100)
	courage = clamp(courage, -100, 100)
	spirituality = clamp(spirituality, -100, 100)
	resourcefulness = clamp(resourcefulness, -100, 100)
	humility = clamp(humility, -100, 100)
	charisma = clamp(charisma, -100, 100)
	empathy = clamp(empathy, -100, 100)
	discipline = clamp(discipline, -100, 100)
	curiosity = clamp(curiosity, -100, 100)

func randomize_personality_stats() -> void:
	ambition = randi_range(-100, 100)
	loyalty = randi_range(-100, 100)
	greed = randi_range(-100, 100)
	patience = randi_range(-100, 100)
	aggression = randi_range(-100, 100)
	cunning = randi_range(-100, 100)
	diligence = randi_range(-100, 100)
	courage = randi_range(-100, 100)
	spirituality = randi_range(-100, 100)
	resourcefulness = randi_range(-100, 100)
	humility = randi_range(-100, 100)
	charisma = randi_range(-100, 100)
	empathy = randi_range(-100, 100)
	discipline = randi_range(-100, 100)
	curiosity = randi_range(-100, 100)
