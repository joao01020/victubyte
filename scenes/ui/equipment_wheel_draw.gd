extends Control

signal equipment_selected(item_id: String)

const ITEMS := [
	{"id": "notebook", "name": "Notebook"},
	{"id": "esp32", "name": "ESP32"},
	{"id": "locked_1", "name": "Bloqueado"},
	{"id": "locked_2", "name": "Bloqueado"},
	{"id": "documents", "name": "Documentos"},
	{"id": "headphones", "name": "Fones"}
]

const WHEEL_SIZE := Vector2(250.0, 250.0)
const CENTER := Vector2(125.0, 125.0)
const OUTER_RADIUS := 115.0
const INNER_RADIUS := 57.0
const ICON_RADIUS := 87.0
const SEGMENT_COUNT := 6
const SEGMENT_ANGLE := TAU / 6.0
const START_ANGLE := -PI / 2.0 - SEGMENT_ANGLE / 2.0

# Transparent colors: do not draw a second background behind the segments.
const CENTER_COLOR := Color(0.02, 0.035, 0.06, 0.92)
const SEGMENT_COLOR := Color(0.039, 0.067, 0.102, 0.70)
const SELECTED_COLOR := Color(0.071, 0.235, 0.384, 0.86)
const BORDER_COLOR := Color(0.149, 0.227, 0.294, 0.78)
const INNER_BORDER_COLOR := Color(0.188, 0.29, 0.376, 0.90)
const ACCENT_COLOR := Color("#29AFFF")
const TEXT_COLOR := Color("#DDEEFF")
const DISABLED_COLOR := Color("#465665")
const ICON_COLOR := Color("#B9D1E2")
const FONT_DIRECTORY := "res://assets/fonts"
const TITLE_FONT_SIZE := 12
const ACTION_FONT_SIZE := 11

var selected_index: int = 0
var equipment_font: Font


func _ready() -> void:
	custom_minimum_size = WHEEL_SIZE
	size = WHEEL_SIZE
	mouse_filter = Control.MOUSE_FILTER_STOP
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_load_equipment_font()
	queue_redraw()


func _load_equipment_font() -> void:
	equipment_font = ThemeDB.fallback_font
	var directory := DirAccess.open(FONT_DIRECTORY)
	if directory == null:
		push_warning("Font directory not found: " + FONT_DIRECTORY)
		return

	var font_files := PackedStringArray()
	directory.list_dir_begin()
	var file_name := directory.get_next()
	while file_name != "":
		if not directory.current_is_dir():
			var extension := file_name.get_extension().to_lower()
			if extension == "ttf" or extension == "otf":
				font_files.append(file_name)
		file_name = directory.get_next()
	directory.list_dir_end()
	font_files.sort()
	if font_files.is_empty():
		push_warning("No font found in: " + FONT_DIRECTORY)
		return

	var loaded_font := load(FONT_DIRECTORY + "/" + font_files[0]) as Font
	if loaded_font != null:
		equipment_font = loaded_font


func _draw() -> void:
	# Only one translucent layer per sector.
	for index in range(SEGMENT_COUNT):
		_draw_segment(index)

	# The central disc is darker and almost opaque.
	draw_circle(CENTER, INNER_RADIUS, CENTER_COLOR)
	draw_arc(CENTER, INNER_RADIUS, 0.0, TAU, 96, INNER_BORDER_COLOR, 1.6, true)
	draw_arc(CENTER, OUTER_RADIUS, 0.0, TAU, 96, BORDER_COLOR, 1.5, true)
	_draw_selected_highlight()
	_draw_center_text()


