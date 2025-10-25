class_name CultivationStage extends Resource

@export var stage_name: String = ""
@export var progress_required: float = 100.0 # From previous stage to this one
@export var icon: Texture

## --- Stat Modifiers (Easy Editor Editing) ---
@export_category("Base Stat Modifiers")
@export var health_modifier: int = 0
@export var qi_modifier: int = 0
@export var lifespan_modifier: int = 0 # In years

@export_category("Primary Stat Modifiers")
@export var strength_modifier: int = 0
@export var constitution_modifier: int = 0
@export var agility_modifier: int = 0
@export var intelligence_modifier: int = 0
@export var wisdom_modifier: int = 0
@export var charisma_modifier: int = 0

## --- Weapon Affinity Modifiers (Detailed) ---
@export_category("Affinities")
@export var blade_affinity_modifier: int = 0
@export var sword_affinity_modifier: int = 0
@export var spear_affinity_modifier: int = 0
@export var guandao_affinity_modifier: int = 0
@export var fist_affinity_modifier: int = 0
@export var bow_affinity_modifier: int = 0
@export var fan_affinity_modifier: int = 0
@export var zither_affinity_modifier: int = 0
## --- Magic/Support Affinity Modifiers ---
@export var magic_affinity_modifier: int = 0
@export var formation_affinity_modifier: int = 0
@export var healing_affinity_modifier: int = 0
