extends Node

## MapManager — Singleton that governs the world map state.
## Tracks the active map layer, hovered province/region, and province ownership.

signal hovered_province_changed(province_id: String)
signal hovered_region_changed(region_id: String)
signal map_layer_changed(layer: MapLayer)

enum MapLayer {
	VISUAL,     # Purely aesthetic background — no interaction
	REGIONS,    # Shows region-level borders and highlights
	PROVINCES   # Shows province-level borders and highlights
}

# Map dimensions — set by main_game.gd before MapRenderer initialises.
var map_width: float = 2100.0
var map_height: float = 1500.0

# Currently active interaction layer
var current_layer: MapLayer = MapLayer.REGIONS

# Currently hovered IDs (empty string = none)
var hovered_province_id: String = ""
var hovered_region_id: String = ""

# Province → Sect ownership: { province_id: [sect_id, ...] }
var province_sects: Dictionary = {}

# -------------------------------------------------------------------------
# LAYER CONTROL
# -------------------------------------------------------------------------

func set_map_layer(layer: MapLayer) -> void:
	if current_layer == layer:
		return
	current_layer = layer
	map_layer_changed.emit(layer)

func cycle_map_layer() -> void:
	var next := (current_layer + 1) % MapLayer.size()
	set_map_layer(next as MapLayer)

# -------------------------------------------------------------------------
# HOVER TRACKING (called by the map renderer each frame)
# -------------------------------------------------------------------------

func set_hovered_province(province_id: String) -> void:
	if hovered_province_id == province_id:
		return
	hovered_province_id = province_id
	hovered_province_changed.emit(province_id)
	
	# Automatically update region hover to match the province's region
	if province_id != "":
		var prov = DataManager.provinces_registry.get(province_id)
		if prov:
			set_hovered_region(prov.get("region_id", ""))
	else:
		set_hovered_region("")

func set_hovered_region(region_id: String) -> void:
	if hovered_region_id == region_id:
		return
	hovered_region_id = region_id
	hovered_region_changed.emit(region_id)

# -------------------------------------------------------------------------
# OWNERSHIP
# -------------------------------------------------------------------------

## Assigns a sect to a province. A province can hold any number of sects.
func assign_sect_to_province(sect_id: String, province_id: String) -> void:
	if not DataManager.provinces_registry.has(province_id):
		printerr("MapManager: Unknown province_id: ", province_id)
		return
	if not province_sects.has(province_id):
		province_sects[province_id] = []
	if not province_sects[province_id].has(sect_id):
		province_sects[province_id].append(sect_id)

## Returns all sect IDs located in the given province.
func get_sects_in_province(province_id: String) -> Array:
	return province_sects.get(province_id, [])

## Returns all sect IDs located in the given region (across all its provinces).
func get_sects_in_region(region_id: String) -> Array:
	var result: Array = []
	for p_id in DataManager.provinces_registry:
		var prov = DataManager.provinces_registry[p_id]
		if prov.get("region_id", "") == region_id:
			result.append_array(get_sects_in_province(p_id))
	return result

## Returns the region_id that contains the given province.
func get_region_for_province(province_id: String) -> String:
	var prov = DataManager.provinces_registry.get(province_id, {})
	return prov.get("region_id", "")

## Returns a list of all province IDs that belong to a region.
func get_provinces_in_region(region_id: String) -> Array[String]:
	var result: Array[String] = []
	for p_id in DataManager.provinces_registry:
		if DataManager.provinces_registry[p_id].get("region_id", "") == region_id:
			result.append(p_id)
	return result

## Returns a random province_id, optionally filtered by region_id.
## Returns an empty string if no provinces exist for the requested region.
func get_random_province(region_id: String = "") -> String:
	var pool: Array[String] = []
	if region_id != "":
		pool = get_provinces_in_region(region_id)
		if pool.is_empty():
			push_warning("MapManager: No provinces found for region '%s'." % region_id)
			return ""
	else:
		for p_id in DataManager.provinces_registry:
			pool.append(p_id)
	
	if pool.is_empty():
		return ""
	
	return pool[randi() % pool.size()]
