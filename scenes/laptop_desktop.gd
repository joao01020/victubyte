extends CanvasLayer

# VICTU OS v1.0.1 - desktop, Linux terminal, Wi-Fi, file explorer, settings and player interaction fix.
# Replace scenes/laptop_desktop.gd with this script.
# All terminal operations are handled internally by the game.

signal wifi_connected
signal desktop_closed

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
const WINDOW_SIZE := Vector2(790.0, 470.0)
const WINDOW_ORIGIN := Vector2(245.0, 135.0)

const APPS := [
	{"id": "files", "title": "Files", "icon": "icon_folder.svg", "fallback": "F"},
	{"id": "terminal", "title": "Terminal", "icon": "icon_terminal.svg", "fallback": ">_"},
	{"id": "guide", "title": "Field Guide", "icon": "icon_book.svg", "fallback": "?"},
	{"id": "network", "title": "Network", "icon": "icon_wifi.svg", "fallback": "W"},
	{"id": "hardware", "title": "Hardware", "icon": "icon_cpu.svg", "fallback": "H"},
	{"id": "cameras", "title": "Cameras", "icon": "icon_camera.svg", "fallback": "C"},
	{"id": "settings", "title": "Settings", "icon": "icon_settings.svg", "fallback": "S"}
]

var terminal_ref: Node = null
var player_ref: Node = null
var opened_from_inventory: bool = false
var desktop_root: Control
var canvas: Control
var window_layer: Control
var taskbar: Panel
var taskbar_apps: HBoxContainer
var app_menu: Panel = null
var status_label: Label
var windows: Dictionary = {}
var minimized: Dictionary = {}
var drag_window: Panel = null
var current_directory: String = "/home/player"
var terminal_output: RichTextLabel
var terminal_input: LineEdit
var terminal_scroll: ScrollContainer
var previous_pause_state: bool = false
var current_locale: String = "pt_BR"
var settings_volume: float = 1.0
const SETTINGS_PATH := "user://victu_os_settings.cfg"
const LANGUAGE_OPTIONS := ["pt_BR", "en"]
var selected_network: String = ""
var connected_network: String = ""

# NVR accounts and camera permissions belong to the laboratory's game state.
# Change these credentials later through mission rewards or discovered documents.
const NVR_USERS := {
	"operator": {"password": "operator2026", "role": "viewer"},
	"admin": {"password": "admin2026", "role": "admin"}
}
const NVR_CAMERAS := [
	{"id": "CAM-01", "location": "Entrance", "status": "ONLINE"},
	{"id": "CAM-02", "location": "Laboratory", "status": "ONLINE"},
	{"id": "CAM-03", "location": "Storage", "status": "ONLINE"},
	{"id": "CAM-04", "location": "Restricted Wing", "status": "ONLINE"}
]
var nvr_username: String = ""
var nvr_role: String = ""
var nvr_selected_camera: String = "CAM-01"
var nvr_show_api: bool = false
var nvr_api_key_visible: bool = false
# Example application credential, used for the in-game integrations page only.
const NVR_API_KEY := "victu-lab-cctv-demo-key"

# Initial credentials for testing. Replace them with mission data later.
# These values are not displayed in the VICTU OS interface.
const WIFI_PASSWORDS := {
	"LAB-EXT": "labext2026",
	"LAB": "lab2026secure",
	"LAB-SYSTEM": "system2026secure"
}
var explorer_path: String = TERMINAL_HOME
var explorer_history: Array[String] = [TERMINAL_HOME]
var explorer_history_index: int = 0
var explorer_status: Label = null
var wifi_networks: Array[Dictionary] = [
	{"ssid": "LAB-EXT", "signal": 5, "quality": "Excellent", "security": "WPA2"},
	{"ssid": "LAB", "signal": 3, "quality": "Fair", "security": "WPA2"},
	{"ssid": "LAB-SYSTEM", "signal": 1, "quality": "Weak", "security": "WPA2"}
]


# Built-in terminal command handler and account state.
const TERMINAL_USER := "player"
const TERMINAL_HOST := "victu"
const TERMINAL_HOME := "/home/player"
# Initial administrator credential. Replace through the mission system.
const TERMINAL_DEMO_PASSWORD := "victu"
var terminal_username: String = TERMINAL_USER
var terminal_password_pending: bool = false
var terminal_pending_command: String = ""
var terminal_prompt_label: Label
var file_permissions: Dictionary = {
	"/home/player": "755", "/home/player/Documents": "755",
	"/home/player/Downloads": "755", "/home/player/FieldGuide": "755",
	"/home/player/Documents/welcome.txt": "644",
	"/remote": "755", "/remote/SEC-TERM-01": "750",
	"/remote/SEC-TERM-01/README.txt": "640",
	"/etc": "755", "/etc/lab.conf": "640",
	"/root": "700", "/root/admin_notes.txt": "600"
}
var file_owners: Dictionary = {
	"/home/player": "player", "/home/player/Documents": "player",
	"/home/player/Downloads": "player", "/home/player/FieldGuide": "player",
	"/home/player/Documents/welcome.txt": "player",
	"/remote": "root", "/remote/SEC-TERM-01": "root",
	"/remote/SEC-TERM-01/README.txt": "root",
	"/etc": "root", "/etc/lab.conf": "root",
	"/root": "root", "/root/admin_notes.txt": "root"
}

# Initial system files. A dedicated filesystem component will replace this.
var virtual_files: Dictionary = {
	"/home/player": ["Documents", "Downloads", "FieldGuide"],
	"/home/player/Documents": ["welcome.txt"],
	"/home/player/Downloads": [],
	"/home/player/FieldGuide": [],
	"/remote": ["SEC-TERM-01"],
	"/remote/SEC-TERM-01": ["README.txt"],
	"/etc": ["lab.conf"],
	"/root": ["admin_notes.txt"]
}
var file_contents: Dictionary = {
	"/home/player/Documents/welcome.txt": "Welcome to VICTU OS.\nExplore the desktop and open a terminal.",
	"/remote/SEC-TERM-01/README.txt": "LAB SECURITY TERMINAL\nMaintenance documents will be added in the first mission.",
	"/etc/lab.conf": "DEVICE=SEC-TERM-01\nACCESS=restricted",
	"/root/admin_notes.txt": "Restricted laboratory maintenance notes."
}


