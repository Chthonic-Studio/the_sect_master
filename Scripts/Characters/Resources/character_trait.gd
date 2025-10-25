class_name CharacterTrait extends Resource

@export var trait_id: int
@export var trait_name: String
@export_multiline var trait_description: String
@export var trait_icon: Texture

# --- Optional stat modifiers (applied at spawn) ---
@export_category("Primary Stat Modifiers")
@export_range(-10, 10, 1) var strength_modifier: int = 0
@export_range(-10, 10, 1) var constitution_modifier: int = 0
@export_range(-10, 10, 1) var agility_modifier: int = 0
@export_range(-10, 10, 1) var intelligence_modifier: int = 0
@export_range(-10, 10, 1) var wisdom_modifier: int = 0
@export_range(-10, 10, 1) var charisma_modifier: int = 0

@export_category("Personality Modifiers")
@export_range(-50, 50, 1) var morality_modifier: int = 0
@export_range(-50, 50, 1) var candor_modifier: int = 0
@export_range(-50, 50, 1) var assertiveness_modifier: int = 0
@export_range(-20, 20, 1) var ego_modifier: int = 0

@export_category("Core Personality (Unipolar) Modifiers")
@export_range(-5, 5, 1) var creativity_modifier: int = 0
@export_range(-5, 5, 1) var resourcefulness_modifier: int = 0
@export_range(-5, 5, 1) var empathy_modifier: int = 0
@export_range(-5, 5, 1) var resolve_modifier: int = 0
@export_range(-5, 5, 1) var ambition_modifier: int = 0
@export_range(-5, 5, 1) var loyalty_modifier: int = 0
@export_range(-5, 5, 1) var integrity_modifier: int = 0

@export_category("Misc Modifiers")
@export var health_modifier: int = 0
@export var qi_modifier: int = 0
@export var potential_modifier: int = 0
@export var lifespan_modifier: int = 0
