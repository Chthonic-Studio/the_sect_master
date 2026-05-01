extends Node

## CombatManager — resolves narrative duels between two characters.
## Call resolve_duel() to get a full combat report Dictionary.

signal duel_resolved(result: Dictionary)

const ROUNDS: int = 5

## Returns a Dictionary with keys:
##   winner_id, loser_id, draw: bool
##   round_narrations: Array[String]
##   final_summary: String
##   winner_delta: Dictionary  (stat changes)
##   loser_delta: Dictionary
func resolve_duel(initiator_id: String, target_id: String) -> Dictionary:
	var attacker: CharacterData = SimulationManager.get_character(initiator_id)
	var defender: CharacterData = SimulationManager.get_character(target_id)

	if not attacker or not defender:
		return {}

	var a_hp: float = _get_effective_hp(attacker)
	var d_hp: float = _get_effective_hp(defender)

	var narrations: Array[String] = []
	var a_name: String = attacker.get_full_name()
	var d_name: String = defender.get_full_name()

	for round_num in range(1, ROUNDS + 1):
		var a_dmg: float = _calc_damage(attacker, defender)
		var d_dmg: float = _calc_damage(defender, attacker)

		# INSIGHT grants counter-attack: a chance to dodge and counter
		var a_insight: float = attacker.get_martial_stat(Definitions.MartialStat.INSIGHT)
		var d_insight: float = defender.get_martial_stat(Definitions.MartialStat.INSIGHT)

		var a_dodge_chance: float = defender.get_martial_stat(Definitions.MartialStat.QINGGONG) / 300.0
		var d_dodge_chance: float = attacker.get_martial_stat(Definitions.MartialStat.QINGGONG) / 300.0

		var a_hit: bool = randf() > d_dodge_chance
		var d_hit: bool = randf() > a_dodge_chance

		if a_hit: d_hp -= a_dmg
		if d_hit: a_hp -= d_dmg

		# Counter-attack opportunity from Insight.
		# Note: counter damage is a fresh _calc_damage() roll (intentional — counters
		# represent improvised strikes, distinct from the standard exchange above).
		if d_insight > 60 and randf() < d_insight / 500.0:
			var counter: float = _calc_damage(defender, attacker) * 0.5
			a_hp -= counter
			narrations.append("Round %d: %s launches a brilliant counter — %s is staggered!" % [round_num, d_name, a_name])
		elif a_insight > 60 and randf() < a_insight / 500.0:
			var counter: float = _calc_damage(attacker, defender) * 0.5
			d_hp -= counter
			narrations.append("Round %d: %s reads the opening perfectly — %s is forced back!" % [round_num, a_name, d_name])
		elif a_hit and d_hit:
			narrations.append("Round %d: Both combatants exchange fierce blows, neither yielding ground." % round_num)
		elif a_hit and not d_hit:
			narrations.append("Round %d: %s lands a solid strike as %s fails to evade." % [round_num, a_name, d_name])
		elif not a_hit and d_hit:
			narrations.append("Round %d: %s sidesteps and retaliates, catching %s off guard." % [round_num, d_name, a_name])
		else:
			narrations.append("Round %d: Both warriors circle each other, probing for weakness." % round_num)

		if a_hp <= 0 or d_hp <= 0:
			break

	# --- DETERMINE OUTCOME ---
	var draw: bool = false
	var winner_id: String = ""
	var loser_id: String = ""

	if a_hp <= 0 and d_hp <= 0:
		draw = true
	elif d_hp <= 0:
		winner_id = initiator_id
		loser_id = target_id
	elif a_hp <= 0:
		winner_id = target_id
		loser_id = initiator_id
	else:
		# Both survived — compare remaining HP ratios
		var a_ratio: float = a_hp / _get_effective_hp(attacker)
		var d_ratio: float = d_hp / _get_effective_hp(defender)
		if absf(a_ratio - d_ratio) < 0.1:
			draw = true
		elif a_ratio > d_ratio:
			winner_id = initiator_id
			loser_id = target_id
		else:
			winner_id = target_id
			loser_id = initiator_id

	var summary: String = ""
	if draw:
		summary = "An honourable draw! Both %s and %s acknowledge each other's skill." % [a_name, d_name]
	else:
		var w: CharacterData = SimulationManager.get_character(winner_id)
		var l: CharacterData = SimulationManager.get_character(loser_id)
		if w and l:
			summary = "%s has prevailed! %s concedes defeat." % [w.get_full_name(), l.get_full_name()]

	# --- APPLY CONSEQUENCES ---
	var winner_delta: Dictionary = {}
	var loser_delta: Dictionary = {}

	_apply_duel_consequences(initiator_id, target_id, winner_id, loser_id, draw, winner_delta, loser_delta)

	var result: Dictionary = {
		"winner_id":       winner_id,
		"loser_id":        loser_id,
		"draw":            draw,
		"round_narrations": narrations,
		"final_summary":   summary,
		"winner_delta":    winner_delta,
		"loser_delta":     loser_delta
	}

	duel_resolved.emit(result)
	return result