# Localized text for the in-game desktop. Command names remain Unix-compatible.
func _tx(key: String) -> String:
	var translations: Dictionary = {
		"Files": "Arquivos",
		"Terminal": "Terminal",
		"Field Guide": "Manual",
		"Manual": "Manual",
		"Network": "Rede",
		"Hardware": "Hardware",
		"Cameras": "Câmeras",
		"Settings": "Configurações",
		"LOCAL SESSION": "SESSÃO LOCAL",
		"REMOTE": "REMOTO",
		"WIRELESS NETWORKS": "REDES WI-FI",
		"Available connections": "Conexões disponíveis",
		"Refresh": "Atualizar",
		"Excellent": "Excelente",
		"Fair": "Razoável",
		"Weak": "Fraco",
		"LOCKED": "PROTEGIDA",
		"Select a network to see its details.": "Selecione uma rede para ver os detalhes.",
		"SELECTED": "SELECIONADA",
		"Signal": "Sinal",
		"Security": "Segurança",
		"Authentication required": "Autenticação necessária",
		"Wi-Fi password": "Senha do Wi-Fi",
		"Enter password": "Digite a senha para conectar à rede.",
		"Password": "Senha",
		"Show": "Mostrar",
		"Hide": "Ocultar",
		"Connect": "Conectar",
		"Cancel": "Cancelar",
		"CONNECTED": "CONECTADA",
		"Connected to": "Conectado a",
		"Incorrect password": "Senha incorreta. Tente novamente.",
		"Password required": "Digite a senha para continuar.",
		"FIELD GUIDE": "MANUAL",
		"Guide info": "As anotações das missões e os documentos baixados aparecerão aqui.\n\nO manual será atualizado enquanto você investiga o laboratório.",
		"HARDWARE": "HARDWARE",
		"Hardware info": "Módulos ESP32 e experimentos eletrônicos estarão disponíveis nas próximas missões.",
		"CAMERAS": "CÂMERAS",
		"Camera info": "Acesso restrito.\n\nConecte-se a um sistema de segurança autorizado durante uma missão.",
		"PLACES": "LOCAIS",
		"Home": "Início",
		"Documents": "Documentos",
		"Downloads": "Downloads",
		"Remote": "Remoto",
		"This folder is empty": "Esta pasta está vazia",
		"FILE": "ARQUIVO",
		"Back": "Voltar",
		"Items": "itens",
		"Permission denied": "Permissão negada",
		"Directory not found": "Diretório não encontrado",
		"Unable to open file.": "Não foi possível abrir o arquivo.",
		"Terminal intro": "Digite 'help' para listar os comandos disponíveis.",
		"Appearance": "Aparência",
		"Language": "Idioma",
		"Sound": "Som",
		"System": "Sistema",
		"Choose language": "Escolha o idioma do VICTU OS.",
		"Language changed": "Idioma atualizado. As janelas foram atualizadas.",
		"Desktop theme": "Tema do desktop",
		"Active theme": "Tema atual",
		"Theme fixed": "Tema VICTU Green ativo.",
		"Volume": "Volume",
		"Game audio": "Volume geral do jogo",
		"System version": "Versão do sistema",
		"Logged user": "Usuário atual",
		"Display": "Tela",
		"Settings saved": "Preferências salvas automaticamente",
		"Select section": "Selecione uma categoria para configurar o sistema.",
	}
	return str(translations.get(key, key)) if current_locale == "pt_BR" else key


func _load_settings() -> void:
	var config: ConfigFile = ConfigFile.new()
	if config.load(SETTINGS_PATH) == OK:
		var configured_locale: String = str(config.get_value("interface", "language", "pt_BR"))
		if LANGUAGE_OPTIONS.has(configured_locale):
			current_locale = configured_locale
		settings_volume = clampf(float(config.get_value("audio", "volume", 1.0)), 0.0, 1.0)
	TranslationServer.set_locale(current_locale)
	_apply_audio_volume()


func _save_settings() -> void:
	var config: ConfigFile = ConfigFile.new()
	config.set_value("interface", "language", current_locale)
	config.set_value("audio", "volume", settings_volume)
	var result: Error = config.save(SETTINGS_PATH)
	if result != OK:
		push_warning("VICTU OS: could not save preferences (%d)." % result)


func _apply_audio_volume() -> void:
	var master_bus: int = AudioServer.get_bus_index("Master")
	if master_bus >= 0:
		AudioServer.set_bus_volume_linear(master_bus, settings_volume)


func _change_language(next_locale: String) -> void:
	if not LANGUAGE_OPTIONS.has(next_locale) or current_locale == next_locale:
		return
	current_locale = next_locale
	TranslationServer.set_locale(current_locale)
	_save_settings()
	call_deferred("_rebuild_localized_desktop")


func _rebuild_localized_desktop() -> void:
	var opened_apps: Array = windows.keys()
	var minimized_apps: Dictionary = minimized.duplicate()
	windows.clear()
	minimized.clear()
	app_menu = null
	drag_window = null
	if is_instance_valid(desktop_root):
		remove_child(desktop_root)
		desktop_root.queue_free()
	_build_interface()
	_fit_canvas()
	_update_session_status()
	for app_id in opened_apps:
		open_app(str(app_id))
		if minimized_apps.get(app_id, false):
			_minimize_app(str(app_id))


func _app_title(app_id: String) -> String:
	for app in APPS:
		if str(app["id"]) == app_id:
			return _tx(str(app["title"]))
	return app_id.capitalize()

func _ready() -> void:
	_load_settings()
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_interface()
	_fit_canvas()
	get_viewport().size_changed.connect(_fit_canvas)
	hide()
	call_deferred("_connect_to_terminal")


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
	for app_id in windows.keys():
		var app_window: Control = windows[app_id]
		if is_instance_valid(app_window):
			app_window.queue_free()
	windows.clear()
	minimized.clear()
	drag_window = null
	_refresh_taskbar()

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
	_label(canvas, "v1.0.1", Vector2(263, 33), Vector2(90, 25), 15, MUTED)
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
	var shortcut := _button(canvas, "", position_value, Vector2(148, 110), func() -> void: open_app(app_id))
	shortcut.add_theme_stylebox_override("normal", _style(PANEL, PANEL))
	shortcut.add_theme_stylebox_override("hover", _style(PANEL_ALT, GREEN))
	shortcut.add_theme_stylebox_override("pressed", _style(HEADER, GREEN))
	_icon(shortcut, app["icon"], app["fallback"], Vector2(51, 11), Vector2(46, 44))
	var title_label := _label(shortcut, _tx(str(app["title"])), Vector2(8, 68), Vector2(132, 32), 14)
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
		_button(app_menu, _tx(str(app["title"])), Vector2(10, 10 + index * 38), Vector2(205, 34), func() -> void:
			open_app(app_id)
			if is_instance_valid(app_menu):
				app_menu.queue_free()
				app_menu = null
		)


func _update_session_status() -> void:
	if status_label == null:
		return
	status_label.text = _tx("REMOTE") + ": SEC-TERM-01" if not opened_from_inventory else _tx("LOCAL SESSION")


func open_app(app_id: String) -> void:
	if windows.has(app_id) and is_instance_valid(windows[app_id]):
		var existing: Control = windows[app_id]
		existing.show()
		minimized[app_id] = false
		window_layer.move_child(existing, window_layer.get_child_count() - 1)
		_refresh_taskbar()
		return

	var title: String = _app_title(app_id)
	var window_offset: float = float(windows.size() % 5) * 25.0
	var window := _panel(window_layer, WINDOW_ORIGIN + Vector2(window_offset, window_offset), WINDOW_SIZE, PANEL_ALT)
	# Outer shadow prevents neighboring desktop icons from visually merging with the frame.
	var window_style: StyleBoxFlat = _style(PANEL_ALT, BORDER, 9)
	window_style.shadow_color = Color(0.0, 0.0, 0.0, 0.95)
	window_style.shadow_size = 12
	window_style.shadow_offset = Vector2.ZERO
	window.add_theme_stylebox_override("panel", window_style)
	window.mouse_filter = Control.MOUSE_FILTER_STOP
	windows[app_id] = window
	minimized[app_id] = false

	var title_bar := _panel(window, Vector2.ZERO, Vector2(WINDOW_SIZE.x, 46), HEADER, 8)
	title_bar.mouse_filter = Control.MOUSE_FILTER_STOP
	title_bar.gui_input.connect(func(event: InputEvent) -> void: _on_title_bar_input(event, window))
	var title_label: Label = _label(title_bar, title, Vector2(18, 10), Vector2(650, 29), 20, GREEN)
	title_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_button(title_bar, "—", Vector2(692, 5), Vector2(42, 35), func() -> void: _minimize_app(app_id))
	_button(title_bar, "×", Vector2(741, 5), Vector2(40, 35), func() -> void: _close_app(app_id))

	var content := Control.new()
	window.add_child(content)
	content.position = Vector2(18, 60)
	content.size = Vector2(754, 390)
	content.mouse_filter = Control.MOUSE_FILTER_PASS
	_build_app_content(app_id, content)
	_refresh_taskbar()


