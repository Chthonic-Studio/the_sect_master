extends Control

## The primary Heads-Up Display. Registered to the HUD layer.
## Handles time controls and quick-access panel buttons.

var _resource_labels: Dictionary = {}  # resource_enum -> Label

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

	# Inject "Menu" button into LeftControls
	var left_controls = %BtnSect.get_parent()
	var btn_menu := Button.new()
	btn_menu.text = "Menu"
	btn_menu.custom_minimum_size = Vector2(80, 40)
	btn_menu.pressed.connect(_on_menu_pressed)
	left_controls.add_child(btn_menu)
	# Ensure it appears after BtnChronicle
	left_controls.move_child(btn_menu, 3)

	# Build the resource bar below the top bar
	_build_resource_bar()

## Initializes the HUD with current data right when it's opened.
func setup_panel(_payload: Variant = null) -> void:
	_update_date_label(TimeManager.day)
	_on_speed_changed(TimeManager.current_speed)
	_refresh_resource_bar()

func _build_resource_bar() -> void:
	# Create a second row at the top of the screen, anchored below the TopBar
	var resource_bar := HBoxContainer.new()
	resource_bar.name = "ResourceBar"
	resource_bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	resource_bar.set_anchor(SIDE_TOP, 0.0)
	resource_bar.set_anchor(SIDE_BOTTOM, 0.0)
	resource_bar.offset_top = 55.0
	resource_bar.offset_bottom = 78.0
	resource_bar.offset_left = 15.0
	resource_bar.offset_right = -15.0
	resource_bar.add_theme_constant_override("separation", 20)
	resource_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(resource_bar)

	# Resource labels
	const RES_DEFS = [
		[Definitions.ResourceType.WEALTH,    "Gold",      Color(0.95, 0.85, 0.3)],
		[Definitions.ResourceType.MATERIALS, "Materials", Color(0.7, 0.85, 0.6)],
		[Definitions.ResourceType.MEDICINE,  "Medicine",  Color(0.5, 0.9, 0.7)],
		[Definitions.ResourceType.ELIXIRS,   "Elixirs",   Color(0.7, 0.5, 0.95)],
	]

	for res_def in RES_DEFS:
		var r_enum = res_def[0]
		var r_name: String = res_def[1]
		var r_color: Color = res_def[2]

		var lbl := Label.new()
		lbl.add_theme_font_size_override("font_size", 12)
		lbl.add_theme_color_override("font_color", r_color)
		lbl.text = r_name + ": —"
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		resource_bar.add_child(lbl)
		_resource_labels[r_enum] = lbl

	# Sect stats: FACE and REPUTATION
	const STAT_DEFS = [
		[Definitions.SectStat.FACE,       "Face",       Color(0.9, 0.6, 0.4)],
		[Definitions.SectStat.REPUTATION, "Reputation", Color(0.8, 0.8, 0.9)],
	]

	for stat_def in STAT_DEFS:
		var s_enum = stat_def[0]
		var s_name: String = stat_def[1]
		var s_color: Color = stat_def[2]

		var lbl := Label.new()
		lbl.add_theme_font_size_override("font_size", 12)
		lbl.add_theme_color_override("font_color", s_color)
		lbl.text = s_name + ": —"
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		resource_bar.add_child(lbl)
		# Store with negative key to differentiate from ResourceType enums
		_resource_labels[-(s_enum + 1)] = lbl

func _refresh_resource_bar() -> void:
	var sect = SimulationManager.get_sect(GameManager.player_sect_id)
	if not sect: return

	var res_names = ["Gold", "Materials", "Medicine", "Elixirs"]
	var r_enums = [
		Definitions.ResourceType.WEALTH,
		Definitions.ResourceType.MATERIALS,
		Definitions.ResourceType.MEDICINE,
		Definitions.ResourceType.ELIXIRS,
	]
	for i in range(r_enums.size()):
		var r_enum = r_enums[i]
		if _resource_labels.has(r_enum):
			_resource_labels[r_enum].text = res_names[i] + ": " + str(sect.resources.get(r_enum, 0))

	var stat_names = ["Face", "Reputation"]
	var s_enums = [Definitions.SectStat.FACE, Definitions.SectStat.REPUTATION]
	for i in range(s_enums.size()):
		var key = -(s_enums[i] + 1)
		if _resource_labels.has(key):
			_resource_labels[key].text = stat_names[i] + ": " + str(sect.stats.get(s_enums[i], 0))

func _update_date_label(_day: int) -> void:
	%DateLabel.text = TimeManager.get_date_string()

func _on_speed_changed(new_speed: int) -> void:
	%BtnPause.modulate = Color.GREEN if new_speed == TimeManager.Speed.PAUSED else Color.WHITE
	%BtnNormal.modulate = Color.GREEN if new_speed == TimeManager.Speed.NORMAL else Color.WHITE
	%BtnFast.modulate = Color.GREEN if new_speed == TimeManager.Speed.FAST else Color.WHITE
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
