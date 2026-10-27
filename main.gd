extends Node2D

# ============================================================
# VICTUBYTE — MAIN GAME SYSTEM
# ============================================================

@onready var player: CharacterBody2D = $Player
@onready var byte_agent: CharacterBody2D = $ByteAgent
@onready var checkpoint: Area2D = $Checkpoint

@onready var capture_screen: CanvasLayer = $CaptureScreen
@onready var black_overlay: ColorRect = $CaptureScreen/BlackOverlay
@onready var capture_label: Label = $CaptureScreen/CaptureLabel

var capture_in_progress: bool = false
var last_checkpoint_position: Vector2 = Vector2.ZERO


# ============================================================
# INITIALIZATION
# ============================================================

func _ready() -> void:
	print("VICTUBYTE started successfully!")

	# Save the initial player position.
	last_checkpoint_position = player.global_position

	# Initialize game systems.
	setup_security_terminal()
	setup_checkpoint()
	setup_capture_screen()
	setup_byte_capture()

	print("VICTUBYTE: Main systems initialized.")


# ============================================================
# SECURITY TERMINAL
# ============================================================

func setup_security_terminal() -> void:
	var security_terminal: Node = get_node_or_null(
		"SecurityTerminal"
	)

	var door: Node = get_node_or_null("Door")

	if security_terminal == null:
		push_warning(
			"VICTUBYTE: SecurityTerminal not found."
		)
		return

	if door == null:
		push_warning(
			"VICTUBYTE: Door not found."
		)
		return

	if not security_terminal.has_signal("access_granted"):
		push_warning(
			"VICTUBYTE: access_granted signal not found."
		)
		return

	if not door.has_method("open_door"):
		push_warning(
			"VICTUBYTE: open_door method not found."
		)
		return

	var door_callback: Callable = Callable(
		door,
		"open_door"
	)

	if not security_terminal.is_connected(
		"access_granted",
		door_callback
	):
		security_terminal.connect(
			"access_granted",
			door_callback
		)

	print("VICTUBYTE: Terminal connected to door.")


# ============================================================
# CHECKPOINT SYSTEM
# ============================================================

func setup_checkpoint() -> void:
	if not is_instance_valid(checkpoint):
		push_warning(
			"VICTUBYTE: Checkpoint not found."
		)
		return

	if not checkpoint.has_signal("checkpoint_activated"):
		push_warning(
			"VICTUBYTE: Checkpoint script or signal not found."
		)
		return

	var checkpoint_callback: Callable = Callable(
		self,
		"_on_checkpoint_activated"
	)

	if not checkpoint.is_connected(
		"checkpoint_activated",
		checkpoint_callback
	):
		checkpoint.connect(
			"checkpoint_activated",
			checkpoint_callback
		)

	print("VICTUBYTE: Checkpoint system connected.")

	# Restore a previously activated checkpoint if necessary.
	if checkpoint.get("is_activated") == true:
		if checkpoint.has_method("get_respawn_position"):
			last_checkpoint_position = checkpoint.call(
				"get_respawn_position"
			)


func _on_checkpoint_activated(
	checkpoint_position: Vector2
) -> void:
	last_checkpoint_position = checkpoint_position

	print(
		"VICTUBYTE: Checkpoint saved at ",
		last_checkpoint_position
	)


# ============================================================
# BYTE CAPTURE CONNECTION
# ============================================================

func setup_byte_capture() -> void:
	if not is_instance_valid(byte_agent):
		push_warning(
			"VICTUBYTE: ByteAgent not found."
		)
		return

	if not byte_agent.has_signal("capture_completed"):
		push_warning(
			"VICTUBYTE: BYTE capture signal not found."
		)
		return

	var capture_callback: Callable = Callable(
		self,
		"show_capture_screen"
	)

	if not byte_agent.is_connected(
		"capture_completed",
		capture_callback
	):
		byte_agent.connect(
			"capture_completed",
			capture_callback
		)

	print("VICTUBYTE: BYTE capture system connected.")