func _on_title_bar_input(event: InputEvent, window: Panel) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			drag_window = window
			window_layer.move_child(window, window_layer.get_child_count() - 1)
		else:
			drag_window = null
	elif event is InputEventMouseMotion and drag_window == window:
		var scale_factor: float = maxf(canvas.scale.x, 0.001)
		var mouse_motion: InputEventMouseMotion = event as InputEventMouseMotion
		var next_position: Vector2 = window.position + mouse_motion.relative / scale_factor
		window.position.x = clampf(next_position.x, 0.0, BASE_SIZE.x - window.size.x)
		window.position.y = clampf(next_position.y, 78.0, 645.0 - window.size.y)


func _minimize_app(app_id: String) -> void:
	if not windows.has(app_id):
		return
	var window: Control = windows[app_id]
	window.hide()
	minimized[app_id] = true
	_refresh_taskbar()


func _close_app(app_id: String) -> void:
	if not windows.has(app_id):
		return
	var window: Control = windows[app_id]
	windows.erase(app_id)
	minimized.erase(app_id)
	window.queue_free()
	_refresh_taskbar()


func _refresh_taskbar() -> void:
	if taskbar_apps == null:
		return
	for child in taskbar_apps.get_children():
		child.queue_free()
	for app_id in windows.keys():
		var shortcut := Button.new()
		shortcut.text = _app_title(str(app_id))
		shortcut.clip_text = true
		shortcut.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		shortcut.custom_minimum_size = Vector2(124, 36)
		shortcut.add_theme_color_override("font_color", GREEN if not minimized.get(app_id, false) else MUTED)
		shortcut.add_theme_stylebox_override("normal", _style(PANEL_ALT))
		shortcut.pressed.connect(func() -> void: open_app(app_id))
		taskbar_apps.add_child(shortcut)


func _build_app_content(app_id: String, content: Control) -> void:
	match app_id:
		"terminal":
			_build_terminal(content)
		"files":
			_build_files(content)
		"guide":
			_build_info(content, _tx("FIELD GUIDE"), _tx("Guide info") if current_locale == "pt_BR" else "Your mission notes and downloaded documents will appear here.\n\nThe field guide will evolve as you investigate the laboratory.")
		"network":
			_build_network(content)
		"hardware":
			_build_info(content, _tx("HARDWARE"), _tx("Hardware info") if current_locale == "pt_BR" else "ESP32 modules and electronic experiments will be available in future missions.")
		"cameras":
			_build_cameras(content)
		"settings":
			_build_settings(content)


# Settings pages share state with the desktop and survive game restarts.
func _build_settings(parent: Control, section: String = "language") -> void:
	for child in parent.get_children():
		parent.remove_child(child)
		child.queue_free()

	var padding: float = 8.0
	var gap: float = 10.0
	var panel_height: float = parent.size.y - padding * 2.0
	var sidebar_width: float = 190.0
	var content_x: float = padding + sidebar_width + gap
	var content_width: float = parent.size.x - content_x - padding

	var sidebar: Panel = _panel(parent, Vector2(padding, padding), Vector2(sidebar_width, panel_height), PANEL, 7)
	_label(sidebar, _tx("Settings"), Vector2(12, 12), Vector2(sidebar_width - 24.0, 30), 18, GREEN)

	var sections: Array[String] = ["appearance", "language", "sound", "system"]
	for index in range(sections.size()):
		var section_id: String = sections[index]
		var section_title: String = _tx(section_id.capitalize())
		var button: Button = _button(sidebar, section_title, Vector2(10, 48 + index * 49), Vector2(sidebar_width - 20.0, 38), func() -> void:
			_build_settings(parent, section_id)
		)
		_apply_sidebar_button_style(button, section == section_id)
		button.add_theme_font_size_override("font_size", 15)

	var content_panel: Panel = _panel(parent, Vector2(content_x, padding), Vector2(content_width, panel_height), BG, 7)
	_label(content_panel, _tx(section.capitalize()), Vector2(18, 14), Vector2(content_width - 36.0, 34), 21, GREEN)

	match section:
		"language":
			_label(content_panel, _tx("Choose language"), Vector2(18, 54), Vector2(content_width - 36.0, 24), 16, MUTED)
			var button_width: float = content_width - 36.0
			var pt_button: Button = _button(content_panel, "Português (Brasil)", Vector2(18, 96), Vector2(button_width, 44), func() -> void:
				_change_language("pt_BR")
			)
			var en_button: Button = _button(content_panel, "English", Vector2(18, 150), Vector2(button_width, 44), func() -> void:
				_change_language("en")
			)
			if current_locale == "pt_BR":
				pt_button.add_theme_stylebox_override("normal", _style(HEADER, GREEN))
			else:
				en_button.add_theme_stylebox_override("normal", _style(HEADER, GREEN))
			_label(content_panel, _tx("Settings saved"), Vector2(18, panel_height - 58.0), Vector2(content_width - 36.0, 24), 14, MUTED)
		"appearance":
			_label(content_panel, _tx("Active theme") + ": VICTU Green", Vector2(18, 74), Vector2(content_width - 36.0, 28), 17, TEXT_COLOR)
			var appearance_note := _label(content_panel, _tx("Theme fixed"), Vector2(18, 113), Vector2(content_width - 36.0, 54), 14, MUTED)
			appearance_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		"sound":
			_label(content_panel, _tx("Game audio"), Vector2(18, 70), Vector2(content_width - 36.0, 28), 17, TEXT_COLOR)
			var volume_label: Label = _label(content_panel, "%d%%" % roundi(settings_volume * 100.0), Vector2(18, 108), Vector2(content_width - 36.0, 24), 18, GREEN)
			var volume_slider: HSlider = HSlider.new()
			content_panel.add_child(volume_slider)
			volume_slider.position = Vector2(18, 146)
			volume_slider.size = Vector2(content_width - 36.0, 26)
			volume_slider.min_value = 0.0
			volume_slider.max_value = 100.0
			volume_slider.step = 1.0
			volume_slider.value = settings_volume * 100.0
			volume_slider.value_changed.connect(func(value: float) -> void:
				settings_volume = value / 100.0
				volume_label.text = "%d%%" % roundi(value)
				_apply_audio_volume()
				_save_settings()
			)
			_label(content_panel, _tx("Settings saved"), Vector2(18, panel_height - 58.0), Vector2(content_width - 36.0, 24), 14, MUTED)
		"system":
			_label(content_panel, "%s: VICTU OS v1.0.1" % _tx("System version"), Vector2(18, 70), Vector2(content_width - 36.0, 28), 17)
			_label(content_panel, "%s: 1280 × 720" % _tx("Display"), Vector2(18, 108), Vector2(content_width - 36.0, 28), 17)
			_label(content_panel, "%s: %s" % [_tx("Logged user"), terminal_username], Vector2(18, 146), Vector2(content_width - 36.0, 28), 17)


