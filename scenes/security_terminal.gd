extends Area2D

# ============================================================
# VICTUBYTE - SECURITY TERMINAL
# ============================================================

signal access_granted
signal laptop_ready
signal checkpoint_activated(checkpoint_position: Vector2)


# ============================================================
# CONFIGURATION
# ============================================================

@export_category("Checkpoint")
@export var enable_checkpoint: bool = true


# ============================================================
# NODE REFERENCES
# ============================================================

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var interaction_label: Label = $InteractionLabel
@onready var respawn_point: Marker2D = $RespawnPoint


# ============================================================
# STATE
# ============================================================

var player_near: bool = false
var unlocked: bool = false
var busy: bool = false
var checkpoint_registered: bool = false

var current_player: CharacterBody2D = null


# ============================================================
# INITIALIZATION
# ============================================================

func _ready() -> void:
	interaction_label.hide()
	sprite.play("idle")

	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

	print("SECURITY TERMINAL: Initialized.")


# ============================================================
# PLAYER INPUT
# ============================================================

func _unhandled_input(event: InputEvent) -> void:
	if not player_near:
		return

	if busy or unlocked:
		return

	if event.is_action_pressed("interact") and not event.is_echo():
		get_viewport().set_input_as_handled()
		start_access()


# ============================================================
# ACCESS START
# ============================================================

func start_access() -> void:
	if busy or unlocked:
		return

	if not is_instance_valid(current_player):
		print("SECURITY TERMINAL: Player unavailable.")
		return

	if not current_player.has_method("start_laptop_equip"):
		push_warning(
			"SECURITY TERMINAL: Player does not support laptop equip."
		)
		return

	busy = true
	interaction_label.hide()

	print("SECURITY TERMINAL: Interaction started.")
	print("SECURITY TERMINAL: Waiting for laptop equip.")

	# Wait for the player to equip the laptop.
	await current_player.start_laptop_equip()

	if not busy or unlocked:
		return

	if not is_instance_valid(current_player):
		cancel_access()
		return

	print("SECURITY TERMINAL: Laptop equipped.")

	# Start interaction animation.
	sprite.play("interacting")

	# Request VICTU OS interface.
	print("SECURITY TERMINAL: Opening VICTU OS.")

	laptop_ready.emit()

	print("SECURITY TERMINAL: Laptop interface requested.")

	# Terminal remains busy until access is completed or cancelled.


# ============================================================
# ACCESS COMPLETION
# ============================================================

func complete_access() -> void:
	if not busy or unlocked:
		return

	print("SECURITY TERMINAL: Processing access.")

	# Processing animation must not loop.
	sprite.play("processing")
	await sprite.animation_finished

	if not busy or unlocked:
		return

	# Unlock animation must not loop.
	sprite.play("unlocked")
	await sprite.animation_finished

	if not busy or unlocked:
		return

	unlocked = true
	busy = false

	interaction_label.hide()

	print("SECURITY TERMINAL: Access granted.")

	# Register checkpoint only after successful access.
	if enable_checkpoint:
		register_checkpoint()

	# Preserve existing door-unlock behavior.
	print("SECURITY TERMINAL: Sending access signal.")

	access_granted.emit()


# ============================================================
# CHECKPOINT SYSTEM
# ============================================================

func register_checkpoint() -> void:
	if checkpoint_registered:
		return

	if not is_instance_valid(respawn_point):
		push_warning(
			"SECURITY TERMINAL: RespawnPoint is missing."
		)
		return

	# Verify that the global checkpoint manager exists.
	if not has_node("/root/CheckpointManager"):
		push_warning(
			"SECURITY TERMINAL: CheckpointManager not found."
		)
		return

	var checkpoint_manager: Node = get_node(
		"/root/CheckpointManager"
	)

	var checkpoint_position: Vector2 = respawn_point.global_position

	checkpoint_manager.activate_checkpoint(
		checkpoint_position
	)

	checkpoint_registered = true

	checkpoint_activated.emit(checkpoint_position)

	print(
		"SECURITY TERMINAL: Checkpoint registered at ",
		checkpoint_position
	)


# ============================================================
# ACCESS CANCELLATION
# ============================================================

func cancel_access() -> void:
	if unlocked:
		return

	busy = false

	sprite.play("idle")

	if player_near and is_instance_valid(current_player):
		interaction_label.show()
	else:
		interaction_label.hide()

	print("SECURITY TERMINAL: Interaction cancelled.")


# ============================================================
# PLAYER DETECTION
# ============================================================

func _on_body_entered(body: Node2D) -> void:
	if not body is CharacterBody2D:
		return

	if not body.is_in_group("player"):
		return

	current_player = body
	player_near = true

	print("SECURITY TERMINAL: Player entered interaction area.")

	if not unlocked and not busy:
		interaction_label.show()


func _on_body_exited(body: Node2D) -> void:
	if body != current_player:
		return

	player_near = false
	current_player = null

	interaction_label.hide()

	print("SECURITY TERMINAL: Player left interaction area.")