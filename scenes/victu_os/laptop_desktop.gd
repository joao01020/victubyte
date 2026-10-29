extends CanvasLayer

signal wifi_connected
signal desktop_closed

const OSStateScript := preload("res://scenes/victu_os/core/os_state.gd")
const FileSystemScript := preload("res://scenes/victu_os/core/virtual_file_system.gd")
const PermissionScript := preload("res://scenes/victu_os/core/permission_manager.gd")
const NetworkScript := preload("res://scenes/victu_os/core/network_manager.gd")
const NVRScript := preload("res://scenes/victu_os/core/nvr_manager.gd")
const SettingsScript := preload("res://scenes/victu_os/core/settings_manager.gd")
const WindowManagerScript := preload("res://scenes/victu_os/ui/window_manager.gd")
const SHORTCUT_SCENE := preload("res://scenes/victu_os/ui/desktop_shortcut.tscn")

const BASE_SIZE := Vector2(1280.0, 720.0)
const BG := Color("020b08")
const PANEL := Color("041611")
const PANEL_ALT := Color("071d17")
const HEADER := Color("09251e")
const GREEN := Color("00ee55")
const TEXT_COLOR := Color("bdffdc")
const MUTED := Color("83b39d")
const BORDER := Color("087e49")
const ICON_DIR := "res://assets/laptop_equip/ui/"

const APPS := [
	{"id": "files", "title": "Files", "icon": "icon_folder.svg", "fallback": "F"},
	{"id": "terminal", "title": "Terminal", "icon": "icon_terminal.svg", "fallback": ">_"},
	{"id": "guide", "title": "Field Guide", "icon": "icon_book.svg", "fallback": "?"},
	{"id": "network", "title": "Network", "icon": "icon_wifi.svg", "fallback": "W"},
	{"id": "hardware", "title": "Hardware", "icon": "icon_cpu.svg", "fallback": "H"},
	{"id": "cameras", "title": "Cameras", "icon": "icon_camera.svg", "fallback": "C"},
	{"id": "settings", "title": "Settings", "icon": "icon_settings.svg", "fallback": "S"}
]

var os_state
var file_system
var permission_manager
var network_manager
var nvr_manager
var settings_manager
var window_manager

var terminal_ref: Node = null
var player_ref: Node = null
var opened_from_inventory: bool = false
var previous_pause_state: bool = false
var desktop_root: Control
var canvas: Control
var window_layer: Control
var taskbar: Panel
var taskbar_apps: HBoxContainer
var app_menu: Panel = null
var status_label: Label

func _app_title(app_id: String) -> String:
	for app in APPS:
		if str(app["id"]) == app_id:
			return settings_manager.tx(str(app["title"]))
	return app_id.capitalize()

func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	os_state = OSStateScript.new()
	file_system = FileSystemScript.new()
	permission_manager = PermissionScript.new(file_system)
	nvr_manager = NVRScript.new()
	settings_manager = SettingsScript.new()
	add_child(settings_manager)
	settings_manager.locale_changed.connect(_on_locale_changed)
	network_manager = NetworkScript.new()
	add_child(network_manager)
	network_manager.network_changed.connect(_on_network_changed)
	window_manager = WindowManagerScript.new()
	add_child(window_manager)
	window_manager.setup(self)
	_build_interface()
	_fit_canvas()
	get_viewport().size_changed.connect(_fit_canvas)
	hide()
	call_deferred("_connect_to_terminal")

func _on_locale_changed() -> void:
	call_deferred("_rebuild_localized_desktop")

func _on_network_changed(ssid: String) -> void:
	if not ssid.is_empty():
		wifi_connected.emit()

func close_app(app_id: String) -> void:
	window_manager.close_app(app_id)

