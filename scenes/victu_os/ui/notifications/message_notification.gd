extends CanvasLayer

@export var laptop_path: NodePath

const NOTIFICATION_SIZE := Vector2(250.0, 68.0)
const MARGIN := Vector2(12.0, 12.0)

const BG_COLOR := Color(0.025, 0.10, 0.075, 0.85)
const BORDER_COLOR := Color(0.0, 0.75, 0.35, 0.65)
const TEXT_COLOR := Color("d4ffe6")
const MUTED_COLOR := Color("a1cbb5")
const GREEN := Color("00ee55")

var laptop: CanvasItem
var notification_panel: PanelContainer

var notification_shown: bool = false
var notification_dismissed: bool = false

var animation: Tween


func _ready() -> void:
	layer = 9
	process_mode = Node.PROCESS_MODE_ALWAYS

	laptop = get_node_or_null(laptop_path) as CanvasItem

	_create_notification()
	notification_panel.hide()

	get_viewport().size_changed.connect(_update_position)

	_show_after_delay()


func _show_after_delay() -> void:
	await get_tree().create_timer(3.0).timeout

	if not is_inside_tree():
		return

	if notification_shown or notification_dismissed:
		return

	notification_shown = true

	if is_instance_valid(laptop) and laptop.visible:
		notification_dismissed = true
		return

	_show_notification()


func _input(event: InputEvent) -> void:
	if notification_dismissed:
		return

	if event is InputEventKey:
		if event.pressed and not event.echo:
			if event.keycode == KEY_TAB:
				_dismiss_notification()


func _process(_delta: float) -> void:
	if notification_dismissed:
		return

	if not is_instance_valid(laptop):
		return

	if laptop.visible:
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

	notification_panel.set_anchors_preset(
		Control.PRESET_TOP_LEFT
	)

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

	notification_panel.add_theme_stylebox_override(
		"panel",
		style
	)

	var content := VBoxContainer.new()
	notification_panel.add_child(content)

	content.mouse_filter = Control.MOUSE_FILTER_IGNORE

	content.add_theme_constant_override(
		"separation",
		1
	)

	# HEADER

	var header := HBoxContainer.new()
	content.add_child(header)

	header.mouse_filter = Control.MOUSE_FILTER_IGNORE

	header.add_theme_constant_override(
		"separation",
		5
	)

	# ICON

	var icon := Label.new()
	header.add_child(icon)

	icon.text = "✉"

	icon.add_theme_color_override(
		"font_color",
		GREEN
	)

	icon.add_theme_font_size_override(
		"font_size",
		13
	)

	# TITLE

	var title := Label.new()
	header.add_child(title)

	title.text = "NOVA MENSAGEM"

	title.add_theme_color_override(
		"font_color",
		GREEN
	)

	title.add_theme_font_size_override(
		"font_size",
		11
	)

	# SPACER

	var spacer := Control.new()
	header.add_child(spacer)

	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	# STATUS INDICATOR

	var indicator := Label.new()
	header.add_child(indicator)

	indicator.text = "●"

	indicator.add_theme_color_override(
		"font_color",
		GREEN
	)

	indicator.add_theme_font_size_override(
		"font_size",
		8
	)

	# MESSAGE DESCRIPTION

	var description := Label.new()
	content.add_child(description)

	description.text = "Você recebeu uma mensagem."

	description.add_theme_color_override(
		"font_color",
		TEXT_COLOR
	)

	description.add_theme_font_size_override(
		"font_size",
		10
	)

	# KEYBOARD HINT

	var hint := Label.new()
	content.add_child(hint)

	hint.text = "[TAB] Abrir notebook"

	hint.add_theme_color_override(
		"font_color",
		MUTED_COLOR
	)

	hint.add_theme_font_size_override(
		"font_size",
		9
	)

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
	if notification_dismissed:
		return

	if is_instance_valid(animation):
		animation.kill()

	_update_position()

	var final_position := notification_panel.position

	notification_panel.position = (
		final_position + Vector2(-25.0, 0.0)
	)

	notification_panel.modulate.a = 0.0
	notification_panel.show()

	animation = create_tween()

	animation.set_parallel(true)
	animation.set_trans(Tween.TRANS_CUBIC)
	animation.set_ease(Tween.EASE_OUT)

	animation.tween_property(
		notification_panel,
		"position",
		final_position,
		0.30
	)

	animation.tween_property(
		notification_panel,
		"modulate:a",
		1.0,
		0.30
	)


func _hide_notification() -> void:
	if is_instance_valid(animation):
		animation.kill()

	if not notification_panel.visible:
		return

	animation = create_tween()

	animation.set_parallel(true)
	animation.set_trans(Tween.TRANS_CUBIC)
	animation.set_ease(Tween.EASE_IN)

	animation.tween_property(
		notification_panel,
		"modulate:a",
		0.0,
		0.20
	)

	animation.tween_property(
		notification_panel,
		"position",
		notification_panel.position + Vector2(-20.0, 0.0),
		0.20
	)

	animation.chain().tween_callback(
		notification_panel.hide
	)