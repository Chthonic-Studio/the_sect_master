# DesireManager.gd
# Autoload Singleton (name: DesireManager)
# Manages all AI desire-related logic, including growth rate formulas and daily updates.

extends Node

# The master list of all desires in the game. Centralizes management.
const ALL_DESIRES = ["Eat", "Training", "Idle", "Socialize", "Study"]

func _ready() -> void:
	# Connect to the TimeManager's signal to run updates automatically each day.
	TimeManager.connect("day_passed", Callable(self, "_on_day_passed"))

# --- PUBLIC API ---

# Initializes desire data for a newly created character resource.
# Called by CharacterManager upon character creation.
func initialize_desires_for_character(res: CharacterResource) -> void:
	res.desire_modifiers.clear()
	res.desire_growth_rates.clear()
	
	for desire_name in ALL_DESIRES:
		res.desire_modifiers[desire_name] = 0.0
		res.desire_growth_rates[desire_name] = _calculate_growth_rate(res, desire_name)

# --- INTERNAL LOGIC ---

# This is the new home for all desire growth rate formulas.
func _calculate_growth_rate(res: CharacterResource, desire_name: String) -> float:
	# Base growth per day. Can be adjusted for game-wide balance.
	var base_growth = 5.0 
	
	match desire_name:
		"Eat":
			# Hardy characters with high Constitution have a greater appetite.
			# Strength also contributes, representing a higher metabolism.
			var constitution_mod = res.constitution / 20.0 # Range: -5 to 5
			var strength_mod = res.strength / 40.0       # Range: -2.5 to 2.5
			return max(0.5, base_growth + constitution_mod + strength_mod)
			
		"Training":
			# Diligent and ambitious characters recover their will to train faster.
			# Cultivators get a significant bonus.
			var is_cultivator_bonus = 0.5 if res is CultivatorResource else 0.2
			var diligence_mod = res.diligence / 25.0  # Range: -4 to 4
			var ambition_mod = res.ambition / 50.0   # Range: -2 to 2
			return max(0.5, (base_growth + diligence_mod + ambition_mod) * is_cultivator_bonus)

		"Socialize":
			# Characters with low Charisma or Empathy will feel their social desire grow slower.
			var charisma_mod = res.charisma / 20.0 # Range: -5 to 5
			var empathy_mod = res.empathy / 40.0   # Range: -2.5 to 2.5
			return max(0.5, base_growth + charisma_mod + empathy_mod)

		"Study":
			# Curious characters' desire to study grows faster.
			var curiosity_mod = res.curiosity / 20.0 # Range: -5 to 5
			return max(0.5, base_growth + curiosity_mod)
			
		"Idle":
			# Idle has no growth; it's a fallback action.
			return 0.0
			
		_:
			# Default growth rate for any future desires.
			return base_growth

# --- SIGNAL HANDLER ---

# Updates the desire modifiers for every character at the end of each day.
func _on_day_passed(_year: int, _season: int, _period: int, _day: int) -> void:
	# Get all character resources from the CharacterManager.
	var all_resources = CharManager.all_character_resources
	
	for res in all_resources:
		if res and not res.desire_modifiers.is_empty():
			for desire_name in res.desire_modifiers.keys():
				var growth_rate = res.desire_growth_rates.get(desire_name, 0.0)
				var current_modifier = res.desire_modifiers[desire_name]
				
				# Increase the modifier by its growth rate and clamp the result.
				res.desire_modifiers[desire_name] = clamp(current_modifier + growth_rate, -100.0, 100.0)
