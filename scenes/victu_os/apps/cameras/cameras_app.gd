extends "res://scenes/victu_os/ui/ui_theme.gd"

const BORDER := Color("#087E49")

const PANEL := Color("041611")
const HEADER := Color("09251e")
const BG := Color("020b08")
const GREEN := Color("00ee55")
const TEXT_COLOR := Color("bdffdc")
const MUTED := Color("83b39d")

func _ready() -> void:
	context.network_manager.network_changed.connect(_on_network_changed)
	_build_cameras(self)

func _on_network_changed(_ssid: String) -> void:
	if is_inside_tree():
		_build_cameras(self)

func _nvr_text(pt: String, en: String) -> String:
	return pt if context.settings_manager.current_locale == "pt_BR" else en

func _build_cameras(parent: Control) -> void:
	for child in parent.get_children():
		parent.remove_child(child)
		child.queue_free()
	var header: Panel = _panel(parent, Vector2(6, 5), Vector2(742, 43), HEADER, 6)
	_label(header, "LAB NVR  •  CCTV-01", Vector2(14, 7), Vector2(390, 28), 19, GREEN)
	_label(header, "192.168.10.20", Vector2(538, 9), Vector2(187, 25), 14, MUTED)

	if context.network_manager.connected_network.is_empty():
		_label(parent, _nvr_text("SERVIDOR INACESSÍVEL", "SERVER UNREACHABLE"), Vector2(22, 94), Vector2(700, 36), 23, GREEN)
		var notice: Label = _label(parent, _nvr_text("Conecte-se à rede do laboratório pelo aplicativo Rede para acessar o NVR.", "Connect to the laboratory network in Network to access the NVR."), Vector2(22, 146), Vector2(700, 86), 17, TEXT_COLOR)
		notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_button(parent, _nvr_text("Tentar novamente", "Retry"), Vector2(22, 258), Vector2(184, 42), func() -> void:
			_build_cameras(parent)
		)
		return

	if context.nvr_manager.username.is_empty():
		_build_nvr_login(parent)
		return

	if context.nvr_manager.show_api:
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
	if not context.nvr_manager.sign_in(account_name, password_input.text):
		feedback.text = _nvr_text("Usuário ou senha incorretos.", "Invalid username or password.")
		password_input.clear()
		password_input.grab_focus()
		return
	password_input.clear()
	context.nvr_manager.show_api = false
	_build_cameras(parent)

func _build_nvr_dashboard(parent: Control) -> void:
	_label(parent, "%s: %s   •   %s: %s" % [_nvr_text("Usuário", "User"), context.nvr_manager.username, _nvr_text("Perfil", "Role"), context.nvr_manager.role.to_upper()], Vector2(14, 59), Vector2(468, 26), 15, TEXT_COLOR)
	_button(parent, "API", Vector2(537, 54), Vector2(87, 34), func() -> void:
		context.nvr_manager.show_api = true
		_build_cameras(parent)
	)
	_button(parent, _nvr_text("Sair", "Logout"), Vector2(631, 54), Vector2(106, 34), func() -> void:
		context.nvr_manager.sign_out()
		_build_cameras(parent)
	)
	var list_panel: Panel = _panel(parent, Vector2(8, 101), Vector2(238, 278), PANEL, 6)
	_label(list_panel, _nvr_text("CÂMERAS", "CAMERAS"), Vector2(12, 8), Vector2(210, 28), 17, GREEN)
	for index in range(context.nvr_manager.cameras.size()):
		var camera_data: Dictionary = context.nvr_manager.cameras[index]
		var camera_id: String = str(camera_data["id"])
		var is_restricted: bool = camera_id == "CAM-04" and context.nvr_manager.role != "admin"
		var button: Button = _button(list_panel, camera_id + ("  [LOCK]" if is_restricted else ""), Vector2(10, 43 + index * 55), Vector2(218, 44), func() -> void:
			context.nvr_manager.selected_camera = camera_id
			_build_cameras(parent)
		)
		if camera_id == context.nvr_manager.selected_camera:
			button.add_theme_stylebox_override("normal", _style(HEADER, GREEN))
	var preview: Panel = _panel(parent, Vector2(255, 101), Vector2(491, 278), BG, 6)
	var restricted: bool = context.nvr_manager.selected_camera == "CAM-04" and context.nvr_manager.role != "admin"
	_label(preview, context.nvr_manager.selected_camera + "  •  " + ("RESTRICTED" if restricted else "ONLINE"), Vector2(17, 11), Vector2(457, 28), 18, GREEN)
	if restricted:
		_label(preview, _nvr_text("ACESSO NEGADO — PERFIL INSUFICIENTE", "ACCESS DENIED — INSUFFICIENT ROLE"), Vector2(20, 107), Vector2(450, 40), 16, TEXT_COLOR)
	else:
		var message: Label = _label(preview, _nvr_text("Canal disponível. A imagem ao vivo será vinculada à câmera do cenário.", "Channel available. Live video will be linked to the scene camera."), Vector2(28, 92), Vector2(430, 93), 16, MUTED)
		message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

func _build_nvr_api(parent: Control) -> void:
	_label(parent, _nvr_text("INTEGRAÇÃO API", "API INTEGRATION"), Vector2(17, 64), Vector2(520, 35), 21, GREEN)
	_button(parent, _nvr_text("Voltar", "Back"), Vector2(618, 58), Vector2(116, 38), func() -> void:
		context.nvr_manager.show_api = false
		_build_cameras(parent)
	)
	var panel: Panel = _panel(parent, Vector2(13, 111), Vector2(726, 258), PANEL, 7)
	var message: Label = _label(panel, _nvr_text("Chaves de API são usadas por programas autorizados para integrar serviços ao NVR. O login normal não exige chave de API.", "API keys allow authorized software to integrate with the NVR. Normal operator login does not require an API key."), Vector2(16, 18), Vector2(691, 78), 16, TEXT_COLOR)
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if context.nvr_manager.role != "admin":
		_label(panel, _nvr_text("Somente administradores podem visualizar as credenciais de integração.", "Only administrators can view integration credentials."), Vector2(16, 135), Vector2(691, 55), 16, MUTED)
		return
	var api_field: LineEdit = _nvr_input(panel, Vector2(16, 125), Vector2(514, 43), not context.nvr_manager.api_key_visible)
	api_field.text = context.nvr_manager.api_key
	api_field.editable = false
	_button(panel, _nvr_text("Ocultar", "Hide") if context.nvr_manager.api_key_visible else _nvr_text("Mostrar", "Show"), Vector2(542, 125), Vector2(164, 43), func() -> void:
		context.nvr_manager.api_key_visible = not context.nvr_manager.api_key_visible
		_build_cameras(parent)
	)