func _build_network(parent: Control) -> void:
	_label(parent, _tx("WIRELESS NETWORKS"), Vector2(12, 10), Vector2(470, 38), 24, GREEN)
	_label(parent, _tx("Available connections"), Vector2(12, 51), Vector2(490, 30), 16, MUTED)
	_button(parent, _tx("Refresh"), Vector2(604, 14), Vector2(128, 39), func() -> void:
		if is_instance_valid(parent):
			_refresh_network(parent)
	)
	_panel(parent, Vector2(10, 92), Vector2(730, 226), PANEL)
	for index in range(wifi_networks.size()):
		var network_data: Dictionary = wifi_networks[index]
		var ssid: String = str(network_data["ssid"])
		var strength: int = int(network_data["signal"])
		var row_y: float = 101.0 + float(index) * 70.0
		var selected: bool = selected_network == ssid
		var row_button: Button = _button(parent, "", Vector2(20, row_y), Vector2(710, 61), func() -> void:
			selected_network = ssid
			_refresh_network(parent)
			if connected_network != ssid:
				_show_wifi_password_dialog(parent, ssid)
		)
		if selected:
			row_button.add_theme_stylebox_override("normal", _style(HEADER, GREEN))
		_icon(row_button, "icon_wifi.svg", "W", Vector2(13, 13), Vector2(30, 31))
		_label(row_button, ssid, Vector2(58, 9), Vector2(250, 28), 19, TEXT_COLOR)
		_label(row_button, "%s  ·  %s" % [_tx(str(network_data["quality"])), str(network_data["security"])], Vector2(58, 36), Vector2(290, 20), 13, MUTED)
		_draw_signal_bars(row_button, Vector2(492, 17), strength)
		_label(row_button, _tx("CONNECTED") if connected_network == ssid else _tx("LOCKED"), Vector2(605, 21), Vector2(102, 24), 13, GREEN if connected_network == ssid else MUTED)
	if selected_network.is_empty():
		_label(parent, _tx("Select a network to see its details."), Vector2(14, 334), Vector2(695, 38), 17, MUTED)
	else:
		var chosen: Dictionary = {}
		for entry in wifi_networks:
			if str(entry["ssid"]) == selected_network:
				chosen = entry
				break
		if not chosen.is_empty():
			_label(parent, _tx("SELECTED") + ": " + selected_network, Vector2(14, 328), Vector2(695, 28), 17, GREEN)
			var connection_message: String = _tx("CONNECTED") if connected_network == selected_network else _tx("Authentication required")
			_label(parent, "%s: %s (%d/5)   |   %s: %s   |   %s" % [_tx("Signal"), _tx(str(chosen["quality"])), int(chosen["signal"]), _tx("Security"), str(chosen["security"]), connection_message], Vector2(14, 359), Vector2(730, 27), 14, MUTED)


# Password prompt stays inside the Network window without changing the desktop.
func _show_wifi_password_dialog(parent: Control, ssid: String) -> void:
	if not is_instance_valid(parent):
		return

	var overlay: Control = Control.new()
	parent.add_child(overlay)
	overlay.position = Vector2.ZERO
	overlay.size = parent.size
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP

	var shade: ColorRect = ColorRect.new()
	overlay.add_child(shade)
	shade.size = parent.size
	shade.color = Color(0.0, 0.0, 0.0, 0.66)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP

	var dialog_width: float = 488.0
	var dialog_height: float = 270.0
	var dialog_x: float = (parent.size.x - dialog_width) * 0.5
	var dialog_y: float = (parent.size.y - dialog_height) * 0.5
	var dialog: Panel = _panel(overlay, Vector2(dialog_x, dialog_y), Vector2(dialog_width, dialog_height), PANEL_ALT, 10)
	dialog.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel(dialog, Vector2.ZERO, Vector2(dialog_width, 44), HEADER, 8)
	_label(dialog, _tx("Wi-Fi password"), Vector2(18, 9), Vector2(405, 28), 20, GREEN)
	_button(dialog, "×", Vector2(439, 6), Vector2(35, 32), func() -> void:
		overlay.queue_free()
	)
	_label(dialog, ssid, Vector2(18, 56), Vector2(450, 30), 19, TEXT_COLOR)
	_label(dialog, _tx("Enter password"), Vector2(18, 91), Vector2(450, 26), 15, MUTED)

	var password_input: LineEdit = LineEdit.new()
	dialog.add_child(password_input)
	password_input.position = Vector2(18, 130)
	password_input.size = Vector2(324, 43)
	password_input.secret = true
	password_input.max_length = 64
	password_input.placeholder_text = _tx("Password")
	password_input.add_theme_color_override("font_color", TEXT_COLOR)
	password_input.add_theme_color_override("caret_color", GREEN)
	password_input.add_theme_font_size_override("font_size", 17)
	password_input.add_theme_stylebox_override("normal", _style(BG))
	password_input.add_theme_stylebox_override("focus", _style(BG, GREEN))

	var show_button: Button = _button(dialog, _tx("Show"), Vector2(351, 130), Vector2(118, 43), func() -> void:
		password_input.secret = not password_input.secret
	)
	show_button.pressed.connect(func() -> void:
		show_button.text = _tx("Show") if password_input.secret else _tx("Hide")
	)

	var error_label: Label = _label(dialog, "", Vector2(18, 179), Vector2(452, 24), 14, Color("ff8585"))
	_button(dialog, _tx("Cancel"), Vector2(218, 215), Vector2(115, 40), func() -> void:
		overlay.queue_free()
	)
	_button(dialog, _tx("Connect"), Vector2(345, 215), Vector2(124, 40), func() -> void:
		_attempt_wifi_connection(parent, overlay, ssid, password_input, error_label)
	)
	password_input.text_submitted.connect(func(_entered_password: String) -> void:
		_attempt_wifi_connection(parent, overlay, ssid, password_input, error_label)
	)
	password_input.call_deferred("grab_focus")


func _attempt_wifi_connection(parent: Control, overlay: Control, ssid: String, password_input: LineEdit, error_label: Label) -> void:
	if not is_instance_valid(parent) or not is_instance_valid(overlay) or not is_instance_valid(password_input):
		return
	var submitted_password: String = password_input.text
	if submitted_password.is_empty():
		error_label.text = _tx("Password required")
		password_input.grab_focus()
		return
	if submitted_password != str(WIFI_PASSWORDS.get(ssid, "")):
		error_label.text = _tx("Incorrect password")
		password_input.clear()
		password_input.grab_focus()
		return

	password_input.clear()
	connected_network = ssid
	selected_network = ssid
	_refresh_network(parent)
	if windows.has("cameras") and is_instance_valid(windows["cameras"]):
		var cameras_window: Control = windows["cameras"]
		if cameras_window.get_child_count() > 1:
			var cameras_content: Control = cameras_window.get_child(1) as Control
			if cameras_content != null:
				_build_cameras(cameras_content)
	# This Wi-Fi login is not linked to the laboratory door or other missions.


