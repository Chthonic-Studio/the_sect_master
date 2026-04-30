extends Node2D
class_name MapRenderer

## Renders the world map using three pre-authored PNG images:
##   base_map.png     — decorative art layer, always visible
##   region_map.png   — flat colour mask one colour per region
##   province_map.png — flat colour mask one colour per province
##
## Hover detection is done by pixel-colour sampling (no polygon maths).
## A shader overlay highlights the currently hovered region or province.
## Province and region name labels are placed at the computed centroid of each
## area. The hovered label receives an outline to make it stand out clearly.

# ── CONFIGURATION ────────────────────────────────────────────────
@export var region_alpha:   float = 0.55
@export var province_alpha: float = 0.65
@export var highlight_color: Color = Color(1.0, 1.0, 1.0, 0.75)
@export var hover_sample_interval: float = 0.04   # seconds between pixel samples

## Stride used when sampling the province image for centroid computation.
## Higher values = faster startup, less precise label placement.
@export var centroid_sample_stride: int = 12

# Inline GLSL shader: highlights pixels whose colour matches target_color.
const _HIGHLIGHT_SHADER := """
shader_type canvas_item;
uniform vec3  target_color  : source_color = vec3(1.0, 0.0, 0.0);
uniform vec4  hilite_color  : source_color = vec4(1.0, 1.0, 1.0, 0.75);
uniform float tolerance     : hint_range(0.0, 0.5) = 0.04;

void fragment() {
    vec3 px = texture(TEXTURE, UV).rgb;
    if (length(px - target_color) < tolerance) {
        COLOR = hilite_color;
    } else {
        discard;
    }
}
"""

# ── INTERNAL ─────────────────────────────────────────────────────
var _base_sprite:     Sprite2D
var _region_sprite:   Sprite2D
var _province_sprite: Sprite2D
var _highlight_sprite: Sprite2D
var _highlight_mat:   ShaderMaterial

# Raw Image objects used for pixel sampling
var _region_img:   Image
var _province_img: Image

# ImageTexture objects kept alive so GC does not collect them
var _base_tex:     ImageTexture
var _region_tex:   ImageTexture
var _province_tex: ImageTexture

var _sample_timer: float = 0.0

# Container nodes for name labels
var _province_label_node: Node2D
var _region_label_node: Node2D

# ID → Label maps for hover-outline effect
var _province_label_map: Dictionary = {}  # province_id → Label
var _region_label_map: Dictionary = {}    # region_id   → Label

# Track which label currently has the hover outline so we can clear it
var _hovered_province_label: Label = null
var _hovered_region_label: Label = null

# ── READY ─────────────────────────────────────────────────────────

func _ready() -> void:
	_load_map_images()
	_setup_sprites()
	_apply_layer_visibility()
	_build_province_labels()
	_build_region_labels()

	MapManager.map_layer_changed.connect(_on_map_layer_changed)
	MapManager.hovered_province_changed.connect(_on_hovered_province_changed)
	MapManager.hovered_region_changed.connect(_on_hovered_region_changed)

# ── IMAGE LOADING ─────────────────────────────────────────────────

func _load_map_images() -> void:
	_region_img   = _try_load_image("res://Assets/Map/region_map.png")
	_province_img = _try_load_image("res://Assets/Map/province_map.png")

	var base_img  = _try_load_image("res://Assets/Map/base_map.png")
	if base_img:
		_base_tex     = ImageTexture.create_from_image(base_img)
	if _region_img:
		_region_tex   = ImageTexture.create_from_image(_region_img)
	if _province_img:
		_province_tex = ImageTexture.create_from_image(_province_img)

func _try_load_image(path: String) -> Image:
	if not FileAccess.file_exists(path):
		push_warning("MapRenderer: Map image not found: %s" % path)
		return null
	var img = Image.load_from_file(path)
	if not img:
		push_warning("MapRenderer: Failed to load image: %s" % path)
	return img

# ── SPRITE SETUP ──────────────────────────────────────────────────

func _setup_sprites() -> void:
	_base_sprite     = _make_sprite("BaseMap",     _base_tex,     1.0)
	_region_sprite   = _make_sprite("RegionMap",   _region_tex,   region_alpha)
	_province_sprite = _make_sprite("ProvinceMap", _province_tex, province_alpha)
	_highlight_sprite = _make_highlight_sprite()

func _make_sprite(node_name: String, tex: ImageTexture, alpha: float) -> Sprite2D:
	var s := Sprite2D.new()
	s.name = node_name
	s.centered = false           # top-left origin: pixel coords match world coords
	s.texture = tex
	s.modulate.a = alpha
	add_child(s)
	return s

func _make_highlight_sprite() -> Sprite2D:
	# The highlight sprite uses the active mask texture + a shader to glow one colour.
	var s := Sprite2D.new()
	s.name = "HoverHighlight"
	s.centered = false

	var shader := Shader.new()
	shader.code = _HIGHLIGHT_SHADER
	_highlight_mat = ShaderMaterial.new()
	_highlight_mat.shader = shader
	_highlight_mat.set_shader_parameter("hilite_color", highlight_color)
	s.material = _highlight_mat

	# Start with no texture (cleared when nothing is hovered)
	add_child(s)
	return s

