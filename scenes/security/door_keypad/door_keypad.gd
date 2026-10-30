extends Area2D

# VICTUBYTE - DOOR KEYPAD
# PIN validation, compact interface and persistent visual states.

signal access_granted

@export_category("Security")
@export var access_code: String = "4826"
@export var keypad_name: String = "SECURITY DOOR 01"
@export var unlock_once: bool = true

@export_category("Visual Feedback")
@export_range(0.1, 3.0, 0.1) var denied_duration: float = 0.9
@export_range(0.1, 3.0, 0.1) var granted_duration: float = 1.0

const GREEN := Color("00e894")
const TEXT := Color("c0f7df")
const BACKGROUND := Color("071a16")
const RED := Color("ff5555")
const PANEL_SCALE := 0.60

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var interaction_label: Label = $InteractionLabel

var player_near: bool = false
var unlocked: bool = false
var panel_open: bool = false
var input_locked: bool = false
var entered_code: String = ""
var previous_pause_state: bool = false
var feedback_sequence: int = 0

var panel_layer: CanvasLayer
var panel_root: Control
var keypad_panel: PanelContainer
var code_label: Label
var feedback_label: Label


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	sprite.process_mode = Node.PROCESS_MODE_ALWAYS
	interaction_label.hide()
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_set_sprite_state("idle")


func _set_sprite_state(state: String) -> void:
	if sprite.sprite_frames == null:
		push_warning("DOOR KEYPAD: SpriteFrames not configured.")
		return
	if not sprite.sprite_frames.has_animation(state):
		push_warning("DOOR KEYPAD: Missing animation: " + state)
		return
	if sprite.sprite_frames.get_frame_count(state) == 0:
		push_warning("DOOR KEYPAD: Empty animation: " + state)
		return

	# Restart the selected animation at its first frame.
	sprite.stop()
	sprite.animation = state
	sprite.frame = 0
	sprite.frame_progress = 0.0
	sprite.play()


func _unhandled_input(event: InputEvent) -> void:
	if panel_open:
		if event is InputEventKey and event.pressed and not event.echo:
			if event.keycode == KEY_ESCAPE:
				if not input_locked:
					close_panel()
			elif not input_locked:
				if event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
					_submit_code()
				elif event.keycode == KEY_BACKSPACE:
					_delete_digit()
				elif event.unicode >= 48 and event.unicode <= 57:
					_append_digit(char(event.unicode))
			get_viewport().set_input_as_handled()
		return

	if not player_near or (unlocked and unlock_once):
		return
	if event.is_action_pressed("interact") and not event.is_echo():
		open_panel()
		get_viewport().set_input_as_handled()


func open_panel() -> void:
	if panel_open or (unlocked and unlock_once):
		return
	panel_open = true
	input_locked = false
	entered_code = ""
	feedback_sequence += 1
	previous_pause_state = get_tree().paused
	get_tree().paused = true
	interaction_label.hide()
	_set_sprite_state("typing")
	_build_panel()


func close_panel() -> void:
	if not panel_open:
		return
	feedback_sequence += 1
	panel_open = false
	input_locked = false
	if is_instance_valid(panel_layer):
		panel_layer.queue_free()
	panel_layer = null
	panel_root = null
	keypad_panel = null
	code_label = null
	feedback_label = null
	get_tree().paused = previous_pause_state
	_set_sprite_state("unlocked" if unlocked else "idle")
	if player_near and not (unlocked and unlock_once):
		interaction_label.show()


