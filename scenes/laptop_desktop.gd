extends CanvasLayer

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
const ATTEMPTS = [
	"10452983", "27193064", "83647510", "50281639", "91427058",
	"66390127", "29084175", "77462091", "19863420", "04729186",
	"58201749", "90371628", "26495731", "61832074", "17360982",
	"40827615", "73195420", "65902814", "34790261", "82641790",
	"51926407", "19057248", "47391862", "00738875", "38149432",
	"29473836", "71492036", "56091380", "81726390", "62409153"
]
const SUCCESS_PASSWORD := "40591627"

var terminal_ref: Node = null
var opened_from_inventory: bool = false
var desktop_root: Control
var canvas: Control
var network_details: Control
var password_edit: LineEdit
var brute_button: Button
var unlock_door_button: Button
var console_text: RichTextLabel
var attack_timer: Timer
var network_selected := false
var connected := false
var attacking := false
var attempt_index := 0


func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_interface()
	_fit_canvas()
	get_viewport().size_changed.connect(_fit_canvas)
	hide()
	call_deferred("_connect_to_terminal")

func _connect_to_terminal() -> void:
	terminal_ref = get_tree().current_scene.get_node_or_null(
		"SecuritySystems/SecurityTerminal"
	)

	if terminal_ref == null or not terminal_ref.has_signal("laptop_ready"):
		push_warning("VICTU OS: terminal de segurança não encontrado.")
		return

	if not terminal_ref.is_connected(
		"laptop_ready",
		Callable(self, "open_desktop")
	):
		terminal_ref.connect(
			"laptop_ready",
			Callable(self, "open_desktop")
		)

	print("VICTU OS: conectado ao terminal de segurança.")

# Original terminal entry point. Keep this for SecurityTerminal.laptop_ready.
func open_desktop() -> void:
	_open_interface(false)


# Inventory entry point: opens the same interface without interacting with the terminal.
func open_from_inventory() -> void:
	_open_interface(true)


func _open_interface(from_inventory: bool) -> void:
	if visible:
		return

	opened_from_inventory = from_inventory
	_reset_state()
	_fit_canvas()
	show()
	get_tree().paused = true

	if opened_from_inventory:
		print("VICTU OS: notebook aberto pelo inventário.")
		_log("Modo portátil: terminal de segurança desconectado.")
	else:
		print("VICTU OS: notebook conectado ao terminal.")


func close_desktop() -> void:
	if not visible:
		return

	var was_terminal_session: bool = not opened_from_inventory

	if attack_timer != null:
		attack_timer.stop()
	attacking = false
	hide()
	get_tree().paused = false

	var player := get_parent().get_node_or_null("Player")
	if player != null and player.has_method("finish_laptop_interaction"):
		player.call("finish_laptop_interaction")

	# Only the terminal session can cancel an active terminal interaction.
	if was_terminal_session and is_instance_valid(terminal_ref):
		if terminal_ref.has_method("cancel_access"):
			terminal_ref.call("cancel_access")

	opened_from_inventory = false
	desktop_closed.emit()
	print("VICTU OS: área de trabalho fechada.")


func _fit_canvas() -> void:
	if not is_instance_valid(canvas) or not is_instance_valid(desktop_root):
		return
	var size := get_viewport().get_visible_rect().size
	desktop_root.size = size
	var factor: float = minf(size.x / BASE_SIZE.x, size.y / BASE_SIZE.y)
	canvas.scale = Vector2.ONE * factor
	canvas.position = (size - BASE_SIZE * factor) / 2.0


func _style(fill: Color, outline: Color = BORDER, radius: int = 7) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = outline
	style.set_border_width_all(1)
	style.set_corner_radius_all(radius)
	return style


func _panel(parent: Node, pos: Vector2, dimensions: Vector2, fill: Color, radius: int = 7) -> Panel:
	var panel := Panel.new()
	parent.add_child(panel)
	panel.position = pos
	panel.size = dimensions
	panel.add_theme_stylebox_override("panel", _style(fill, BORDER, radius))
	return panel