func _draw_signal_bars(parent: Control, position_value: Vector2, strength: int) -> void:
	for index in range(5):
		var bar_height: float = 9.0 + float(index) * 5.0
		var indicator: ColorRect = ColorRect.new()
		parent.add_child(indicator)
		indicator.position = position_value + Vector2(float(index) * 11.0, 30.0 - bar_height)
		indicator.size = Vector2(7.0, bar_height)
		indicator.color = GREEN if index < strength else Color("24513c")
		indicator.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _refresh_network(parent: Control) -> void:
	if not is_instance_valid(parent):
		return
	for child in parent.get_children():
		parent.remove_child(child)
		child.queue_free()
	_build_network(parent)


# The NVR web interface uses an account login. API credentials are for software
# integrations and are not required to sign into the operator console.
func _nvr_text(pt: String, en: String) -> String:
	return pt if current_locale == "pt_BR" else en


func _build_cameras(parent: Control) -> void:
	for child in parent.get_children():
		parent.remove_child(child)
		child.queue_free()
	var header: Panel = _panel(parent, Vector2(6, 5), Vector2(742, 43), HEADER, 6)
	_label(header, "LAB NVR  •  CCTV-01", Vector2(14, 7), Vector2(390, 28), 19, GREEN)
	_label(header, "192.168.10.20", Vector2(538, 9), Vector2(187, 25), 14, MUTED)

	if connected_network.is_empty():
		_label(parent, _nvr_text("SERVIDOR INACESSÍVEL", "SERVER UNREACHABLE"), Vector2(22, 94), Vector2(700, 36), 23, GREEN)
		var notice: Label = _label(parent, _nvr_text("Conecte-se à rede do laboratório pelo aplicativo Rede para acessar o NVR.", "Connect to the laboratory network in Network to access the NVR."), Vector2(22, 146), Vector2(700, 86), 17, TEXT_COLOR)
		notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_button(parent, _nvr_text("Tentar novamente", "Retry"), Vector2(22, 258), Vector2(184, 42), func() -> void:
			_build_cameras(parent)
		)
		return

	if nvr_username.is_empty():
		_build_nvr_login(parent)
		return

	if nvr_show_api:
		_build_nvr_api(parent)
	else:
		_build_nvr_dashboard(parent)


func _build_nvr_login(parent: Control) -> void:
	var form: Panel = _panel(parent, Vector2(125, 59), Vector2(504, 315), PANEL, 8)
	_label(form, _nvr_text("ACESSO AO MONITORAMENTO", "MONITORING LOGIN"), Vector2(22, 15), Vector2(460, 33), 21, GREEN)
	_label(form, _nvr_text("Usuário", "Username"), Vector2(22, 62), Vector2(450, 22), 15, MUTED)
	var username_input: LineEdit = _nvr_input(form, Vector2(22, 86), Vector2(458, 39), false)
	username_input.placeholder_text = _nvr_text("Nome de usuário", "Username")
	_label(form, _nvr_text("Senha", "Password"), Vector2(22, 133), Vector2(450, 22), 15, MUTED)
	var password_input: LineEdit = _nvr_input(form, Vector2(22, 157), Vector2(458, 39), true)
	password_input.placeholder_text = _nvr_text("Senha do NVR", "NVR password")
	var feedback: Label = _label(form, "", Vector2(22, 206), Vector2(460, 24), 14, Color("ff8585"))
	_button(form, _nvr_text("Entrar", "Sign in"), Vector2(329, 247), Vector2(151, 43), func() -> void:
		_nvr_sign_in(parent, username_input, password_input, feedback)
	)
	password_input.text_submitted.connect(func(_value: String) -> void:
		_nvr_sign_in(parent, username_input, password_input, feedback)
	)
	username_input.call_deferred("grab_focus")


func _nvr_input(parent: Control, position_value: Vector2, size_value: Vector2, is_hidden: bool) -> LineEdit:
	var input: LineEdit = LineEdit.new()
	parent.add_child(input)
	input.position = position_value
	input.size = size_value
	input.secret = is_hidden
	input.max_length = 80
	input.add_theme_color_override("font_color", TEXT_COLOR)
	input.add_theme_color_override("caret_color", GREEN)
	input.add_theme_font_size_override("font_size", 16)
	input.add_theme_stylebox_override("normal", _style(BG, BORDER))
	input.add_theme_stylebox_override("focus", _style(BG, GREEN))
	return input


func _nvr_sign_in(parent: Control, username_input: LineEdit, password_input: LineEdit, feedback: Label) -> void:
	if not is_instance_valid(username_input) or not is_instance_valid(password_input):
		return
	var account_name: String = username_input.text.strip_edges().to_lower()
	var credentials: Dictionary = NVR_USERS.get(account_name, {})
	if credentials.is_empty() or password_input.text != str(credentials.get("password", "")):
		feedback.text = _nvr_text("Usuário ou senha incorretos.", "Invalid username or password.")
		password_input.clear()
		password_input.grab_focus()
		return
	nvr_username = account_name
	nvr_role = str(credentials.get("role", "viewer"))
	password_input.clear()
	nvr_show_api = false
	_build_cameras(parent)


func _build_nvr_dashboard(parent: Control) -> void:
	_label(parent, "%s: %s   •   %s: %s" % [_nvr_text("Usuário", "User"), nvr_username, _nvr_text("Perfil", "Role"), nvr_role.to_upper()], Vector2(14, 59), Vector2(468, 26), 15, TEXT_COLOR)
	_button(parent, "API", Vector2(537, 54), Vector2(87, 34), func() -> void:
		nvr_show_api = true
		_build_cameras(parent)
	)
	_button(parent, _nvr_text("Sair", "Logout"), Vector2(631, 54), Vector2(106, 34), func() -> void:
		nvr_username = ""
		nvr_role = ""
		nvr_show_api = false
		_build_cameras(parent)
	)
	var list_panel: Panel = _panel(parent, Vector2(8, 101), Vector2(238, 278), PANEL, 6)
	_label(list_panel, _nvr_text("CÂMERAS", "CAMERAS"), Vector2(12, 8), Vector2(210, 28), 17, GREEN)
	for index in range(NVR_CAMERAS.size()):
		var camera_data: Dictionary = NVR_CAMERAS[index]
		var camera_id: String = str(camera_data["id"])
		var is_restricted: bool = camera_id == "CAM-04" and nvr_role != "admin"
		var button: Button = _button(list_panel, camera_id + ("  [LOCK]" if is_restricted else ""), Vector2(10, 43 + index * 55), Vector2(218, 44), func() -> void:
			nvr_selected_camera = camera_id
			_build_cameras(parent)
		)
		if camera_id == nvr_selected_camera:
			button.add_theme_stylebox_override("normal", _style(HEADER, GREEN))
	var preview: Panel = _panel(parent, Vector2(255, 101), Vector2(491, 278), BG, 6)
	var restricted: bool = nvr_selected_camera == "CAM-04" and nvr_role != "admin"
	_label(preview, nvr_selected_camera + "  •  " + ("RESTRICTED" if restricted else "ONLINE"), Vector2(17, 11), Vector2(457, 28), 18, GREEN)
	if restricted:
		_label(preview, _nvr_text("ACESSO NEGADO — PERFIL INSUFICIENTE", "ACCESS DENIED — INSUFFICIENT ROLE"), Vector2(20, 107), Vector2(450, 40), 16, TEXT_COLOR)
	else:
		var message: Label = _label(preview, _nvr_text("Canal disponível. A imagem ao vivo será vinculada à câmera do cenário.", "Channel available. Live video will be linked to the scene camera."), Vector2(28, 92), Vector2(430, 93), 16, MUTED)
		message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART


