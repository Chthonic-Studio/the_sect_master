extends Directive

## Deep secluded cultivation. The character enters SimTier.FROZEN for the duration,
## accruing intensive cultivation progress. On completion there is a chance for
## a realm breakthrough — or Qi Deviation (injury) if cultivation is forced.

func _init(duration: int = 90, custom_mods: Dictionary = {}) -> void:
	# Seclusion freezes normal daily decay entirely; we override it with minimal passive state.
	var applied_mods = custom_mods if not custom_mods.is_empty() else {
		"fatigue_rate": 0.0,      # Complete rest for the body while the spirit cultivates
		"loneliness_rate": 8.0,   # Profound isolation
		"training_rate": -5.0,    # Training need satisfied at an accelerated rate
	}
	super(duration, applied_mods)
	id = "directive_seclusion_cultivation"

func process_tick(character: CharacterData) -> void:
	if not character.is_martial_artist: return

	# Freeze social simulation while in seclusion
	# (CharacterData already handles directive bypass of normal AI,
	#  so we just apply the cultivation gains here)
	var apt_mult: float = Definitions.APTITUDE_TRAINING_MULT.get(character.aptitude, 1.0)

	# Seclusion is more efficient than normal training
	character.base_martial[Definitions.MartialStat.INTERNAL_FORCE] += clampi(int(randf_range(2.0, 4.0) * apt_mult), 1, 7)
	character.base_martial[Definitions.MartialStat.QI_FLOW] += clampi(int(randf_range(1.0, 2.5) * apt_mult), 1, 4)
	character.base_martial[Definitions.MartialStat.INSIGHT] += 1 if randf() < 0.3 * apt_mult else 0
	character.recalculate_all_stats()

func on_complete(character: CharacterData) -> void:
	# Check for breakthrough or Qi Deviation
	var apt_mult: float = Definitions.APTITUDE_TRAINING_MULT.get(character.aptitude, 1.0)
	var breakthrough_chance: float = clampf(0.25 * apt_mult, 0.05, 0.80)
	var qi_deviation_chance: float = clampf(0.1 * (1.0 / max(0.3, apt_mult)), 0.02, 0.25)

	# Threshold-based check: fires the breakthrough event if IF meets the realm threshold.
	character.check_realm_advancement()

	# Probability-based path: only fires if the threshold check didn't already set a pending
	# breakthrough (avoids spawning two simultaneous cultivation_breakthrough_attempt events).
	if not character.has_memory("pending_breakthrough"):
		if randf() < breakthrough_chance:
			character.add_log("Emerged from seclusion with a sudden, profound breakthrough!")
			character.add_memory("pending_breakthrough", {"realm": character.current_realm})
			EventManager.trigger_event("cultivation_breakthrough_attempt", {"initiator": character.char_id})
		elif randf() < qi_deviation_chance:
			character.is_hurt = true
			character.add_trait("internal_injury")
			character.add_log("Qi Deviation occurred during deep seclusion. Internal injuries sustained.")
			WorldLogManager.add_log("cultivation", character.get_full_name() + " suffered a Qi Deviation during secluded cultivation.")
		else:
			character.add_log("Emerged from seclusion. The long meditation has refined the Qi channels.")

	if GameManager.is_player(character.char_id):
		WorldLogManager.add_log("cultivation", character.get_full_name() + " has ended their secluded cultivation.")