# ── LABEL HELPERS ─────────────────────────────────────────────────

## Shared helper: creates a styled Label at the centroid position and registers
## it in the provided map dictionary keyed by id.
func _create_label(id: String, display_name: String, cx: float, cy: float,
		parent: Node2D, label_map: Dictionary, font_size: int) -> void:
	var lbl := Label.new()
	lbl.name = "Label_" + id
	lbl.text = display_name
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", font_size)
	lbl.add_theme_color_override("font_color", Color(1.0, 1.0, 0.9))
	lbl.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.85))
	lbl.add_theme_constant_override("shadow_offset_x", 1)
	lbl.add_theme_constant_override("shadow_offset_y", 1)
	# Outline is added/removed dynamically on hover; start at 0
	lbl.add_theme_constant_override("outline_size", 0)
	lbl.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 1.0))
	var label_size: Vector2 = lbl.get_combined_minimum_size()
	lbl.size = label_size
	lbl.position = Vector2(cx - label_size.x * 0.5, cy - label_size.y * 0.5)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(lbl)
	label_map[id] = lbl

## Samples the given image at the given stride and builds a centroid_data dict.
func _compute_centroids(img: Image, hex_to_id: Dictionary) -> Dictionary:
	var centroid_data: Dictionary = {}
	var img_w: int = img.get_width()
	var img_h: int = img.get_height()
	var stride: int = max(1, centroid_sample_stride)

	for y in range(0, img_h, stride):
		for x in range(0, img_w, stride):
			var c: Color = img.get_pixel(x, y)
			var hex: String = _pixel_to_hex(c)
			if hex_to_id.has(hex):
				var id: String = hex_to_id[hex]
				if not centroid_data.has(id):
					centroid_data[id] = {"sum_x": 0.0, "sum_y": 0.0, "count": 0}
				centroid_data[id]["sum_x"] += x
				centroid_data[id]["sum_y"] += y
				centroid_data[id]["count"]  += 1
	return centroid_data

# ── PROVINCE NAME LABELS ──────────────────────────────────────────

## Computes centroid for every province by sampling province_map.png, then
## creates a Label2D-style (Label inside Node2D) for each province name.
## Labels are only shown when the PROVINCES layer is active.
func _build_province_labels() -> void:
	_province_label_node = Node2D.new()
	_province_label_node.name = "ProvinceLabels"
	add_child(_province_label_node)

	if not _province_img:
		return

	var hex_to_id: Dictionary = {}
	for p_id in DataManager.provinces_registry:
		var hex: String = DataManager.provinces_registry[p_id].get("mask_color", "").to_lower()
		if hex != "":
			hex_to_id[hex] = p_id

	if hex_to_id.is_empty():
		return

	var centroid_data: Dictionary = _compute_centroids(_province_img, hex_to_id)

	for p_id in centroid_data:
		var d: Dictionary = centroid_data[p_id]
		if d["count"] == 0:
			continue
		var cx: float = d["sum_x"] / d["count"]
		var cy: float = d["sum_y"] / d["count"]
		var prov_data: Dictionary = DataManager.provinces_registry.get(p_id, {})
		var prov_name: String = prov_data.get("name", p_id)
		_create_label(p_id, prov_name, cx, cy, _province_label_node, _province_label_map, 18)

	_province_label_node.visible = (MapManager.current_layer == MapManager.MapLayer.PROVINCES)

# ── REGION NAME LABELS ────────────────────────────────────────────

## Computes centroid for every region by sampling region_map.png, then
## creates a label for each region name.
## Labels are shown when the REGIONS layer is active.
func _build_region_labels() -> void:
	_region_label_node = Node2D.new()
	_region_label_node.name = "RegionLabels"
	add_child(_region_label_node)

	if not _region_img:
		return

	var hex_to_id: Dictionary = {}
	for r_id in DataManager.regions_registry:
		var hex: String = DataManager.regions_registry[r_id].get("mask_color", "").to_lower()
		if hex != "":
			hex_to_id[hex] = r_id

	if hex_to_id.is_empty():
		return

	var centroid_data: Dictionary = _compute_centroids(_region_img, hex_to_id)

	for r_id in centroid_data:
		var d: Dictionary = centroid_data[r_id]
		if d["count"] == 0:
			continue
		var cx: float = d["sum_x"] / d["count"]
		var cy: float = d["sum_y"] / d["count"]
		var region_data: Dictionary = DataManager.regions_registry.get(r_id, {})
		var region_name: String = region_data.get("name", r_id)
		# Larger font for region labels since they cover a bigger area
		_create_label(r_id, region_name, cx, cy, _region_label_node, _region_label_map, 26)

	_region_label_node.visible = (MapManager.current_layer == MapManager.MapLayer.REGIONS)

# ── LAYER VISIBILITY ──────────────────────────────────────────────

