extends Control

## The primary Heads-Up Display. Registered to the HUD layer.
## Handles time controls and quick-access panel buttons.

func _ready() -> void:
	UIManager.register_panel("hud", self, UIManager.Layer.HUD)
	
	# Connect TimeManager signals
	TimeManager.day_passed.connect(_update_date_label)
	TimeManager.speed_changed.connect(_on_speed_changed)
	
	# Connect Time Controls
	%BtnPause.pressed.connect(func(): TimeManager.set_time_speed(TimeManager.Speed.PAUSED))
	%BtnNormal.pressed.connect(func(): TimeManager.set_time_speed(TimeManager.Speed.NORMAL))
	%BtnFast.pressed.connect(func(): TimeManager.set_time_speed(TimeManager.Speed.FAST))
	%BtnSuperFast.pressed.connect(func(): TimeManager.set_time_speed(TimeManager.Speed.SUPER_FAST))
	
	# Connect Panel Shortcuts
	%BtnSect.pressed.connect(_on_sect_pressed)
	%BtnPlayer.pressed.connect(_on_player_pressed)

## Initializes the HUD with current data right when it's opened.
func setup_panel(_payload: Variant = null) -> void:
	_update_date_label(TimeManager.day)
	_on_speed_changed(TimeManager.current_speed)

func _update_date_label(_day: int) -> void:
	%DateLabel.text = TimeManager.get_date_string()

func _on_speed_changed(new_speed: int) -> void:
	# Provide visual feedback on which speed is active (e.g., modulating color)
	# In a real project, you'd swap out TextureButton normal/pressed textures.
	%BtnPause.modulate = Color.GREEN if new_speed == TimeManager.Speed.PAUSED else Color.WHITE
	%BtnNormal.modulate = Color.GREEN if new_speed == TimeManager.Speed.NORMAL else Color.WHITE
	%BtnFast.modulate = Color.GREEN if new_speed == TimeManager.Speed.FAST else Color.WHITE
	%BtnSuperFast.modulate = Color.GREEN if new_speed == TimeManager.Speed.SUPER_FAST else Color.WHITE

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
