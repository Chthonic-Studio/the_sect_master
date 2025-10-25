class_name CharacterDefinition extends Resource

enum Gender {MALE, FEMALE}

## --- System Values ---
@export_category("System Values (Static)")
## A unique key for the definition, used for data lookup
@export var definition_key: String = "" 

## --- Character Info ---
@export_category("Character Info")
@export var char_fullname: String = "New Character"
@export var char_first_name: String = "First"
@export var char_last_name: String = "Last"
@export var char_gender: Gender
@export var char_lifespan: int = 70 
@export var spiritual_root: SpiritualRoot 

## --- Initial Attributes (Static Defaults) ---

@export var cultivation_path: CultivationPathDef = preload("res://Resources/Characters/cultivation_path.tres")

@export_category("Primary Combat/Ability Attributes (Initial)")
@export_range(1, 20, 1) var strength: int = 10
@export_range(1, 20, 1) var constitution: int = 10
@export_range(1, 20, 1) var agility: int = 10
@export_range(1, 20, 1) var intelligence: int = 10
@export_range(1, 20, 1) var wisdom: int = 10
@export_range(1, 20, 1) var charisma: int = 10

@export_category("Personality Axes (Initial Bipolar)")
@export_range(-100, 100, 1) var morality: int = 0
@export_range(-100, 100, 1) var candor: int = 0
@export_range(-100, 100, 1) var assertiveness: int = 0
@export_range(-100, 100, 1) var ego: int = 0

@export_category("Core Personality Traits (Initial Unipolar)")
@export_range(1, 20, 1) var creativity: int = 10
@export_range(1, 20, 1) var resourcefulness: int = 10
@export_range(1, 20, 1) var empathy: int = 10
@export_range(1, 20, 1) var resolve: int = 10
@export_range(1, 20, 1) var ambition: int = 10
@export_range(1, 20, 1) var loyalty: int = 10
@export_range(1, 20, 1) var integrity: int = 10

@export_category("Starting Traits")
@export var starting_traits: Array[CharacterTrait] # Array of trait resources
