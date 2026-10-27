extends Node

# ============================================================
# VICTUBYTE - CHECKPOINT MANAGER
# ============================================================

signal checkpoint_updated(checkpoint_position: Vector2)

var last_checkpoint_position: Vector2 = Vector2.ZERO
var has_checkpoint: bool = false


func activate_checkpoint(checkpoint_position: Vector2) -> void:
	last_checkpoint_position = checkpoint_position
	has_checkpoint = true

	checkpoint_updated.emit(checkpoint_position)

	print("CHECKPOINT ACTIVATED: ", checkpoint_position)


func respawn_player(player: CharacterBody2D) -> void:
	if not has_checkpoint:
		push_warning("CHECKPOINT: No checkpoint available.")
		return

	if not is_instance_valid(player):
		return

	player.global_position = last_checkpoint_position
	player.velocity = Vector2.ZERO

	print("CHECKPOINT: Player respawned.")