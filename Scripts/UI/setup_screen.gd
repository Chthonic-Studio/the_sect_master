extends Control

# ---- STATE ----
var _selected_avatar_index: int = 0
var _selected_trait_id: String = ""
var _avatar_buttons: Array[Button] = []
var _trait_buttons: Array[Button] = []

# Ordered lists for character culture dropdown (Page 1)
const CULTURE_ORDER: Array = [
	Definitions.Culture.CENTRAL_PLAINS,
	Definitions.Culture.JIANGNAN,
	Definitions.Culture.SICHUAN,
	Definitions.Culture.LINGNAN,
	Definitions.Culture.WESTERN_REGIONS,
	Definitions.Culture.NORTHERN_BORDER,
	Definitions.Culture.GORYEO
]
const CULTURE_LABELS: Array = [
	"Central Plains", "Jiangnan", "Sichuan", "Lingnan",
	"Western Regions", "Northern Border", "Goryeo"
]

# Ordered region list for the sect location selector (Page 2).
const REGION_ORDER: Array = [
	"central_plains", "jiangnan", "sichuan", "lingnan",
	"western_regions", "northern_border", "goryeo"
]
const REGION_LABELS: Array = [
	"Central Plains", "Jiangnan", "Sichuan", "Lingnan",
	"Western Regions", "Northern Border", "Goryeo"
]

const ALIGNMENT_ORDER: Array = [
	Definitions.SectAlignment.ORTHODOX,
	Definitions.SectAlignment.NEUTRAL,
	Definitions.SectAlignment.UNORTHODOX,
	Definitions.SectAlignment.DEMONIC,
	Definitions.SectAlignment.EVIL
]
const ALIGNMENT_LABELS: Array = ["Orthodox", "Neutral", "Unorthodox", "Demonic", "Evil"]

const ORG_TYPE_ORDER: Array = [
	Definitions.OrgType.SECT,
	Definitions.OrgType.CLAN,
	Definitions.OrgType.CULT
]
const ORG_TYPE_LABELS: Array = ["Sect", "Clan", "Cult"]

const APTITUDE_ORDER: Array = [
	Definitions.Aptitude.GENIUS,
	Definitions.Aptitude.MEDIOCRE,
	Definitions.Aptitude.WITHERED
]
const APTITUDE_LABELS: Array = ["Gifted (Genius)", "Ordinary (Average)", "Arduous Path (Withered)"]

const LAW_PRESETS: Array = ["council_rule", "absolute_master"]
const LAW_PRESET_LABELS: Array = ["Council Traditions (Elders share power)", "Iron Rule (Master's word is law)"]

const SECT_TIER_ORDER: Array = [SectGenerator.SectTier.MINOR, SectGenerator.SectTier.AVERAGE]
const SECT_TIER_LABELS: Array = ["Small Band (~10 members)", "Established Sect (~20 members)"]

const POP_SCALE_LABELS: Array = ["Low (1,500)", "Normal (3,000)", "High (5,000)"]
const POP_SCALE_VALUES: Array = [1500, 3000, 5000]

# Starting trait pool shown to the player (personality traits with flavor)
const STARTING_TRAITS: Array = [
	"disciplined", "cunning", "altruistic", "arrogant", "impulsive"
]

const GENDER_LABELS: Array = ["Male", "Female", "Non-Binary"]

# ---- READY ----
func _ready() -> void:
	_populate_page1_dropdowns()
	_populate_page1_avatar_grid()
	_populate_page1_trait_buttons()
	_populate_page2_dropdowns()
	_populate_page3_dropdowns()
	_connect_signals()

func _populate_page1_dropdowns() -> void:
	for i in GENDER_LABELS.size():
		%GenderDropdown.add_item(GENDER_LABELS[i], i)
	for i in CULTURE_LABELS.size():
		%CultureDropdown.add_item(CULTURE_LABELS[i], i)
	for i in APTITUDE_LABELS.size():
		%AptitudeDropdown.add_item(APTITUDE_LABELS[i], i)

