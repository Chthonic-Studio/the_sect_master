extends Directive

## Send a disciple on a scouting patrol to gather intelligence on rival sects
## in a target province. On completion, reveals sect information.

var target_province_id: String = ""

func _init(duration: int = 20, custom_mods: Dictionary = {}) -> void:
	var applied_mods = custom_mods if not custom_mods.is_empty() else {
		"fatigue_rate": 10.0,
		"stress_rate": 2.0,
		"loneliness_rate": 4.0,
	}
	super(duration, applied_mods)
	id = "directive_scouting_patrol"

func process_tick(_character: CharacterData) -> void:
	# Small chance of a random encounter during patrol
	if randf() < 0.02:
		_character.state_vars["stress"] = minf(100.0, _character.state_vars.get("stress", 0.0) + 10.0)

func on_complete(character: CharacterData) -> void:
	character.add_log("Returned from a scouting patrol with valuable intelligence.")
	WorldLogManager.add_log("politics", character.get_full_name() + " has returned from a scouting mission.")

	# Reward: Sect gains Face from successful intelligence gathering
	var sect = SimulationManager.get_sect(character.sect_id)
	if sect:
		sect.stats[Definitions.SectStat.FACE] = clampi(
			sect.stats.get(Definitions.SectStat.FACE, 0) + 5, 0, 100)

	# Fire a directive_complete event so the event system can elaborate
	EventManager.trigger_event("directive_scouting_complete", {"initiator": character.char_id})
