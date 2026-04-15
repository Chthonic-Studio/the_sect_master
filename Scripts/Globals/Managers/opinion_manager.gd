extends Node

## Calculates and returns dynamic relationship values between characters.

## HOW TO USE: 
## var opinion = OpinionManager.get_opinion(player_char, target_char)
## Returns an integer between -100 and 100.

func get_opinion(char_a: CharacterData, char_b: CharacterData) -> int:
	if not char_a or not char_b or char_a == char_b:
		return 0
		
	var total_opinion: int = 0
	
	# 1. Sect Affiliation
	if char_a.sect_id != "" and char_a.sect_id == char_b.sect_id:
		total_opinion += 10 # Same sect solidarity
	elif char_a.sect_id != "" and char_b.sect_id != "":
		# Check if sects are rivals or allies
		var sect_rel = SimulationManager.get_sect_relationship(char_a.sect_id, char_b.sect_id)
		# Scale the macro sect relationship (-100 to 100) to a personal opinion impact (-25 to 25)
		total_opinion += int(sect_rel * 0.25)

	# 2. Trait Compatibility
	total_opinion += _calculate_trait_compatibility(char_a, char_b)
	
	# 3. Directed Temporal Opinions (e.g. Swayed, Insulted)
	if char_a.directed_opinions.has(char_b.char_id):
		for mod in char_a.directed_opinions[char_b.char_id]:
			total_opinion += mod.get("value", 0)
			
	# 4. Base Charisma Impact
	# High charisma makes everyone like you just a little bit more organically
	var b_charisma = char_b.get_stat(Definitions.Stat.CHARISMA)
	if b_charisma > 50:
		total_opinion += int((b_charisma - 50) * 0.2)
		
	return clampi(total_opinion, -100, 100)

func _calculate_trait_compatibility(char_a: CharacterData, char_b: CharacterData) -> int:
	var score: int = 0
	
	for trait_a in char_a.traits:
		var t_data_a = DataManager.traits_registry.get(trait_a, {})
		
		# Check if B has the exact same trait
		if char_b.traits.has(trait_a):
			score += t_data_a.get("same_trait_opinion", 0)
			
		# Check if B has conflicting/opposite traits
		var conflicts = t_data_a.get("conflicts", [])
		for conflict_trait in conflicts:
			if char_b.traits.has(conflict_trait):
				score += t_data_a.get("opposite_trait_opinion", 0)
				
		# Check specific trait opinions
		var specific_ops = t_data_a.get("specific_trait_opinions", {})
		for b_trait in char_b.traits:
			if specific_ops.has(b_trait):
				score += specific_ops[b_trait]
				
	return score
