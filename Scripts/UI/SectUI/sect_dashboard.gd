extends Control
class_name SectDashboard

## Master controller for the Sect UI. 
## Routes the active SectData down to the specialized sub-panels.

var active_sect: SectData

func _ready() -> void:
	# Tell the UIManager this panel exists and is ready to receive data, and put it in the PANELS layer.
	UIManager.register_panel("sect_dashboard", self, UIManager.Layer.PANELS)
	$CloseButton.pressed.connect(func(): UIManager.close_panel("sect_dashboard"))

func setup_dashboard(sect: SectData) -> void:
	if active_sect and active_sect.strength_recalculated.is_connected(_on_strength_recalculated):
		active_sect.strength_recalculated.disconnect(_on_strength_recalculated)
		
	active_sect = sect
	
	%SectNameLabel.text = active_sect.sect_name
	_on_strength_recalculated(active_sect)
	
	if not active_sect.strength_recalculated.is_connected(_on_strength_recalculated):
		active_sect.strength_recalculated.connect(_on_strength_recalculated)
	
	if %LedgerPanel.has_method("setup_panel"):
		%LedgerPanel.setup_panel(active_sect)
	if %HierarchyPanel.has_method("setup_panel"):
		%HierarchyPanel.setup_panel(active_sect)
	if %InfrastructurePanel.has_method("setup_panel"):
		%InfrastructurePanel.setup_panel(active_sect)
	if %PreceptsPanel.has_method("setup_panel"):
		%PreceptsPanel.setup_panel(active_sect)

func _on_strength_recalculated(sect: SectData) -> void:
	%SectStrengthLabel.text = "SS: " + str(sect.cached_sect_strength)
