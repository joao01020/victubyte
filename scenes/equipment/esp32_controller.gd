extends Node2D

# ============================================================
# VICTUBYTE — ESP32 CONTROLLER
# ============================================================

signal battery_changed(value: float)
signal jamming_started(camera: Node2D)
signal jamming_stopped(camera: Node2D)

# ============================================================
# CONFIGURATION
# ============================================================

@export var max_battery: float = 100.0
@export var battery_consumption: float = 2.0
@export var max_range: float = 250.0

# ============================================================
# NODES
# ============================================================

@onready var device_sprite: Sprite2D = (
	get_node_or_null("DeviceSprite") as Sprite2D
)

@onready var esp32_light_anchor: Marker2D = (
	get_parent().get_node_or_null("ESP32LightAnchor") as Marker2D
)

# ============================================================
# STATE
# ============================================================

var battery: float = 100.0

var active_camera: Node2D = null

var is_equipped: bool = false
var is_jamming: bool = false

# ============================================================
# INITIALIZATION
# ============================================================

func _ready() -> void:
	battery = maxf(max_battery, 0.0)

	# The ESP32 is already drawn in the player animations.
	if device_sprite != null:
		device_sprite.visible = false

	# Keep the additional light disabled initially.
	update_esp32_light()

	battery_changed.emit(battery)

	print("ESP32: dispositivo iniciado")
	print("ESP32: bateria ", battery, "%")

	if esp32_light_anchor == null:
		push_warning(
			"ESP32: ESP32LightAnchor não encontrado no Player."
		)
	else:
		print("ESP32: sistema de iluminação conectado")


# ============================================================
# PROCESS
# ============================================================

func _process(delta: float) -> void:
	if not is_jamming:
		return

	# Stop if the target camera no longer exists.
	if not is_instance_valid(active_camera):
		stop_jamming()
		return

	# Stop if the camera is outside the device range.
	var distance: float = global_position.distance_to(
		active_camera.global_position
	)

	if distance > max_range:
		stop_jamming()
		print("ESP32: câmera fora do alcance")
		return

	# Battery consumption.
	battery = maxf(
		battery - battery_consumption * delta,
		0.0
	)

	battery_changed.emit(battery)

	# Stop when the battery is depleted.
	if battery <= 0.0:
		stop_jamming()
		print("ESP32: bateria esgotada")


# ============================================================
# INPUT
# ============================================================

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey:
		return

	if event.echo:
		return

	if event.keycode == KEY_F:
		if event.pressed:
			if is_equipped:
				start_jamming()
		else:
			stop_jamming()


# ============================================================
# EQUIPMENT
# ============================================================

func set_equipped(value: bool) -> void:
	if not value:
		stop_jamming()

	is_equipped = value

	update_esp32_light()

	print("ESP32: estado equipado = ", is_equipped)


# ============================================================
# START JAMMING
# ============================================================

func start_jamming() -> void:
	if not is_equipped:
		return

	if is_jamming:
		return

	if battery <= 0.0:
		print("ESP32: bateria insuficiente")
		return

	var camera: Node2D = find_nearest_camera()

	if camera == null:
		print("ESP32: nenhuma câmera no alcance")
		return

	active_camera = camera
	is_jamming = true

	# Disable the camera.
	active_camera.start_jamming()

	# Enable the pulsing light.
	update_esp32_light()

	jamming_started.emit(active_camera)

	print("ESP32: interferência iniciada")


# ============================================================
# STOP JAMMING
# ============================================================

func stop_jamming() -> void:
	if not is_jamming:
		update_esp32_light()
		return

	is_jamming = false

	var previous_camera: Node2D = active_camera
	active_camera = null

	# Disable the additional light.
	update_esp32_light()

	# Restore the camera's reboot sequence.
	if is_instance_valid(previous_camera):
		if previous_camera.has_method("stop_jamming"):
			previous_camera.stop_jamming()

		jamming_stopped.emit(previous_camera)

	print("ESP32: interferência encerrada")
	print(
		"ESP32: bateria restante ",
		snappedf(battery, 0.1),
		"%"
	)


# ============================================================
# CAMERA DETECTION
# ============================================================

func find_nearest_camera() -> Node2D:
	var nearest_camera: Node2D = null
	var nearest_distance: float = max_range

	for node in get_tree().get_nodes_in_group(
		"security_cameras"
	):
		if not node is Node2D:
			continue

		var camera: Node2D = node as Node2D

		if not camera.has_method("start_jamming"):
			continue

		var distance: float = global_position.distance_to(
			camera.global_position
		)

		if distance <= nearest_distance:
			nearest_distance = distance
			nearest_camera = camera

	return nearest_camera


# ============================================================
# ESP32 LIGHT
# ============================================================

func update_esp32_light() -> void:
	if not is_instance_valid(esp32_light_anchor):
		return

	var should_pulse: bool = (
		is_equipped
		and is_jamming
		and battery > 0.0
	)

	if esp32_light_anchor.has_method("set_jamming"):
		esp32_light_anchor.set_jamming(should_pulse)


# ============================================================
# BATTERY MANAGEMENT
# ============================================================

func recharge_battery(amount: float) -> void:
	if amount <= 0.0:
		return

	battery = clampf(
		battery + amount,
		0.0,
		maxf(max_battery, 0.0)
	)

	battery_changed.emit(battery)

	print(
		"ESP32: bateria recarregada para ",
		snappedf(battery, 0.1),
		"%"
	)