func _label(parent: Node, value: String, pos: Vector2, dimensions: Vector2, size: int = 17, tint: Color = TEXT_COLOR) -> Label:
	var label := Label.new()
	parent.add_child(label)
	label.position = pos
	label.size = dimensions
	label.text = value
	label.add_theme_color_override("font_color", tint)
	label.add_theme_font_size_override("font_size", size)
	return label


func _icon(parent: Node, filename: String, fallback: String, pos: Vector2, dimensions: Vector2) -> void:
	# Prefer SVG; fall back to an existing PNG during migration.
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
		rect.position = pos
		rect.size = dimensions
		rect.texture = texture
		rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		rect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		return

	var fallback_label := _label(parent, fallback, pos, dimensions, 22, GREEN)
	fallback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	fallback_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	fallback_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	push_warning("VICTU OS: ícone não encontrado: " + svg_path)


func _button(parent: Node, title: String, pos: Vector2, dimensions: Vector2, action: Callable) -> Button:
	var button := Button.new()
	parent.add_child(button)
	button.position = pos
	button.size = dimensions
	button.text = title
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_color_override("font_color", TEXT_COLOR)
	button.add_theme_color_override("font_hover_color", GREEN)
	button.add_theme_color_override("font_disabled_color", MUTED)
	button.add_theme_font_size_override("font_size", 16)
	button.add_theme_stylebox_override("normal", _style(PANEL_ALT))
	button.add_theme_stylebox_override("hover", _style(HEADER, GREEN))
	button.add_theme_stylebox_override("pressed", _style(HEADER, GREEN))
	button.add_theme_stylebox_override("disabled", _style(PANEL))
	button.pressed.connect(action)
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

	# Barra superior e logotipo.
	_panel(canvas, Vector2(16, 12), Vector2(1248, 62), HEADER, 10)
	_icon(canvas, "victu_logo.svg", "◉", Vector2(34, 24), Vector2(40, 38))
	_label(canvas, "VICTU OS", Vector2(91, 27), Vector2(186, 35), 26, GREEN)
	_label(canvas, "v0.1", Vector2(260, 34), Vector2(74, 26), 15, MUTED)
	_icon(canvas, "icon_wifi.svg", "◉", Vector2(1122, 28), Vector2(32, 30))
	_icon(canvas, "icon_battery.svg", "▣", Vector2(1174, 28), Vector2(31, 30))
	_icon(canvas, "icon_volume.svg", "◖", Vector2(1220, 28), Vector2(30, 30))

	# Barra lateral: imagens ficam dentro de botões com área clicável.
	_panel(canvas, Vector2(16, 94), Vector2(104, 572), PANEL)
	_sidebar_button("icon_wifi.svg", "Wi-Fi", 108, _on_wifi_app_pressed)
	_sidebar_button("icon_terminal.svg", "Terminal", 218, _on_terminal_app_pressed)
	_sidebar_button("icon_camera.svg", "Câmeras", 328, _on_cameras_app_pressed)
	_sidebar_button("icon_folder.svg", "Arquivos", 438, _on_files_app_pressed)
	_button(canvas, "Fechar", Vector2(25, 611), Vector2(86, 43), close_desktop)

	# Janela Wi-Fi.
	_panel(canvas, Vector2(136, 94), Vector2(555, 572), PANEL)
	_panel(canvas, Vector2(136, 94), Vector2(555, 49), HEADER)
	_icon(canvas, "icon_wifi.svg", "◉", Vector2(152, 108), Vector2(27, 23))
	_label(canvas, "Wi-Fi", Vector2(190, 105), Vector2(190, 31), 21, GREEN)
	_label(canvas, "—  □  ×", Vector2(599, 108), Vector2(80, 25), 17, GREEN)
	_label(canvas, "Redes disponíveis", Vector2(160, 169), Vector2(370, 37), 24, GREEN)
	_label(canvas, "Selecione uma rede para conectar.", Vector2(160, 209), Vector2(465, 30), 17, MUTED)
	var network := _button(canvas, "", Vector2(160, 259), Vector2(506, 77), _on_network_selected)
	_icon(network, "icon_wifi.svg", "◉", Vector2(18, 16), Vector2(48, 43))
	var network_label := _label(network, "LAB_SYS", Vector2(87, 22), Vector2(230, 33), 22, GREEN)
	network_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_icon(network, "icon_lock.svg", "□", Vector2(455, 23), Vector2(29, 29))

	network_details = Control.new()
	canvas.add_child(network_details)
	network_details.position = Vector2(160, 388)
	network_details.size = Vector2(506, 136)
	_panel(network_details, Vector2.ZERO, Vector2(506, 136), PANEL_ALT)
	_label(network_details, "Senha:", Vector2(18, 16), Vector2(200, 29), 17)
	password_edit = LineEdit.new()
	network_details.add_child(password_edit)
	password_edit.position = Vector2(18, 61)
	password_edit.size = Vector2(292, 52)
	password_edit.editable = false
	password_edit.secret = true
	password_edit.text = "00000000"
	password_edit.add_theme_font_size_override("font_size", 18)
	password_edit.add_theme_stylebox_override("normal", _style(BG))
	brute_button = _button(network_details, "BruteForce", Vector2(326, 61), Vector2(164, 52), _on_bruteforce_pressed)
	brute_button.disabled = true

	# Available only when the simulated Wi-Fi connection succeeds.
	unlock_door_button = _button(
		canvas,
		"Desbloquear porta",
		Vector2(160, 548),
		Vector2(506, 68),
		_on_unlock_door_pressed
	)
	unlock_door_button.add_theme_stylebox_override("normal", _style(HEADER, GREEN, 8))
	unlock_door_button.add_theme_color_override("font_color", GREEN)
	unlock_door_button.add_theme_font_size_override("font_size", 21)
	unlock_door_button.hide()

	# Console com scroll para as tentativas numericas simuladas.
	_panel(canvas, Vector2(705, 94), Vector2(559, 572), PANEL)
	_panel(canvas, Vector2(705, 94), Vector2(559, 49), HEADER)
	_icon(canvas, "icon_terminal.svg", ">_", Vector2(721, 108), Vector2(28, 24))
	_label(canvas, "Console de Rede", Vector2(759, 104), Vector2(290, 32), 20, GREEN)
	_label(canvas, "—  □  ×", Vector2(1175, 108), Vector2(79, 25), 17, GREEN)
	console_text = RichTextLabel.new()
	canvas.add_child(console_text)
	console_text.position = Vector2(726, 164)
	console_text.size = Vector2(516, 478)
	console_text.bbcode_enabled = false
	console_text.scroll_active = true
	console_text.scroll_following = true
	console_text.add_theme_color_override("default_color", TEXT_COLOR)
	console_text.add_theme_font_size_override("normal_font_size", 16)

	_label(canvas, "DEVICE SEC-TERM-01", Vector2(26, 680), Vector2(300, 25), 12, MUTED)
	_label(canvas, "SECURITY LEVEL 01", Vector2(1110, 680), Vector2(166, 25), 12, MUTED)

	attack_timer = Timer.new()
	add_child(attack_timer)
	attack_timer.wait_time = 0.12
	attack_timer.timeout.connect(_on_attempt_tick)


