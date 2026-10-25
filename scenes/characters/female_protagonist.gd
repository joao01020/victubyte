extends CharacterBody2D

# Movement settings.
@export_group("Movement")

@export var player_controlled: bool = true
@export var speed: float = 140.0
@export var acceleration: float = 900.0
@export var friction: float = 1200.0
@export var jump_velocity: float = -280.0
@export var gravity: float = 850.0


# Animation settings.
@export_group("Animation")

@export_enum("idle", "run", "jump")
var initial_animation: String = "idle"


# Individual animation scales.
@export_group("Animation Scale")

@export_range(0.1, 3.0, 0.01)
var idle_scale: float = 1.0

@export_range(0.1, 3.0, 0.01)
var run_scale: float = 1.0

@export_range(0.1, 3.0, 0.01)
var jump_scale: float = 1.0


# Individual animation offsets.
@export_group("Animation Offset")

@export var idle_offset: Vector2 = Vector2.ZERO
@export var run_offset: Vector2 = Vector2.ZERO
@export var jump_offset: Vector2 = Vector2.ZERO


# Debug settings.
@export_group("Debug")

@export var debug_input: bool = false


# Node references.
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D


# Character state.
var movement_direction: float = 0.0
var is_jumping: bool = false
var is_animation_locked: bool = false

var base_sprite_scale: Vector2 = Vector2.ONE
var base_sprite_position: Vector2 = Vector2.ZERO
var current_animation: String = ""

var previous_debug_direction: float = 0.0


func _ready() -> void:
	# Preserve sprite settings from the editor.
	base_sprite_scale = sprite.scale
	base_sprite_position = sprite.position

	# Initialize animation.
	play_animation(initial_animation)

	print("Personagem feminina inicializada.")
	print("Controle feminino ativado: ", player_controlled)
	print("Modo de processamento: ", process_mode)

	# Show movement configuration.
	if player_controlled:
		print("Use as setas para mover e Espaço para pular.")


func _physics_process(delta: float) -> void:
	# Apply gravity.
	if not is_on_floor():
		velocity.y += gravity * delta
	elif velocity.y > 0.0:
		velocity.y = 0.0

	# Read player input when control is enabled.
	if player_controlled:
		read_player_input()

	# Apply horizontal movement.
	var target_speed: float = movement_direction * speed

	if movement_direction != 0.0:
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

	# Apply collision and movement.
	move_and_slide()

	# Update jump state.
	if is_on_floor():
		is_jumping = false

	# Update animations and direction.
	update_animation()


func read_player_input() -> void:
	# Use the same input actions as the protagonist.
	movement_direction = Input.get_axis(
		"ui_left",
		"ui_right"
	)

	# Debug horizontal keyboard input.
	if debug_input:
		if movement_direction != previous_debug_direction:
			print(
				"Movimento feminino: ",
				movement_direction
			)

			previous_debug_direction = movement_direction

	# Jump when pressing the jump key.
	if Input.is_action_just_pressed("ui_accept"):
		if debug_input:
			print(
				"Comando de pulo recebido. No chão: ",
				is_on_floor()
			)

		if is_on_floor():
			play_jump()

	# Variable jump height.
	if Input.is_action_just_released("ui_accept"):
		if velocity.y < 0.0:
			velocity.y *= 0.5


func update_animation() -> void:
	# Preserve externally locked animations.
	if is_animation_locked:
		return

	# Select animation based on physics.
	if not is_on_floor():
		play_animation("jump")
	elif abs(velocity.x) > 10.0:
		play_animation("run")
	else:
		play_animation("idle")

	# Update facing direction.
	if velocity.x > 1.0:
		face_right()
	elif velocity.x < -1.0:
		face_left()


func play_animation(animation_name: String) -> void:
	# Validate SpriteFrames.
	if sprite.sprite_frames == null:
		push_warning(
			"Personagem feminina: SpriteFrames não configurado."
		)
		return

	# Validate animation name.
	if not sprite.sprite_frames.has_animation(animation_name):
		push_warning(
			"Personagem feminina: animação não encontrada: "
			+ animation_name
		)
		return

	# Apply animation-specific scale and offset.
	if current_animation != animation_name:
		current_animation = animation_name

		apply_animation_transform(animation_name)

	# Avoid unnecessary animation restarts.
	if sprite.animation == animation_name and sprite.is_playing():
		return

	sprite.play(animation_name)


func apply_animation_transform(animation_name: String) -> void:
	var animation_scale: float = 1.0
	var animation_offset: Vector2 = Vector2.ZERO

	match animation_name:
		"idle":
			animation_scale = idle_scale
			animation_offset = idle_offset

		"run":
			animation_scale = run_scale
			animation_offset = run_offset

		"jump":
			animation_scale = jump_scale
			animation_offset = jump_offset

		_:
			animation_scale = 1.0
			animation_offset = Vector2.ZERO

	# Preserve relative scale from the scene editor.
	sprite.scale = base_sprite_scale * animation_scale

	# Preserve relative position from the scene editor.
	sprite.position = base_sprite_position + animation_offset


func play_idle() -> void:
	movement_direction = 0.0
	is_animation_locked = false

	play_animation("idle")


func play_run() -> void:
	is_animation_locked = false

	play_animation("run")


func play_jump() -> void:
	# Only jump while grounded.
	if not is_on_floor():
		return

	velocity.y = jump_velocity

	is_jumping = true
	is_animation_locked = false

	play_animation("jump")


func move_left() -> void:
	movement_direction = -1.0
	face_left()


func move_right() -> void:
	movement_direction = 1.0
	face_right()


func stop_movement() -> void:
	movement_direction = 0.0


func face_left() -> void:
	sprite.flip_h = true


func face_right() -> void:
	sprite.flip_h = false


func lock_animation(animation_name: String) -> void:
	is_animation_locked = true

	play_animation(animation_name)


func unlock_animation() -> void:
	is_animation_locked = false

	update_animation()


func set_character_visible(value: bool) -> void:
	visible = value


func enable_player_control() -> void:
	player_controlled = true
	movement_direction = 0.0

	print("Controle da personagem feminina ativado.")


func disable_player_control() -> void:
	player_controlled = false
	movement_direction = 0.0

	print("Controle da personagem feminina desativado.")
