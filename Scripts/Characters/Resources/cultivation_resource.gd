class_name CultivationStage extends Resource

@export var stage_name: String = ""
@export var progress_required: float = 100.0 # From previous stage to this one
@export var icon: Texture

## --- Stat Modifiers (Easy Editor Editing) ---
# We use a nested class or a dedicated export group for clarity
@export_category("Base Stat Modifiers")
@export var health_modifier: int = 50
@export var qi_modifier: int = 50
@export var lifespan_modifier: int = 5 # In years

## --- Affinity Modifiers (The Consolidated Approach) ---

@export_category("Discipline Affinities")
@export_range(0, 10, 1) var melee_affinity_modifier: int = 0      # Consolidates Blade/Sword/Spear/Guandao/Fist
@export_range(0, 10, 1) var ranged_affinity_modifier: int = 0     # Consolidates Bow/Fan/Zither
@export_range(0, 10, 1) var magic_affinity_modifier: int = 0      # Consolidates Spells/Formation
@export_range(0, 10, 1) var support_affinity_modifier: int = 0    # HealingAffinity

# Add modifiers for Primary Combat Stats (STR, INT, etc.) if they should be increased per stage
@export_category("Primary Stat Modifiers")
@export var strength_modifier: int = 0
@export var intelligence_modifier: int = 0
