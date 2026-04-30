extends PlayerAction

## Attempt to recruit a character into the player's sect.
## Requires the target to be unaffiliated OR from a lower-ranking sect.
## Costs FACE and requires a CHARISMA check.

const FACE_COST: int = 5

func _init() -> void:
	id = "action_recruit"
	display_name = "Recruit to Sect"
	tooltip = "Offer this person a place in your sect. Costs Face and depends on your Charisma."

func can_execute(initiator: CharacterData, target: CharacterData) -> bool:
	# Player must have a sect
	var player_sect = SimulationManager.get_sect(initiator.sect_id)
	if not player_sect:
		return false

	# Target must be unaffiliated
	if target.sect_id != "":
		return false

	# Must be a martial artist (no recruiting peasants as disciples)
	if not target.is_martial_artist:
		return false

	# Must have enough Face
	if player_sect.stats.get(Definitions.SectStat.FACE, 0) < FACE_COST:
		return false

	return true

func execute(initiator: CharacterData, target: CharacterData) -> void:
	var player_sect = SimulationManager.get_sect(initiator.sect_id)
	if not player_sect: return

	# Spend Face
	player_sect.stats[Definitions.SectStat.FACE] = clampi(
		player_sect.stats.get(Definitions.SectStat.FACE, 0) - FACE_COST, 0, 100)

	# Charisma check: base chance is 40%, modified by relative CHARISMA vs target INTELLIGENCE
	var initiator_charisma: float = initiator.get_stat(Definitions.Stat.CHARISMA)
	var target_intelligence: float = target.get_stat(Definitions.Stat.INTELLIGENCE)
	var success_chance: float = 0.4 + (initiator_charisma - target_intelligence) / 200.0
	success_chance = clampf(success_chance, 0.1, 0.9)

	# Opinion bonus
	var opinion: int = OpinionManager.get_opinion(target, initiator)
	success_chance += opinion / 400.0

	if randf() < success_chance:
		# SUCCESS: add the character to the sect
		target.sect_id = initiator.sect_id
		player_sect.add_member(target.char_id, Definitions.SectRank.OUTER_DISCIPLE)

		initiator.add_log("Successfully recruited " + target.get_full_name() + " into " + player_sect.sect_name + ".")
		target.add_log("Accepted an invitation from " + initiator.get_full_name() + " to join " + player_sect.sect_name + ".")
		WorldLogManager.add_log("social", target.get_full_name() + " has joined " + player_sect.sect_name + " as an Outer Disciple.")

		# Positive opinion impact
		target.add_directed_opinion(initiator.char_id, "recruited_me", 30, 720)
	else:
		# FAILURE: target declines
		initiator.add_log(target.get_full_name() + " declined the invitation to join the sect.")
		target.add_directed_opinion(initiator.char_id, "recruitment_attempt", -5, 90)
		WorldLogManager.add_log("social", target.get_full_name() + " has declined an invitation to join " + player_sect.sect_name + ".")
