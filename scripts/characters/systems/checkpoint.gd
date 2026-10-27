extends Area2D

# ============================================================
# VICTUBYTE - CHECKPOINT SYSTEM
# ============================================================

signal checkpoint_activated(checkpoint_position: Vector2)

@export var respawn_point: Marker2D

var is_activated: bool = false
var saved_respawn_position: Vector2 = Vector2.ZERO


func _ready() -> void:
	# Connect the checkpoint detection signal.
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	# Prevent repeated activation.
	if is_activated:
		return

	# Only allow the player to activate checkpoints.
	if not body is CharacterBody2D:
		return

	if not body.is_in_group("player"):
		return

	activate_checkpoint()


func activate_checkpoint() -> void:
	if is_activated:
		return

	is_activated = true

	# Save the checkpoint respawn position.
	saved_respawn_position = get_respawn_position()

	# Notify the main game system.
	checkpoint_activated.emit(saved_respawn_position)

	print("CHECKPOINT ACTIVATED: ", saved_respawn_position)


func get_respawn_position() -> Vector2:
	# Prefer the configured respawn marker.
	if is_instance_valid(respawn_point):
		return respawn_point.global_position

	# Fallback to the checkpoint position.
	return global_position


func reset_checkpoint() -> void:
	# Allow this checkpoint to be activated again.
	is_activated = false
	saved_respawn_position = Vector2.ZERO

	print("CHECKPOINT RESET")