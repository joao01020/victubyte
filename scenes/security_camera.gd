extends Node2D

# ============================================================
# VICTUBYTE — SECURITY CAMERA
# ============================================================

signal player_detected
signal camera_jammed
signal camera_recovered

enum CameraState {
	IDLE,
	DETECTED,
	JAMMED,
	REBOOTING
}

# ============================================================
# CONFIGURATION
# ============================================================

@export var reboot_duration: float = 2.0

@export var camera_id: String = "CAM_001"

# ============================================================
# NODES
# ============================================================

@onready var camera_pivot: Node2D = $CameraPivot
@onready var camera_sprite: Sprite2D = $CameraPivot/CameraSprite
@onready var detection_area: Area2D = $DetectionArea

# ============================================================
# STATE
# ============================================================

var current_state: CameraState = CameraState.IDLE

var is_disabled: bool = false
var player_in_range: bool = false

var reboot_timer: float = 0.0

# ============================================================
# INITIALIZATION
# ============================================================

func _ready() -> void:
	# Register this camera for ESP32 discovery.
	add_to_group("security_cameras")

	camera_pivot.rotation = 0.0
	camera_pivot.scale = Vector2.ONE

	camera_sprite.flip_h = false
	camera_sprite.frame = 0

	detection_area.body_entered.connect(_on_body_entered)
	detection_area.body_exited.connect(_on_body_exited)

	# Detect players already overlapping when the scene starts.
	call_deferred("refresh_player_detection")

	print(
		"SecurityCamera: ",
		camera_id,
		" | sistema iniciado"
	)


# ============================================================
# PROCESS
# ============================================================

func _process(delta: float) -> void:
	if current_state == CameraState.REBOOTING:
		reboot_timer -= delta

		if reboot_timer <= 0.0:
			recover_camera()


# ============================================================
# PLAYER DETECTION
# ============================================================

func _on_body_entered(body: Node2D) -> void:
	if not is_player(body):
		return

	player_in_range = true

	if can_detect_player():
		detect_player()


func _on_body_exited(body: Node2D) -> void:
	if not is_player(body):
		return

	player_in_range = false

	if current_state == CameraState.DETECTED:
		reset_camera()


func is_player(body: Node2D) -> bool:
	return body is CharacterBody2D and body.name == "Player"


func can_detect_player() -> bool:
	if is_disabled:
		return false

	if current_state != CameraState.IDLE:
		return false

	return true


func detect_player() -> void:
	if not can_detect_player():
		return

	current_state = CameraState.DETECTED

	camera_sprite.frame = 2

	player_detected.emit()

	print(
		"SecurityCamera: ",
		camera_id,
		" | jogador detectado"
	)


func reset_camera() -> void:
	if is_disabled:
		return

	if current_state != CameraState.DETECTED:
		return

	current_state = CameraState.IDLE

	camera_sprite.frame = 0

	print(
		"SecurityCamera: ",
		camera_id,
		" | jogador fora de alcance"
	)


func refresh_player_detection() -> void:
	if not is_instance_valid(detection_area):
		return

	player_in_range = false

	for body in detection_area.get_overlapping_bodies():
		if is_player(body):
			player_in_range = true
			break

	if player_in_range and can_detect_player():
		detect_player()


# ============================================================
# ESP32 — CAMERA JAMMING
# ============================================================

func start_jamming() -> void:
	# Avoid restarting an active interference.
	if current_state == CameraState.JAMMED:
		return

	# Disable detection immediately.
	is_disabled = true

	current_state = CameraState.JAMMED

	reboot_timer = 0.0

	# Return camera sprite to its neutral frame.
	camera_sprite.frame = 0

	camera_jammed.emit()

	print(
		"SecurityCamera: ",
		camera_id,
		" | interferência iniciada"
	)


func stop_jamming() -> void:
	if current_state != CameraState.JAMMED:
		return

	# Keep detection disabled during reboot.
	is_disabled = true

	current_state = CameraState.REBOOTING

	reboot_timer = maxf(reboot_duration, 0.0)

	print(
		"SecurityCamera: ",
		camera_id,
		" | reiniciando..."
	)

	if reboot_timer <= 0.0:
		recover_camera()


# ============================================================
# CAMERA RECOVERY
# ============================================================

func recover_camera() -> void:
	if current_state != CameraState.REBOOTING:
		return

	is_disabled = false

	current_state = CameraState.IDLE

	reboot_timer = 0.0

	camera_sprite.frame = 0

	camera_recovered.emit()

	print(
		"SecurityCamera: ",
		camera_id,
		" | sistema restaurado"
	)

	# Check if the player is still inside the detection area.
	refresh_player_detection()


# ============================================================
# CAMERA STATUS
# ============================================================

func is_camera_jammed() -> bool:
	return current_state == CameraState.JAMMED


func is_camera_operational() -> bool:
	return (
		current_state == CameraState.IDLE
		or current_state == CameraState.DETECTED
	)


func get_camera_id() -> String:
	return camera_id