func _build_nvr_api(parent: Control) -> void:
	_label(parent, _nvr_text("INTEGRAÇÃO API", "API INTEGRATION"), Vector2(17, 64), Vector2(520, 35), 21, GREEN)
	_button(parent, _nvr_text("Voltar", "Back"), Vector2(618, 58), Vector2(116, 38), func() -> void:
		nvr_show_api = false
		_build_cameras(parent)
	)
	var panel: Panel = _panel(parent, Vector2(13, 111), Vector2(726, 258), PANEL, 7)
	var message: Label = _label(panel, _nvr_text("Chaves de API são usadas por programas autorizados para integrar serviços ao NVR. O login normal não exige chave de API.", "API keys allow authorized software to integrate with the NVR. Normal operator login does not require an API key."), Vector2(16, 18), Vector2(691, 78), 16, TEXT_COLOR)
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if nvr_role != "admin":
		_label(panel, _nvr_text("Somente administradores podem visualizar as credenciais de integração.", "Only administrators can view integration credentials."), Vector2(16, 135), Vector2(691, 55), 16, MUTED)
		return
	var api_field: LineEdit = _nvr_input(panel, Vector2(16, 125), Vector2(514, 43), not nvr_api_key_visible)
	api_field.text = NVR_API_KEY
	api_field.editable = false
	_button(panel, _nvr_text("Ocultar", "Hide") if nvr_api_key_visible else _nvr_text("Mostrar", "Show"), Vector2(542, 125), Vector2(164, 43), func() -> void:
		nvr_api_key_visible = not nvr_api_key_visible
		_build_cameras(parent)
	)


func _build_info(parent: Control, heading: String, description: String) -> void:
	_label(parent, heading, Vector2(12, 12), Vector2(690, 38), 23, GREEN)
	var message := _label(parent, description, Vector2(12, 67), Vector2(710, 270), 18)
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART


func _build_terminal(parent: Control) -> void:
	# A single scrollable terminal surface: history and editable prompt
	# share the same text flow, without a separate command field.
	terminal_scroll = ScrollContainer.new()
	parent.add_child(terminal_scroll)
	terminal_scroll.position = Vector2(8, 8)
	terminal_scroll.size = Vector2(738, 390)
	terminal_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	terminal_scroll.mouse_filter = Control.MOUSE_FILTER_PASS

	var lines := VBoxContainer.new()
	terminal_scroll.add_child(lines)
	lines.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lines.custom_minimum_size = Vector2(716, 0)
	lines.add_theme_constant_override("separation", 0)

	terminal_output = RichTextLabel.new()
	lines.add_child(terminal_output)
	terminal_output.fit_content = true
	terminal_output.scroll_active = false
	terminal_output.bbcode_enabled = false
	terminal_output.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	terminal_output.add_theme_color_override("default_color", TEXT_COLOR)
	terminal_output.add_theme_font_size_override("normal_font_size", 17)
	terminal_output.add_theme_constant_override("line_separation", 3)
	terminal_output.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var input_row := HBoxContainer.new()
	lines.add_child(input_row)
	input_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	input_row.add_theme_constant_override("separation", 8)

	terminal_prompt_label = Label.new()
	input_row.add_child(terminal_prompt_label)
	terminal_prompt_label.add_theme_color_override("font_color", GREEN)
	terminal_prompt_label.add_theme_font_size_override("font_size", 17)
	terminal_prompt_label.mouse_filter = Control.MOUSE_FILTER_IGNORE

	terminal_input = LineEdit.new()
	input_row.add_child(terminal_input)
	terminal_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	terminal_input.custom_minimum_size = Vector2(60, 28)
	terminal_input.flat = true
	terminal_input.placeholder_text = ""
	terminal_input.caret_blink = true
	terminal_input.add_theme_color_override("font_color", TEXT_COLOR)
	terminal_input.add_theme_color_override("caret_color", GREEN)
	terminal_input.add_theme_font_size_override("font_size", 17)
	for state in ["normal", "focus", "read_only"]:
		terminal_input.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	terminal_input.text_submitted.connect(_on_command_submitted)
	terminal_scroll.gui_input.connect(_on_terminal_surface_input)

	_write_terminal("VICTU OS TERMINAL v1.0")
	_write_terminal(_tx("Terminal intro") + "\n")
	_update_terminal_prompt()
	terminal_input.grab_focus()
	_scroll_terminal_to_bottom.call_deferred()


func _on_terminal_surface_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if is_instance_valid(terminal_input):
			terminal_input.grab_focus()


func _scroll_terminal_to_bottom() -> void:
	if is_instance_valid(terminal_scroll):
		var scroll_bar: VScrollBar = terminal_scroll.get_v_scroll_bar()
		terminal_scroll.scroll_vertical = int(scroll_bar.max_value)


func _terminal_prompt() -> String:
	var shown_path: String = current_directory
	if current_directory == TERMINAL_HOME:
		shown_path = "~"
	elif current_directory.begins_with(TERMINAL_HOME + "/"):
		shown_path = "~" + current_directory.substr(TERMINAL_HOME.length())
	var marker: String = "#" if terminal_username == "root" else "$"
	return "%s@%s:%s%s" % [terminal_username, TERMINAL_HOST, shown_path, marker]


func _update_terminal_prompt() -> void:
	if not is_instance_valid(terminal_prompt_label):
		return
	terminal_prompt_label.text = "[sudo] password for %s:" % TERMINAL_USER if terminal_password_pending else _terminal_prompt()
	if is_instance_valid(terminal_input):
		terminal_input.secret = terminal_password_pending
		terminal_input.placeholder_text = ""
	_scroll_terminal_to_bottom.call_deferred()


func _write_terminal(message: String) -> void:
	if is_instance_valid(terminal_output):
		terminal_output.append_text(message + "\n")
		_scroll_terminal_to_bottom.call_deferred()


func _on_command_submitted(command: String) -> void:
	if not is_instance_valid(terminal_input):
		return
	terminal_input.clear()
	if terminal_password_pending:
		# The password must not appear in terminal history.
		_write_terminal(terminal_prompt_label.text)
		terminal_password_pending = false
		var pending: String = terminal_pending_command
		terminal_pending_command = ""
		if command == TERMINAL_DEMO_PASSWORD:
			_execute_terminal_command(pending, true)
		else:
			_write_terminal("sudo: incorrect password")
		if is_instance_valid(terminal_input):
			_update_terminal_prompt()
			terminal_input.grab_focus()
		return

	var trimmed: String = command.strip_edges()
	_write_terminal(_terminal_prompt() + " " + command)
	if trimmed.is_empty():
		_update_terminal_prompt()
		terminal_input.grab_focus()
		return
	if trimmed == "sudo -l":
		_write_terminal("User player may run the following commands as root: ALL")
	elif trimmed == "sudo" or trimmed.begins_with("sudo "):
		if terminal_username == "root":
			_execute_terminal_command(trimmed.substr(5).strip_edges(), true)
		else:
			var sudo_command: String = trimmed.substr(5).strip_edges()
			if sudo_command.is_empty():
				_write_terminal("usage: sudo COMMAND")
			else:
				terminal_pending_command = sudo_command
				terminal_password_pending = true
	else:
		_execute_terminal_command(trimmed, terminal_username == "root")
	if is_instance_valid(terminal_input) and not terminal_input.is_queued_for_deletion():
		_update_terminal_prompt()
		terminal_input.grab_focus()


