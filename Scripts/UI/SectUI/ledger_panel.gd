extends VBoxContainer
class_name LedgerPanel

var active_sect: SectData
var grid: GridContainer
var _cached_resource_labels: Dictionary = {}

func _ready() -> void:
	TimeManager.month_passed.connect(_on_month_passed)
	grid = $OtherResources/ResourcesGrid
	
	# Pre-clear the placeholder labels created in the Godot Editor
	# We do this exactly once during instantiation, never during runtime.
	for child in grid.get_children():
		child.queue_free()

func setup_panel(sect: SectData) -> void:
	active_sect = sect
	_update_ledger()

func _update_ledger() -> void:
	if not active_sect:
		return
		
	# --- STATS ---
	%FaceStat.text = str(active_sect.stats.get(Definitions.SectStat.FACE, 0))
	%ReputationStat.text = str(active_sect.stats.get(Definitions.SectStat.REPUTATION, 50))
	%KarmaStat.text = str(active_sect.stats.get(Definitions.SectStat.KARMA, 50))
	
	# --- ECONOMY (Wealth) ---
	var deltas = active_sect.get_projected_monthly_deltas()
	var wealth_delta = deltas.get(Definitions.ResourceType.WEALTH, 0)
	
	%CurrentWealth.text = str(active_sect.resources.get(Definitions.ResourceType.WEALTH, 0))
	
	var delta_prefix = "+" if wealth_delta >= 0 else ""
	%WealthDeltaTooltip.text = "%s%d / month" % [delta_prefix, wealth_delta]
	
	if wealth_delta < 0:
		%WealthDeltaTooltip.add_theme_color_override("font_color", Color.INDIAN_RED)
	else:
		%WealthDeltaTooltip.add_theme_color_override("font_color", Color.PALE_GREEN)
	
	# --- OTHER RESOURCES ---
	# Dynamically populate non-wealth resources using our cache
	for r_enum in Definitions.ResourceType.values():
		if r_enum == Definitions.ResourceType.WEALTH:
			continue
			
		var res_name = Definitions.ResourceType.keys()[r_enum].capitalize()
		var current_val = active_sect.resources.get(r_enum, 0)
		var delta_val = deltas.get(r_enum, 0)
		
		# Pool creation
		if not _cached_resource_labels.has(r_enum):
			var lbl = Label.new()
			grid.add_child(lbl)
			_cached_resource_labels[r_enum] = lbl
			
		# Text update
		var cached_lbl = _cached_resource_labels[r_enum]
		var d_prefix = "+" if delta_val >= 0 else ""
		cached_lbl.text = "%s: %d (%s%d)" % [res_name, current_val, d_prefix, delta_val]

func _on_month_passed(_month: int) -> void:
	if is_visible_in_tree():
		_update_ledger()
