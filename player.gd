extends CharacterBody2D

@export var speed: float = 140.0
@export var acceleration: float = 900.0
@export var friction: float = 1200.0
@export var jump_velocity: float = -280.0
@export var gravity: float = 850.0

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D


func _ready() -> void:
	sprite.play("idle")


func _physics_process(delta: float) -> void:
	# Gravidade
	if not is_on_floor():
		velocity.y += gravity * delta

	# Movimento horizontal
	var direction := Input.get_axis("ui_left", "ui_right")
	var target_speed := direction * speed

	if direction != 0.0:
		velocity.x = move_toward(
			velocity.x,
			target_speed,
			acceleration * delta
		)
	else:
		velocity.x = move_toward(
			velocity.x,
			0.0,
			friction * delta
		)

	# Pulo
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = jump_velocity

	# Pulo variável
	if Input.is_action_just_released("ui_accept") and velocity.y < 0.0:
		velocity.y *= 0.5

	move_and_slide()
	update_animation()


func update_animation() -> void:
	# Selecionar animação conforme o movimento
	if not is_on_floor():
		if velocity.y < 0.0:
			sprite.play("jump")
		else:
			sprite.play("fall")
	elif abs(velocity.x) > 10.0:
		sprite.play("run")
	else:
		sprite.play("idle")

	# Virar personagem conforme a direção
	if velocity.x > 1.0:
		sprite.flip_h = false
	elif velocity.x < -1.0:
		sprite.flip_h = true
