extends MarginContainer

## Handles static numbers and traits using node caching to eliminate GC spikes.

var _cached_stats: Dictionary = {}
var _cached_traits: Dictionary = {}

func refresh_panel(character: CharacterData, dashboard: CharacterDashboard) -> void:
	_refresh_stats(character, dashboard)
	_refresh_traits(character, dashboard)

func _refresh_stats(character: CharacterData, dashboard: CharacterDashboard) -> void:
	var can_see_stats = dashboard.is_data_visible("base_stats")
	var grid = %StatsGrid
	
	for stat_enum in Definitions.Stat.values():
		var stat_name = Definitions.Stat.keys()[stat_enum].capitalize()
		var stat_val = str(character.get_stat(stat_enum)) if can_see_stats else "???"
		
		# Instantiate only if it doesn't exist in our pool
		if not _cached_stats.has(stat_enum):
			var name_lbl = Label.new()
			var val_lbl = Label.new()
			
			grid.add_child(name_lbl)
			grid.add_child(val_lbl)
			
			_cached_stats[stat_enum] = { "name_lbl": name_lbl, "val_lbl": val_lbl }
			
		# Update existing nodes
		var cached = _cached_stats[stat_enum]
		cached.name_lbl.text = stat_name + ":"
		cached.val_lbl.text = stat_val

func _refresh_traits(character: CharacterData, dashboard: CharacterDashboard) -> void:
	var list = %TraitsList
	var can_see_traits = dashboard.is_data_visible("traits")
	
	# First, hide all cached trait labels to reset the view safely
	for t_id in _cached_traits:
		_cached_traits[t_id].hide()
		
	if not can_see_traits:
		# Special fallback label for hidden traits
		if not _cached_traits.has("HIDDEN_TRAIT_MSG"):
			var lbl = Label.new()
			lbl.add_theme_color_override("font_color", Color.GRAY)
			list.add_child(lbl)
			_cached_traits["HIDDEN_TRAIT_MSG"] = lbl
			
		var hidden_lbl = _cached_traits["HIDDEN_TRAIT_MSG"]
		hidden_lbl.text = "Traits Hidden"
		hidden_lbl.show()
		return
		
	# Show and update only the traits this character currently has
	for t_id in character.traits:
		if not _cached_traits.has(t_id):
			var lbl = Label.new()
			lbl.add_theme_color_override("font_color", Color.AQUAMARINE)
			list.add_child(lbl)
			_cached_traits[t_id] = lbl
			
		var lbl = _cached_traits[t_id]
		var t_data = DataManager.traits_registry.get(t_id, {})
		
		lbl.text = "[" + t_data.get("display_name", t_id) + "]" 
		lbl.tooltip_text = t_data.get("description", "")
		lbl.show()