func _populate_page1_avatar_grid() -> void:
	for i in range(12):
		var btn := Button.new()
		btn.text = "P%d" % (i + 1)
		btn.custom_minimum_size = Vector2(80, 80)
		btn.pressed.connect(_on_avatar_selected.bind(i, btn))
		%AvatarGrid.add_child(btn)
		_avatar_buttons.append(btn)
	_highlight_avatar(0)

func _populate_page1_trait_buttons() -> void:
	for t_id in STARTING_TRAITS:
		var trait_data = DataManager.traits_registry.get(t_id, {})
		var btn := Button.new()
		btn.text = trait_data.get("name", t_id.capitalize()).replace("_", " ")
		btn.custom_minimum_size = Vector2(120, 40)
		btn.pressed.connect(_on_trait_selected.bind(t_id, btn))
		%TraitContainer.add_child(btn)
		_trait_buttons.append(btn)

func _populate_page2_dropdowns() -> void:
	for lbl in ALIGNMENT_LABELS:
		%AlignmentDropdown.add_item(lbl)
	for i in ORG_TYPE_LABELS.size():
		%OrgTypeDropdown.add_item(ORG_TYPE_LABELS[i], i)
	for lbl in LAW_PRESET_LABELS:
		%LawPresetDropdown.add_item(lbl)
	for lbl in SECT_TIER_LABELS:
		%SectTierDropdown.add_item(lbl)

	# Show description for first org type
	_on_org_type_changed(0)

	# Populate region dropdown - culture is derived, not user-selected
	for i in REGION_LABELS.size():
		%SectRegionDropdown.add_item(REGION_LABELS[i], i)

	# Populate tenet dropdown for default alignment
	_repopulate_tenets(0)
	# Initialise province dropdown and culture info for the first region
	_on_region_changed(0)

func _populate_page3_dropdowns() -> void:
	for lbl in POP_SCALE_LABELS:
		%PopScaleDropdown.add_item(lbl)
	%PopScaleDropdown.selected = 1

func _connect_signals() -> void:
	%BtnPage1Next.pressed.connect(_on_page1_next)
	%BtnPage2Back.pressed.connect(_on_page2_back)
	%BtnPage2Next.pressed.connect(_on_page2_next)
	%BtnPage3Back.pressed.connect(_on_page3_back)
	%BtnStart.pressed.connect(_on_start_pressed)
	%AlignmentDropdown.item_selected.connect(_repopulate_tenets)
	%OrgTypeDropdown.item_selected.connect(_on_org_type_changed)
	%SectRegionDropdown.item_selected.connect(_on_region_changed)

# ---- AVATAR SELECTION ----
func _on_avatar_selected(index: int, btn: Button) -> void:
	_selected_avatar_index = index
	_highlight_avatar(index)

func _highlight_avatar(index: int) -> void:
	for i in _avatar_buttons.size():
		_avatar_buttons[i].modulate = Color(0.5, 0.5, 0.5) if i != index else Color(1.0, 0.8, 0.2)

# ---- TRAIT SELECTION ----
func _on_trait_selected(trait_id: String, btn: Button) -> void:
	_selected_trait_id = trait_id
	for b in _trait_buttons:
		b.modulate = Color(0.6, 0.6, 0.6)
	btn.modulate = Color(1.0, 0.85, 0.3)

# ---- TENET REPOPULATION ----
func _repopulate_tenets(align_index: int) -> void:
	%TenetDropdown.clear()
	var alignment_value = ALIGNMENT_ORDER[align_index]
	var selected_alignment_key = Definitions.SectAlignment.keys()[alignment_value]

	for t_id in DataManager.tenets_registry:
		var t_data = DataManager.tenets_registry[t_id]
		var allowed: Array = t_data.get("allowed_alignments", [])
		if allowed.has(selected_alignment_key):
			%TenetDropdown.add_item(t_data.get("name", t_id), %TenetDropdown.item_count)
			%TenetDropdown.set_item_metadata(%TenetDropdown.item_count - 1, t_id)

	if %TenetDropdown.item_count == 0:
		%TenetDropdown.add_item("(None available)")
		%TenetDropdown.set_item_metadata(0, "")
	%TenetDropdown.selected = 0

