extends Control

@onready var sect_list_vbox = $SectList/SectList_Vbox
@onready var sect_info_container = $SectInfo/SectInfoContainer
@onready var btn_spawn_minor = $VBoxContainer/SpawnNewSect_Minor
@onready var btn_spawn_average = $VBoxContainer/SpawnNewSect_Average
@onready var btn_spawn_major = $VBoxContainer/SpawnNewSect_Major

func _ready() -> void:
	# Run World Gen immediately for debugging purposes
	# Spawns 3 Minor, 2 Average, 1 Major + Premades
	SectGenerator.generate_world_sects(3, 2, 1) 
	
	_refresh_sect_list()
	
	# Connect your debug buttons to the correct Sect Tiers
	btn_spawn_minor.pressed.connect(func(): _spawn_debug_sect(SectGenerator.SectTier.MINOR))
	btn_spawn_average.pressed.connect(func(): _spawn_debug_sect(SectGenerator.SectTier.AVERAGE))
	btn_spawn_major.pressed.connect(func(): _spawn_debug_sect(SectGenerator.SectTier.MAJOR))

func _spawn_debug_sect(tier: int) -> void:
	# Generates a sect, which automatically registers itself in the SimulationManager
	var _sect = SectGenerator._generate_dynamic_sect(tier)
	_refresh_sect_list()

func _refresh_sect_list() -> void:
	# Clear the old list
	for child in sect_list_vbox.get_children():
		child.queue_free()
		
	# Populate with current simulation data
	for sect_id in SimulationManager.sect_repo:
		var sect: SectData = SimulationManager.sect_repo[sect_id]
		
		var btn = Button.new()
		var alignment_str = Definitions.SectAlignment.keys()[sect.alignment]
		btn.text = "%s (%s) - Members: %d" % [sect.sect_name, alignment_str, sect.all_members.size()]
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		
		# Bind the button press to display the info
		btn.pressed.connect(_display_sect_info.bind(sect))
		sect_list_vbox.add_child(btn)

func _display_sect_info(sect: SectData) -> void:
	for child in sect_info_container.get_children():
		child.queue_free()
		
	# Helper lambda to add UI labels quickly
	var add_label = func(title: String, val: String):
		var title_lbl = Label.new()
		title_lbl.text = title
		title_lbl.modulate = Color.AQUA
		
		var val_lbl = Label.new()
		val_lbl.text = val
		val_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		val_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		
		sect_info_container.add_child(title_lbl)
		sect_info_container.add_child(val_lbl)

	add_label.call("ID:", sect.sect_id)
	add_label.call("Name:", sect.sect_name)
	add_label.call("Alignment:", Definitions.SectAlignment.keys()[sect.alignment])
	
	# --- TENETS ---
	var tenet_names: Array[String] = []
	for t_id in sect.active_tenets:
		var t_data = DataManager.tenets_registry.get(t_id, {})
		tenet_names.append(t_data.get("name", t_id))
	var tenet_str = ", ".join(tenet_names) if not tenet_names.is_empty() else "None"
	add_label.call("Tenets:", tenet_str)
	
	# --- RIVAL & RELATIONSHIPS ---
	var rival_name = "None"
	if sect.rival_sect_id != "":
		var rival = SimulationManager.get_sect(sect.rival_sect_id)
		if rival:
			rival_name = rival.sect_name
	add_label.call("Rival Sect:", rival_name)
	
	# Fetch all centralized relationships involving this sect
	var rel_strings: Array[String] = []
	for other_id in SimulationManager.sect_repo:
		if other_id == sect.sect_id:
			continue
		var val = sect.get_relationship(other_id)
		if val != 0:
			var other_sect = SimulationManager.get_sect(other_id)
			if other_sect:
				rel_strings.append("%s: %d" % [other_sect.sect_name, val])
				
	var rel_str = "\n".join(rel_strings) if not rel_strings.is_empty() else "Neutral to all"
	add_label.call("Relationships:", rel_str)
	
	# --- STATS & MEMBERS ---
	add_label.call("Sect Strength:", str(sect.cached_sect_strength))
	add_label.call("Total Members:", str(sect.all_members.size()))
	
	var master_count = sect.members_by_rank.get(Definitions.SectRank.SECT_MASTER, []).size()
	var elder_count = sect.members_by_rank.get(Definitions.SectRank.ELDER, []).size()
	add_label.call("Hierarchy:", "%d Master, %d Elders" % [master_count, elder_count])
	
	var res_string = ""
	for r_enum in sect.resources:
		var r_name = Definitions.ResourceType.keys()[r_enum]
		res_string += "%s: %d | " % [r_name.capitalize(), sect.resources[r_enum]]
	add_label.call("Resources:", res_string)
