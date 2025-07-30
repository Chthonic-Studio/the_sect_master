# definitions.gd
# Holds global enums and constants for the game.
# HOW & WHERE TO USE:
# 1. Place in res://scripts/data/definitions.gd
# 2. Use 'extends Resource' so it can be loaded or referenced easily.
# 3. Use as a singleton if needed, or simply preload/import where necessary.

extends Node

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

# REASON FOR CHANGE:
# We are centralizing the spiritual root icons here for easy access across the game.
# Preloading them ensures they are loaded into memory once at the start of the game,
# which is efficient. The dictionary maps the enum from CharacterResource to a texture.
const SPIRITUAL_ROOT_ICONS := {
	CharacterResource.SpiritualRootType.NONE: preload("res://Assets/UI/Icons/SpiritualRoot_None.png"),
	CharacterResource.SpiritualRootType.COMMON: preload("res://Assets/UI/Icons/SpiritualRoot_Common.png"),
	CharacterResource.SpiritualRootType.SUPERIOR: preload("res://Assets/UI/Icons/SpiritualRoot_Superior.png"),
	CharacterResource.SpiritualRootType.HEAVENLY: preload("res://Assets/UI/Icons/SpiritualRoot_Heavenly.png"),
	CharacterResource.SpiritualRootType.MUTATED: preload("res://Assets/UI/Icons/SpiritualRoot_Mutated.png"),
	CharacterResource.SpiritualRootType.DEMONIC: preload("res://Assets/UI/Icons/SpiritualRoot_Demonic.png"),
	CharacterResource.SpiritualRootType.GHOSTLY: preload("res://Assets/UI/Icons/SpiritualRoot_Ghostly.png")
}


# --- Utility: Get string names for enums (for UI/debug) ---
static func element_to_string(element: int) -> String:
	return Element.keys()[element]

# REASON FOR CHANGE:
# This new helper function provides a safe and easy way for UI scripts to get the
# correct icon texture for a given spiritual root type.
static func get_spiritual_root_icon(root_type: CharacterResource.SpiritualRootType) -> Texture2D:
	return SPIRITUAL_ROOT_ICONS.get(root_type, null)
