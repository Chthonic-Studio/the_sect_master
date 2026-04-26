extends Camera2D
class_name MapCameraController

## Map camera controller.
## Supports WASD / arrow key panning, scroll-wheel zoom,
## and a "fit map to screen" reset triggered by UIManager.map_fit_requested.

# ── CONFIGURATION ────────────────────────────────────────────────
@export var pan_speed: float = 400.0          # pixels per second at zoom 1
@export var pan_speed_fast_multiplier: float = 2.5  # held with Shift
@export var zoom_step: float = 0.15           # zoom fraction per scroll tick
@export var zoom_min: float = 0.25
@export var zoom_max: float = 3.0
@export var smooth_pan: bool = true           # lerp pan for feel
@export var smooth_factor: float = 8.0        # lerp speed (higher = snappier)

# Map world bounds — set these to match your actual map dimensions.
# The renderer and MapManager own the canonical size; we read it here.
@export var map_width: float = 3840.0
@export var map_height: float = 2160.0

# ── INTERNAL ─────────────────────────────────────────────────────
var _target_position: Vector2 = Vector2.ZERO
var _target_zoom: Vector2 = Vector2.ONE
var _panning: bool = false      # mouse middle-button drag
var _pan_start_mouse: Vector2 = Vector2.ZERO
var _pan_start_pos: Vector2 = Vector2.ZERO

func _ready() -> void:
	_fit_to_screen()
	# Listen for the "world_screen" shortcut emitted by UIManager
	UIManager.map_fit_requested.connect(_fit_to_screen)

func _process(delta: float) -> void:
	_handle_keyboard_pan(delta)
	
	if smooth_pan:
		position = position.lerp(_target_position, smooth_factor * delta)
		zoom = zoom.lerp(_target_zoom, smooth_factor * delta)
	else:
		position = _target_position
		zoom = _target_zoom

func _unhandled_input(event: InputEvent) -> void:
	# ── Scroll Wheel Zoom ─────────────────────────────────────────
	if event is InputEventMouseButton:
		if event.pressed:
			if event.button_index == MOUSE_BUTTON_WHEEL_UP:
				_zoom_toward_mouse(event.position, 1.0 + zoom_step)
				get_viewport().set_input_as_handled()
			elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				_zoom_toward_mouse(event.position, 1.0 - zoom_step)
				get_viewport().set_input_as_handled()
			elif event.button_index == MOUSE_BUTTON_MIDDLE:
				_panning = true
				_pan_start_mouse = event.position
				_pan_start_pos = _target_position
				get_viewport().set_input_as_handled()
		else:
			if event.button_index == MOUSE_BUTTON_MIDDLE:
				_panning = false
	
	# ── Middle-Mouse Drag Pan ─────────────────────────────────────
	if event is InputEventMouseMotion and _panning:
		var delta_px: Vector2 = event.position - _pan_start_mouse
		_target_position = _pan_start_pos - delta_px / _target_zoom
		_clamp_position()
		get_viewport().set_input_as_handled()

# ── KEYBOARD PAN ─────────────────────────────────────────────────

func _handle_keyboard_pan(delta: float) -> void:
	var dir := Vector2.ZERO
	
	if Input.is_action_pressed("ui_left") or Input.is_key_pressed(KEY_A):
		dir.x -= 1.0
	if Input.is_action_pressed("ui_right") or Input.is_key_pressed(KEY_D):
		dir.x += 1.0
	if Input.is_action_pressed("ui_up") or Input.is_key_pressed(KEY_W):
		dir.y -= 1.0
	if Input.is_action_pressed("ui_down") or Input.is_key_pressed(KEY_S):
		dir.y += 1.0
	
	if dir == Vector2.ZERO:
		return
	
	var speed := pan_speed
	if Input.is_key_pressed(KEY_SHIFT):
		speed *= pan_speed_fast_multiplier
	
	# Scale pan speed by current zoom so fast-zoomed views feel consistent
	_target_position += dir.normalized() * speed * delta / _target_zoom.x
	_clamp_position()

# ── ZOOM HELPERS ──────────────────────────────────────────────────

func _zoom_toward_mouse(mouse_screen_pos: Vector2, factor: float) -> void:
	var old_zoom := _target_zoom.x
	var new_zoom := clampf(old_zoom * factor, zoom_min, zoom_max)
	if is_equal_approx(new_zoom, old_zoom):
		return
	
	# Keep the world point under the cursor fixed
	var viewport_size := get_viewport_rect().size
	var old_world := _target_position + (mouse_screen_pos - viewport_size * 0.5) / old_zoom
	
	_target_zoom = Vector2(new_zoom, new_zoom)
	_target_position = old_world - (mouse_screen_pos - viewport_size * 0.5) / new_zoom
	_clamp_position()

func _clamp_position() -> void:
	var half_screen := get_viewport_rect().size * 0.5 / _target_zoom.x
	_target_position.x = clampf(_target_position.x, half_screen.x, map_width - half_screen.x)
	_target_position.y = clampf(_target_position.y, half_screen.y, map_height - half_screen.y)

## Zooms and pans so the entire map fits within the viewport.
func _fit_to_screen() -> void:
	var viewport_size := get_viewport_rect().size
	var zoom_x := viewport_size.x / map_width
	var zoom_y := viewport_size.y / map_height
	var fit_zoom := minf(zoom_x, zoom_y)
	fit_zoom = clampf(fit_zoom, zoom_min, zoom_max)
	
	_target_zoom = Vector2(fit_zoom, fit_zoom)
	_target_position = Vector2(map_width * 0.5, map_height * 0.5)
