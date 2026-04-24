extends Node2D
class_name MapRenderer

## Renders the world map as procedurally generated Polygon2D nodes.
## Three render layers:
##   - background: a solid coloured backdrop
##   - regions: one Polygon2D per region
##   - provinces: one Polygon2D per province
## On hover, the currently highlighted polygon gains a visible outline.

# ── CONFIGURATION ────────────────────────────────────────────────
@export var region_alpha: float = 0.55
@export var province_alpha: float = 0.65
@export var hover_outline_color: Color = Color(1.0, 1.0, 1.0, 0.85)
@export var hover_outline_width: float = 3.0

# ── INTERNAL ─────────────────────────────────────────────────────
var _region_polys: Dictionary = {}    # region_id → Polygon2D
var _province_polys: Dictionary = {}  # province_id → Polygon2D
var _current_hover_poly: Polygon2D = null

# Layer nodes (children set up in _ready)
var _background_layer: ColorRect
var _region_layer: Node2D
var _province_layer: Node2D
var _outline_layer: Node2D

func _ready() -> void:
	_setup_layers()
	_build_region_polygons()
	_build_province_polygons()
	_apply_layer_visibility()
	
	MapManager.map_layer_changed.connect(_on_map_layer_changed)
	MapManager.hovered_province_changed.connect(_on_hovered_province_changed)
	MapManager.hovered_region_changed.connect(_on_hovered_region_changed)

func _setup_layers() -> void:
	_background_layer = ColorRect.new()
	_background_layer.name = "BackgroundLayer"
	_background_layer.color = Color(0.14, 0.12, 0.10, 1.0)
	# Use the map dimensions stored as metadata by main_game.gd
	var map_w: float = MapManager.get_meta("map_width", 2100.0)
	var map_h: float = MapManager.get_meta("map_height", 1500.0)
	_background_layer.size = Vector2(map_w, map_h)
	add_child(_background_layer)
	
	_region_layer = Node2D.new()
	_region_layer.name = "RegionLayer"
	add_child(_region_layer)
	
	_province_layer = Node2D.new()
	_province_layer.name = "ProvinceLayer"
	add_child(_province_layer)
	
	_outline_layer = Node2D.new()
	_outline_layer.name = "OutlineLayer"
	add_child(_outline_layer)

func _build_region_polygons() -> void:
	for r_id in DataManager.regions_registry:
		var r_data: Dictionary = DataManager.regions_registry[r_id]
		var poly := Polygon2D.new()
		poly.name = "Region_" + r_id
		poly.polygon = _parse_polygon(r_data.get("polygon", []))
		var col := Color(r_data.get("color", "888888"))
		col.a = region_alpha
		poly.color = col
		poly.set_meta("map_id", r_id)
		_region_layer.add_child(poly)
		_region_polys[r_id] = poly

func _build_province_polygons() -> void:
	for p_id in DataManager.provinces_registry:
		var p_data: Dictionary = DataManager.provinces_registry[p_id]
		var poly := Polygon2D.new()
		poly.name = "Province_" + p_id
		poly.polygon = _parse_polygon(p_data.get("polygon", []))
		var col := Color(p_data.get("color", "888888"))
		col.a = province_alpha
		poly.color = col
		poly.set_meta("map_id", p_id)
		_province_layer.add_child(poly)
		_province_polys[p_id] = poly

func _parse_polygon(raw: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for pt in raw:
		if pt is Array and pt.size() >= 2:
			out.append(Vector2(float(pt[0]), float(pt[1])))
	return out

# ── LAYER VISIBILITY ─────────────────────────────────────────────

func _apply_layer_visibility() -> void:
	match MapManager.current_layer:
		MapManager.MapLayer.VISUAL:
			_region_layer.visible = false
			_province_layer.visible = false
		MapManager.MapLayer.REGIONS:
			_region_layer.visible = true
			_province_layer.visible = false
		MapManager.MapLayer.PROVINCES:
			_region_layer.visible = true
			_province_layer.visible = true

func _on_map_layer_changed(_layer: int) -> void:
	_apply_layer_visibility()
	_clear_outline()

# ── MOUSE HOVER DETECTION ─────────────────────────────────────────

func _process(_delta: float) -> void:
	if not is_visible_in_tree():
		return
	_check_mouse_hover()

func _check_mouse_hover() -> void:
	var mouse_world := get_global_mouse_position()
	
	match MapManager.current_layer:
		MapManager.MapLayer.PROVINCES:
			var found := ""
			for p_id in _province_polys:
				var poly: Polygon2D = _province_polys[p_id]
				if Geometry2D.is_point_in_polygon(mouse_world, poly.polygon):
					found = p_id
					break
			MapManager.set_hovered_province(found)
		
		MapManager.MapLayer.REGIONS:
			var found := ""
			for r_id in _region_polys:
				var poly: Polygon2D = _region_polys[r_id]
				if Geometry2D.is_point_in_polygon(mouse_world, poly.polygon):
					found = r_id
					break
			MapManager.set_hovered_region(found)
			MapManager.set_hovered_province("")

# ── OUTLINE DRAWING ───────────────────────────────────────────────

func _on_hovered_province_changed(province_id: String) -> void:
	if MapManager.current_layer == MapManager.MapLayer.PROVINCES:
		_draw_outline_for_poly(
			_province_polys.get(province_id) if province_id != "" else null
		)

func _on_hovered_region_changed(region_id: String) -> void:
	if MapManager.current_layer == MapManager.MapLayer.REGIONS:
		_draw_outline_for_poly(
			_region_polys.get(region_id) if region_id != "" else null
		)

func _draw_outline_for_poly(poly: Polygon2D) -> void:
	_clear_outline()
	if poly == null or poly.polygon.is_empty():
		return
	
	# Draw the outline as a Line2D on the outline layer
	var line := Line2D.new()
	line.width = hover_outline_width
	line.default_color = hover_outline_color
	line.joint_mode = Line2D.LINE_JOINT_ROUND
	line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	line.end_cap_mode = Line2D.LINE_CAP_ROUND
	
	var pts: PackedVector2Array = poly.polygon
	for pt in pts:
		line.add_point(pt)
	# Close the loop
	if pts.size() > 0:
		line.add_point(pts[0])
	
	_outline_layer.add_child(line)

func _clear_outline() -> void:
	for child in _outline_layer.get_children():
		child.queue_free()
