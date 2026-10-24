extends Node2D

@onready var door_body: Node2D = $DoorBody
@onready var closed_pos: Marker2D = $ClosedPos
@onready var open_pos: Marker2D = $OpenPos
@onready var collision: CollisionShape2D = $DoorBody/StaticBody2D/CollisionShape2D

var is_open := false
var is_moving := false


func _ready() -> void:
	door_body.position = closed_pos.position
	door_body.show()
	collision.set_deferred("disabled", false)


func open_door() -> void:
	if is_open or is_moving:
		return

	is_moving = true

	var tween := create_tween()

	tween.tween_property(
		door_body,
		"position",
		open_pos.position,
		1.0
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	await tween.finished

	# Desativa apenas a colisão.
	# A porta permanece visível, mas atrás do chão.
	collision.set_deferred("disabled", true)

	is_open = true
	is_moving = false

	print("VICTUBYTE: porta recolhida no chão!")


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		if event.pressed and not event.echo and event.keycode == KEY_O:
			open_door()
