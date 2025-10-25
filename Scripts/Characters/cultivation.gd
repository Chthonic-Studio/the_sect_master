extends Node
class_name Cultivation

## --- Dynamic State ---
@export var current_stage_index: int = 0
@export var progress_to_next_stage: float = 0.0

@export var current_health: int = 100
@export var max_health: int = 100
@export var current_qi: int = 100
@export var max_qi: int = 100

## --- Affinities (Unipolar Runtime Stats) ---
var blade_affinity: int = 0
var sword_affinity: int = 0
var spear_affinity: int = 0
var guandao_affinity: int = 0
var fist_affinity: int = 0
var bow_affinity: int = 0
var fan_affinity: int = 0
var zither_affinity: int = 0
var magic_affinity: int = 0
var formation_affinity: int = 0
var healing_affinity: int = 0

## --- References to Definitions ---
var stage_definitions: Array[CultivationStage]

# Cache a reference to the owning CharacterData
var _data: CharacterData

func _ready() -> void:
	pass

# Initialize cultivation path and immediately apply current stage modifiers
func initialize_cultivation(path_def: CultivationPathDef) -> void:
	if not path_def:
		push_error("initialize_cultivation called with null path_def.")
		return
	stage_definitions = path_def.stages
	_apply_current_stage_modifiers()

func _apply_current_stage_modifiers() -> void:
	if not stage_definitions or current_stage_index >= stage_definitions.size():
		return

	var current_stage = stage_definitions[current_stage_index]

	# Apply health and qi modifiers
	max_health += current_stage.health_modifier
	max_qi += current_stage.qi_modifier

	# Apply lifespan modifier on CharacterData (safer than calling parent)
	if _data and _data.has_method("apply_lifespan_modifier"):
		_data.apply_lifespan_modifier(current_stage.lifespan_modifier)

	# Apply stat modifiers dynamically via CharacterData.modify_stat
	var stat_modifiers = [
		["strength", "strength_modifier"],
		["constitution", "constitution_modifier"],
		["agility", "agility_modifier"],
		["intelligence", "intelligence_modifier"],
		["wisdom", "wisdom_modifier"],
		["charisma", "charisma_modifier"]
	]
	for pair in stat_modifiers:
		var stat = pair[0]
		var mod_name = pair[1]
		var amount = current_stage.get(mod_name)
		if amount != 0 and _data and _data.has_method("modify_stat"):
			_data.modify_stat(stat, amount)

	# Apply all affinities
	var affinity_modifiers = [
		["blade_affinity", "blade_affinity_modifier"],
		["sword_affinity", "sword_affinity_modifier"],
		["spear_affinity", "spear_affinity_modifier"],
		["guandao_affinity", "guandao_affinity_modifier"],
		["fist_affinity", "fist_affinity_modifier"],
		["bow_affinity", "bow_affinity_modifier"],
		["fan_affinity", "fan_affinity_modifier"],
		["zither_affinity", "zither_affinity_modifier"],
		["magic_affinity", "magic_affinity_modifier"],
		["formation_affinity", "formation_affinity_modifier"],
		["healing_affinity", "healing_affinity_modifier"]
	]
	for pair in affinity_modifiers:
		var affinity = pair[0]
		var mod_name = pair[1]
		var amount = current_stage.get(mod_name)
		if amount != 0:
			self.set(affinity, self.get(affinity) + amount)

func gain_progress(amount: float) -> void:
	if not _data:
		return
	var potential_bonus = float(_data.potential) / 10.0
	var modified_amount = amount * (1.0 + potential_bonus)
	progress_to_next_stage += modified_amount
	if current_stage_index < stage_definitions.size() - 1:
		var next_stage = stage_definitions[current_stage_index + 1]
		if progress_to_next_stage >= next_stage.progress_required:
			_advance_stage()

func _advance_stage() -> void:
	current_stage_index += 1
	progress_to_next_stage = 0.0
	_apply_current_stage_modifiers()
	print("Cultivation stage advanced!")
