extends Node2D

@onready var camera_pivot: Node2D = $CameraPivot
@onready var camera_sprite: Sprite2D = $CameraPivot/CameraSprite
@onready var detection_area: Area2D = $DetectionArea

var is_disabled: bool = false


func _ready() -> void:
	camera_pivot.rotation = 0.0
	camera_pivot.scale = Vector2.ONE

	camera_sprite.flip_h = false
	camera_sprite.frame = 0

	detection_area.body_entered.connect(_on_body_entered)
	detection_area.body_exited.connect(_on_body_exited)


func _on_body_entered(body: Node2D) -> void:
	if is_disabled:
		return

	if body is CharacterBody2D and body.name == "Player":
		camera_sprite.frame = 2
		print("SecurityCamera: jogador detectado")


func _on_body_exited(body: Node2D) -> void:
	if body is CharacterBody2D and body.name == "Player":
		camera_sprite.frame = 0
		print("SecurityCamera: jogador fora de alcance")
