class_name SectProposal extends RefCounted

## Handles the lifecycle and voting logic of a Sect decision (Laws, War, etc.)

signal proposal_resolved(proposal: SectProposal, passed: bool)

var proposal_id: String
var type: String # e.g., "change_law", "declare_war"
var payload: Dictionary
var days_remaining: int

var supporters: Array[String] = []
var opposers: Array[String] = []
var undecided: Array[String] = []

func _init(p_type: String, p_payload: Dictionary, duration_days: int, elder_ids: Array[String]) -> void:
	proposal_id = "prop_" + str(TimeManager.get_total_days_elapsed()) + "_" + str(randi() % 1000)
	type = p_type
	payload = p_payload
	days_remaining = duration_days
	undecided.assign(elder_ids)

## Called daily by the SectData to simulate the Elders taking time to make a decision
func process_daily_tick(sect: SectData) -> void:
	days_remaining -= 1
	
	# Evaluate one undecided elder per day to simulate a developing political debate
	# (And to perfectly distribute CPU load across the week)
	if not undecided.is_empty():
		var elder_id = undecided.pop_back()
		_evaluate_elder_vote(elder_id, sect)
		
	if days_remaining <= 0:
		_resolve_proposal(sect)

func _evaluate_elder_vote(elder_id: String, sect: SectData) -> void:
	var elder = SimulationManager.get_character(elder_id)
	if not elder or not elder.is_alive:
		return
		
	# Base stance is driven by their Loyalty to the Sect/Master
	var loyalty = elder.get_personality_value("loyalty")
	var ambition = elder.get_personality_value("ambition")
	var greed = elder.get_personality_value("greed")
	
	var support_score = loyalty
	
	# --- OPINION MODIFIER ---
	# An elder who likes the Sect Master is more likely to support their proposals.
	var master_ids: Array = sect.members_by_rank.get(Definitions.SectRank.SECT_MASTER, [])
	if not master_ids.is_empty():
		var master = SimulationManager.get_character(master_ids[0])
		if master:
			var opinion_of_master = OpinionManager.get_opinion(elder, master)
			# opinion is -100 to 100; scale it to a -25 to +25 bonus/penalty
			support_score += opinion_of_master * 0.25
	
	# Specific logic based on the proposal type
	match type:
		"change_law":
			if payload.get("law_id") == "elder_stipends":
				# Greedy elders hate taking pay cuts
				if payload.get("new_option_id") == "none":
					support_score -= (greed * 1.5)
				elif payload.get("new_option_id") == "lavish":
					support_score += greed
		"declare_war":
			var ruthlessness = elder.get_personality_value("ruthlessness")
			support_score += (ruthlessness - 50) # Ruthless elders want war, peaceful ones oppose it

	# Add a slight random variance for the "human factor"
	support_score += randf_range(-15.0, 15.0)

	if support_score >= 50.0:
		supporters.append(elder_id)
	else:
		opposers.append(elder_id)

func _resolve_proposal(sect: SectData) -> void:
	# Force any remaining undecided elders to vote immediately at the deadline
	while not undecided.is_empty():
		_evaluate_elder_vote(undecided.pop_back(), sect)
		
	# Sect Master's vote is the tie-breaker
	var passed = supporters.size() >= opposers.size()
	proposal_resolved.emit(self, passed)
