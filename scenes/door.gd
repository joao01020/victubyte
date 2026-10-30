extends Node2D

# ============================================================
# VICTUBYTE - SECURITY DOOR
# ============================================================

signal door_opened

@export_category("Door Settings")
@export_range(0.1, 5.0, 0.1) var opening_duration: float = 1.0

@onready var door_body: Node2D = $DoorBody
@onready var closed_pos: Marker2D = $ClosedPos
@onready var open_pos: Marker2D = $OpenPos
@onready var collision: CollisionShape2D = $DoorBody/StaticBody2D/CollisionShape2D

var is_open: bool = false
var is_moving: bool = false


# ============================================================
# INITIALIZATION
# ============================================================

func _ready() -> void:
	door_body.position = closed_pos.position
	door_body.show()

	collision.set_deferred("disabled", false)

	is_open = false
	is_moving = false


# ============================================================
# OPEN DOOR
# ============================================================

func open_door() -> void:
	if is_open or is_moving:
		return

	is_moving = true

	print("VICTUBYTE: Opening security door.")

	var tween: Tween = create_tween()

	tween.tween_property(
		door_body,
		"position",
		open_pos.position,
		opening_duration
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	await tween.finished

	if not is_inside_tree():
		return

	# Disable collision after the door finishes moving.
	# The door remains visible beneath the floor.
	collision.set_deferred("disabled", true)

	is_open = true
	is_moving = false

	print("VICTUBYTE: Security door opened.")

	door_opened.emit()