## Resolves a single combat round given tactic choices.
## a_tactic / d_tactic: "strike_hard", "measured", "defend", "feint"
## Returns a Dictionary with "a_dmg", "d_dmg", "narration".
func resolve_single_round(attacker: CharacterData, defender: CharacterData,
		a_tactic: String, d_tactic: String) -> Dictionary:
	if not attacker or not defender:
		return {}

	var a_name: String = attacker.get_full_name()
	var d_name: String = defender.get_full_name()

	# Tactic multipliers: [atk_mult, def_mult]
	const TACTIC_MULTS: Dictionary = {
		"strike_hard": [1.5, 0.5],
		"measured":    [1.0, 1.0],
		"defend":      [0.5, 1.8],
		"feint":       [0.6, 0.9],
	}

	var a_mults: Array = TACTIC_MULTS.get(a_tactic, [1.0, 1.0])
	var d_mults: Array = TACTIC_MULTS.get(d_tactic, [1.0, 1.0])

	var a_atk_mult: float = a_mults[0]
	var d_atk_mult: float = d_mults[0]
	var a_def_mult: float = a_mults[1]
	var d_def_mult: float = d_mults[1]

	# Feint counters Strike Hard: the reckless attacker is disrupted
	if a_tactic == "feint" and d_tactic == "strike_hard":
		d_atk_mult = 0.0  # Defender's reckless strike is completely disrupted
	if d_tactic == "feint" and a_tactic == "strike_hard":
		a_atk_mult = 0.0  # Attacker's reckless strike is completely disrupted

	var a_base_dmg: float = _calc_damage(attacker, defender)
	var d_base_dmg: float = _calc_damage(defender, attacker)

	# Apply dodge chance
	var a_dodge: float = defender.get_martial_stat(Definitions.MartialStat.QINGGONG) / 300.0
	var d_dodge: float = attacker.get_martial_stat(Definitions.MartialStat.QINGGONG) / 300.0

	var a_hit: bool = randf() > a_dodge
	var d_hit: bool = randf() > d_dodge

	# Effective damage after tactic modifiers
	var a_dmg: float = (a_base_dmg * a_atk_mult / d_def_mult) if a_hit else 0.0
	var d_dmg: float = (d_base_dmg * d_atk_mult / a_def_mult) if d_hit else 0.0

	a_dmg = maxf(0.0, a_dmg)
	d_dmg = maxf(0.0, d_dmg)

	# Build narration
	var narration: String = ""
	match [a_tactic, d_tactic]:
		["strike_hard", "feint"]:
			narration = "%s surges forward recklessly — %s sidesteps and disrupts the assault!" % [a_name, d_name]
		["feint", "strike_hard"]:
			narration = "%s feints brilliantly, redirecting %s's wild charge into empty air!" % [a_name, d_name]
		["defend", "strike_hard"]:
			narration = "%s weathers %s's ferocious assault with a solid defensive form." % [a_name, d_name]
		["strike_hard", "defend"]:
			narration = "%s hammers at %s's defences but cannot break through cleanly." % [a_name, d_name]
		["feint", "feint"]:
			narration = "Both warriors attempt feints simultaneously — a moment of tense standoff."
		_:
			if a_hit and d_hit:
				narration = "Both combatants exchange fierce blows, neither yielding ground."
			elif a_hit and not d_hit:
				narration = "%s lands a decisive strike as %s narrowly evades." % [a_name, d_name]
			elif not a_hit and d_hit:
				narration = "%s manoeuvres past the attack and strikes back at %s." % [d_name, a_name]
			else:
				narration = "Both warriors circle and probe — no decisive exchange this round."

	return {"a_dmg": a_dmg, "d_dmg": d_dmg, "narration": narration}

