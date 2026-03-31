extends Control
class_name SectDashboard

## Master controller for the Sect UI. 
## Routes the active SectData down to the specialized sub-panels.

var active_sect: SectData

func setup_dashboard(sect: SectData) -> void:
	if active_sect:
		# Clean up old connections if we switch views between different sects
		active_sect.strength_recalculated.disconnect(_on_strength_recalculated)
		
	active_sect = sect
	
	# Initial Header Update
	%SectNameLabel.text = active_sect.sect_name
	_on_strength_recalculated(active_sect)
	
	# Listen for dynamic strength changes (e.g., someone leveled up or died)
	active_sect.strength_recalculated.connect(_on_strength_recalculated)
	
	# Propagate the data downward to our modular panels
	# (We use has_method to prevent crashes if a panel isn't scripted yet)
	if %LedgerPanel.has_method("setup_panel"): %LedgerPanel.setup_panel(active_sect)
	if %HierarchyPanel.has_method("setup_panel"): %HierarchyPanel.setup_panel(active_sect)
	if %InfrastructurePanel.has_method("setup_panel"): %InfrastructurePanel.setup_panel(active_sect)
	if %PreceptsPanel.has_method("setup_panel"): %PreceptsPanel.setup_panel(active_sect)

func _on_strength_recalculated(sect: SectData) -> void:
	%SectStrengthLabel.text = "SS: " + str(sect.cached_sect_strength)
