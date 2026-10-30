extends CanvasLayer

# ============================================================
# VICTUBYTE — ESP32 MINIMAL HUD
# ============================================================

@export var debug_force_visible: bool = false
@export var hud_margin: Vector2 = Vector2(14.0, 14.0)

const HUD_WIDTH: float = 140.0
const HUD_HEIGHT: float = 49.0

const COLOR_TEXT: Color = Color("#E7F3F7")
const COLOR_MUTED: Color = Color("#7E97A4")
const COLOR_READY: Color = Color("#37E0A1")
const COLOR_JAMMING: Color = Color("#43DDF5")
const COLOR_WARNING: Color = Color("#FFD45A")

# ============================================================
# REFERENCES
# ============================================================

var controller: Node2D = null

var panel: PanelContainer
var status_dot: ColorRect
var status_label: Label
var target_label: Label
var details_label: Label

var waveform: HBoxContainer
var waveform_bars: Array[ColorRect] = []

# ============================================================
# ANIMATION
# ============================================================

var animation_time: float = 0.0
var last_wave_frame: int = -1


# ============================================================
# INITIALIZATION
# ============================================================

func _ready() -> void:
	layer = 20

	build_interface()
	connect_controller()

	panel.visible = debug_force_visible

	print("ESP32HUD: interface inicializada")


func connect_controller() -> void:
	var main_scene: Node = get_tree().current_scene

	if main_scene == null:
		controller = null
		return

	controller = main_scene.get_node_or_null(
		"Characters/Player/ESP32Controller"
	) as Node2D

	if controller != null:
		print("ESP32HUD: controlador conectado")
	else:
		push_warning("ESP32HUD: ESP32Controller não encontrado.")


# ============================================================
# PROCESS
# ============================================================

func _process(delta: float) -> void:
	animation_time += delta

	if panel == null:
		return

	if not is_instance_valid(controller):
		connect_controller()

	var equipped: bool = false

	if is_instance_valid(controller):
		equipped = bool(controller.get("is_equipped"))

	panel.visible = debug_force_visible or equipped

	if not panel.visible:
		return

	update_interface()
	update_status_pulse()


# ============================================================
# BUILD INTERFACE
# ============================================================

func build_interface() -> void:
	panel = PanelContainer.new()
	panel.name = "ESP32MinimalPanel"
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	add_child(panel)

	# Bottom-left position

	panel.anchor_left = 0.0
	panel.anchor_right = 0.0
	panel.anchor_top = 1.0
	panel.anchor_bottom = 1.0

	panel.offset_left = hud_margin.x
	panel.offset_right = hud_margin.x + HUD_WIDTH
	panel.offset_top = - HUD_HEIGHT - hud_margin.y
	panel.offset_bottom = - hud_margin.y

	panel.custom_minimum_size = Vector2(
		HUD_WIDTH,
		HUD_HEIGHT
	)

	# Background

	var style := StyleBoxFlat.new()

	style.bg_color = Color(
		0.03,
		0.08,
		0.12,
		0.86
	)

	style.border_color = Color(
		0.11,
		0.24,
		0.30,
		0.55
	)

	style.set_border_width_all(1)
	style.set_corner_radius_all(8)

	style.content_margin_left = 8.0
	style.content_margin_right = 8.0
	style.content_margin_top = 5.0
	style.content_margin_bottom = 5.0

	panel.add_theme_stylebox_override(
		"panel",
		style
	)

	# Main content

	var content := VBoxContainer.new()
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE

	content.add_theme_constant_override(
		"separation",
		1
	)

	panel.add_child(content)

	# ========================================================
	# TOP ROW
	# ========================================================

	var top_row := HBoxContainer.new()
	top_row.mouse_filter = Control.MOUSE_FILTER_IGNORE

	top_row.add_theme_constant_override(
		"separation",
		4
	)

	content.add_child(top_row)

	# Status indicator

	var dot_wrap := CenterContainer.new()

	dot_wrap.custom_minimum_size = Vector2(
		6.0,
		0.0
	)

	dot_wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE

	top_row.add_child(dot_wrap)

	status_dot = ColorRect.new()
	status_dot.color = COLOR_READY

	status_dot.custom_minimum_size = Vector2(
		4.0,
		4.0
	)

	status_dot.mouse_filter = Control.MOUSE_FILTER_IGNORE

	dot_wrap.add_child(status_dot)

	# Status label

	status_label = create_label(
		"PRONTO",
		COLOR_READY,
		9
	)

	top_row.add_child(status_label)

	# ========================================================
	# MIDDLE ROW
	# ========================================================

	var middle_holder := Control.new()

	middle_holder.custom_minimum_size = Vector2(
		0.0,
		13.0
	)

	middle_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE

	content.add_child(middle_holder)

	# Camera name

	target_label = create_label(
		"SEM ALVO",
		COLOR_TEXT,
		10
	)

	middle_holder.add_child(target_label)

	# Waveform

	waveform = HBoxContainer.new()
	waveform.visible = false

	waveform.position = Vector2(
		0.0,
		1.0
	)

	waveform.mouse_filter = Control.MOUSE_FILTER_IGNORE

	waveform.add_theme_constant_override(
		"separation",
		2
	)

	middle_holder.add_child(waveform)

	for i in range(10):
		var bar := ColorRect.new()

		bar.color = COLOR_JAMMING

		bar.custom_minimum_size = Vector2(
			2.0,
			5.0
		)

		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE

		waveform.add_child(bar)
		waveform_bars.append(bar)

	# ========================================================
	# BOTTOM ROW
	# ========================================================

	details_label = create_label(
		"Bateria 100% · Procurando câmera",
		COLOR_MUTED,
		8
	)

	details_label.clip_text = true

	content.add_child(details_label)


