extends Node
class_name CultivationComponent

## --- Dynamic State ---
@export var current_stage_index: int = 0
@export var progress_to_next_stage: float = 0.0

@export var current_health: int = 100
@export var max_health: int = 100
@export var current_qi: int = 100
@export var max_qi: int = 100

## --- Affinities (Unipolar Runtime Stats) ---
# NOTE: These are the runtime values, set by the CultivationStageDef and SpiritualRoot
var blade_affinity: int = 0
var sword_affinity: int = 0
# ... (all 13 affinities declared here) ...

## --- References to Definitions ---
# This is an array of ALL stages in order, loaded from the CultivationPath
var stage_definitions: Array[CultivationStage]

func initialize_cultivation(path_def: CultivationPathDef) -> void:
	stage_definitions = path_def.stages
	_apply_current_stage_modifiers()
	
func _apply_current_stage_modifiers() -> void:
	if current_stage_index >= stage_definitions.size():
		return
		
	var current_stage = stage_definitions[current_stage_index]
	
	# 1. Apply Modifiers to the CharacterData/Stats
	# This requires accessing the sibling Data node via the parent controller
	var data = get_parent().data # Assuming Character.gd links the data node

	# Example: Apply Max Health and Lifespan
	max_health += current_stage.health_modifier
	get_parent().apply_lifespan_modifier(current_stage.lifespan_modifier)
	
	# 2. Apply Affinities (Example)
	# This logic is crucial: it updates the runtime affinity values
	sword_affinity += current_stage.stat_modifiers.sword_affinity_modifier
	# ... and so on for all relevant affinities.
	
func gain_progress(amount: float) -> void:
	# Logic for progress gain, factoring in the character's Potential
	var data = get_parent().data 
	var potential_bonus = float(data.potential) / 10.0 # Example influence calculation
	var modified_amount = amount * (1.0 + potential_bonus)
	
	progress_to_next_stage += modified_amount
	
	if current_stage_index < stage_definitions.size() - 1:
		var next_stage = stage_definitions[current_stage_index + 1]
		if progress_to_next_stage >= next_stage.progress_required:
			_advance_stage()

func _advance_stage() -> void:
	# Logic to advance stage, reset progress, apply new modifiers, and notify
	current_stage_index += 1
	progress_to_next_stage = 0.0
	_apply_current_stage_modifiers()
	print("Cultivation stage advanced!")