## Chooses a tactic for an AI combatant based on personality and current HP ratio.
func ai_choose_tactic(character: CharacterData, own_hp: float, own_max_hp: float,
		opponent_hp: float, _opponent_max_hp: float) -> String:
	var insight: float      = character.get_martial_stat(Definitions.MartialStat.INSIGHT)
	var ferocity_stat: float = character.get_martial_stat(Definitions.MartialStat.FEROCITY)
	var ruthlessness: float = character.get_personality_value("ruthlessness")
	var hp_ratio: float     = own_hp / max(1.0, own_max_hp)

	# Desperate: defend or feint when badly wounded
	if hp_ratio < 0.3 and randf() < 0.6:
		return "defend" if randf() < 0.5 else "feint"

	# Insight-heavy characters favour feints to exploit openings
	if insight > 70 and randf() < 0.4:
		return "feint"

	# High ferocity / ruthlessness characters favour aggressive strikes
	if (ferocity_stat > 60 or ruthlessness > 65) and randf() < 0.5:
		return "strike_hard"

	# Winning decisively? Press the advantage
	var opp_ratio: float = opponent_hp / max(1.0, _opponent_max_hp)
	if opp_ratio < 0.5 and hp_ratio > 0.6 and randf() < 0.5:
		return "strike_hard"

	return "measured"

func _get_effective_hp(character: CharacterData) -> float:
	var constitution: float = character.get_stat(Definitions.Stat.CONSTITUTION)
	var realm_bonus: float = character.current_realm * 50.0
	return 100.0 + constitution * 2.0 + realm_bonus

func _calc_damage(attacker: CharacterData, defender: CharacterData) -> float:
	var base_atk: float = attacker.get_martial_stat(Definitions.MartialStat.INTERNAL_FORCE) * 0.4
	base_atk += attacker.get_martial_stat(Definitions.MartialStat.TECHNIQUE) * 0.3
	base_atk += attacker.get_martial_stat(Definitions.MartialStat.FEROCITY) * 0.2

	# Destiny adds a small random luck factor (max ±20%)
	var destiny_roll: float = attacker.get_martial_stat(Definitions.MartialStat.DESTINY)
	base_atk *= (1.0 + (destiny_roll - 50.0) / 500.0)

	# Critical strike chance from FEROCITY
	var ferocity: float = attacker.get_martial_stat(Definitions.MartialStat.FEROCITY)
	if randf() < ferocity / 400.0:
		base_atk *= 1.5

	# Defender TECHNIQUE reduces damage (parrying skill)
	var def_tech: float = defender.get_martial_stat(Definitions.MartialStat.TECHNIQUE)
	base_atk -= def_tech * 0.15

	return maxf(1.0, base_atk + randf_range(-5.0, 5.0))

func _apply_duel_consequences(
	initiator_id: String, target_id: String,
	winner_id: String, loser_id: String, draw: bool,
	winner_delta: Dictionary, loser_delta: Dictionary
) -> void:
	var initiator: CharacterData = SimulationManager.get_character(initiator_id)
	var target: CharacterData = SimulationManager.get_character(target_id)
	if not initiator or not target: return

	# Opinion changes
	initiator.add_directed_opinion(target_id, "dueled", -10, 180)
	target.add_directed_opinion(initiator_id, "dueled", -10, 180)

	var winner: CharacterData = SimulationManager.get_character(winner_id)
	var loser: CharacterData = SimulationManager.get_character(loser_id)

	if draw:
		WorldLogManager.add_log("social", initiator.get_full_name() + " and " + target.get_full_name() + " fought to a honourable draw.")
		return

	if winner and loser:
		# Winner gains FACE/reputation; loser loses it
		var w_sect = SimulationManager.get_sect(winner.sect_id)
		var l_sect = SimulationManager.get_sect(loser.sect_id)

		if w_sect:
			w_sect.stats[Definitions.SectStat.FACE] = clampi(w_sect.stats[Definitions.SectStat.FACE] + 10, 0, 100)
			winner_delta["face"] = 10
		if l_sect:
			l_sect.stats[Definitions.SectStat.FACE] = clampi(l_sect.stats[Definitions.SectStat.FACE] - 5, 0, 100)
			loser_delta["face"] = -5

		# Loser is hurt
		if not loser.is_hurt and randf() < 0.5:
			loser.is_hurt = true
			loser.add_trait("injured")
			loser_delta["injured"] = true

		# Opinion: winner might pity or respect the loser
		winner.add_directed_opinion(loser_id, "defeated_them", 15, 180)
		loser.add_directed_opinion(winner_id, "defeated_by", -20, 360)

		WorldLogManager.add_log("social", winner.get_full_name() + " defeated " + loser.get_full_name() + " in single combat.")
