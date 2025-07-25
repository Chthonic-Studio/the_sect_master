# definitions.gd
# Holds global enums and constants for the game.
# HOW & WHERE TO USE:
# 1. Place in res://scripts/data/definitions.gd
# 2. Use 'extends Resource' so it can be loaded or referenced easily.
# 3. Use as a singleton if needed, or simply preload/import where necessary.

extends Node

# --- Cultivation Realms ---
enum CultivationRealm {
	QI_GATHERING,
	QI_BUILDING,
	GOLDEN_CORE,
	NASCENT_SOUL,
	HEAVENLY_SPIRIT,
	SOUL_TRANSFORMATION,
	ORIGIN_SELF,
	ASTRAL_BODY,
	DEMI_GOD
}

# --- Elements (for affinities, techniques, etc.) ---
enum Element {
	NONE,
	FIRE,
	WATER,
	EARTH,
	WOOD,
	METAL
	# Expand as needed
}

# --- Utility: Get string names for enums (for UI/debug) ---
static func cultivation_realm_to_string(realm: int) -> String:
	return CultivationRealm.keys()[realm]

static func element_to_string(element: int) -> String:
	return Element.keys()[element]
