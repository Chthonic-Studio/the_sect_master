extends HBoxContainer
class_name InfrastructurePanel

var active_sect: SectData

func _ready() -> void:
	# Listen to the daily tick to update the countdowns
	TimeManager.day_passed.connect(_on_day_passed)

func setup_panel(sect: SectData) -> void:
	if active_sect and active_sect.building_completed.is_connected(_on_building_completed):
		active_sect.building_completed.disconnect(_on_building_completed)
		
	active_sect = sect
	
	if active_sect and not active_sect.building_completed.is_connected(_on_building_completed):
		active_sect.building_completed.connect(_on_building_completed)
	
	_refresh_panel()

func _refresh_panel() -> void:
	_refresh_queue()
	_refresh_available_buildings()

# --- LIGHTWEIGHT REFRESH (Runs every in-game day) ---
func _refresh_queue() -> void:
	if not is_instance_valid(active_sect): return
	
	var queue_list = $ConstructionQueue/ActiveQueueList
	
	# Clean old labels
	for child in queue_list.get_children():
		queue_list.remove_child(child)
		child.queue_free()
		
	if active_sect.construction_queue.is_empty():
		var lbl = Label.new()
		lbl.text = "No active projects."
		lbl.add_theme_color_override("font_color", Color.DIM_GRAY)
		queue_list.add_child(lbl)
	else:
		for project in active_sect.construction_queue:
			var b_id = project["building_id"]
			var b_data = DataManager.buildings_registry.get(b_id, {})
			var lbl = Label.new()
			lbl.text = "%s - %d days left" % [b_data.get("name", b_id), project["days_remaining"]]
			queue_list.add_child(lbl)

# --- HEAVY REFRESH (Runs only on click or when a building finishes) ---
func _refresh_available_buildings() -> void:
	if not is_instance_valid(active_sect): return
	
	var available_list = $AvailableBuildings/ScrollContainer/VBoxContainer
	for child in available_list.get_children():
		available_list.remove_child(child)
		child.queue_free()
		
	for b_id in DataManager.buildings_registry:
		var b_data = DataManager.buildings_registry[b_id]
		var container = HBoxContainer.new()
		
		var lbl = Label.new()
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		
		# Check if it's currently building
		var is_in_queue = false
		for q in active_sect.construction_queue:
			if q.get("building_id") == b_id:
				is_in_queue = true
				break
		
		if active_sect.completed_buildings.has(b_id):
			lbl.text = "[Built] " + b_data.get("name", b_id)
			lbl.add_theme_color_override("font_color", Color.AQUAMARINE)
			container.add_child(lbl)
		elif is_in_queue:
			lbl.text = "[Under Construction] " + b_data.get("name", b_id)
			lbl.add_theme_color_override("font_color", Color.PALE_GOLDENROD)
			container.add_child(lbl)
		else:
			lbl.text = b_data.get("name", b_id)
			var btn = Button.new()
			btn.text = "Build"
			btn.disabled = not active_sect.can_build(b_id)
			
			btn.pressed.connect(func():
				if active_sect.start_construction(b_id):
					_refresh_panel()
			)
			container.add_child(btn)
			container.add_child(lbl)
			
		available_list.add_child(container)

# --- EVENT HANDLERS ---

func _on_day_passed(_day: int) -> void:
	# We only recalculate the UI if the player is actively looking at it!
	if is_visible_in_tree():
		_refresh_queue()

func _on_building_completed(_sect: SectData, _building_id: String) -> void:
	# When a building finishes, we MUST do a heavy refresh to change the 
	# "[Under Construction]" label to "[Built]" on the available buildings list.
	if is_visible_in_tree():
		_refresh_panel()