func _rebuild_localized_desktop() -> void:
	var opened_apps: Array = window_manager.windows.keys()
	var minimized_apps: Dictionary = window_manager.minimized.duplicate()
	window_manager.close_all()
	if is_instance_valid(app_menu):
		app_menu.queue_free()
		app_menu = null
	if is_instance_valid(desktop_root):
		remove_child(desktop_root)
		desktop_root.queue_free()
	_build_interface()
	_fit_canvas()
	_update_session_status()
	for app_id in opened_apps:
		open_app(str(app_id))
		if minimized_apps.get(app_id, false):
			window_manager.minimize_app(str(app_id))

func _connect_to_terminal() -> void:
	var current_scene := get_tree().current_scene
	if current_scene == null:
		return
	terminal_ref = current_scene.get_node_or_null("SecuritySystems/SecurityTerminal")
	if terminal_ref == null or not terminal_ref.has_signal("laptop_ready"):
		push_warning("VICTU OS: security terminal not found; inventory mode is still available.")
		return
	var callback := Callable(self, "open_desktop")
	if not terminal_ref.is_connected("laptop_ready", callback):
		terminal_ref.connect("laptop_ready", callback)

func notify_wifi_connected() -> void:
	wifi_connected.emit()

func open_desktop() -> void:
	_open_interface(false)

func open_from_inventory() -> void:
	_open_interface(true)

func _open_interface(from_inventory: bool) -> void:
	if visible:
		return
	opened_from_inventory = from_inventory
	previous_pause_state = get_tree().paused
	_fit_canvas()
	show()
	get_tree().paused = true
	_update_session_status()

func _find_player() -> Node:
	# The Player is under Characters in the main scene, not next to this CanvasLayer.
	# The player script registers itself in the "player" group during _ready().
	if is_instance_valid(player_ref) and player_ref.is_inside_tree():
		return player_ref

	var players: Array[Node] = get_tree().get_nodes_in_group("player")
	for player_candidate in players:
		if is_instance_valid(player_candidate) and player_candidate.has_method("finish_laptop_interaction"):
			player_ref = player_candidate
			return player_ref

	# Fallback for scenes where the player has not been added to the group.
	var current_scene: Node = get_tree().current_scene
	if is_instance_valid(current_scene):
		var paths: Array[String] = ["Characters/Player", "Player", "Level/Player"]
		for node_path in paths:
			var path_candidate: Node = current_scene.get_node_or_null(node_path)
			if is_instance_valid(path_candidate) and path_candidate.has_method("finish_laptop_interaction"):
				player_ref = path_candidate
				return player_ref

	push_warning("VICTU OS: Could not find a player with finish_laptop_interaction().")
	return null

func close_desktop() -> void:
	if not visible:
		return

	var was_terminal_session: bool = not opened_from_inventory

	# Close OS windows without altering Wi-Fi, files, or other application state.
	if is_instance_valid(app_menu):
		app_menu.queue_free()
		app_menu = null
	window_manager.close_all()

	# Restore gameplay processing before releasing the character.
	hide()
	get_tree().paused = previous_pause_state

	# End a remote-terminal session before restoring the player's final pose.
	if was_terminal_session and is_instance_valid(terminal_ref):
		if terminal_ref.has_method("cancel_access"):
			terminal_ref.call("cancel_access")

	var player: Node = _find_player()
	if is_instance_valid(player):
		player.call("finish_laptop_interaction")

	opened_from_inventory = false
	desktop_closed.emit()

func _fit_canvas() -> void:
	if not is_instance_valid(canvas) or not is_instance_valid(desktop_root):
		return
	var viewport_size := get_viewport().get_visible_rect().size
	desktop_root.size = viewport_size
	var factor := minf(viewport_size.x / BASE_SIZE.x, viewport_size.y / BASE_SIZE.y)
	canvas.scale = Vector2.ONE * factor
	canvas.position = (viewport_size - BASE_SIZE * factor) / 2.0

func _style(fill: Color, outline: Color = BORDER, radius: int = 9) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = outline
	style.set_border_width_all(1)
	style.set_corner_radius_all(radius)
	return style

