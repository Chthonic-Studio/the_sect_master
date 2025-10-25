class_name SpiritualRoot extends Resource

@export var root_id: int = 0
@export var root_name: String = "Basic Five-Element Root"
@export_multiline var root_description: String
@export var root_image: Texture

@export_category("Stat Modifiers")
## These modifiers apply immediately upon character creation
@export var health_modifier: int = 10
@export var qi_modifier: int = 20
@export var potential_modifier: int = 1 
@export var lifespan_modifier: int = 5

## Affinity Modifiers - Using the consolidated categories
@export_category("Discipline Affinities")
@export_range(0, 10, 1) var melee_affinity_modifier: int = 0
@export_range(0, 10, 1) var ranged_affinity_modifier: int = 0
@export_range(0, 10, 1) var magic_affinity_modifier: int = 0
@export_range(0, 10, 1) var support_affinity_modifier: int = 0
