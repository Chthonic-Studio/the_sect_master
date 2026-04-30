extends Directive

## Focused training retreat: higher stat gains, no social obligations.
## Martial stats improve at 2× normal rate during the retreat.

func _init(duration: int = 30, custom_mods: Dictionary = {}) -> void:
	var applied_mods = custom_mods if not custom_mods.is_empty() else {
		"fatigue_rate": 12.0,
		"loneliness_rate": 6.0,   # Isolated from the sect
		"training_rate": -2.0,    # Negative = training need accumulates SLOWER (they're always training)
	}
	super(duration, applied_mods)
	id = "directive_training_retreat"

func process_tick(character: CharacterData) -> void:
	if not character.is_martial_artist: return

	var apt_mult: float = Definitions.APTITUDE_TRAINING_MULT.get(character.aptitude, 1.0)

	# Daily martial stat gain during a training retreat
	character.base_martial[Definitions.MartialStat.INTERNAL_FORCE] += clampi(int(randf_range(1.5, 3.0) * apt_mult), 1, 5)
	character.base_martial[Definitions.MartialStat.TECHNIQUE] += clampi(int(randf_range(1.0, 2.0) * apt_mult), 1, 4)
	character.base_martial[Definitions.MartialStat.QI_FLOW] += clampi(int(randf_range(0.5, 1.5) * apt_mult), 0, 3)
	character.recalculate_all_stats()

func on_complete(character: CharacterData) -> void:
	character.add_log("Completed an intensive training retreat. The results are palpable.")
	character.check_realm_advancement()
	WorldLogManager.add_log("cultivation", character.get_full_name() + " has returned from a training retreat.")
	EventManager.trigger_event("directive_training_complete", {"initiator": character.char_id})
