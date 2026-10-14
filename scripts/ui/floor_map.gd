extends Control
## A schematic, drawn in world coordinates; no minimap scene or extra camera needed.

const FONT := preload("res://assets/fonts/NotoSans-Regular.ttf")
const BOLD := preload("res://assets/fonts/NotoSans-Bold.ttf")
const TEAL := Color("70c9bb")
const MUTED := Color("97adad")
const AMBER := Color("e9b46a")


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


func _point(world_x: float, world_z: float) -> Vector2:
	var scale_factor: float = minf((size.x - 80.0) / 27.0, (size.y - 40.0) / 29.0)
	return Vector2(size.x * 0.5 + world_x * scale_factor, size.y * 0.5 + (world_z + 1.0) * scale_factor)


func _room(from: Vector2, to: Vector2, fill: Color) -> void:
	var rect := Rect2(_point(from.x, from.y), _point(to.x, to.y) - _point(from.x, from.y))
	draw_rect(rect, fill)
	draw_rect(rect, TEAL, false, 1.5)


func _draw() -> void:
	draw_style_box(_panel(), Rect2(Vector2.ZERO, size))
	for x: int in range(20, int(size.x), 28):
		draw_line(Vector2(x, 0), Vector2(x, size.y), Color(0.2, 0.4, 0.4, 0.10))
	for y: int in range(20, int(size.y), 28):
		draw_line(Vector2(0, y), Vector2(size.x, y), Color(0.2, 0.4, 0.4, 0.10))
	_room(Vector2(-2.8, -14), Vector2(2.8, 12), Color("1d383b"))
	_room(Vector2(3, -10), Vector2(11, -2), Color("172e33"))
	_room(Vector2(-10, -1), Vector2(-3, 7), Color("172e33"))
	draw_line(_point(2.5, -5), _point(3.5, -5), Color("1d383b"), 15.0)
	draw_line(_point(-3.5, 3), _point(-2.5, 3), Color("1d383b"), 15.0)
	var scale_factor: float = minf((size.x - 80.0) / 27.0, (size.y - 40.0) / 29.0)
	var font_size: int = 13 if size.x > 600 else 11
	draw_string(BOLD, _point(4, -7), "PHÒNG 307", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, TEAL)
	draw_string(FONT, _point(4, -5), "Hiện trường", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size - 1, MUTED)
	draw_string(BOLD, _point(-9.3, 1.5), "CAMERA", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, TEAL)
	draw_string(FONT, _point(-9.3, 3.5), "Giám sát", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size - 1, MUTED)
	draw_string(FONT, _point(-2, 13.5), "LỐI VÀO", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size - 1, MUTED)
	draw_string(BOLD, Vector2(size.x - 38, 30), "B", HORIZONTAL_ALIGNMENT_CENTER, 20, 12, MUTED)
	draw_line(Vector2(size.x - 28, 42), Vector2(size.x - 28, 62), MUTED, 1.0)
	draw_line(Vector2(size.x - 28, 42), Vector2(size.x - 32, 48), MUTED, 1.0)
	draw_line(Vector2(size.x - 28, 42), Vector2(size.x - 24, 48), MUTED, 1.0)
	var position: Vector3 = GameState.player_position
	var marker: Vector2 = _point(position.x, position.z)
	draw_circle(marker, 9, Color(0.91, 0.70, 0.42, 0.16))
	draw_circle(marker, 4, AMBER)
	var direction := Vector2(-sin(GameState.player_yaw), -cos(GameState.player_yaw))
	draw_line(marker, marker + direction * minf(scale_factor * 1.5, 18.0), AMBER, 2.0)


func _panel() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color("0b171b")
	box.border_color = Color("31464a")
	box.set_border_width_all(1)
	box.set_corner_radius_all(5)
	return box