func _execute_terminal_command(command: String, as_root: bool) -> void:
	var parts: PackedStringArray = command.split(" ", false)
	if parts.is_empty():
		return
	var verb: String = parts[0].to_lower()
	var argument: String = parts[1] if parts.size() > 1 else ""
	match verb:
		"help":
			_write_terminal("help  ls [-l]  pwd  cd  cat  whoami  id  sudo -l")
			_write_terminal("chmod MODE FILE  touch FILE  clear  exit  sudo -i")
		"pwd":
			_write_terminal(current_directory)
		"whoami":
			_write_terminal("root" if as_root else terminal_username)
		"id":
			_write_terminal("uid=0(root) gid=0(root)" if as_root else "uid=1000(player) gid=1000(player) groups=1000(player),27(sudo)")
		"ls":
			var detailed: bool = argument == "-l"
			var path_arg: String = parts[2] if detailed and parts.size() > 2 else (argument if not detailed else "")
			var target: String = current_directory if path_arg.is_empty() else _resolve_path(path_arg)
			if not virtual_files.has(target):
				_write_terminal("ls: cannot access '%s': No such directory" % target)
			elif not _can_access(target, "r", as_root):
				_write_terminal("ls: cannot open directory '%s': Permission denied" % target)
			else:
				var names: Array = virtual_files[target]
				for item in names:
					var full_path: String = target.path_join(str(item))
					if detailed:
						var mode: String = str(file_permissions.get(full_path, "644"))
						var prefix: String = "d" if virtual_files.has(full_path) else "-"
						_write_terminal("%s%s  %-7s %s" % [prefix, _mode_text(mode), str(file_owners.get(full_path, "player")), item])
					else:
						_write_terminal(str(item))
		"cd":
			var target: String = _resolve_path(argument)
			if not virtual_files.has(target):
				_write_terminal("cd: %s: No such directory" % argument)
			elif not _can_access(target, "x", as_root):
				_write_terminal("cd: %s: Permission denied" % argument)
			else:
				current_directory = target
		"cat":
			if argument.is_empty():
				_write_terminal("cat: missing file operand")
			else:
				var target: String = _resolve_path(argument)
				if not file_contents.has(target):
					_write_terminal("cat: %s: No such file" % argument)
				elif not _can_access(target, "r", as_root):
					_write_terminal("cat: %s: Permission denied" % argument)
				else:
					_write_terminal(str(file_contents[target]))
		"chmod":
			if parts.size() < 3:
				_write_terminal("usage: chmod MODE FILE (e.g. chmod 600 welcome.txt)")
			else:
				var mode: String = parts[1]
				var path: String = _resolve_path(parts[2])
				if mode.length() != 3 or not mode.is_valid_int() or int(mode) < 0 or int(mode) > 777 or mode.contains("8") or mode.contains("9"):
					_write_terminal("chmod: invalid mode: " + mode)
				elif not file_permissions.has(path):
					_write_terminal("chmod: cannot access '%s'" % path)
				elif not as_root and str(file_owners.get(path, "root")) != TERMINAL_USER:
					_write_terminal("chmod: changing permissions of '%s': Operation not permitted" % path)
				else:
					file_permissions[path] = mode
		"touch":
			if argument.is_empty():
				_write_terminal("touch: missing file operand")
			else:
				var path: String = _resolve_path(argument)
				var parent_dir: String = path.get_base_dir()
				if not virtual_files.has(parent_dir):
					_write_terminal("touch: cannot touch '%s': No such directory" % argument)
				elif not _can_access(parent_dir, "w", as_root):
					_write_terminal("touch: cannot touch '%s': Permission denied" % argument)
				elif virtual_files.has(path):
					_write_terminal("touch: '%s' is a directory" % argument)
				else:
					if not file_contents.has(path):
						file_contents[path] = ""
						var contents: Array = virtual_files[parent_dir]
						contents.append(path.get_file())
						virtual_files[parent_dir] = contents
						file_permissions[path] = "644"
						file_owners[path] = "root" if as_root else TERMINAL_USER
		"-i":
			if not as_root:
				_write_terminal("-i: permission denied")
			else:
				terminal_username = "root"
				current_directory = "/root"
				_write_terminal("Root session started. Type 'exit' to return to player.")
		"clear":
			if is_instance_valid(terminal_output):
				terminal_output.clear()
				_scroll_terminal_to_bottom.call_deferred()
		"exit":
			if terminal_username == "root":
				terminal_username = TERMINAL_USER
				current_directory = TERMINAL_HOME
				_write_terminal("Returned to player session.")
			else:
				_close_app("terminal")
		_:
			_write_terminal("%s: command not found. Try 'help'." % verb)


func _can_access(path: String, operation: String, as_root: bool) -> bool:
	if as_root:
		return true
	var mode: String = str(file_permissions.get(path, "000"))
	var file_owner: String = str(file_owners.get(path, "root"))
	var digit_index: int = 0 if file_owner == TERMINAL_USER else 2
	if mode.length() != 3:
		return false
	var bits: int = int(mode.substr(digit_index, 1))
	var required: int = 4 if operation == "r" else (2 if operation == "w" else 1)
	return (bits & required) != 0


func _mode_text(mode: String) -> String:
	var result: String = ""
	for digit in mode:
		var bits: int = int(digit)
		result += "r" if (bits & 4) != 0 else "-"
		result += "w" if (bits & 2) != 0 else "-"
		result += "x" if (bits & 1) != 0 else "-"
	return result


func _resolve_path(argument: String) -> String:
	if argument.is_empty() or argument == "~":
		return "/home/player"
	var segments := PackedStringArray()
	var raw_path := argument if argument.begins_with("/") else current_directory.path_join(argument)
	for segment in raw_path.split("/", false):
		if segment == ".":
			continue
		if segment == "..":
			if not segments.is_empty():
				segments.remove_at(segments.size() - 1)
		else:
			segments.append(segment)
	return "/" + "/".join(segments)


# The graphical explorer reads the exact same dictionaries as the terminal.
# Selecting a folder enters it; files open in a dedicated viewer.
func _build_files(parent: Control) -> void:
	_render_explorer(parent)


func _clear_explorer(parent: Control) -> void:
	for child in parent.get_children():
		parent.remove_child(child)
		child.queue_free()


func _explorer_navigate(parent: Control, path: String, record_history: bool = true) -> void:
	if not virtual_files.has(path):
		return
	if not _can_access(path, "x", terminal_username == "root"):
		_show_explorer_notice(parent, _tx("Permission denied") + ": " + path)
		return
	explorer_path = path
	if record_history:
		while explorer_history.size() > explorer_history_index + 1:
			explorer_history.remove_at(explorer_history.size() - 1)
		explorer_history.append(path)
		explorer_history_index = explorer_history.size() - 1
	_render_explorer(parent)


func _explorer_back(parent: Control) -> void:
	if explorer_history_index <= 0:
		return
	explorer_history_index -= 1
	_explorer_navigate(parent, explorer_history[explorer_history_index], false)


func _explorer_forward(parent: Control) -> void:
	if explorer_history_index + 1 >= explorer_history.size():
		return
	explorer_history_index += 1
	_explorer_navigate(parent, explorer_history[explorer_history_index], false)


