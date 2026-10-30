extends CanvasLayer

# VICTUBYTE - MESSAGE NOTIFICATION
# Displays the initial notification and reacts to new messages.

@export var laptop_path: NodePath

const NOTIFICATION_SIZE := Vector2(250.0, 68.0)
const MARGIN := Vector2(12.0, 12.0)
const BG_COLOR := Color(0.025, 0.10, 0.075, 0.85)
const BORDER_COLOR := Color(0.0, 0.75, 0.35, 0.65)
const TEXT_COLOR := Color("d4ffe6")
const MUTED_COLOR := Color("a1cbb5")
const GREEN := Color("00ee55")

var laptop: CanvasItem
var messages_manager: Node
var notification_panel: PanelContainer
var animation: Tween
var notification_shown: bool = false
var notification_dismissed: bool = false
var received_new_message: bool = false
var pending_message_id: String = ""
var last_message_id: String = ""


func _ready() -> void:
	layer = 9
	process_mode = Node.PROCESS_MODE_ALWAYS
	_resolve_laptop()
	_create_notification()
	notification_panel.hide()
	get_viewport().size_changed.connect(_update_position)
	call_deferred("_connect_messages_manager")
	_show_after_delay()


func _resolve_laptop() -> void:
	if is_instance_valid(laptop):
		return
	if not laptop_path.is_empty():
		laptop = get_node_or_null(laptop_path) as CanvasItem
	if not is_instance_valid(laptop):
		laptop = get_node_or_null("/root/Main/UI/LaptopDesktop") as CanvasItem


func _connect_messages_manager() -> void:
	_resolve_laptop()
	if not is_instance_valid(laptop):
		return
	var manager_value: Variant = laptop.get("messages_manager")
	if not (manager_value is Node):
		return
	var manager: Node = manager_value as Node
	if not is_instance_valid(manager):
		return
	messages_manager = manager
	if not messages_manager.has_signal("message_received"):
		push_warning("VICTUBYTE: MessagesManager has no message_received signal.")
		return
	if not messages_manager.message_received.is_connected(_on_message_received):
		messages_manager.message_received.connect(_on_message_received)
		print("VICTUBYTE: Message notifications connected.")


func _show_after_delay() -> void:
	await get_tree().create_timer(3.0).timeout
	if not is_inside_tree() or received_new_message:
		return
	if notification_shown or notification_dismissed:
		return
	_resolve_laptop()
	if is_instance_valid(laptop) and laptop.visible:
		return
	_show_notification()


func _on_message_received(message_id: String) -> void:
	show_new_message_notification(message_id)


# Also supports a direct call from the second-sector trigger.
func show_new_message_notification(message_id: String = "") -> void:
	if not message_id.is_empty() and message_id == last_message_id:
		return

	if not message_id.is_empty():
		last_message_id = message_id

	received_new_message = true
	notification_dismissed = false
	_resolve_laptop()

	if is_instance_valid(laptop) and laptop.visible:
		pending_message_id = message_id if not message_id.is_empty() else "pending"
		print("VICTUBYTE: Notification queued until laptop closes.")
		return

	pending_message_id = ""
	_show_notification()
	print("VICTUBYTE: On-screen message notification displayed.")


func _input(event: InputEvent) -> void:
	if notification_dismissed or not notification_panel.visible:
		return
	if event is InputEventKey:
		if event.pressed and not event.echo and event.keycode == KEY_TAB:
			_dismiss_notification()


func _process(_delta: float) -> void:
	if not is_instance_valid(messages_manager):
		_connect_messages_manager()

	_resolve_laptop()

	if not pending_message_id.is_empty():
		if not is_instance_valid(laptop) or not laptop.visible:
			pending_message_id = ""
			_show_notification()
			print("VICTUBYTE: Queued notification displayed.")
		return

	if notification_dismissed or not notification_panel.visible:
		return

	if is_instance_valid(laptop) and laptop.visible:
		_dismiss_notification()


func _dismiss_notification() -> void:
	if notification_dismissed:
		return
	notification_dismissed = true
	if notification_panel.visible:
		_hide_notification()


func _create_notification() -> void:
	notification_panel = PanelContainer.new()
	add_child(notification_panel)
	notification_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	notification_panel.custom_minimum_size = NOTIFICATION_SIZE
	notification_panel.size = NOTIFICATION_SIZE
	notification_panel.clip_contents = true
	notification_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var style := StyleBoxFlat.new()
	style.bg_color = BG_COLOR
	style.border_color = BORDER_COLOR
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	style.content_margin_left = 9
	style.content_margin_right = 9
	style.content_margin_top = 5
	style.content_margin_bottom = 5
	notification_panel.add_theme_stylebox_override("panel", style)

	var content := VBoxContainer.new()
	notification_panel.add_child(content)
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_theme_constant_override("separation", 1)

	var header := HBoxContainer.new()
	content.add_child(header)
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_theme_constant_override("separation", 5)

	var icon := Label.new()
	header.add_child(icon)
	icon.text = "✉"
	icon.add_theme_color_override("font_color", GREEN)
	icon.add_theme_font_size_override("font_size", 13)

	var title := Label.new()
	header.add_child(title)
	title.text = "NOVA MENSAGEM"
	title.add_theme_color_override("font_color", GREEN)
	title.add_theme_font_size_override("font_size", 11)

	var spacer := Control.new()
	header.add_child(spacer)
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var indicator := Label.new()
	header.add_child(indicator)
	indicator.text = "●"
	indicator.add_theme_color_override("font_color", GREEN)
	indicator.add_theme_font_size_override("font_size", 8)

	var description := Label.new()
	content.add_child(description)
	description.text = "Você recebeu uma mensagem."
	description.add_theme_color_override("font_color", TEXT_COLOR)
	description.add_theme_font_size_override("font_size", 10)

	var hint := Label.new()
	content.add_child(hint)
	hint.text = "[TAB] Abrir notebook"
	hint.add_theme_color_override("font_color", MUTED_COLOR)
	hint.add_theme_font_size_override("font_size", 9)
	_update_position()


func _update_position() -> void:
	if not is_instance_valid(notification_panel):
		return
	notification_panel.size = NOTIFICATION_SIZE
	var viewport_size := get_viewport().get_visible_rect().size
	notification_panel.position = Vector2(
		MARGIN.x,
		viewport_size.y - NOTIFICATION_SIZE.y - MARGIN.y
	)


func _show_notification() -> void:
	if is_instance_valid(animation):
		animation.kill()
	notification_shown = true
	notification_dismissed = false
	_update_position()
	var final_position := notification_panel.position
	notification_panel.position = final_position + Vector2(-25.0, 0.0)
	notification_panel.modulate.a = 0.0
	notification_panel.show()
	animation = create_tween()
	animation.set_parallel(true)
	animation.set_trans(Tween.TRANS_CUBIC)
	animation.set_ease(Tween.EASE_OUT)
	animation.tween_property(notification_panel, "position", final_position, 0.30)
	animation.tween_property(notification_panel, "modulate:a", 1.0, 0.30)


func _hide_notification() -> void:
	if is_instance_valid(animation):
		animation.kill()
	if not notification_panel.visible:
		return
	animation = create_tween()
	animation.set_parallel(true)
	animation.set_trans(Tween.TRANS_CUBIC)
	animation.set_ease(Tween.EASE_IN)
	animation.tween_property(notification_panel, "modulate:a", 0.0, 0.20)
	animation.tween_property(
		notification_panel,
		"position",
		notification_panel.position + Vector2(-20.0, 0.0),
		0.20
	)
	animation.chain().tween_callback(notification_panel.hide)
