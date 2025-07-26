# SectNameGenerator.gd
# Procedural name generator for sects.
# Uses static functions for easy access without needing an instance.
# Place at: res://Scripts/Characters/SectNameGenerator.gd

extends Node
class_name SectNameGenerator

# Enum reference (must match SectResource)
enum CultureGroup { WESTERN, TRADITIONAL }

# --- Name Data Pools ---
# Using a simple [Prefix] + [Suffix] structure for now. Can be expanded easily.
const NAME_POOLS := {
	"WESTERN": {
		"prefixes": ["Argent", "Golden", "Veridian", "Crimson", "Shadow", "Iron", "Adamant"],
		"suffixes": ["Order", "Sodality", "Pact", "Covenant", "Brotherhood", "Garrison", "Circle"]
	},
	"TRADITIONAL": {
		"prefixes": ["Heavenly", "Jade", "Golden", "Dragon", "Phoenix", "Spirit", "Myriad", "Azure", "Scarlet"],
		"suffixes": ["Sect", "Clan", "Palace", "Pavilion", "Mountain", "Valley", "School", "Temple"]
	}
}

# === API ===

# Generates a full sect name based on the provided culture group.
static func generate_sect_name(culture_group: int) -> String:
	var pool_key := ""
	match culture_group:
		CultureGroup.WESTERN:
			pool_key = "WESTERN"
		CultureGroup.TRADITIONAL:
			pool_key = "TRADITIONAL"
		_:
			push_error("Unknown culture_group for sect name generation: %s" % [culture_group])
			return "Nameless Sect"

	var pool = NAME_POOLS[pool_key]
	var prefix = pool["prefixes"][randi() % pool["prefixes"].size()]
	var suffix = pool["suffixes"][randi() % pool["suffixes"].size()]
	
	return "%s %s" % [prefix, suffix]

# --- How & Where to Use ---
# 1. Place this script at res://Scripts/Characters/SectNameGenerator.gd
# 2. Call the static function from anywhere, no instance needed.
#    Example: `var new_name = SectNameGenerator.generate_sect_name(SectResource.CultureGroup.TRADITIONAL)`
