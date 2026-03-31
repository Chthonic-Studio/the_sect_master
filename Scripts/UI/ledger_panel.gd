extends VBoxContainer
class_name LedgerPanel

var active_sect: SectData

func _ready() -> void:
	# Event-driven UI: Only recalculate economy when a month actually passes.
	TimeManager.month_passed.connect(_on_month_passed)

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
	
	# --- ECONOMY ---
	%CurrentWealth.text = str(active_sect.resources.get(Definitions.ResourceType.WEALTH, 0))
	
	var deltas = active_sect.get_projected_monthly_deltas()
	var wealth_delta = deltas.get(Definitions.ResourceType.WEALTH, 0)
	
	# Format delta with a positive sign if profitable
	var delta_prefix = "+" if wealth_delta >= 0 else ""
	%WealthDeltaTooltip.text = "%s%d / month" % [delta_prefix, wealth_delta]
	
	# Color code the income for quick UX readability
	if wealth_delta < 0:
		%WealthDeltaTooltip.add_theme_color_override("font_color", Color.INDIAN_RED)
	else:
		%WealthDeltaTooltip.add_theme_color_override("font_color", Color.PALE_GREEN)

func _on_month_passed(_month: int) -> void:
	# Optimization: Only update the labels if the player is actually looking at this tab
	if is_visible_in_tree():
		_update_ledger()