func _draw_segment(index: int) -> void:
	var start_angle := START_ANGLE + float(index) * SEGMENT_ANGLE
	var end_angle := start_angle + SEGMENT_ANGLE
	var segment_color := SELECTED_COLOR if index == selected_index else SEGMENT_COLOR
	var points := PackedVector2Array()
	var colors := PackedColorArray()

	for step in range(25):
		var angle := lerpf(start_angle, end_angle, float(step) / 24.0)
		points.append(CENTER + Vector2.from_angle(angle) * OUTER_RADIUS)
		colors.append(segment_color)
	for step in range(24, -1, -1):
		var angle := lerpf(start_angle, end_angle, float(step) / 24.0)
		points.append(CENTER + Vector2.from_angle(angle) * INNER_RADIUS)
		colors.append(segment_color)

	draw_polygon(points, colors)
	draw_line(
		CENTER + Vector2.from_angle(start_angle) * INNER_RADIUS,
		CENTER + Vector2.from_angle(start_angle) * OUTER_RADIUS,
		BORDER_COLOR, 1.2, true
	)
	_draw_segment_icon(index)


func _draw_segment_icon(index: int) -> void:
	var angle := START_ANGLE + (float(index) + 0.5) * SEGMENT_ANGLE
	var icon_position := CENTER + Vector2.from_angle(angle) * ICON_RADIUS
	var item_id: String = ITEMS[index]["id"]
	var icon_color := ICON_COLOR
	if item_id.begins_with("locked"):
		icon_color = DISABLED_COLOR
	elif index == selected_index:
		icon_color = ACCENT_COLOR

	match item_id:
		"notebook":
			_draw_notebook_icon(icon_position, icon_color)
		"esp32":
			_draw_esp32_icon(icon_position, icon_color)
		"headphones":
			_draw_headphones_icon(icon_position, icon_color)
		"documents":
			_draw_document_icon(icon_position, icon_color)
		_:
			_draw_locked_icon(icon_position, icon_color)


func _draw_notebook_icon(icon_position: Vector2, icon_color: Color) -> void:
	var screen_rect := Rect2(icon_position + Vector2(-13.0, -13.0), Vector2(26.0, 20.0))
	draw_rect(screen_rect, icon_color, false, 1.6)
	draw_rect(Rect2(icon_position + Vector2(-10.0, -10.0), Vector2(20.0, 14.0)), Color("#102337"))
	draw_line(icon_position + Vector2(-15.0, 10.0), icon_position + Vector2(15.0, 10.0), icon_color, 2.4)
	draw_line(icon_position + Vector2(-12.0, 7.0), icon_position + Vector2(-15.0, 10.0), icon_color, 1.5)
	draw_line(icon_position + Vector2(12.0, 7.0), icon_position + Vector2(15.0, 10.0), icon_color, 1.5)
	draw_line(icon_position + Vector2(-7.0, 12.0), icon_position + Vector2(7.0, 12.0), icon_color, 1.0)


func _draw_esp32_icon(icon_position: Vector2, icon_color: Color) -> void:
	var board_rect := Rect2(icon_position + Vector2(-10.0, -16.0), Vector2(20.0, 32.0))
	draw_rect(board_rect, icon_color, false, 1.7)
	draw_rect(Rect2(icon_position + Vector2(-7.0, -12.0), Vector2(14.0, 13.0)), icon_color, false, 1.3)
	draw_rect(Rect2(icon_position + Vector2(-5.0, 5.0), Vector2(10.0, 7.0)), icon_color, false, 1.2)
	for pin in range(5):
		var pin_y := -12.0 + float(pin) * 6.0
		draw_line(icon_position + Vector2(-14.0, pin_y), icon_position + Vector2(-10.0, pin_y), icon_color, 1.5)
		draw_line(icon_position + Vector2(10.0, pin_y), icon_position + Vector2(14.0, pin_y), icon_color, 1.5)


func _draw_headphones_icon(icon_position: Vector2, icon_color: Color) -> void:
	draw_arc(icon_position + Vector2(0.0, 1.0), 12.0, PI, TAU, 24, icon_color, 2.6, true)
	draw_rect(Rect2(icon_position + Vector2(-15.0, 0.0), Vector2(5.0, 13.0)), icon_color)
	draw_rect(Rect2(icon_position + Vector2(10.0, 0.0), Vector2(5.0, 13.0)), icon_color)