func _sidebar_button(icon_file: String, title: String, y: float, action: Callable) -> void:
	var button := _button(canvas, "", Vector2(25, y), Vector2(86, 92), action)
	_icon(button, icon_file, "◉", Vector2(24, 12), Vector2(38, 38))
	var title_label := _label(button, title, Vector2(4, 61), Vector2(78, 24), 13, TEXT_COLOR)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _reset_state() -> void:
	attack_timer.stop()
	network_selected = false
	connected = false
	attacking = false
	attempt_index = 0
	brute_button.disabled = true
	brute_button.text = "BruteForce"
	unlock_door_button.hide()
	unlock_door_button.disabled = false
	password_edit.secret = true
	password_edit.text = "00000000"
	_console_clear()
	_log("VICTU OS v0.1")
	_log("Interface de rede inicializada.")
	_log("Selecione LAB_SYS para continuar.")


func _console_clear() -> void:
	console_text.clear()


func _log(message: String) -> void:
	console_text.append_text(message + "\n")
	console_text.scroll_to_line(maxi(0, console_text.get_line_count() - 1))


func _on_network_selected() -> void:
	if connected or attacking:
		return
	network_selected = true
	brute_button.disabled = false
	_log("")
	_log("Rede selecionada: LAB_SYS")
	_log("Autenticacao necessaria. Clique em BruteForce.")


