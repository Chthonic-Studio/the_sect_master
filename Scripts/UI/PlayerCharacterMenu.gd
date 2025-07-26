# PlayerCharacterMenu.gd
# Manages the UI display for the player's character (Sect Master).
# Attach this script to the "PlayerCharacterMenu" Control node in main_ui.tscn.

extends Control
class_name PlayerCharacterMenu

# --- UI Node References ---
# We get references to all the labels we need to update.
@onready var name_label: Label = $SectMasterName
@onready var age_label: Label = $Age
@onready var gender_label: Label = $Gender
@onready var realm_label: Label = $CultivationRealm
@onready var renown_label: Label = $HBoxContainer2/Renown
@onready var reputation_label: Label = $HBoxContainer2/Reputation
@onready var health_label: Label = $VBoxContainer/HBoxContainer/VBoxContainer2/HealthValue
@onready var qi_label: Label = $VBoxContainer/HBoxContainer/VBoxContainer2/QiValue
@onready var strength_label: Label = $VBoxContainer/HBoxContainer/VBoxContainer2/StrengthValue
@onready var agility_label: Label = $VBoxContainer/HBoxContainer/VBoxContainer2/AgilityValue
@onready var constitution_label: Label = $VBoxContainer/HBoxContainer/VBoxContainer2/ConstitutionValue
@onready var intelligence_label: Label = $VBoxContainer/HBoxContainer/VBoxContainer2/IntelligenceValue
@onready var perception_label: Label = $VBoxContainer/HBoxContainer/VBoxContainer2/PerceptionValue
@onready var traits_container: HBoxContainer = $TraitsScrollContainer/TraitsHBox


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
	gender_label.text = "%s" % CharacterResource.Gender.keys()[res.gender]
	renown_label.text = "%s" % res.renown_title
	reputation_label.text = "%s" % res.reputation
	
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
		realm_label.text = Definitions.cultivation_realm_to_string(res.cultivation_realm)
	else:
		realm_label.text = "Mortal"
		
	# --- Update Traits ---
	# For now, we'll just show the trait names as labels.
	# Clear any old trait labels first.
	for child in traits_container.get_children():
		child.queue_free()
	
	for trait_name in res.traits:
		var trait_label = Label.new()
		trait_label.text = trait_name.capitalize()
		# You can add theming here later if you want.
		traits_container.add_child(trait_label)

# --- How & Where to Use ---
# 1. Attach this script to the "PlayerCharacterMenu" node in `main_ui.tscn`.
# 2. Ensure PlayerManager is set up as an Autoload.
# 3. The script will automatically connect and update the UI when the player is created.