func _explorer_up(parent: Control) -> void:
	if explorer_path == "/":
		return
	var parent_path: String = explorer_path.get_base_dir()
	if parent_path.is_empty():
		parent_path = "/"
	if virtual_files.has(parent_path):
		_explorer_navigate(parent, parent_path)


func _explorer_home(parent: Control) -> void:
	_explorer_navigate(parent, TERMINAL_HOME)


func _show_explorer_notice(_parent: Control, message: String) -> void:
	if is_instance_valid(explorer_status):
		explorer_status.text = message


func _render_explorer(parent: Control) -> void:
	if not is_instance_valid(parent):
		return
	_clear_explorer(parent)

	# Standard file-manager toolbar, navigation buttons and address bar.
	var toolbar: Panel = _panel(parent, Vector2(0, 0), Vector2(parent.size.x, 48), HEADER, 7)
	_button(toolbar, "‹", Vector2(8, 6), Vector2(38, 36), func() -> void: _explorer_back(parent))
	_button(toolbar, "›", Vector2(50, 6), Vector2(38, 36), func() -> void: _explorer_forward(parent))
	_button(toolbar, "↑", Vector2(92, 6), Vector2(38, 36), func() -> void: _explorer_up(parent))
	_button(toolbar, "⌂", Vector2(134, 6), Vector2(38, 36), func() -> void: _explorer_home(parent))
	var address: LineEdit = LineEdit.new()
	toolbar.add_child(address)
	address.position = Vector2(184, 7)
	address.size = Vector2(474, 34)
	address.text = explorer_path
	address.add_theme_color_override("font_color", TEXT_COLOR)
	address.add_theme_font_size_override("font_size", 15)
	address.add_theme_stylebox_override("normal", _style(PANEL))
	address.text_submitted.connect(func(value: String) -> void:
		var target: String = _explorer_absolute_path(value)
		if virtual_files.has(target):
			_explorer_navigate(parent, target)
		else:
			_show_explorer_notice(parent, _tx("Directory not found") + ": " + target)
	)
	_button(toolbar, "⟳", Vector2(670, 6), Vector2(38, 36), func() -> void: _render_explorer(parent))
	_button(toolbar, "▦", Vector2(710, 6), Vector2(35, 36), func() -> void: _render_explorer(parent))

	# Places sidebar similar to Dolphin's familiar 'Locais' panel.
	var sidebar: Panel = _panel(parent, Vector2(0, 56), Vector2(184, 297), PANEL, 5)
	_label(sidebar, _tx("PLACES"), Vector2(11, 10), Vector2(147, 25), 15, MUTED)
	var places: Array[Dictionary] = [
		{"label": "⌂  " + _tx("Home"), "path": TERMINAL_HOME},
		{"label": "▣  " + _tx("Documents"), "path": TERMINAL_HOME + "/Documents"},
		{"label": "⇩  " + _tx("Downloads"), "path": TERMINAL_HOME + "/Downloads"},
		{"label": "▤  " + _tx("Manual"), "path": TERMINAL_HOME + "/FieldGuide"},
		{"label": "◉  " + _tx("Remote"), "path": "/remote"}
	]
	for i in range(places.size()):
		var place: Dictionary = places[i]
		var destination: String = str(place["path"])
		var place_button: Button = _button(sidebar, str(place["label"]), Vector2(8, 39 + i * 45), Vector2(168, 39), func() -> void:
			_explorer_navigate(parent, destination)
		)
		_apply_sidebar_button_style(place_button, explorer_path == destination)
		place_button.add_theme_font_size_override("font_size", 14)

	# Icon grid with a scroll area; the list comes from virtual_files.
	var area: Panel = _panel(parent, Vector2(191, 56), Vector2(563, 297), BG, 5)
	var scroll: ScrollContainer = ScrollContainer.new()
	area.add_child(scroll)
	scroll.position = Vector2(6, 8)
	scroll.size = Vector2(551, 278)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var grid: GridContainer = GridContainer.new()
	scroll.add_child(grid)
	grid.columns = 4
	grid.custom_minimum_size = Vector2(525, 0)
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 12)

	var contents: Array = virtual_files.get(explorer_path, [])
	if contents.is_empty():
		_label(area, _tx("This folder is empty"), Vector2(155, 122), Vector2(280, 35), 17, MUTED)
	for entry in contents:
		var entry_name: String = str(entry)
		var full_path: String = explorer_path.path_join(entry_name)
		var is_directory: bool = virtual_files.has(full_path)
		var tile: Button = Button.new()
		grid.add_child(tile)
		tile.custom_minimum_size = Vector2(126, 105)
		tile.text = ""
		tile.add_theme_stylebox_override("normal", _style(BG, BG, 6))
		tile.add_theme_stylebox_override("hover", _style(PANEL_ALT, GREEN, 6))
		tile.add_theme_stylebox_override("pressed", _style(HEADER, GREEN, 6))
		if is_directory:
			_icon(tile, "icon_folder.svg", "▣", Vector2(41, 9), Vector2(44, 42))
		else:
			_icon(tile, "icon_file.svg", "▤", Vector2(41, 9), Vector2(44, 42))
		var file_label: Label = _label(tile, entry_name, Vector2(4, 58), Vector2(118, 44), 13, TEXT_COLOR)
		file_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		file_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		file_label.max_lines_visible = 2
		tile.pressed.connect(func() -> void:
			if is_directory:
				_explorer_navigate(parent, full_path)
			else:
				_explorer_open_file(parent, full_path)
		)

	explorer_status = _label(parent, "%d %s    •    %s" % [contents.size(), _tx("Items"), explorer_path], Vector2(6, 361), Vector2(744, 27), 14, MUTED)


func _explorer_absolute_path(raw_path: String) -> String:
	var value: String = raw_path.strip_edges()
	if value == "~":
		return TERMINAL_HOME
	if value.begins_with("~/"):
		value = TERMINAL_HOME + value.substr(1)
	elif not value.begins_with("/"):
		value = explorer_path.path_join(value)
	var segments: PackedStringArray = PackedStringArray()
	for segment in value.split("/", false):
		if segment == ".":
			continue
		if segment == "..":
			if not segments.is_empty():
				segments.remove_at(segments.size() - 1)
		else:
			segments.append(segment)
	return "/" + "/".join(segments)


func _explorer_open_file(parent: Control, path: String) -> void:
	_clear_explorer(parent)
	var toolbar: Panel = _panel(parent, Vector2.ZERO, Vector2(754, 48), HEADER)
	_button(toolbar, "‹  " + _tx("Back"), Vector2(8, 6), Vector2(112, 35), func() -> void: _render_explorer(parent))
	_label(toolbar, path.get_file(), Vector2(136, 10), Vector2(588, 27), 18, GREEN)
	var text_view: TextEdit = TextEdit.new()
	parent.add_child(text_view)
	text_view.position = Vector2(10, 62)
	text_view.size = Vector2(733, 285)
	text_view.text = str(file_contents.get(path, _tx("Unable to open file.")))
	text_view.editable = false
	text_view.add_theme_color_override("font_color", TEXT_COLOR)
	text_view.add_theme_font_size_override("font_size", 17)
	text_view.add_theme_stylebox_override("normal", _style(BG))
	explorer_status = _label(parent, _tx("FILE") + "    •    " + path, Vector2(6, 360), Vector2(736, 27), 14, MUTED)
