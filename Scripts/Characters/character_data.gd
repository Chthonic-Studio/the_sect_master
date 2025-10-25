extends Node
class_name CharacterData

## --- Dynamic System Values ---
@export_category("System Values (Dynamic)")
## A character's unique ID, generated at spawn
@export var char_id: int = -1 

## The Definition Resource to pull initial values from
@export var char_definition: CharacterDefinition 

@export var char_age: int = 5
@export var potential: int = 1
@export var current_hp: int = 100 
@export var max_hp: int = 100
@export var current_qi: int = 100
@export var max_qi: int = 100

## Reference to the character's progression state
@onready var cultivation_state: Cultivation

## --- Current Attributes (Dynamic Runtime Values) ---
## Primary Combat/Ability Attributes
var strength: int
var constitution: int
var agility: int
var intelligence: int
var wisdom: int
var charisma: int

## Personality Axes (Bipolar)
var morality: int
var candor: int
var assertiveness: int
var ego: int

## Core Personality Traits (Unipolar)
var creativity: int
var resourcefulness: int
var empathy: int
var resolve: int
var ambition: int
var loyalty: int
var integrity: int

## Traits
var active_traits: Array[CharacterTrait] = []

func _ready() -> void:
	if char_definition:
		# Initialize dynamic stats from the static definition
		_initialize_from_definition()
		# Ensure a unique ID is assigned if not loaded from a save
		if char_id == -1:
			char_id = randi() # Placeholder: Replace with a proper ID generation system

func _initialize_from_definition() -> void:
	# Set the current, dynamic stats to the initial values from the static Definition
	strength = char_definition.strength
	constitution = char_definition.constitution
	agility = char_definition.agility
	intelligence = char_definition.intelligence
	wisdom = char_definition.wisdom
	charisma = char_definition.charisma

	morality = char_definition.morality
	candor = char_definition.candor
	assertiveness = char_definition.assertiveness
	ego = char_definition.ego

	creativity = char_definition.creativity
	resourcefulness = char_definition.resourcefulness
	empathy = char_definition.empathy
	resolve = char_definition.resolve
	ambition = char_definition.ambition
	loyalty = char_definition.loyalty
	integrity = char_definition.integrity

	active_traits.clear()
	active_traits.append_array(char_definition.starting_traits)
	# The character's age and potential will start at their initial values or be set by the spawner

## Provides safe, centralized stat access by name (for AI, UI, etc.)
func get_stat(stat_name: String) -> int:
	match stat_name:
		"strength": return strength
		"constitution": return constitution
		"agility": return agility
		"intelligence": return intelligence
		"wisdom": return wisdom
		"charisma": return charisma
		"morality": return morality
		"candor": return candor
		"assertiveness": return assertiveness
		"ego": return ego
		"creativity": return creativity
		"resourcefulness": return resourcefulness
		"empathy": return empathy
		"resolve": return resolve
		"ambition": return ambition
		"loyalty": return loyalty
		"integrity": return integrity
		_:
			push_error("Attempted to access non-existent stat: " + stat_name)
			return 0

## Modifies a stat by name, clamps where appropriate, and can emit a signal if you add one
func modify_stat(stat_name: String, amount: int) -> void:
	match stat_name:
		"strength":
			strength = clamp(strength + amount, 1, 20)
		"constitution":
			constitution = clamp(constitution + amount, 1, 20)
		"agility":
			agility = clamp(agility + amount, 1, 20)
		"intelligence":
			intelligence = clamp(intelligence + amount, 1, 20)
		"wisdom":
			wisdom = clamp(wisdom + amount, 1, 20)
		"charisma":
			charisma = clamp(charisma + amount, 1, 20)
		"morality":
			morality = clamp(morality + amount, -100, 100)
		"candor":
			candor = clamp(candor + amount, -100, 100)
		"assertiveness":
			assertiveness = clamp(assertiveness + amount, -100, 100)
		"ego":
			ego = clamp(ego + amount, -100, 100)
		"creativity":
			creativity = clamp(creativity + amount, 1, 20)
		"resourcefulness":
			resourcefulness = clamp(resourcefulness + amount, 1, 20)
		"empathy":
			empathy = clamp(empathy + amount, 1, 20)
		"resolve":
			resolve = clamp(resolve + amount, 1, 20)
		"ambition":
			ambition = clamp(ambition + amount, 1, 20)
		"loyalty":
			loyalty = clamp(loyalty + amount, 1, 20)
		"integrity":
			integrity = clamp(integrity + amount, 1, 20)
		_:
			push_error("Attempted to modify non-existent stat: " + stat_name)
	# Optionally emit a stat_changed signal here
