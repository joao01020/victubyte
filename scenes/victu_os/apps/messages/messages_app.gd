extends Control

# ============================================================
# VICTU OS - MESSAGES APP
# ============================================================

const BG_COLOR := Color("071d17")
const PANEL_COLOR := Color("09251e")
const BORDER_COLOR := Color("087e49")
const GREEN := Color("00ee55")
const TEXT_COLOR := Color("d4ffe6")
const MUTED_COLOR := Color("83b39d")
const UNREAD_COLOR := Color("123b2a")

const SIDEBAR_WIDTH := 235.0

var host: Node = null
var messages_manager: Node = null

var selected_message_id: String = ""

var inbox_status: Label
var inbox_list: VBoxContainer
var message_container: VBoxContainer


# ============================================================
# INITIALIZATION
# ============================================================

func configure(desktop: Node) -> void:
	host = desktop

	if host != null:
		messages_manager = host.get("messages_manager")


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS

	_build_interface()
	_connect_manager_signals()
	_refresh_inbox()


func _connect_manager_signals() -> void:
	if not is_instance_valid(messages_manager):
		push_warning(
			"VICTU OS: MessagesManager was not found."
		)
		return

	if messages_manager.has_signal("message_received"):
		messages_manager.message_received.connect(
			_on_message_received
		)

	if messages_manager.has_signal("unread_count_changed"):
		messages_manager.unread_count_changed.connect(
			_on_unread_count_changed
		)


# ============================================================
# INTERFACE
# ============================================================

func _build_interface() -> void:
	var background := Panel.new()
	add_child(background)

	background.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)

	background.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var background_style := StyleBoxFlat.new()
	background_style.bg_color = BG_COLOR
	background_style.set_corner_radius_all(6)

	background.add_theme_stylebox_override(
		"panel",
		background_style
	)

	var layout := HBoxContainer.new()
	add_child(layout)

	layout.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)

	layout.add_theme_constant_override(
		"separation",
		12
	)

	_create_sidebar(layout)
	_create_message_panel(layout)


# ============================================================
# SIDEBAR
# ============================================================

func _create_sidebar(parent: HBoxContainer) -> void:
	var sidebar := PanelContainer.new()

	sidebar.custom_minimum_size = Vector2(
		SIDEBAR_WIDTH,
		0
	)

	parent.add_child(sidebar)

	var sidebar_style := StyleBoxFlat.new()

	sidebar_style.bg_color = PANEL_COLOR
	sidebar_style.border_color = BORDER_COLOR
	sidebar_style.set_border_width_all(1)
	sidebar_style.set_corner_radius_all(6)
	sidebar_style.set_content_margin_all(12)

	sidebar.add_theme_stylebox_override(
		"panel",
		sidebar_style
	)

	var sidebar_layout := VBoxContainer.new()

	sidebar_layout.add_theme_constant_override(
		"separation",
		12
	)

	sidebar.add_child(sidebar_layout)

	# Inbox title

	var inbox_title := Label.new()
	inbox_title.text = "CAIXA DE ENTRADA"

	inbox_title.add_theme_color_override(
		"font_color",
		GREEN
	)

	inbox_title.add_theme_font_size_override(
		"font_size",
		15
	)

	sidebar_layout.add_child(inbox_title)

	# Unread counter

	inbox_status = Label.new()

	inbox_status.add_theme_color_override(
		"font_color",
		MUTED_COLOR
	)

	inbox_status.add_theme_font_size_override(
		"font_size",
		12
	)

	sidebar_layout.add_child(inbox_status)

	# Scrollable inbox

	var scroll := ScrollContainer.new()

	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED

	sidebar_layout.add_child(scroll)

	inbox_list = VBoxContainer.new()

	inbox_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	inbox_list.add_theme_constant_override(
		"separation",
		8
	)

	scroll.add_child(inbox_list)


# ============================================================
# MESSAGE PANEL
# ============================================================

func _create_message_panel(parent: HBoxContainer) -> void:
	var message_panel := PanelContainer.new()

	message_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	parent.add_child(message_panel)

	var message_style := StyleBoxFlat.new()

	message_style.bg_color = PANEL_COLOR
	message_style.border_color = BORDER_COLOR

	message_style.set_border_width_all(1)
	message_style.set_corner_radius_all(6)
	message_style.set_content_margin_all(18)

	message_panel.add_theme_stylebox_override(
		"panel",
		message_style
	)

	message_container = VBoxContainer.new()

	message_container.add_theme_constant_override(
		"separation",
		12
	)

	message_panel.add_child(message_container)

	_show_empty_state()


# ============================================================
# REFRESH INBOX
# ============================================================

func _refresh_inbox() -> void:
	if not is_instance_valid(inbox_list):
		return

	_clear_container(inbox_list)

	if not is_instance_valid(messages_manager):
		_update_inbox_status()
		return

	var messages: Array[Dictionary] = (
		messages_manager.get_messages()
	)

	messages.reverse()

	for message in messages:
		_create_message_button(message)

	_update_inbox_status()


# ============================================================
# MESSAGE BUTTON
# ============================================================

