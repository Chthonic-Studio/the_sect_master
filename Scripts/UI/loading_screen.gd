extends Control

## Fullscreen world-generation loading screen.
## Reads SceneManager._pending_game_params and drives the entire generation
## pipeline so neither setup_screen nor main_menu need to do heavy work.

var _status_label: Label
var _progress_bar: ProgressBar
var _spinner_label: Label
var _spinner_tween: Tween

const SPINNER_FRAMES: Array[String] = ["◐", "◓", "◑", "◒"]
var _spinner_frame: int = 0

func _ready() -> void:
	_setup_ui()
	SectGenerator.generation_progress.connect(_on_generation_progress)
	# Defer so the scene renders at least one frame before blocking generation begins.
	_start_generation.call_deferred()

# --- UI Construction (fully programmatic, no .tscn layout needed) ---

func _setup_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	var bg := ColorRect.new()
	bg.color = Color(0.04, 0.04, 0.08, 1.0)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 24)
	center.add_child(vbox)

	var title := Label.new()
	title.text = "THE SECT MASTER"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 44)
	title.add_theme_color_override("font_color", Color(0.90, 0.80, 0.40))
	vbox.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Generating World"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 20)
	subtitle.add_theme_color_override("font_color", Color(0.70, 0.65, 0.55))
	vbox.add_child(subtitle)

	_spinner_label = Label.new()
	_spinner_label.text = SPINNER_FRAMES[0]
	_spinner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_spinner_label.add_theme_font_size_override("font_size", 28)
	_spinner_label.add_theme_color_override("font_color", Color(0.80, 0.75, 0.50))
	vbox.add_child(_spinner_label)

	_progress_bar = ProgressBar.new()
	_progress_bar.min_value = 0.0
	_progress_bar.max_value = 1.0
	_progress_bar.value = 0.0
	_progress_bar.custom_minimum_size = Vector2(420, 22)
	vbox.add_child(_progress_bar)

	_status_label = Label.new()
	_status_label.text = "Preparing the realm..."
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.add_theme_font_size_override("font_size", 16)
	_status_label.add_theme_color_override("font_color", Color(0.65, 0.62, 0.55))
	vbox.add_child(_status_label)

	_start_spinner()

func _start_spinner() -> void:
	_spinner_tween = create_tween().set_loops()
	_spinner_tween.tween_callback(_advance_spinner).set_delay(0.15)

func _advance_spinner() -> void:
	_spinner_frame = (_spinner_frame + 1) % SPINNER_FRAMES.size()
	if is_instance_valid(_spinner_label):
		_spinner_label.text = SPINNER_FRAMES[_spinner_frame]

func _on_generation_progress(stage: String, percent: float) -> void:
	if is_instance_valid(_status_label):
		_status_label.text = stage
	if is_instance_valid(_progress_bar):
		_progress_bar.value = percent

# --- Generation Pipeline ---

func _start_generation() -> void:
	var params: Dictionary = SceneManager._pending_game_params
	await _generate_game_from_params(params)

func _generate_game_from_params(params: Dictionary) -> void:
	_on_generation_progress("Applying world settings...", 0.0)

	TimeManager.year = params.get("start_year", 740)
	WorldManager.target_world_population = params.get("pop_scale", 3000)

	# Async world generation with progress signals (emitted by SectGenerator)
	await SectGenerator.generate_world_sects()

	_on_generation_progress("Setting up your sect...", 0.95)

	# --- Player Sect Creation ---
	var sect_tenets: Array[String] = []
	var tenet_id: String = params.get("tenet_id", "")
	if tenet_id != "":
		sect_tenets.append(tenet_id)

	var law_preset: String = params.get("law_preset", "")
	var starting_laws: Dictionary = {}
	if law_preset != "":
		starting_laws = {"sect_authority": law_preset}

	var sect_tier: SectGenerator.SectTier = params.get("sect_tier", SectGenerator.SectTier.AVERAGE)
	var members_count: int = params.get("members_count",
		randi_range(10 * int(sect_tier), 20 * int(sect_tier)))

	var overrides: Dictionary = {
		"name":       params.get("sect_name", ""),
		"alignment":  params.get("alignment",  Definitions.SectAlignment.NEUTRAL),
		"org_type":   params.get("org_type",   Definitions.OrgType.SECT),
		"culture":    params.get("sect_culture", Definitions.Culture.CENTRAL_PLAINS),
		"province_id": params.get("province_id", ""),
		"tenets":     sect_tenets,
		"laws":       starting_laws,
		"members_count": members_count,
	}
	var player_sect: SectData = SectGenerator.generate_custom_sect(sect_tier, overrides)

	# --- Player Character Setup ---
	var masters: Array = player_sect.members_by_rank.get(Definitions.SectRank.SECT_MASTER, [])
	if not masters.is_empty():
		var master_char: CharacterData = SimulationManager.get_character(masters[0])
		if master_char:
			var first_name: String = params.get("first_name", "")
			var last_name: String  = params.get("last_name",  "")
			if first_name != "":
				master_char.first_name = first_name
			if last_name != "":
				master_char.last_name = last_name

			var gender: int = params.get("gender", -1)
			if gender >= 0:
				master_char.gender = gender

			var char_culture: int = params.get("char_culture", -1)
			if char_culture >= 0:
				master_char.culture = char_culture

			var avatar_idx: int = params.get("avatar_idx", 0)
			master_char.avatar_index = avatar_idx

			var aptitude: int = params.get("aptitude", -1)
			if aptitude >= 0:
				master_char.aptitude = aptitude

			var starting_trait: String = params.get("starting_trait", "")
			if starting_trait != "":
				master_char.add_trait(starting_trait)

			master_char.recalculate_all_stats()
			# Setting the player triggers SimulationManager.sync_all_sim_tiers(),
			# promoting this sect's members to MICRO and demoting everyone else.
			GameManager.set_player_character(master_char.char_id)

	_on_generation_progress("Entering the realm...", 1.0)
	SceneManager.goto_game_scene()