# ---- ORG TYPE CASCADE ----
func _on_org_type_changed(org_index: int) -> void:
	var org_key: String = Definitions.OrgType.keys()[ORG_TYPE_ORDER[org_index]]
	%OrgTypeDescLabel.text = Definitions.ORG_TYPE_DESCRIPTIONS.get(org_key, "")

# ---- REGION / PROVINCE / CULTURE CASCADE ----
func _on_region_changed(region_index: int) -> void:
	var region_id: String = REGION_ORDER[region_index]

	# Rebuild province dropdown for this region
	%SectProvinceDropdown.clear()
	var provinces := MapManager.get_provinces_in_region(region_id)
	for p_id in provinces:
		var p_data: Dictionary = DataManager.provinces_registry.get(p_id, {})
		%SectProvinceDropdown.add_item(p_data.get("name", p_id))
		%SectProvinceDropdown.set_item_metadata(%SectProvinceDropdown.item_count - 1, p_id)
	if %SectProvinceDropdown.item_count > 0:
		%SectProvinceDropdown.selected = 0

	# Update culture info labels (culture is determined by region)
	var region_data: Dictionary = DataManager.regions_registry.get(region_id, {})
	var culture_key: String = region_data.get("culture", "CENTRAL_PLAINS")
	var culture_name: String = culture_key.replace("_", " ").capitalize()
	%SectCultureNameLabel.text = "Culture: %s" % culture_name
	%SectCultureDescLabel.text = Definitions.CULTURE_DESCRIPTIONS.get(
		culture_key, "A culture with its own unique martial traditions.")

# ---- PAGE NAVIGATION ----
func _on_page1_next() -> void:
	%P1ValidationLabel.text = ""
	var first = %FirstNameInput.text.strip_edges()
	var last  = %LastNameInput.text.strip_edges()
	if first == "" or last == "":
		%P1ValidationLabel.text = "Please enter both a first name and a surname."
		return
	if _selected_trait_id == "" and not STARTING_TRAITS.is_empty():
		_on_trait_selected(STARTING_TRAITS[0], _trait_buttons[0])
	$CenterContainer/MainBox/Page1.visible = false
	$CenterContainer/MainBox/Page2.visible = true

func _on_page2_back() -> void:
	$CenterContainer/MainBox/Page2.visible = false
	$CenterContainer/MainBox/Page1.visible = true

func _on_page2_next() -> void:
	%P2ValidationLabel.text = ""
	var sect_name = %SectNameInput.text.strip_edges()
	if sect_name == "":
		%P2ValidationLabel.text = "Please enter a sect name."
		return
	$CenterContainer/MainBox/Page2.visible = false
	$CenterContainer/MainBox/Page3.visible = true

func _on_page3_back() -> void:
	$CenterContainer/MainBox/Page3.visible = false
	$CenterContainer/MainBox/Page2.visible = true

