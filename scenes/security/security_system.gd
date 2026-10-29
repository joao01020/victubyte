extends Node

# ============================================================
# VICTUBYTE - CENTRAL SECURITY SYSTEM
# ============================================================

signal alarm_triggered(source: Node)
signal alarm_cleared


# ============================================================
# SETTINGS
# ============================================================

@export_group("Alarm Settings")

@export var alarm_duration: float = 15.0


# ============================================================
# STATE
# ============================================================

var is_alarm_active: bool = false
var alarm_timer: float = 0.0
var alarm_source: Node = null


# ============================================================
# INITIALIZATION
# ============================================================

func _ready() -> void:
	call_deferred("initialize_security_system")


func initialize_security_system() -> void:
	connect_security_cameras()
	synchronize_wall_alarms()

	print("SECURITY SYSTEM INITIALIZED")


# ============================================================
# CAMERA CONNECTIONS
# ============================================================

func connect_security_cameras() -> void:
	var cameras: Array[Node] = get_tree().get_nodes_in_group(
		"security_cameras"
	)

	for camera in cameras:
		if not camera.has_signal("player_detected"):
			push_warning(
				"SecuritySystem: Camera has no player_detected signal: "
				+ camera.name
			)
			continue

		var callback: Callable = Callable(
			self,
			"_on_camera_detected"
		).bind(camera)

		if camera.is_connected("player_detected", callback):
			continue

		camera.connect(
			"player_detected",
			callback
		)

		print("SECURITY CAMERA CONNECTED: ", camera.name)


# ============================================================
# CAMERA DETECTION
# ============================================================

func _on_camera_detected(camera: Node) -> void:
	if not is_instance_valid(camera):
		return

	print("CAMERA DETECTED PLAYER: ", camera.name)

	activate_alarm(camera)


# ============================================================
# ACTIVATE SECURITY ALERT
# ============================================================

func activate_alarm(source: Node = null) -> void:
	# Refresh the alarm duration on every detection.
	alarm_timer = maxf(alarm_duration, 0.0)

	# Do not restart an active alert.
	if is_alarm_active:
		synchronize_wall_alarms()
		return

	is_alarm_active = true
	alarm_source = source

	activate_wall_alarms()

	# Notify BYTE and other security systems.
	alarm_triggered.emit(source)

	print("SECURITY ALERT ACTIVATED")

	if is_instance_valid(source):
		print("ALERT SOURCE: ", source.name)


# ============================================================
# ACTIVATE ALL WALL ALARMS
# ============================================================

func activate_wall_alarms() -> void:
	var alarms: Array[Node] = get_tree().get_nodes_in_group(
		"security_alarms"
	)

	for alarm in alarms:
		if not is_instance_valid(alarm):
			continue

		if alarm.has_method("activate_alarm"):
			alarm.activate_alarm()

	print("WALL ALARMS ACTIVATED: ", alarms.size())


# ============================================================
# DEACTIVATE ALL WALL ALARMS
# ============================================================

func deactivate_wall_alarms() -> void:
	var alarms: Array[Node] = get_tree().get_nodes_in_group(
		"security_alarms"
	)

	for alarm in alarms:
		if not is_instance_valid(alarm):
			continue

		if alarm.has_method("deactivate_alarm"):
			alarm.deactivate_alarm()

	print("WALL ALARMS DEACTIVATED")


# ============================================================
# SYNCHRONIZE WALL ALARMS
# ============================================================

func synchronize_wall_alarms() -> void:
	var alarms: Array[Node] = get_tree().get_nodes_in_group(
		"security_alarms"
	)

	for alarm in alarms:
		if not is_instance_valid(alarm):
			continue

		if is_alarm_active:
			if alarm.has_method("activate_alarm"):
				alarm.activate_alarm()

		else:
			if alarm.has_method("deactivate_alarm"):
				alarm.deactivate_alarm()


# ============================================================
# SECURITY TIMER
# ============================================================

func _process(delta: float) -> void:
	if not is_alarm_active:
		return

	alarm_timer -= delta

	if alarm_timer <= 0.0:
		deactivate_alarm()


# ============================================================
# DEACTIVATE SECURITY ALERT
# ============================================================

func deactivate_alarm() -> void:
	if not is_alarm_active:
		return

	is_alarm_active = false
	alarm_timer = 0.0
	alarm_source = null

	deactivate_wall_alarms()

	# Notify BYTE and other connected systems.
	alarm_cleared.emit()

	print("SECURITY ALERT CLEARED")


# ============================================================
# MANUAL RESET
# ============================================================

func reset_security_system() -> void:
	if is_alarm_active:
		deactivate_alarm()
	else:
		alarm_timer = 0.0
		alarm_source = null
		synchronize_wall_alarms()

	print("SECURITY SYSTEM RESET")


# ============================================================
# SECURITY STATUS
# ============================================================

func is_security_alert_active() -> bool:
	return is_alarm_active


func get_remaining_alarm_time() -> float:
	return maxf(alarm_timer, 0.0)


func get_alarm_source() -> Node:
	if is_instance_valid(alarm_source):
		return alarm_source

	return null