func _apply_sidebar_button_style(button: Button, selected: bool = false) -> void:
	# Text is inset from the button border, including hover/selected states.
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	var normal_style: StyleBoxFlat = _style(HEADER if selected else PANEL_ALT, GREEN if selected else BORDER, 7)
	var hover_style: StyleBoxFlat = _style(HEADER, GREEN, 7)
	for style_box in [normal_style, hover_style]:
		style_box.content_margin_left = 15.0
		style_box.content_margin_right = 10.0
		style_box.content_margin_top = 3.0
		style_box.content_margin_bottom = 3.0
	button.add_theme_stylebox_override("normal", normal_style)
	button.add_theme_stylebox_override("hover", hover_style)
	button.add_theme_stylebox_override("pressed", hover_style)

func _panel(parent: Node, position_value: Vector2, size_value: Vector2, fill: Color, radius: int = 9) -> Panel:
	var panel := Panel.new()
	parent.add_child(panel)
	panel.position = position_value
	panel.size = size_value
	panel.add_theme_stylebox_override("panel", _style(fill, BORDER, radius))
	return panel

func _label(parent: Node, content: String, position_value: Vector2, size_value: Vector2, font_size: int = 17, tint: Color = TEXT_COLOR) -> Label:
	var label := Label.new()
	parent.add_child(label)
	label.position = position_value
	label.size = size_value
	label.text = content
	label.add_theme_color_override("font_color", tint)
	label.add_theme_font_size_override("font_size", font_size)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

func _icon(parent: Node, filename: String, fallback: String, position_value: Vector2, size_value: Vector2) -> void:
	var svg_path := ICON_DIR + filename
	var png_path := ICON_DIR + filename.get_basename() + ".png"
	var texture: Texture2D = null
	if ResourceLoader.exists(svg_path):
		texture = load(svg_path) as Texture2D
	if texture == null and ResourceLoader.exists(png_path):
		texture = load(png_path) as Texture2D
	if texture != null:
		var rect := TextureRect.new()
		parent.add_child(rect)
		rect.position = position_value
		rect.size = size_value
		rect.texture = texture
		rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		return
	var fallback_label := _label(parent, fallback, position_value, size_value, 22, GREEN)
	fallback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	fallback_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

func _button(parent: Node, content: String, position_value: Vector2, size_value: Vector2, callback: Callable) -> Button:
	var button := Button.new()
	parent.add_child(button)
	button.position = position_value
	button.size = size_value
	button.text = content
	button.focus_mode = Control.FOCUS_NONE
	button.clip_text = true
	button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.add_theme_color_override("font_color", TEXT_COLOR)
	button.add_theme_color_override("font_hover_color", GREEN)
	button.add_theme_font_size_override("font_size", 16)
	button.add_theme_stylebox_override("normal", _style(PANEL_ALT))
	button.add_theme_stylebox_override("hover", _style(HEADER, GREEN))
	button.add_theme_stylebox_override("pressed", _style(HEADER, GREEN))
	button.pressed.connect(callback)
	return button

