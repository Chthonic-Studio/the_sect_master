# PlayerCharacterMenu.gd
# Manages the UI display for the player's character (Sect Master).
# Attach this script to the "PlayerCharacterMenu" Control node in main_ui.tscn.

extends Control
class_name PlayerCharacterMenu

# --- UI Node References ---
@export_category("Personal Information")
@export var name_label: Label
@export var age_label: Label 
@export var gender_label: Label
@export var realm_label: Label
@export var renown_label: Label
@export var reputation_label: Label
@export_category("Icons")
@export var realm_icon: TextureRect
@export var spiritual_root_icon: TextureRect
@export_category("Stats")
@export var health_label: Label
@export var qi_label: Label
@export var strength_label: Label
@export var agility_label: Label
@export var constitution_label: Label
@export var intelligence_label: Label
@export var perception_label: Label
@export_category("Traits")
@export var traits_container: HBoxContainer


func _ready() -> void:
	# Connect to the PlayerManager's signal. When it emits, we update the UI.
	# This decouples the UI from the game's startup logic.
	PlayerManager.connect("player_initialized", Callable(self, "update_display"))
	
	# Initial update in case the player is already initialized when this UI loads.
	update_display()


# --- Main Update Function ---

# Pulls data from the PlayerManager and updates all UI elements.
func update_display() -> void:
	var res = PlayerManager.player_character_resource
	
	# If there's no player resource yet, do nothing.
	if not res:
		return
		
	# --- Update Basic Info ---
	name_label.text = res.name_display
	age_label.text = "Age: %d" % res.age
	# FIX: The Gender enum is part of the CharacterResource class, not a key on the instance.
	gender_label.text = "Gender: %s" % CharacterResource.Gender.keys()[res.gender]
	renown_label.text = res.renown_title
	reputation_label.text = res.reputation
	
	# --- Update Core Stats ---
	health_label.text = "%d/%d" % [res.current_hp, res.max_hp]
	qi_label.text = "%d/%d" % [res.current_qi, res.max_qi]
	strength_label.text = str(res.strength)
	agility_label.text = str(res.agility)
	constitution_label.text = str(res.constitution)
	intelligence_label.text = str(res.intelligence)
	perception_label.text = str(res.perception)
	
	# --- Update Cultivator Info (if applicable) ---
	if res is CultivatorResource:
		var realm_res: CultivationRealmResource = CultivationManager.get_realm(res.cultivation_realm)
		if realm_res:
			realm_label.text = realm_res.display_name
			realm_icon.texture = realm_res.icon
		else:
			realm_label.text = "Unknown Realm"
			realm_icon.texture = null
	else:
		realm_label.text = "Mortal"
		realm_icon.texture = null
		
	# --- Update Traits ---
	for child in traits_container.get_children():
		child.queue_free()
	
	for trait_id in res.traits:
		var trait_res = TraitManager.get_trait(trait_id)
		if trait_res and trait_res.icon:
			var trait_icon_rect = TextureRect.new()
			trait_icon_rect.texture = trait_res.icon
			trait_icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			trait_icon_rect.custom_minimum_size = Vector2(32, 32) # Set a fixed size for icons
			trait_icon_rect.tooltip_text = "[b]%s[/b]\n%s" % [trait_res.display_name, trait_res.description]
			traits_container.add_child(trait_icon_rect)

# --- How & Where to Use ---
# 1. Attach this script to the "PlayerCharacterMenu" node in `main_ui.tscn`.
# 2. Ensure PlayerManager, CultivationManager, and TraitManager are set up as Autoloads.
# 3. The script will automatically connect and update the UI when the player is created.
