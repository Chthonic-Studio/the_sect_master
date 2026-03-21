extends Node

# --- CORE CHARACTER STATS ---
# These are the "Raw" values that define a character's physical and mental power.
enum Stat {
	CONSTITUTION, # Health, physical resistance, longevity
	STRENGTH,     # Physical damage, carrying capacity
	AGILITY,      # Attack speed, evasion
	INTELLIGENCE, # Learning speed, spell potency
	CHARISMA      # Sect loyalty, recruitment success, social influence
}

# --- CULTIVATION STATS ---
# Specific to the Wuxia/Xianxia theme.
enum CultivationStat {
	QI_CAPACITY,     # Maximum energy pool
	QI_ABSORPTION,   # How fast they gain XP/Cultivation
	COMPREHENSION,   # Chance to learn rare techniques
	LUCK             # Critical hit chance and random event favorability
}

# --- MARTIAL PROGRESSION ---
# Based on internal energy refinement and Jianghu reputation.
enum MartialRealm {
	UNINITIATED,		# Commoner/Novice
	THIRD_RATE,			# Basic internal energy, local thug level
	SECOND_RATE,		# Proficient, established sect member
	FIRST_RATE,			# Master level, can lead a branch
	PEAK_MASTER,		# Famous in the region
	GRANDMASTER,		# Sect leader level, legendary status
	TRASCENDENT,		# Mythical, "Invincible under the Heavens"
	SUMMIT,				# Last step before immortality
}

# --- PERSONALITY AXES ---
# These track the hidden "Utility AI" values. 
# JSONs will reference these to drive NPC decision making.
const PERSONALITY_STATS = [
	"ambition",     # Drive to rise in rank. High = Confidence; Low = Humility.
	"honor",        # Adherence to rules. High = Integrity/Honesty; Low = Deception.
	"greed",        # Desire for material wealth and resources.
	"sociability",  # Likelihood to form bonds. Covers Empathy, Humor, and Extroversion.
	"ruthlessness", # Willingness to kill. High = Evil/Aggression; Low = Good/Pacifism.
	"discipline",   # Combines Willpower, Tenacity, and Patience. High = rigorous cultivator.
	"curiosity",    # Combines Creativity and Adaptability. Drive to discover new techniques.
	"cunning",      # Combines Resourcefulness and manipulation. Smart survival instinct.
	"loyalty"       # Dedication specifically to the Sect/Master. Distinct from general honor.
]

# --- APTITUDE LEVELS ---
# Used by the generator to define quality tiers.
enum Aptitude {
	MEDIOCRE,			# Slow learning, low Qi ceiling
	STURDY,				# Bonus to External/Physical arts
	FLEXIBLE,			# Bonus to Agility/Lightness skills
	GENIUS,				# Bonus to Intelligence and skill gain speed
	ENLIGHTENED,		# High comprehension for Internal arts
	HEAVEN_SENT,		# Rare 'Martial Skeleton', fast learning in all areas
	WITHERED,			# Blocked meridians, extremely difficult to cultivate
}

# --- CHARACTER STATE ---
enum LifeState {
	HEALTHY,
	INJURED,			# Flesh wounds (External)
	INTERNAL_INJURY,	# Damaged meridians (Qi-based)
	CRIPPLED,			# Permanent stat loss
	MEDITATING,
	RETIRED,			# Left the Jianghu
	DEAD
}

enum Gender {
	MALE,
	FEMALE,
	NON_BINARY,
	NON_HUMAN
}

# --- GEOGRAPHY & CULTURE ---
# Used for name generation, starting traits, and regional bonuses.
enum Culture {
	CENTRAL_PLAINS,		# Standard/Han balance
	SICHUAN,			# Poison/Hidden Weapon affinity, spicy temperament
	JIANGNAN,			# Scholar/Elegant arts, high comprehension
	LINGNAN,			# Hard physical styles, resilient
	WESTERN_REGIONS,	# Exotic styles, high agility
	NORTHERN_BORDER		# Heavy weapons, high strength
}

# --- SECT HIERARCHY ---
enum SectRank {
	LABORER,
	OUTER_DISCIPLE,
	INNER_DISCIPLE,
	CORE_DISCIPLE,
	ELDER,
	SECT_MASTER
}

enum SocialClass {
	PEASANT,
	CITIZEN,
	GENTRY,
	NOBILITY,
	OUTCAST			# Bandits, beggars, etc.
}



# --- GENERATION CONSTANTS ---
# Centralized math modifiers so you can balance the whole game in one file.
const BASE_STATS_BY_AGE = {
	"child": 5,     # Age 0-12
	"teen": 10,     # Age 13-19
	"adult": 20,    # Age 20-60
	"elder": 15     # Age 60+ 
}

const STAT_CAP = 255
const MAX_TRAITS_PER_CHARACTER = 5

# --- HELPER: STAT MAPPING ---
# Translates string keys from JSON into the Enum values used in code.
func get_stat_enum(stat_name: String):
	match stat_name.to_lower():
		"constitution": return Stat.CONSTITUTION
		"strength": return Stat.STRENGTH
		"agility": return Stat.AGILITY
		"intelligence": return Stat.INTELLIGENCE
		"charisma": return Stat.CHARISMA
	return -1
