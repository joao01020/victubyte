extends Area2D

# ============================================================
# VICTUBYTE - SECURITY TERMINAL
# Physical laboratory terminal with checkpoint and network info.
# ============================================================

signal access_granted
signal checkpoint_activated(checkpoint_position: Vector2)
signal terminal_opened
signal terminal_closed

@export_category("Checkpoint")
@export var enable_checkpoint: bool = true
@export var activate_checkpoint_on_open: bool = false

@export_category("Network")
@export var terminal_name: String = "LAB-NODE-01"
@export var ip_address: String = "192.168.1.10"
@export var ssh_enabled: bool = true
@export var ssh_port: int = 22

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var interaction_label: Label = $InteractionLabel
@onready var respawn_point: Marker2D = get_node_or_null("RespawnPoint") as Marker2D

var player_near: bool = false
var unlocked: bool = false # Reserved for future access-control puzzles.
var busy: bool = false
var checkpoint_registered: bool = false
var current_player: CharacterBody2D = null

var _screen_layer: CanvasLayer
var _screen_panel: PanelContainer
var _status_label: Label
var _checkpoint_button: Button
var _copy_button: Button
var _copy_feedback: Label

# The project stretches UI coordinates; scale the terminal independently.
const TERMINAL_UI_SCALE := 0.34

func _ready() -> void:
	interaction_label.hide()
	_play_animation("idle")
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	print("SECURITY TERMINAL: Initialized: ", terminal_name)

func _unhandled_input(event: InputEvent) -> void:
	if busy:
		if event.is_action_pressed("ui_cancel") and not event.is_echo():
			get_viewport().set_input_as_handled()
			close_terminal()
		return

	if not player_near or not is_instance_valid(current_player):
		return

	if event.is_action_pressed("interact") and not event.is_echo():
		get_viewport().set_input_as_handled()
		start_access()

func start_access() -> void:
	if busy or not player_near or not is_instance_valid(current_player):
		return
	busy = true
	interaction_label.hide()
	_play_animation("interacting")
	_open_terminal_interface()
	terminal_opened.emit()
	if activate_checkpoint_on_open and enable_checkpoint:
		register_checkpoint()
	_update_interface()

func _open_terminal_interface() -> void:
	_screen_layer = CanvasLayer.new()
	_screen_layer.name = "SecurityTerminalScreen"
	_screen_layer.layer = 100
	add_child(_screen_layer)

	var backdrop := ColorRect.new()
	backdrop.color = Color(0.0, 0.04, 0.03, 0.85)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	_screen_layer.add_child(backdrop)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_screen_layer.add_child(center)

	_screen_panel = PanelContainer.new()
	_screen_panel.custom_minimum_size = Vector2(330, 230)
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color("071d17")
	panel_style.border_color = Color("00bb66")
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(8)
	_screen_panel.add_theme_stylebox_override("panel", panel_style)
	center.add_child(_screen_panel)
	_screen_panel.scale = Vector2.ONE * TERMINAL_UI_SCALE
	_screen_panel.resized.connect(_center_panel_pivot)
	_center_panel_pivot()

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 9)
	margin.add_theme_constant_override("margin_bottom", 9)
	_screen_panel.add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	margin.add_child(column)

	var title := Label.new()
	title.text = "LABORATORY CONTROL SYSTEM"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Color("00ee88"))
	title.add_theme_font_size_override("font_size", 14)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(title)

	var divider := HSeparator.new()
	column.add_child(divider)

	var device_info := Label.new()
	device_info.text = "DEVICE: %s" % terminal_name
	device_info.add_theme_color_override("font_color", Color("a5e8c6"))
	device_info.add_theme_font_size_override("font_size", 12)
	column.add_child(device_info)

	# Read-only IP field with a dedicated clipboard button.
	var ip_row := HBoxContainer.new()
	ip_row.add_theme_constant_override("separation", 5)
	column.add_child(ip_row)

	var ip_label := Label.new()
	ip_label.text = "IP:"
	ip_label.add_theme_color_override("font_color", Color("a5e8c6"))
	ip_label.add_theme_font_size_override("font_size", 12)
	ip_row.add_child(ip_label)

	var ip_field := LineEdit.new()
	ip_field.text = ip_address
	ip_field.editable = false
	ip_field.selecting_enabled = true
	ip_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ip_field.custom_minimum_size = Vector2(0, 25)
	ip_field.add_theme_font_size_override("font_size", 12)
	ip_row.add_child(ip_field)

	_copy_button = Button.new()
	_copy_button.text = "⧉"
	_copy_button.tooltip_text = "Copy IP address"
	_copy_button.custom_minimum_size = Vector2(30, 25)
	_copy_button.add_theme_font_size_override("font_size", 15)
	_copy_button.pressed.connect(_copy_ip_address)
	ip_row.add_child(_copy_button)

	_copy_feedback = Label.new()
	_copy_feedback.text = "Click ⧉ to copy IP"
	_copy_feedback.add_theme_color_override("font_color", Color("75ae95"))
	_copy_feedback.add_theme_font_size_override("font_size", 10)
	column.add_child(_copy_feedback)

	var network_info := Label.new()
	network_info.text = "SSH: %s  |  PORT: %d" % [
		"ONLINE" if ssh_enabled else "OFFLINE",
		ssh_port
	]
	network_info.add_theme_color_override("font_color", Color("a5e8c6"))
	network_info.add_theme_font_size_override("font_size", 12)
	column.add_child(network_info)

	_status_label = Label.new()
	_status_label.add_theme_color_override("font_color", Color("00ee88"))
	_status_label.add_theme_font_size_override("font_size", 12)
	column.add_child(_status_label)

	_checkpoint_button = Button.new()
	_checkpoint_button.text = "ACTIVATE CHECKPOINT"
	_checkpoint_button.pressed.connect(_on_checkpoint_pressed)
	_checkpoint_button.custom_minimum_size = Vector2(0, 25)
	column.add_child(_checkpoint_button)

	var close_button := Button.new()
	close_button.text = "CLOSE TERMINAL [ESC]"
	close_button.pressed.connect(close_terminal)
	close_button.custom_minimum_size = Vector2(0, 25)
	column.add_child(close_button)

	var hint := Label.new()
	hint.text = "SSH (future): ssh user@%s" % ip_address
	hint.add_theme_color_override("font_color", Color("75ae95"))
	hint.add_theme_font_size_override("font_size", 10)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(hint)

