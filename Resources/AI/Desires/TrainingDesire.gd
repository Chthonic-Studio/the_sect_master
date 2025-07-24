# TrainingDesire.gd

extends UtilityDesireResource
class_name TrainingDesire


func get_utility(character: Node) -> float:
	# Desire to train is based on personality (Diligence, Ambition) and core stats (Potential).
	var res = character.character_resource
	if res:
		# Normalize personality stats from [-100, 100] to [0, 100] for easier calculation.
		var diligence_score = (res.diligence + 100) / 2
		var ambition_score = (res.ambition + 100) / 2
		
		# The final score is a weighted average of their potential and personality.
		# A diligent character with high potential will have a strong desire to train.
		var desire_score = (res.potential * 0.5) + (diligence_score * 0.3) + (ambition_score * 0.2)
		return desire_score
	return 0.0