# ============================================================
# LABEL HELPER
# ============================================================

func create_label(
	text_value: String,
	text_color: Color,
	font_size: int
) -> Label:
	var label := Label.new()

	label.text = text_value
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE

	label.add_theme_color_override(
		"font_color",
		text_color
	)

	label.add_theme_font_size_override(
		"font_size",
		font_size
	)

	return label


# ============================================================
# LIVE DATA
# ============================================================

func update_interface() -> void:
	if not is_instance_valid(controller):
		set_status(
			"DESCONECTADO",
			COLOR_WARNING
		)

		target_label.text = "SEM DISPOSITIVO"
		details_label.text = "Controlador indisponível"

		show_waveform(false)
		return

	# Battery

	var battery: float = float(
		controller.get("battery")
	)

	var max_battery: float = maxf(
		float(controller.get("max_battery")),
		1.0
	)

	var battery_percent: int = roundi(
		clampf(
			battery / max_battery * 100.0,
			0.0,
			100.0
		)
	)

	# Jamming state

	var is_jamming: bool = bool(
		controller.get("is_jamming")
	)

	if is_jamming:
		update_jamming_state(battery_percent)
		return

	show_waveform(false)

	# Empty battery

	if battery <= 0.0:
		set_status(
			"SEM BATERIA",
			COLOR_WARNING
		)

		target_label.text = "BATERIA ESGOTADA"
		details_label.text = "Bateria 0%"

		return

	# Camera detection

	var camera: Node2D = null

	if controller.has_method("find_nearest_camera"):
		camera = controller.call(
			"find_nearest_camera"
		) as Node2D

	set_status(
		"PRONTO",
		COLOR_READY
	)

	if not is_instance_valid(camera):
		target_label.text = "SEM ALVO"

		details_label.text = (
			"Bateria %d%% · Procurando câmera"
			% battery_percent
		)

		return

	target_label.text = get_camera_display_name(camera)

	details_label.text = (
		"Bateria %d%% · F para interferir"
		% battery_percent
	)


# ============================================================
# JAMMING STATE
# ============================================================

func update_jamming_state(
	battery_percent: int
) -> void:
	set_status(
		"INTERFERINDO",
		COLOR_JAMMING
	)

	show_waveform(true)
	update_waveform()

	details_label.text = (
		"Sinal interrompido · Bateria %d%%"
		% battery_percent
	)


# ============================================================
# CAMERA DISPLAY NAME
# ============================================================

func get_camera_display_name(
	camera: Node2D
) -> String:
	var cameras: Array[Node] = get_tree().get_nodes_in_group(
		"security_cameras"
	)

	var camera_index: int = cameras.find(camera)

	if camera_index >= 0:
		return "CAM_%03d" % (camera_index + 1)

	return String(camera.name)


# ============================================================
# VISUAL STATE
# ============================================================

func set_status(
	text_value: String,
	status_color: Color
) -> void:
	status_label.text = text_value

	status_label.add_theme_color_override(
		"font_color",
		status_color
	)

	status_dot.color = status_color


func show_waveform(enabled: bool) -> void:
	target_label.visible = not enabled
	waveform.visible = enabled


# ============================================================
# WAVEFORM ANIMATION
# ============================================================

func update_waveform() -> void:
	var current_frame: int = int(
		animation_time * 12.0
	)

	if current_frame == last_wave_frame:
		return

	last_wave_frame = current_frame

	for i in range(waveform_bars.size()):
		var bar: ColorRect = waveform_bars[i]

		var height_value: float = (
			4.0
			+ absf(
				sin(
					float(current_frame) * 0.75
					+ float(i) * 1.3
				)
			) * 7.0
		)

		bar.custom_minimum_size = Vector2(
			2.0,
			height_value
		)


# ============================================================
# STATUS INDICATOR PULSE
# ============================================================

func update_status_pulse() -> void:
	if status_dot == null:
		return

	var is_jamming: bool = false

	if is_instance_valid(controller):
		is_jamming = bool(
			controller.get("is_jamming")
		)

	if is_jamming:
		var pulse: float = (
			0.5 + 0.5 * sin(animation_time * 8.0)
		)

		status_dot.modulate.a = (
			0.55 + 0.45 * pulse
		)
	else:
		status_dot.modulate.a = 1.0
