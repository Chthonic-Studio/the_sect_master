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

# --- PERSONALITY AXES ---
# These track the hidden "Utility AI" values. 
# Your JSONs will reference these to drive NPC decision making.
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

# --- TALENT LEVELS ---
# Used by the generator to define quality tiers.
enum TalentTier {
	TRASH,     # Gray
	COMMON,    # White
	EARTH,     # Green
	HEAVEN,    # Purple
	MYTHIC     # Gold/Orange
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
