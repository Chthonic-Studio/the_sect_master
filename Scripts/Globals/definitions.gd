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

const STAT_NAMES = {
	Stat.CONSTITUTION: "constitution",
	Stat.STRENGTH: "strength",
	Stat.AGILITY: "agility",
	Stat.INTELLIGENCE: "intelligence",
	Stat.CHARISMA: "charisma"
}

# --- MARTIAL STATS ---
enum MartialStat {
	INTERNAL_FORCE,  	# Neigong pool (Max Qi)
	QI_FLOW,   			# Qi recovery & training speed
	QINGGONG,        	# Lightness skill (Initiative & Evasion)
	TECHNIQUE,       	# Execution of forms (Accuracy & Parry)
	INSIGHT,         	# Comprehension (Countering & Feints)
	FEROCITY,        	# Killing intent & Crit Chance
	DESTINY		 	# Luck, basically
}

const MARTIAL_STAT_NAMES = {
	MartialStat.INTERNAL_FORCE: "internal_force",
	MartialStat.QI_FLOW: "qi_flow",
	MartialStat.QINGGONG: "qinggong",
	MartialStat.TECHNIQUE: "technique",
	MartialStat.INSIGHT: "insight",
	MartialStat.FEROCITY: "ferocity",
	MartialStat.DESTINY: "destiny"
}
	
# --- DAMAGE & INJURY TYPES & WEAPONS ---
enum DamageType {
	SLASHING,		# Swords, Sabers
	PIERCING,		# Spears, Needles
	BLUNT,			# Staffs, Hammers, Fists
	INTERNAL,		# Palm strikes, Qi-blasts (ignores physical armor)
	POISON,			# Sichuan specialty, damage over time
	PSYCHIC,		# Mental attacks, illusions
}

enum WeaponType{
	SWORD,
	SABER,
	SPEAR,
	NEEDLE,
	STAFF,
	HAMMER,
	FIST,
	UNARMED,
	DAGGER,
	HIDDEN_WEAPON,
	FAN
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

# Cosmic and Social alignment axes (0 to 100, where 50 is neutral)
const ALIGNMENT_STATS = [
	"morality",    # 0 = Demonic/Orthodox, 100 = Righteous. Influences faction relations.
	"karma",       # 0 = Sinner/Heaven's Wrath, 100 = Blessed/Meritorious. Influences tribulation difficulty and luck events.
	"reputation"   # 0 = Unknown, 100 = Jianghu Legend. Influences recruitment and intimidation.
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

# --- SECT SYSTEM DEFINITIONS ---
enum SectAlignment {
	ORTHODOX,
	DEMONIC,
	NEUTRAL,
	UNORTHODOX,
	EVIL
}

# The physical and abstract currencies used by Sects for expansion and upkeep.
enum ResourceType {
	WEALTH,     # Gold/Silver, used for wages and standard purchases
	MATERIALS,  # Wood/Stone/Metal, used for building construction
	MEDICINE,   # Healing salves and common herbs
	ELIXIRS     # Rare elixirs to help with trainings
}

# Abstract macro-stats that define a Sect's standing in the Jianghu.
enum SectStat {
	FACE,       # Prestige/Influence. Spent on diplomacy or forcing demands.
	REPUTATION, # 0 (Despised/Feared) to 100 (Revered).
	KARMA       # 0 (Sinful) to 100 (Meritorious). Affects luck events and tribulation severity.
}

# --- GENERATION CONSTANTS ---
# Centralized math modifiers so you can balance the whole game in one file.
const BASE_STATS_BY_AGE = {
	"child": 5,     # Age 0-12
	"teen": 10,     # Age 13-19
	"adult": 20,    # Age 20-60
	"elder": 15     # Age 60+ 
}

# Age thresholds dictating how many personality traits a character has organically developed.
const PERSONALITY_AGE_THRESHOLDS = {
	6: 0,   # 0-6 years: 0 traits
	12: 1,  # 7-12 years: 1 trait
	17: 2,  # 13-17 years: 2 traits
	999: 3  # 18+ years: 3 traits
}

enum TraitType {
	PERSONALITY,
	COMMON
}

const STAT_CAP = 255
const MAX_TRAITS_PER_CHARACTER = 5

# --- HELPER: STAT MAPPING ---
# Translates string keys from JSON into the Enum values used in code.
func get_stat_enum(stat_name: String) -> int:
	var upper = stat_name.to_upper()
	if Stat.keys().has(upper):
		return Stat[upper]
	return -1

func get_martial_enum(martial_name: String) -> int:
	var upper = martial_name.to_upper()
	if MartialStat.keys().has(upper):
		return MartialStat[upper]
	return -1

func get_weapon_enum(weapon_name: String) -> int:
	var upper = weapon_name.to_upper()
	if WeaponType.keys().has(upper):
		return WeaponType[upper]
	return -1

func get_resource_enum(resource_name: String) -> int:
	var upper = resource_name.to_upper()
	if ResourceType.keys().has(upper):
		return ResourceType[upper]
	return -1

func get_sect_stat_enum(stat_name: String) -> int:
	var upper = stat_name.to_upper()
	if SectStat.keys().has(upper):
		return SectStat[upper]
	return -1