func _on_bruteforce_pressed() -> void:
	if not network_selected or connected or attacking:
		return
	attacking = true
	attempt_index = 0
	brute_button.disabled = true
	_console_clear()
	_log("Iniciando recuperacao simulada de senha...")
	_log("Alvo: LAB_SYS")
	attack_timer.start()


func _on_attempt_tick() -> void:
	if attempt_index < ATTEMPTS.size():
		_log("Testando: %s ... Negado" % ATTEMPTS[attempt_index])
		attempt_index += 1
		return
	attack_timer.stop()
	attacking = false
	connected = true
	password_edit.text = SUCCESS_PASSWORD
	brute_button.text = "Conectado"
	_log("Senha encontrada: %s" % SUCCESS_PASSWORD)
	_log("Conectando a LAB_SYS...")
	_log("Conexao estabelecida com sucesso.")
	if opened_from_inventory:
		# A portable laptop can use the Wi-Fi simulation but cannot access
		# the security terminal or unlock doors from anywhere in the map.
		unlock_door_button.hide()
		_log("")
		_log("Modo portátil: rede conectada.")
		_log("Conecte o notebook ao terminal para controlar a porta.")
		print("VICTU OS: Wi-Fi conectado em modo portátil, sem acesso à porta.")
	else:
		wifi_connected.emit()
		unlock_door_button.show()
		_log("")
		_log("Dispositivo encontrado: SEC-TERM-01")
		_log("Controle de acesso disponível.")
		_log("Clique em Desbloquear porta para continuar.")
		print("VICTU OS: conexão Wi-Fi simulada concluída. Porta disponível para desbloqueio.")


func _on_wifi_app_pressed() -> void:
	_log("Rede disponivel: LAB_SYS" if not connected else "Rede LAB_SYS conectada.")


func _on_terminal_app_pressed() -> void:
	_log("Terminal disponivel para a proxima fase." if connected else "Conecte ao Wi-Fi primeiro.")


func _on_cameras_app_pressed() -> void:
	_log("Cameras: modulo reservado para uma fase futura.")


func _on_files_app_pressed() -> void:
	_log("Arquivos: ainda nao ha arquivos nesta missao.")


func _on_unlock_door_pressed() -> void:
	# Double guard: no access even if the button is triggered programmatically.
	if opened_from_inventory:
		_log("Acesso negado: notebook não conectado ao terminal.")
		return

	if not connected or attacking or unlock_door_button.disabled:
		return

	if not is_instance_valid(terminal_ref) or not terminal_ref.has_method("complete_access"):
		push_warning("VICTU OS: terminal de segurança indisponível para desbloqueio.")
		return

	unlock_door_button.disabled = true
	attack_timer.stop()
	print("VICTU OS: solicitando desbloqueio da porta de segurança.")

	# Resume the world so the terminal's processing/unlocked animations can finish.
	get_tree().paused = false
	hide()

	var player := get_parent().get_node_or_null("Player")
	if is_instance_valid(player) and player.has_method("finish_laptop_interaction"):
		player.call("finish_laptop_interaction")

	# Do not call cancel_access(): the terminal must finish its unlock sequence.
	terminal_ref.call("complete_access")
	opened_from_inventory = false
	desktop_closed.emit()