func _apply_layer_visibility() -> void:
	match MapManager.current_layer:
		MapManager.MapLayer.VISUAL:
			_region_sprite.visible   = false
			_province_sprite.visible = false
		MapManager.MapLayer.REGIONS:
			_region_sprite.visible   = true
			_province_sprite.visible = false
		MapManager.MapLayer.PROVINCES:
			_region_sprite.visible   = true
			_province_sprite.visible = true

	if is_instance_valid(_province_label_node):
		_province_label_node.visible = (MapManager.current_layer == MapManager.MapLayer.PROVINCES)
	if is_instance_valid(_region_label_node):
		_region_label_node.visible = (MapManager.current_layer == MapManager.MapLayer.REGIONS)

func _on_map_layer_changed(_layer: int) -> void:
	_apply_layer_visibility()
	_clear_highlight()

# ── HOVER DETECTION ───────────────────────────────────────────────

func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_sample_timer += delta
	if _sample_timer >= hover_sample_interval:
		_sample_timer = 0.0
		_check_mouse_hover()

func _check_mouse_hover() -> void:
	var mouse_world := get_global_mouse_position()
	var px := int(mouse_world.x)
	var py := int(mouse_world.y)

	match MapManager.current_layer:
		MapManager.MapLayer.PROVINCES:
			if _province_img and _in_image_bounds(px, py, _province_img):
				var hex := _pixel_to_hex(_province_img.get_pixel(px, py))
				MapManager.set_hovered_province(MapManager.get_province_by_color(hex))
			else:
				MapManager.set_hovered_province("")

		MapManager.MapLayer.REGIONS:
			if _region_img and _in_image_bounds(px, py, _region_img):
				var hex := _pixel_to_hex(_region_img.get_pixel(px, py))
				MapManager.set_hovered_region(MapManager.get_region_by_color(hex))
				MapManager.set_hovered_province("")
			else:
				MapManager.set_hovered_region("")
				MapManager.set_hovered_province("")

		MapManager.MapLayer.VISUAL:
			MapManager.set_hovered_province("")
			MapManager.set_hovered_region("")

func _in_image_bounds(px: int, py: int, img: Image) -> bool:
	return px >= 0 and py >= 0 and px < img.get_width() and py < img.get_height()

func _pixel_to_hex(c: Color) -> String:
	return "#%02x%02x%02x" % [int(round(c.r * 255)), int(round(c.g * 255)), int(round(c.b * 255))]

# ── CLICK HANDLING ────────────────────────────────────────────────

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return
	if not (event as InputEventMouseButton).pressed:
		return
	if (event as InputEventMouseButton).button_index != MOUSE_BUTTON_LEFT:
		return

	match MapManager.current_layer:
		MapManager.MapLayer.PROVINCES:
			if MapManager.hovered_province_id != "":
				MapManager.province_clicked.emit(MapManager.hovered_province_id)
				get_viewport().set_input_as_handled()
		MapManager.MapLayer.REGIONS:
			if MapManager.hovered_region_id != "":
				MapManager.region_clicked.emit(MapManager.hovered_region_id)
				get_viewport().set_input_as_handled()

# ── HOVER HIGHLIGHT ───────────────────────────────────────────────

func _on_hovered_province_changed(province_id: String) -> void:
	if MapManager.current_layer != MapManager.MapLayer.PROVINCES:
		return
	# Clear the outline on the previously hovered label
	if is_instance_valid(_hovered_province_label):
		_hovered_province_label.add_theme_constant_override("outline_size", 0)
		_hovered_province_label = null

	if province_id == "":
		_clear_highlight()
		return

	var hex: String = DataManager.provinces_registry.get(province_id, {}).get("mask_color", "")
	_set_highlight(_province_tex, hex)

	# Add outline to the label for this province
	if _province_label_map.has(province_id):
		var lbl: Label = _province_label_map[province_id]
		lbl.add_theme_constant_override("outline_size", 3)
		_hovered_province_label = lbl

func _on_hovered_region_changed(region_id: String) -> void:
	# Clear the outline on the previously hovered label
	if is_instance_valid(_hovered_region_label):
		_hovered_region_label.add_theme_constant_override("outline_size", 0)
		_hovered_region_label = null

	if MapManager.current_layer != MapManager.MapLayer.REGIONS:
		return

	if region_id == "":
		_clear_highlight()
		return

	var hex: String = DataManager.regions_registry.get(region_id, {}).get("mask_color", "")
	_set_highlight(_region_tex, hex)

	# Add outline to the label for this region
	if _region_label_map.has(region_id):
		var lbl: Label = _region_label_map[region_id]
		lbl.add_theme_constant_override("outline_size", 4)
		_hovered_region_label = lbl

func _set_highlight(tex: ImageTexture, hex: String) -> void:
	if not tex or hex == "":
		_clear_highlight()
		return
	_highlight_sprite.texture = tex
	var col := Color(hex)
	_highlight_mat.set_shader_parameter("target_color", Vector3(col.r, col.g, col.b))
	_highlight_mat.set_shader_parameter("hilite_color", highlight_color)

func _clear_highlight() -> void:
	_highlight_sprite.texture = null