func _build_panel() -> void:
	panel_layer = CanvasLayer.new()
	panel_layer.layer = 25
	panel_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(panel_layer)

	var overlay := ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.65)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	panel_layer.add_child(overlay)

	panel_root = Control.new()
	panel_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel_layer.add_child(panel_root)

	keypad_panel = PanelContainer.new()
	keypad_panel.custom_minimum_size = Vector2(240, 310)
	keypad_panel.scale = Vector2.ONE * PANEL_SCALE
	keypad_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel_root.add_child(keypad_panel)
	keypad_panel.resized.connect(_center_panel)
	panel_root.resized.connect(_center_panel)

	var style := StyleBoxFlat.new()
	style.bg_color = BACKGROUND
	style.border_color = GREEN
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(9)
	keypad_panel.add_theme_stylebox_override("panel", style)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	keypad_panel.add_child(column)

	column.add_child(_make_label(keypad_name, 13, GREEN))
	column.add_child(_make_label("ENTER ACCESS CODE", 10, TEXT))

	code_label = _make_label("", 17, GREEN)
	column.add_child(code_label)
	feedback_label = _make_label("AWAITING CODE", 10, TEXT)
	column.add_child(feedback_label)

	var grid := GridContainer.new()
	grid.columns = 3
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 4)
	column.add_child(grid)

	for digit in ["1", "2", "3", "4", "5", "6", "7", "8", "9", "CLEAR", "0", "DEL"]:
		var button := Button.new()
		button.text = digit
		button.custom_minimum_size = Vector2(62, 27)
		button.add_theme_font_size_override("font_size", 12 if digit.length() == 1 else 10)
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(_on_key_pressed.bind(digit))
		grid.add_child(button)

	var submit := Button.new()
	submit.text = "CONFIRM"
	submit.custom_minimum_size = Vector2(0, 27)
	submit.add_theme_font_size_override("font_size", 11)
	submit.focus_mode = Control.FOCUS_NONE
	submit.pressed.connect(_submit_code)
	column.add_child(submit)

	var close_button := Button.new()
	close_button.text = "CLOSE [ESC]"
	close_button.custom_minimum_size = Vector2(0, 27)
	close_button.add_theme_font_size_override("font_size", 11)
	close_button.focus_mode = Control.FOCUS_NONE
	close_button.pressed.connect(close_panel)
	column.add_child(close_button)

	_update_code_label()
	_center_panel.call_deferred()


func _center_panel() -> void:
	if not is_instance_valid(panel_root) or not is_instance_valid(keypad_panel):
		return
	keypad_panel.position = (panel_root.size - keypad_panel.size * PANEL_SCALE) * 0.5


func _make_label(value: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = value
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


func _on_key_pressed(value: String) -> void:
	if not panel_open or input_locked:
		return
	match value:
		"CLEAR":
			entered_code = ""
			_update_display()
		"DEL":
			_delete_digit()
		_:
			_append_digit(value)


func _append_digit(value: String) -> void:
	if input_locked or entered_code.length() >= access_code.length():
		return
	entered_code += value
	_update_display()


func _delete_digit() -> void:
	if input_locked:
		return
	if not entered_code.is_empty():
		entered_code = entered_code.substr(0, entered_code.length() - 1)
	_update_display()


func _update_code_label() -> void:
	if not is_instance_valid(code_label):
		return
	var cells: Array[String] = []
	for index in range(access_code.length()):
		cells.append("●" if index < entered_code.length() else "_")
	code_label.text = " ".join(cells)


func _update_display() -> void:
	_update_code_label()
	if is_instance_valid(feedback_label):
		feedback_label.text = "AWAITING CODE"
		feedback_label.add_theme_color_override("font_color", TEXT)
	_set_sprite_state("typing")


func _submit_code() -> void:
	if not panel_open or input_locked:
		return
	input_locked = true
	feedback_sequence += 1
	var sequence: int = feedback_sequence

	if not access_code.is_empty() and entered_code == access_code:
		unlocked = true
		_set_sprite_state("unlocked")
		feedback_label.text = "ACCESS GRANTED"
		feedback_label.add_theme_color_override("font_color", GREEN)
		access_granted.emit()
		# Allow the unlocked visual state to be seen before closing.
		await get_tree().create_timer(granted_duration, true).timeout
		if not is_inside_tree() or sequence != feedback_sequence:
			return
		close_panel()
	else:
		_set_sprite_state("denied")
		feedback_label.text = "ACCESS DENIED"
		feedback_label.add_theme_color_override("font_color", RED)
		entered_code = ""
		_update_code_label()
		await get_tree().create_timer(denied_duration, true).timeout
		if not is_inside_tree() or sequence != feedback_sequence:
			return
		input_locked = false
		_update_display()


func _on_body_entered(body: Node2D) -> void:
	if body is CharacterBody2D and body.is_in_group("player"):
		player_near = true
		if not panel_open and not (unlocked and unlock_once):
			interaction_label.show()


func _on_body_exited(body: Node2D) -> void:
	if body is CharacterBody2D and body.is_in_group("player"):
		player_near = false
		interaction_label.hide()
