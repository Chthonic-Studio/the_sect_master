# SectManagerUI.gd
# Manages the UI for the main sect management panel.
# Place on the root Control node of sect_management_menu.tscn.

extends Control

# === Node References (set these in the Inspector) ===
@export var sect_name_label: Label
@export var spirit_stones_label: Label
@export var materials_label: Label
@export var food_label: Label
@export var gold_label: Label

var _current_sect_id: int = -1

# --- Initialization ---
func _ready() -> void:
	# It's crucial to defer connecting signals until the PlayerManager is ready,
	# as it ensures the player's sect has been created.
	PlayerManager.connect("player_initialized", Callable(self, "_on_player_initialized"), CONNECT_ONE_SHOT)

# --- Signal Handlers ---

# Called once the player's sect and character are ready.
func _on_player_initialized() -> void:
	var player_sect = PlayerManager.get_player_sect()
	if player_sect:
		_current_sect_id = PlayerManager.player_sect_id
		# Connect to the SectManager to listen for resource changes for ANY sect.
		SectManager.connect("sect_resources_updated", Callable(self, "_on_sect_resources_updated"))
		# Update the UI with initial values.
		update_all_fields(player_sect)
	else:
		push_error("SectManagerUI: Player sect not found after initialization!")

# Listens for resource changes and updates the UI only if it's for the player's sect.
func _on_sect_resources_updated(sect_id: int, _resource_name: String, _new_value: int) -> void:
	if sect_id == _current_sect_id:
		var sect_res = SectManager.get_sect_by_id(sect_id)
		if sect_res:
			update_all_fields(sect_res) # For simplicity, we update all fields.

# --- UI Update Logic ---

# Updates all displayed fields with data from the SectResource.
func update_all_fields(sect_res: SectResource) -> void:
	if not is_instance_valid(sect_name_label): return

	sect_name_label.text = sect_res.sect_name
	spirit_stones_label.text = str(sect_res.resources.get("spirit_stones", 0))
	materials_label.text = str(sect_res.resources.get("materials", 0))
	food_label.text = str(sect_res.resources.get("food", 0))
	gold_label.text = str(sect_res.resources.get("gold", 0))
