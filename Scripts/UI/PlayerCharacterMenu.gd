# PlayerCharacterMenu.gd
# Manages the UI for the player's character status panel.
# Place on the root Control node of player_character_menu.tscn.

extends Control

# === Node References (set these in the Inspector) ===
@export var name_label: Label
@export var age_label: Label
@export var gender_label: Label
@export var realm_label: Label
@export var renown_label: Label
@export var reputation_label: Label
@export var realm_icon: TextureRect
@export var spiritual_root_icon: TextureRect
@export var health_label: Label
@export var qi_label: Label
@export var strength_label: Label
@export var agility_label: Label
@export var constitution_label: Label
@export var intelligence_label: Label
@export var perception_label: Label
@export var traits_container: HBoxContainer

var _current_character: CharacterResource

# --- Initialization ---
func _ready() -> void:
	# Defer UI updates until the PlayerManager has finished its setup.
	PlayerManager.connect("player_initialized", Callable(self, "_on_player_initialized"), CONNECT_ONE_SHOT)
	# Hide the menu initially until it's populated.
	hide()

# --- Signal Handlers ---

# Called once the player's character is created and ready.
func _on_player_initialized() -> void:
	_current_character = PlayerManager.player_character_resource
	if _current_character:
		update_all_fields()
		show() # Show the menu now that it has data.
		# TODO: Connect to signals on the character resource to update UI when stats change.
	else:
		push_error("PlayerCharacterMenu: Player character resource not found after initialization!")

# --- UI Update Logic ---

# Updates all displayed fields with data from the CharacterResource.
func update_all_fields() -> void:
	if not _current_character: return

	name_label.text = _current_character.name_display
	age_label.text = "Age: %d" % _current_character.age
	gender_label.text = "Gender: %s" % CharacterResource.Gender.keys()[_current_character.gender]
	
	renown_label.text = "Renown: %s" % _current_character.renown_title
	reputation_label.text = "Reputation: %s" % _current_character.reputation
	
	health_label.text = "%d/%d" % [_current_character.current_hp, _current_character.max_hp]
	qi_label.text = "%d/%d" % [_current_character.current_qi, _current_character.max_qi]
	
	strength_label.text = str(_current_character.strength)
	agility_label.text = str(_current_character.agility)
	constitution_label.text = str(_current_character.constitution)
	intelligence_label.text = str(_current_character.intelligence)
	perception_label.text = str(_current_character.perception)
	
	spiritual_root_icon.texture = Definitions.get_spiritual_root_icon(_current_character.spiritual_root)
	
	if _current_character is CultivatorResource:
		var realm_res: CultivationRealmResource = CultivationManager.get_realm(_current_character.cultivation_realm)
		if realm_res:
			realm_label.text = realm_res.display_name
			realm_icon.texture = realm_res.icon
		else:
			realm_label.text = "Unknown Realm"
			realm_icon.texture = null
		realm_label.show()
		realm_icon.show()
	else:
		realm_label.hide()
		realm_icon.hide()
	
	# REASON FOR CHANGE:
	# This new section dynamically populates the trait icons. It clears any old
	# icons, loops through the character's traits, fetches the corresponding
	# TraitResource, and creates a TextureRect for each icon, complete with a helpful tooltip.
	_populate_trait_icons(traits_container, _current_character)

# --- Helper for populating trait icons (can be reused) ---
func _populate_trait_icons(container: HBoxContainer, character_res: CharacterResource) -> void:
	# Clear previous trait icons
	for child in container.get_children():
		child.queue_free()
		
	if not character_res: return

	for trait_id in character_res.traits:
		var trait_res = TraitManager.get_trait(trait_id)
		if trait_res and trait_res.icon:
			var icon_rect = TextureRect.new()
			icon_rect.texture = trait_res.icon
			icon_rect.custom_minimum_size = Vector2(32, 32) # Standardize icon size
			icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon_rect.tooltip_text = "[b]%s[/b]\n%s" % [trait_res.display_name, trait_res.description]
			container.add_child(icon_rect)
