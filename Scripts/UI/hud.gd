extends Control

## The primary Heads-Up Display. Registered to the HUD layer.
## Handles time controls and quick-access panel buttons.
## All UI elements are defined in hud.tscn — no nodes are built in code.

func _ready() -> void:
	UIManager.register_panel("hud", self, UIManager.Layer.HUD)
	
	# Connect TimeManager signals
	TimeManager.day_passed.connect(_update_date_label)
	TimeManager.speed_changed.connect(_on_speed_changed)
	TimeManager.month_passed.connect(_on_month_passed)
	
	# Connect Time Controls
	%BtnPause.pressed.connect(func(): TimeManager.set_time_speed(TimeManager.Speed.PAUSED))
	%BtnNormal.pressed.connect(func(): TimeManager.set_time_speed(TimeManager.Speed.NORMAL))
	%BtnFast.pressed.connect(func(): TimeManager.set_time_speed(TimeManager.Speed.FAST))
	%BtnSuperFast.pressed.connect(func(): TimeManager.set_time_speed(TimeManager.Speed.SUPER_FAST))
	
	# Connect Panel Shortcuts
	%BtnSect.pressed.connect(_on_sect_pressed)
	%BtnPlayer.pressed.connect(_on_player_pressed)
	%BtnChronicle.pressed.connect(_on_chronicle_pressed)
	%BtnMenu.pressed.connect(_on_menu_pressed)

## Initialises the HUD with current data right when it's opened.
func setup_panel(_payload: Variant = null) -> void:
	_update_date_label(TimeManager.day)
	_on_speed_changed(TimeManager.current_speed)
	_refresh_resource_bar()

func _refresh_resource_bar() -> void:
	var sect = SimulationManager.get_sect(GameManager.player_sect_id)
	if not sect: return

	%LblWealth.text    = "Gold: "        + str(sect.resources.get(Definitions.ResourceType.WEALTH,    0))
	%LblMaterials.text = "Materials: "   + str(sect.resources.get(Definitions.ResourceType.MATERIALS, 0))
	%LblMedicine.text  = "Medicine: "    + str(sect.resources.get(Definitions.ResourceType.MEDICINE,  0))
	%LblElixirs.text   = "Elixirs: "     + str(sect.resources.get(Definitions.ResourceType.ELIXIRS,   0))
	%LblFace.text      = "Face: "        + str(sect.stats.get(Definitions.SectStat.FACE,       0))
	%LblReputation.text = "Reputation: " + str(sect.stats.get(Definitions.SectStat.REPUTATION, 0))

func _update_date_label(_day: int) -> void:
	%DateLabel.text = TimeManager.get_date_string()

func _on_speed_changed(new_speed: int) -> void:
	%BtnPause.modulate    = Color.GREEN if new_speed == TimeManager.Speed.PAUSED     else Color.WHITE
	%BtnNormal.modulate   = Color.GREEN if new_speed == TimeManager.Speed.NORMAL     else Color.WHITE
	%BtnFast.modulate     = Color.GREEN if new_speed == TimeManager.Speed.FAST       else Color.WHITE
	%BtnSuperFast.modulate = Color.GREEN if new_speed == TimeManager.Speed.SUPER_FAST else Color.WHITE

func _on_month_passed(_month: int) -> void:
	_refresh_resource_bar()

func _on_sect_pressed() -> void:
	var player_sect = SimulationManager.get_sect(GameManager.player_sect_id)
	if player_sect:
		UIManager.open_panel("sect_dashboard", player_sect)
	else:
		printerr("HUD: Player has no valid sect assigned!")

func _on_player_pressed() -> void:
	var player_char = SimulationManager.get_character(GameManager.player_char_id)
	if player_char:
		UIManager.open_panel("character_dashboard", player_char)
	else:
		printerr("HUD: No player character assigned!")

func _on_chronicle_pressed() -> void:
	UIManager.open_panel("world_log")

func _on_menu_pressed() -> void:
	UIManager.open_panel("system_menu")

