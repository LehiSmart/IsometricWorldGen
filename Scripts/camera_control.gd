extends Camera2D

# Panning settings
var dragging: bool = false
var last_mouse_pos: Vector2 = Vector2.ZERO

# Zoom settings
@export var min_zoom: float = 0.5
@export var max_zoom: float = 3.0
@export var zoom_speed: float = 0.1

func _unhandled_input(event: InputEvent) -> void:
	# --- Panning (Middle Mouse or Right Mouse Click & Drag) ---
	if event is InputEventMouseButton:
		# Change MOUSE_BUTTON_MIDDLE to MOUSE_BUTTON_LEFT or MOUSE_BUTTON_RIGHT if preferred
		if event.button_index == MOUSE_BUTTON_MIDDLE or event.button_index == MOUSE_BUTTON_RIGHT:
			if event.pressed:
				dragging = true
				last_mouse_pos = event.position
			else:
				dragging = false

	if event is InputEventMouseMotion and dragging:
		# Move camera inversely to mouse displacement
		var delta = event.position - last_mouse_pos
		position -= delta / zoom
		last_mouse_pos = event.position

	# --- Zooming (Mouse Wheel) ---
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom_at_point(zoom_speed, event.position)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom_at_point(-zoom_speed, event.position)

func zoom_at_point(zoom_change: float, mouse_pos: Vector2) -> void:
	var old_zoom = zoom
	var new_zoom = (zoom + Vector2(zoom_change, zoom_change)).clamp(
		Vector2(min_zoom, min_zoom), 
		Vector2(max_zoom, max_zoom)
	)
	
	if old_zoom == new_zoom:
		return

	# Zoom towards the current mouse position rather than screen center
	var mouse_world_before = get_global_mouse_position()
	zoom = new_zoom
	var mouse_world_after = get_global_mouse_position()
	
	position += (mouse_world_before - mouse_world_after)