# ---- GAME START ----
func _on_start_pressed() -> void:
	# Collect all form data first
	var first_name     = %FirstNameInput.text.strip_edges()
	var last_name      = %LastNameInput.text.strip_edges()
	var gender         = Definitions.Gender.values()[%GenderDropdown.selected]
	var char_culture   = CULTURE_ORDER[%CultureDropdown.selected]
	var aptitude       = APTITUDE_ORDER[%AptitudeDropdown.selected]
	var avatar_idx     = _selected_avatar_index
	var starting_trait = _selected_trait_id

	var sect_name  = %SectNameInput.text.strip_edges()
	var alignment  = ALIGNMENT_ORDER[%AlignmentDropdown.selected]
	var org_type   = ORG_TYPE_ORDER[%OrgTypeDropdown.selected]
	var tenet_id   = %TenetDropdown.get_item_metadata(%TenetDropdown.selected) if %TenetDropdown.item_count > 0 else ""
	var law_preset = LAW_PRESETS[%LawPresetDropdown.selected]
	var sect_tier  = SECT_TIER_ORDER[%SectTierDropdown.selected]

	# Derive sect culture and province from selected region / province
	var region_index: int = %SectRegionDropdown.selected
	var region_id: String = REGION_ORDER[region_index]
	var region_data: Dictionary = DataManager.regions_registry.get(region_id, {})
	var culture_key: String = region_data.get("culture", "CENTRAL_PLAINS")
	var sect_culture: int = Definitions.Culture.get(culture_key, Definitions.Culture.CENTRAL_PLAINS)

	var province_id: String = ""
	if %SectProvinceDropdown.item_count > 0:
		province_id = %SectProvinceDropdown.get_item_metadata(%SectProvinceDropdown.selected)

	var pop_scale   = POP_SCALE_VALUES[%PopScaleDropdown.selected]
	var start_year  = int(%StartYearSpinBox.value)

	# Disable the start button to prevent double-clicks during generation
	%BtnStart.disabled = true

	# Show the loading overlay and wait one frame so it actually renders before
	# the heavy generation work begins.
	var overlay = _create_loading_overlay()
	add_child(overlay)
	await get_tree().process_frame
	await get_tree().process_frame

	_generate_game(
		first_name, last_name, gender, char_culture, aptitude, avatar_idx, starting_trait,
		sect_name, alignment, org_type, sect_culture, province_id, tenet_id, law_preset, sect_tier,
		pop_scale, start_year
	)

## Builds a fullscreen dark overlay with a "Generating World…" message.
func _create_loading_overlay() -> Control:
	var overlay := Control.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP

	var bg := ColorRect.new()
	bg.color = Color(0.04, 0.04, 0.07, 0.92)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(bg)

	var lbl := Label.new()
	lbl.text = "Generating World…\nPlease wait."
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	lbl.add_theme_font_size_override("font_size", 28)
	lbl.add_theme_color_override("font_color", Color(0.9, 0.85, 0.6))
	overlay.add_child(lbl)

	return overlay

func _generate_game(
	first_name: String, last_name: String, gender: int, char_culture: int,
	aptitude: int, avatar_idx: int, starting_trait: String,
	sect_name: String, alignment: int, org_type: int, sect_culture: int, province_id: String,
	tenet_id: String, law_preset: String, sect_tier: SectGenerator.SectTier,
	pop_scale: int, start_year: int
) -> void:

	# 1. Apply world settings
	TimeManager.year = start_year
	WorldManager.target_world_population = pop_scale

	# 2. Generate the world's rival sects.
	SectGenerator.generate_world_sects()

	# 3. Generate the player's sect with full overrides
	var sect_tenets: Array[String] = []
	if tenet_id != "":
		sect_tenets.append(tenet_id)

	var starting_laws: Dictionary = { "sect_authority": law_preset }
	var members_count: int = 10 if sect_tier == SectGenerator.SectTier.MINOR else 20

	var player_sect = SectGenerator.generate_custom_sect(sect_tier, {
		"name":          sect_name,
		"alignment":     alignment,
		"org_type":      org_type,
		"culture":       sect_culture,
		"province_id":   province_id,
		"tenets":        sect_tenets,
		"laws":          starting_laws,
		"members_count": members_count
	})

	# 4. Locate the Sect Master and apply player customisations
	var masters: Array = player_sect.members_by_rank.get(Definitions.SectRank.SECT_MASTER, [])
	if not masters.is_empty():
		var master_char: CharacterData = SimulationManager.get_character(masters[0])
		if master_char:
			master_char.first_name   = first_name
			master_char.last_name    = last_name
			master_char.gender       = gender
			master_char.culture      = char_culture
			master_char.avatar_index = avatar_idx
			master_char.aptitude     = aptitude
			if starting_trait != "":
				master_char.add_trait(starting_trait)
			master_char.recalculate_all_stats()
			GameManager.set_player_character(master_char.char_id)

	# 5. Transition to the game
	SceneManager.goto_game_scene()