func _draw_document_icon(icon_position: Vector2, icon_color: Color) -> void:
	draw_rect(Rect2(icon_position + Vector2(-10.0, -14.0), Vector2(20.0, 28.0)), icon_color, false, 1.6)
	for line_index in range(4):
		var line_y := -7.0 + float(line_index) * 6.0
		draw_line(icon_position + Vector2(-6.0, line_y), icon_position + Vector2(6.0, line_y), icon_color, 1.2)


func _draw_locked_icon(icon_position: Vector2, icon_color: Color) -> void:
	draw_arc(icon_position + Vector2(0.0, -5.0), 7.0, PI, TAU, 20, icon_color, 2.0, true)
	draw_rect(Rect2(icon_position + Vector2(-9.0, -5.0), Vector2(18.0, 16.0)), icon_color)
	draw_circle(icon_position + Vector2(0.0, 2.0), 1.7, Color("#050910"))


func _draw_selected_highlight() -> void:
	var start_angle := START_ANGLE + float(selected_index) * SEGMENT_ANGLE
	var end_angle := start_angle + SEGMENT_ANGLE
	draw_arc(CENTER, OUTER_RADIUS, start_angle, end_angle, 28, Color(0.12, 0.56, 0.95, 0.23), 5.0, true)
	draw_arc(CENTER, OUTER_RADIUS, start_angle, end_angle, 28, ACCENT_COLOR, 2.0, true)
	draw_arc(CENTER, INNER_RADIUS, start_angle, end_angle, 28, ACCENT_COLOR, 1.4, true)


func _draw_center_text() -> void:
	var item: Dictionary = ITEMS[selected_index]
	var item_name: String = item["name"]
	var item_id: String = item["id"]
	var action := "Equipar"
	if item_id.begins_with("locked"):
		action = "Bloqueado"
	elif item_id == "documents":
		action = "Abrir"
	_draw_centered_string(item_name, CENTER.y - 3.0, TITLE_FONT_SIZE, TEXT_COLOR)
	_draw_centered_string(action, CENTER.y + 15.0, ACTION_FONT_SIZE, ACCENT_COLOR)


func _draw_centered_string(value: String, y: float, font_size: int, text_color: Color) -> void:
	if equipment_font == null:
		return
	var text_size := equipment_font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	draw_string(equipment_font, Vector2(CENTER.x - text_size.x / 2.0, y), value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, text_color)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var new_index := _index_from_position(event.position)
		if new_index >= 0 and new_index != selected_index:
			selected_index = new_index
			queue_redraw()
	elif event is InputEventMouseButton:
		if event.button_index != MOUSE_BUTTON_LEFT or not event.pressed:
			return
		var new_index := _index_from_position(event.position)
		if new_index >= 0:
			selected_index = new_index
			queue_redraw()
			confirm_selection()
			accept_event()


func _index_from_position(local_position: Vector2) -> int:
	var direction := local_position - CENTER
	var distance := direction.length()
	if distance < INNER_RADIUS or distance > OUTER_RADIUS:
		return -1
	var normalized_angle := fposmod(direction.angle() - START_ANGLE, TAU)
	return clampi(int(floor(normalized_angle / SEGMENT_ANGLE)), 0, SEGMENT_COUNT - 1)


func confirm_selection() -> void:
	var item_id: String = ITEMS[selected_index]["id"]
	if item_id.begins_with("locked"):
		return
	equipment_selected.emit(item_id)


func select_equipment(index: int) -> void:
	if index < 0 or index >= SEGMENT_COUNT:
		return
	selected_index = index
	queue_redraw()


func get_selected_equipment() -> String:
	return ITEMS[selected_index]["id"]