# ============================================================
# CAPTURE SCREEN INITIALIZATION
# ============================================================

func setup_capture_screen() -> void:
	# Keep the capture screen above the game.
	capture_screen.layer = 10

	# Prevent the overlay from intercepting mouse input.
	black_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	capture_label.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Set capture message.
	capture_label.text = "CAPTURADO"

	# Center the text inside its existing rectangle.
	capture_label.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)

	capture_label.vertical_alignment = (
		VERTICAL_ALIGNMENT_CENTER
	)

	# Initialize capture screen opacity.
	black_overlay.modulate.a = 0.0
	capture_label.modulate.a = 0.0

	# Hide the capture screen initially.
	capture_screen.visible = false

	print("VICTUBYTE: Capture screen initialized.")


# ============================================================
# CAPTURE SYSTEM
# ============================================================

func show_capture_screen() -> void:
	if capture_in_progress:
		return

	if not is_instance_valid(player):
		push_warning(
			"VICTUBYTE: Cannot capture missing player."
		)
		return

	capture_in_progress = true

	print("VICTUBYTE: Player captured!")

	# Lock player movement.
	lock_player()

	# Prepare capture screen.
	capture_screen.visible = true

	black_overlay.modulate.a = 0.0
	capture_label.modulate.a = 0.0

	# Fade to black.
	var fade_in: Tween = create_tween()
	fade_in.set_parallel(true)

	fade_in.tween_property(
		black_overlay,
		"modulate:a",
		1.0,
		0.5
	)

	fade_in.tween_property(
		capture_label,
		"modulate:a",
		1.0,
		0.5
	)

	await fade_in.finished

	print("VICTUBYTE: Capture screen displayed.")

	# Keep the capture message visible.
	await get_tree().create_timer(1.5).timeout

	# Return player to the last checkpoint.
	respawn_player()

	# Fade capture screen out.
	var fade_out: Tween = create_tween()
	fade_out.set_parallel(true)

	fade_out.tween_property(
		black_overlay,
		"modulate:a",
		0.0,
		0.5
	)

	fade_out.tween_property(
		capture_label,
		"modulate:a",
		0.0,
		0.5
	)

	await fade_out.finished

	# Hide capture screen.
	capture_screen.visible = false

	capture_in_progress = false

	print("VICTUBYTE: Capture sequence completed.")


# ============================================================
# PLAYER CONTROL
# ============================================================

func lock_player() -> void:
	if not is_instance_valid(player):
		return

	player.velocity = Vector2.ZERO

	# Use the player's custom capture method if available.
	if player.has_method("capture"):
		player.call("capture")

	# Ensure movement and input are disabled.
	player.set_physics_process(false)
	player.set_process_input(false)
	player.set_process_unhandled_input(false)
	player.set_process_unhandled_key_input(false)

	print("VICTUBYTE: Player controls locked.")


func unlock_player() -> void:
	if not is_instance_valid(player):
		return

	player.velocity = Vector2.ZERO

	player.set_physics_process(true)
	player.set_process_input(true)
	player.set_process_unhandled_input(true)
	player.set_process_unhandled_key_input(true)

	print("VICTUBYTE: Player controls restored.")


# ============================================================
# PLAYER RESPAWN
# ============================================================

func respawn_player() -> void:
	if not is_instance_valid(player):
		push_warning(
			"VICTUBYTE: Player not found."
		)
		return

	print(
		"VICTUBYTE: Respawning player at ",
		last_checkpoint_position
	)

	# Deactivate BYTE before restoring the player.
	if is_instance_valid(byte_agent):
		if byte_agent.has_method("deactivate_agent"):
			byte_agent.call("deactivate_agent")

	# Restore player position.
	if player.has_method("respawn"):
		player.call(
			"respawn",
			last_checkpoint_position
		)
	else:
		player.global_position = last_checkpoint_position
		player.velocity = Vector2.ZERO

	# Restore player controls.
	unlock_player()

	print("VICTUBYTE: Player respawn completed.")
