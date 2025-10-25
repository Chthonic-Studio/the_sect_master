class_name Character extends Resource

@export_category("System Values")
## A character's unique ID, generated at spawn
@export var char_id: int

## The basic info of every character
@export_category("Character Info")
@export var char_fullname: String
@export var char_first_name: String
@export var char_last_name: String
@export var char_age: int = 5
@export var char_lifespan: int = 70
@export var potential: int = 1

@export_category("Primary Combat/Ability Attributes")
@export_range(1, 20, 1) var strength: int = 10         # Physical Power, Damage, Carry Weight
@export_range(1, 20, 1) var constitution: int = 10     # Health, Stamina, Resistance to damage
@export_range(1, 20, 1) var agility: int = 10          # Speed, Evasion, Initiative
@export_range(1, 20, 1) var intelligence: int = 10     # Knowledge, Magic Power, AI effectiveness
@export_range(1, 20, 1) var wisdom: int = 10           # Intuition, Perception checks, Will saves
@export_range(1, 20, 1) var charisma: int = 10         # Social checks, Influence, Leadership (Eliminates Leadership/Diplomacy/Persuasion)

@export_category("Personality Axes (Bipolar)")
@export_range(-100, 100, 1) var morality: int = 0       # Good (+100) vs. Evil (-100)
@export_range(-100, 100, 1) var candor: int = 0         # Honesty (+100) vs. Deception (-100)
@export_range(-100, 100, 1) var assertiveness: int = 0  # Aggression (+100) vs. Passivity (-100)
@export_range(-100, 100, 1) var ego: int = 0            # Confidence (+100) vs. Humility (-100)

@export_category("Core Personality Traits (Unipolar)")
@export_range(1, 20, 1) var creativity: int = 10       # Solution generation, unique action paths
@export_range(1, 20, 1) var resourcefulness: int = 10  # Utilizing environment/inventory, Cunning/Problem-solving
@export_range(1, 20, 1) var empathy: int = 10          # Understanding NPC motives, reading emotions
@export_range(1, 20, 1) var resolve: int = 10          # Combined Tenacity, Willpower, Patience, Morale
@export_range(1, 20, 1) var ambition: int = 10         # Goal-driven behavior, long-term decisions
@export_range(1, 20, 1) var loyalty: int = 10          # Alignment with group/faction, reliability
@export_range(1, 20, 1) var integrity: int = 10        # Adherence to personal code, resistance to corruption