func _copy_ip_address() -> void:
	DisplayServer.clipboard_set(ip_address)
	if is_instance_valid(_copy_feedback):
		_copy_feedback.text = "IP COPIED!"
	if is_instance_valid(_copy_button):
		_copy_button.text = "✓"

func _center_panel_pivot() -> void:
	if is_instance_valid(_screen_panel):
		_screen_panel.pivot_offset = _screen_panel.size * 0.5

func _on_checkpoint_pressed() -> void:
	register_checkpoint()
	_update_interface()

func _update_interface() -> void:
	if not is_instance_valid(_status_label):
		return
	if not enable_checkpoint:
		_status_label.text = "CHECKPOINT: DISABLED"
	elif checkpoint_registered:
		_status_label.text = "CHECKPOINT: ACTIVE"
	else:
		_status_label.text = "CHECKPOINT: NOT ACTIVATED"
	if is_instance_valid(_checkpoint_button):
		_checkpoint_button.disabled = not enable_checkpoint or checkpoint_registered

func register_checkpoint() -> void:
	if not enable_checkpoint or checkpoint_registered:
		return
	if not is_instance_valid(respawn_point):
		push_warning("SECURITY TERMINAL: RespawnPoint is missing.")
		return
	var checkpoint_manager := get_node_or_null("/root/CheckpointManager")
	if checkpoint_manager == null:
		push_warning("SECURITY TERMINAL: CheckpointManager autoload not found.")
		return
	if not checkpoint_manager.has_method("activate_checkpoint"):
		push_warning("SECURITY TERMINAL: CheckpointManager has no activate_checkpoint() method.")
		return
	var checkpoint_position := respawn_point.global_position
	checkpoint_manager.call("activate_checkpoint", checkpoint_position)
	checkpoint_registered = true
	checkpoint_activated.emit(checkpoint_position)
	print("SECURITY TERMINAL: Checkpoint activated at ", checkpoint_position)
	_update_interface()

func close_terminal() -> void:
	if not busy:
		return
	busy = false
	if is_instance_valid(_screen_layer):
		_screen_layer.queue_free()
	_screen_layer = null
	_screen_panel = null
	_status_label = null
	_checkpoint_button = null
	_copy_button = null
	_copy_feedback = null
	_play_animation("idle")
	if player_near and is_instance_valid(current_player):
		interaction_label.show()
	terminal_closed.emit()

func cancel_access() -> void:
	close_terminal()

# Legacy compatibility. Only call this from a future authenticated
# access-control challenge; checkpoint activation never calls it.
func complete_access() -> void:
	if unlocked:
		return
	unlocked = true
	access_granted.emit()

func _play_animation(animation_name: String) -> void:
	if sprite.sprite_frames != null and sprite.sprite_frames.has_animation(animation_name):
		sprite.play(animation_name)

func _on_body_entered(body: Node2D) -> void:
	if not body is CharacterBody2D or not body.is_in_group("player"):
		return
	current_player = body as CharacterBody2D
	player_near = true
	if not busy:
		interaction_label.show()

func _on_body_exited(body: Node2D) -> void:
	if body != current_player:
		return
	player_near = false
	current_player = null
	interaction_label.hide()
	if busy:
		close_terminal()
