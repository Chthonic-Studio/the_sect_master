extends Node2D
class_name MapRenderer

## Renders the world map using three pre-authored PNG images:
##   base_map.png     — decorative art layer, always visible
##   region_map.png   — flat colour mask one colour per region
##   province_map.png — flat colour mask one colour per province
##
## Hover detection is done by pixel-colour sampling (no polygon maths).
## A shader overlay highlights the currently hovered region or province.

# ── CONFIGURATION ────────────────────────────────────────────────
@export var region_alpha:   float = 0.55
@export var province_alpha: float = 0.65
@export var highlight_color: Color = Color(1.0, 1.0, 1.0, 0.75)
@export var hover_sample_interval: float = 0.04   # seconds between pixel samples

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

# ── READY ─────────────────────────────────────────────────────────

func _ready() -> void:
	_load_map_images()
	_setup_sprites()
	_apply_layer_visibility()

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

# ── HOVER HIGHLIGHT ───────────────────────────────────────────────

func _on_hovered_province_changed(province_id: String) -> void:
	if MapManager.current_layer != MapManager.MapLayer.PROVINCES:
		return
	if province_id == "":
		_clear_highlight()
		return
	var hex: String = DataManager.provinces_registry.get(province_id, {}).get("mask_color", "")
	_set_highlight(_province_tex, hex)

func _on_hovered_region_changed(region_id: String) -> void:
	if MapManager.current_layer != MapManager.MapLayer.REGIONS:
		return
	if region_id == "":
		_clear_highlight()
		return
	var hex: String = DataManager.regions_registry.get(region_id, {}).get("mask_color", "")
	_set_highlight(_region_tex, hex)

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