func _create_message_button(message: Dictionary) -> void:
	var message_id: String = str(
		message.get("id", "")
	)

	var sender: String = str(
		message.get("sender", "Desconhecido")
	)

	var subject: String = str(
		message.get("subject", "Sem assunto")
	)

	var is_read: bool = bool(
		message.get("read", false)
	)

	var button := Button.new()

	button.text = (
		("● " if not is_read else "")
		+ sender
		+"\n"
		+ subject
	)

	button.custom_minimum_size = Vector2(0, 70)

	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.clip_text = true

	button.add_theme_color_override(
		"font_color",
		TEXT_COLOR
	)

	button.add_theme_font_size_override(
		"font_size",
		13
	)

	var button_style := StyleBoxFlat.new()

	button_style.bg_color = (
		UNREAD_COLOR if not is_read else PANEL_COLOR
	)

	button_style.border_color = (
		GREEN if message_id == selected_message_id else BORDER_COLOR
	)

	button_style.set_border_width_all(1)
	button_style.set_corner_radius_all(6)
	button_style.set_content_margin_all(10)

	button.add_theme_stylebox_override(
		"normal",
		button_style
	)

	var hover_style := button_style.duplicate() as StyleBoxFlat
	hover_style.bg_color = UNREAD_COLOR
	hover_style.border_color = GREEN

	button.add_theme_stylebox_override(
		"hover",
		hover_style
	)

	button.add_theme_stylebox_override(
		"pressed",
		hover_style
	)

	button.pressed.connect(
		func() -> void:
			_open_message(message_id)
	)

	inbox_list.add_child(button)


# ============================================================
# OPEN MESSAGE
# ============================================================

func _open_message(message_id: String) -> void:
	if not is_instance_valid(messages_manager):
		return

	var message: Dictionary = (
		messages_manager.get_message(message_id)
	)

	if message.is_empty():
		return

	selected_message_id = message_id

	messages_manager.mark_as_read(message_id)

	_show_message(message)
	_refresh_inbox()


# ============================================================
# DISPLAY MESSAGE
# ============================================================

func _show_message(message: Dictionary) -> void:
	_clear_container(message_container)

	var sender_name: String = str(
		message.get("sender", "Desconhecido")
	)

	var subject_text: String = str(
		message.get("subject", "Sem assunto")
	)

	var body_text: String = str(
		message.get("body", "")
	)

	# Sender

	var sender := Label.new()

	sender.text = "DE: " + sender_name

	sender.add_theme_color_override(
		"font_color",
		GREEN
	)

	sender.add_theme_font_size_override(
		"font_size",
		16
	)

	message_container.add_child(sender)

	# Subject

	var subject := Label.new()

	subject.text = subject_text

	subject.add_theme_color_override(
		"font_color",
		TEXT_COLOR
	)

	subject.add_theme_font_size_override(
		"font_size",
		14
	)

	message_container.add_child(subject)

	# Separator

	var separator := HSeparator.new()
	message_container.add_child(separator)

	# Scroll area

	var scroll := ScrollContainer.new()

	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	scroll.horizontal_scroll_mode = (
		ScrollContainer.SCROLL_MODE_DISABLED
	)

	message_container.add_child(scroll)

	# Message content

	var body := RichTextLabel.new()

	body.bbcode_enabled = true
	body.fit_content = true
	body.scroll_active = false

	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	body.add_theme_color_override(
		"default_color",
		TEXT_COLOR
	)

	body.add_theme_font_size_override(
		"normal_font_size",
		14
	)

	# Escape BBCode before highlighting the access code.
	var formatted_body: String = (
		body_text.replace("[", "[lb]")
	)

	formatted_body = formatted_body.replace(
		"CÓDIGO: 4826",
		"[color=#00ee55][b]CÓDIGO: 4826[/b][/color]"
	)

	body.text = formatted_body

	scroll.add_child(body)


# ============================================================
# EMPTY STATE
# ============================================================

func _show_empty_state() -> void:
	_clear_container(message_container)

	var empty_label := Label.new()

	empty_label.text = (
		"Selecione uma mensagem\n"
		+"para visualizar."
	)

	empty_label.add_theme_color_override(
		"font_color",
		MUTED_COLOR
	)

	empty_label.add_theme_font_size_override(
		"font_size",
		14
	)

	message_container.add_child(empty_label)


# ============================================================
# INBOX STATUS
# ============================================================

func _update_inbox_status() -> void:
	if not is_instance_valid(inbox_status):
		return

	if not is_instance_valid(messages_manager):
		inbox_status.text = "Mensagens indisponíveis"
		return

	var unread_count: int = (
		messages_manager.get_unread_count()
	)

	if unread_count == 0:
		inbox_status.text = "Nenhuma mensagem não lida"
	elif unread_count == 1:
		inbox_status.text = "1 mensagem não lida"
	else:
		inbox_status.text = (
			str(unread_count) + " mensagens não lidas"
		)


# ============================================================
# SIGNAL CALLBACKS
# ============================================================

func _on_message_received(_message_id: String) -> void:
	_refresh_inbox()


func _on_unread_count_changed(_count: int) -> void:
	_refresh_inbox()


# ============================================================
# CLEAR CONTENT
# ============================================================

func _clear_container(container: Node) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()