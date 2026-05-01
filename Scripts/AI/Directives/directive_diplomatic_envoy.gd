extends Directive

## Diplomatic envoy mission: travel to a rival sect to improve relations.
## The target sect relationship is improved on completion.

var target_sect_id: String = ""

func _init(duration: int = 30, custom_mods: Dictionary = {}) -> void:
	var applied_mods = custom_mods if not custom_mods.is_empty() else {
		"fatigue_rate": 8.0,
		"stress_rate": 3.0,
		"loneliness_rate": 3.0,
	}
	super(duration, applied_mods)
	id = "directive_diplomatic_envoy"

func process_tick(_character: CharacterData) -> void:
	pass

func on_complete(character: CharacterData) -> void:
	character.add_log("Completed a diplomatic envoy mission.")

	var my_sect = SimulationManager.get_sect(character.sect_id)
	if not my_sect: return

	# Improve relations with the nearest neighbour sect if no specific target
	var t_id = target_sect_id
	if t_id == "" or not SimulationManager.sect_repo.has(t_id):
		# Find the highest-relation non-allied sect
		var best_rel = -200
		for s_id in SimulationManager.sect_repo:
			if s_id == my_sect.sect_id: continue
			var rel = SimulationManager.get_sect_relationship(my_sect.sect_id, s_id)
			if rel > best_rel and rel < 80:
				best_rel = rel
				t_id = s_id

	if t_id != "":
		var improvement: int = randi_range(10, 25)
		SimulationManager.modify_sect_relationship(my_sect.sect_id, t_id, improvement)
		var t_sect = SimulationManager.get_sect(t_id)
		if t_sect:
			WorldLogManager.add_log("diplomacy", my_sect.sect_name + " has improved relations with " + t_sect.sect_name + " through diplomacy.")

	EventManager.trigger_event("directive_envoy_complete", {"initiator": character.char_id})
