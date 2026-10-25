extends CharacterBody2D

@export var speed: float = 140.0
@export var acceleration: float = 900.0
@export var friction: float = 1200.0
@export var jump_velocity: float = -280.0
@export var gravity: float = 850.0

const NORMAL_SCALE := Vector2(0.15, 0.15)
const LAPTOP_SCALE := Vector2(0.04, 0.04)

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

var is_equipping_laptop: bool = false
var is_using_laptop: bool = false


func _ready() -> void:
	sprite.scale = NORMAL_SCALE
	sprite.play("idle")


func _physics_process(delta: float) -> void:
	# Apply gravity.
	if not is_on_floor():
		velocity.y += gravity * delta

	# Stop horizontal movement while using the laptop.
	if is_equipping_laptop or is_using_laptop:
		velocity.x = 0.0
		move_and_slide()
		return

	# Horizontal movement.
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

	# Jump.
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = jump_velocity

	# Variable jump height.
	if Input.is_action_just_released("ui_accept") and velocity.y < 0.0:
		velocity.y *= 0.5

	move_and_slide()
	update_animation()


func update_animation() -> void:
	# Do not interrupt the laptop animation.
	if is_equipping_laptop or is_using_laptop:
		return

	# Use jump animation during both ascent and descent.
	if not is_on_floor():
		sprite.play("jump")
	elif abs(velocity.x) > 10.0:
		sprite.play("run")
	else:
		sprite.play("idle")

	# Face the movement direction.
	if velocity.x > 1.0:
		sprite.flip_h = false
	elif velocity.x < -1.0:
		sprite.flip_h = true


func start_laptop_equip() -> void:
	# Prevent duplicate interactions.
	if is_equipping_laptop or is_using_laptop:
		return

	is_equipping_laptop = true
	velocity.x = 0.0

	# Face right for the current terminal interaction.
	sprite.flip_h = false

	# Apply the laptop animation scale.
	sprite.scale = LAPTOP_SCALE

	# Restart the equip animation from its first frame.
	sprite.play("laptop_equip")
	sprite.set_frame_and_progress(0, 0.0)

	await sprite.animation_finished

	# Handle unexpected animation interruptions.
	if sprite.animation != "laptop_equip":
		is_equipping_laptop = false
		sprite.scale = NORMAL_SCALE
		update_animation()
		return

	is_equipping_laptop = false
	is_using_laptop = true

	# Keep the notebook visible after the animation.
	sprite.stop()
	sprite.frame = sprite.sprite_frames.get_frame_count("laptop_equip") - 1

	print("Jogador: notebook equipado.")


func finish_laptop_interaction() -> void:
	# Restore normal movement.
	is_equipping_laptop = false
	is_using_laptop = false

	# Restore the original sprite scale.
	sprite.scale = NORMAL_SCALE

	# Return to the idle animation.
	sprite.play("idle")

	print("Jogador: interação com notebook finalizada.")