func _build_interface() -> void:
	desktop_root = Control.new()
	add_child(desktop_root)
	desktop_root.mouse_filter = Control.MOUSE_FILTER_STOP
	var backdrop := ColorRect.new()
	desktop_root.add_child(backdrop)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color("010504")
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP

	canvas = Control.new()
	desktop_root.add_child(canvas)
	canvas.size = BASE_SIZE
	canvas.mouse_filter = Control.MOUSE_FILTER_PASS
	_panel(canvas, Vector2.ZERO, BASE_SIZE, BG, 0)

	_panel(canvas, Vector2(16, 12), Vector2(1248, 60), HEADER)
	_icon(canvas, "victu_logo.svg", "◉", Vector2(32, 24), Vector2(38, 34))
	_label(canvas, "VICTU OS", Vector2(82, 26), Vector2(176, 34), 26, GREEN)
	_label(canvas, "v1.1", Vector2(263, 33), Vector2(90, 25), 15, MUTED)
	_icon(canvas, "icon_wifi.svg", "W", Vector2(1124, 28), Vector2(27, 28))
	_icon(canvas, "icon_battery.svg", "B", Vector2(1170, 28), Vector2(27, 28))
	_button(canvas, "×", Vector2(1210, 22), Vector2(39, 39), close_desktop)

	_panel(canvas, Vector2(16, 85), Vector2(1248, 554), PANEL)
	for index in range(APPS.size()):
		var app: Dictionary = APPS[index]
		var column := index % 4
		var row_index: int = floori(float(index) / 4.0)
		# Keep the outside columns entirely outside the default window bounds.
		# This avoids half-visible button borders and clipped titles beside windows.
		var column_positions: Array[float] = [70.0, 360.0, 655.0, 1050.0]
		var icon_position: Vector2 = Vector2(column_positions[column], 122.0 + float(row_index) * 126.0)
		_desktop_shortcut(app, icon_position)

	window_layer = Control.new()
	canvas.add_child(window_layer)
	window_layer.position = Vector2.ZERO
	window_layer.size = BASE_SIZE
	window_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE

	taskbar = _panel(canvas, Vector2(16, 651), Vector2(1248, 52), HEADER)
	_button(taskbar, "◉", Vector2(12, 8), Vector2(42, 36), _toggle_app_menu)
	taskbar_apps = HBoxContainer.new()
	taskbar.add_child(taskbar_apps)
	taskbar_apps.position = Vector2(68, 7)
	taskbar_apps.size = Vector2(850, 38)
	taskbar_apps.add_theme_constant_override("separation", 8)
	status_label = _label(taskbar, "LOCAL SESSION", Vector2(960, 15), Vector2(260, 22), 14, MUTED)

func _desktop_shortcut(app: Dictionary, position_value: Vector2) -> void:
	var app_id: String = app["id"]
	var shortcut: Button = SHORTCUT_SCENE.instantiate() as Button
	canvas.add_child(shortcut)
	shortcut.position = position_value
	shortcut.size = Vector2(148, 110)
	shortcut.focus_mode = Control.FOCUS_NONE
	shortcut.pressed.connect(func() -> void: open_app(app_id))
	shortcut.add_theme_stylebox_override("normal", _style(PANEL, PANEL))
	shortcut.add_theme_stylebox_override("hover", _style(PANEL_ALT, GREEN))
	shortcut.add_theme_stylebox_override("pressed", _style(HEADER, GREEN))
	_icon(shortcut, app["icon"], app["fallback"], Vector2(51, 11), Vector2(46, 44))
	var title_label := _label(shortcut, settings_manager.tx(str(app["title"])), Vector2(8, 68), Vector2(132, 32), 14)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title_label.clip_text = true

func _toggle_app_menu() -> void:
	if is_instance_valid(app_menu):
		app_menu.queue_free()
		app_menu = null
		return
	app_menu = _panel(canvas, Vector2(20, 360), Vector2(225, 282), HEADER)
	canvas.move_child(app_menu, canvas.get_child_count() - 1)
	for index in range(APPS.size()):
		var app: Dictionary = APPS[index]
		var app_id: String = app["id"]
		_button(app_menu, settings_manager.tx(str(app["title"])), Vector2(10, 10 + index * 38), Vector2(205, 34), func() -> void:
			open_app(app_id)
			if is_instance_valid(app_menu):
				app_menu.queue_free()
				app_menu = null
		)

func _update_session_status() -> void:
	if status_label == null:
		return
	status_label.text = settings_manager.tx("REMOTE") + ": SEC-TERM-01" if not opened_from_inventory else settings_manager.tx("LOCAL SESSION")


func _tx(key: String) -> String:
	return settings_manager.tx(key)

func open_app(app_id: String) -> void:
	window_manager.open_app(app_id)
