extends Camera2D
class_name MapCameraController

## Map camera controller.
## Supports WASD / arrow key panning (via project input actions),
## scroll-wheel zoom (via zoom_in / zoom_out input actions),
## middle-mouse drag pan, and a "fit map to screen" reset.

# ── CONFIGURATION ────────────────────────────────────────────────
@export var pan_speed: float = 400.0          # pixels per second at zoom 1
@export var pan_speed_fast_multiplier: float = 2.5  # held with Shift
@export var zoom_step: float = 0.15           # zoom fraction per scroll tick
@export var smooth_pan: bool = true           # lerp pan for feel
@export var smooth_factor: float = 8.0        # lerp speed (higher = snappier)

# Zoom limits — computed at runtime in _ready() from map/viewport dimensions.
# zoom_min = fit the full map into the viewport (max zoom-out).
# zoom_max = 1.0 = 1 : 1 pixel (max zoom-in, original art quality).
var zoom_min: float = 0.25   # overridden at runtime
var zoom_max: float = 1.0    # 1:1 pixels

# Map world bounds — set these to match your actual map dimensions.
# The renderer and MapManager own the canonical size; we read it here.
@export var map_width: float = 3840.0
@export var map_height: float = 2160.0

## Viewport (game resolution). Leave at 0 to auto-read from
## ProjectSettings (display/window/size/viewport_width|height) at runtime.
## Set a non-zero value in the Inspector only when you need non-standard sizing.
@export var viewport_width: float = 0.0
@export var viewport_height: float = 0.0

# ── INTERNAL ─────────────────────────────────────────────────────
var _target_position: Vector2 = Vector2.ZERO
var _target_zoom: Vector2 = Vector2.ONE
var _panning: bool = false      # mouse middle-button drag
var _pan_start_mouse: Vector2 = Vector2.ZERO
var _pan_start_pos: Vector2 = Vector2.ZERO

func _ready() -> void:
	# Resolve viewport size from ProjectSettings when not overridden in the Inspector.
	if viewport_width <= 0.0:
		viewport_width = float(ProjectSettings.get_setting("display/window/size/viewport_width", 1200))
	if viewport_height <= 0.0:
		viewport_height = float(ProjectSettings.get_setting("display/window/size/viewport_height", 800))

	# Compute zoom limits from map and viewport dimensions.
	# zoom_min: entire map visible (max zoom-out).
	# zoom_max: 1 : 1 pixels (max zoom-in, no upscaling of the art).
	zoom_max = 1.0
	if map_width <= 0.0 or map_height <= 0.0:
		zoom_min = zoom_max
	else:
		var fit_x := viewport_width / map_width
		var fit_y := viewport_height / map_height
		zoom_min = minf(minf(fit_x, fit_y), zoom_max)

	# Set Camera2D built-in limits so Godot also enforces the map boundary.
	limit_left = 0
	limit_top = 0
	limit_right = int(map_width)
	limit_bottom = int(map_height)
	_fit_to_screen()
	# Ensure this camera is the active one (overrides any static Camera2D in the scene).
	make_current()
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
	if event is InputEventMouseButton:
		# ── Scroll Wheel Zoom (via input actions) ────────────────
		if event.is_action_pressed("zoom_in"):
			_zoom_toward_mouse(event.position, 1.0 + zoom_step)
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed("zoom_out"):
			_zoom_toward_mouse(event.position, 1.0 - zoom_step)
			get_viewport().set_input_as_handled()
		# ── Middle-Mouse Drag Pan ─────────────────────────────────
		elif event.pressed and event.button_index == MOUSE_BUTTON_MIDDLE:
			_panning = true
			_pan_start_mouse = event.position
			_pan_start_pos = _target_position
			get_viewport().set_input_as_handled()
		elif not event.pressed and event.button_index == MOUSE_BUTTON_MIDDLE:
			_panning = false
	
	if event is InputEventMouseMotion and _panning:
		var delta_px: Vector2 = event.position - _pan_start_mouse
		_target_position = _pan_start_pos - delta_px / _target_zoom
		_clamp_position()
		get_viewport().set_input_as_handled()

# ── KEYBOARD PAN ─────────────────────────────────────────────────

func _handle_keyboard_pan(delta: float) -> void:
	var dir := Vector2.ZERO
	
	if Input.is_action_pressed("left"):
		dir.x -= 1.0
	if Input.is_action_pressed("right"):
		dir.x += 1.0
	if Input.is_action_pressed("up"):
		dir.y -= 1.0
	if Input.is_action_pressed("down"):
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
	var vp_size := Vector2(viewport_width, viewport_height)
	var old_world := _target_position + (mouse_screen_pos - vp_size * 0.5) / old_zoom
	
	_target_zoom = Vector2(new_zoom, new_zoom)
	_target_position = old_world - (mouse_screen_pos - vp_size * 0.5) / new_zoom
	_clamp_position()

func _clamp_position() -> void:
	var half_screen := Vector2(viewport_width, viewport_height) * 0.5 / _target_zoom.x
	
	if half_screen.x * 2.0 >= map_width:
		_target_position.x = map_width * 0.5
	else:
		_target_position.x = clampf(_target_position.x, half_screen.x, map_width - half_screen.x)
	
	if half_screen.y * 2.0 >= map_height:
		_target_position.y = map_height * 0.5
	else:
		_target_position.y = clampf(_target_position.y, half_screen.y, map_height - half_screen.y)

## Zooms and pans so the entire map fits within the viewport.
func _fit_to_screen() -> void:
	var vp_size := Vector2(viewport_width, viewport_height)
	var zoom_x := vp_size.x / map_width
	var zoom_y := vp_size.y / map_height
	var fit_zoom := minf(zoom_x, zoom_y)
	fit_zoom = clampf(fit_zoom, zoom_min, zoom_max)
	
	_target_zoom = Vector2(fit_zoom, fit_zoom)
	_target_position = Vector2(map_width * 0.5, map_height * 0.5)
	# Snap immediately so the first frame shows the full map instead of the raw top-left corner.
	zoom = _target_zoom
	position = _target_position

