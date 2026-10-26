extends CharacterBody2D

# ============================================================
# VICTUBYTE — PLAYER
# ============================================================

@export var speed: float = 140.0
@export var acceleration: float = 900.0
@export var friction: float = 1200.0
@export var jump_velocity: float = -280.0
@export var gravity: float = 850.0

const NORMAL_SCALE := Vector2(0.15, 0.15)
const LAPTOP_SCALE := Vector2(0.04, 0.04)
const ESP32_SCALE := Vector2(0.15, 0.15)

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var esp32_controller: Node = get_node_or_null("ESP32Controller")

var is_equipping_laptop: bool = false
var is_using_laptop: bool = false

var is_equipping_esp32: bool = false
var is_using_esp32: bool = false


# ============================================================
# INITIALIZATION
# ============================================================

func _ready() -> void:
	sprite.scale = NORMAL_SCALE
	sprite.play("idle")

	if esp32_controller != null:
		esp32_controller.set_equipped(false)


# ============================================================
# MOVEMENT
# ============================================================

func _physics_process(delta: float) -> void:
	# Gravity
	if not is_on_floor():
		velocity.y += gravity * delta

	# Only the laptop locks player movement.
	if is_equipping_laptop or is_using_laptop:
		velocity.x = 0.0
		move_and_slide()
		return

	# ESP32 does NOT interrupt movement.
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

	# Jump
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = jump_velocity

	if Input.is_action_just_released("ui_accept") and velocity.y < 0.0:
		velocity.y *= 0.5

	move_and_slide()

	update_facing_direction()
	update_animation()


# ============================================================
# ANIMATIONS
# ============================================================

func update_animation() -> void:
	# Do not interrupt the laptop or ESP32 equip animations.
	if (
		is_equipping_laptop
		or is_using_laptop
		or is_equipping_esp32
	):
		return

	if is_using_esp32:
		update_esp32_animation()
		return

	# Normal movement animations.
	if not is_on_floor():
		sprite.play("jump")

	elif abs(velocity.x) > 10.0:
		sprite.play("run")

	else:
		sprite.play("idle")


func update_esp32_animation() -> void:
	# Jumping with ESP32
	if not is_on_floor():
		if has_animation_frames("esp32_jump"):
			sprite.play("esp32_jump")
		elif abs(velocity.x) > 10.0 and has_animation_frames("esp32_run"):
			sprite.play("esp32_run")
		else:
			show_esp32_hold_pose()
		return

	# Running with ESP32
	if abs(velocity.x) > 10.0:
		if has_animation_frames("esp32_run"):
			sprite.play("esp32_run")
		else:
			show_esp32_hold_pose()
		return

	# Idle with ESP32
	if has_animation_frames("esp32_idle"):
		sprite.play("esp32_idle")
	else:
		show_esp32_hold_pose()


func has_animation_frames(animation_name: StringName) -> bool:
	return (
		sprite.sprite_frames.has_animation(animation_name)
		and sprite.sprite_frames.get_frame_count(animation_name) > 0
	)


func show_esp32_hold_pose() -> void:
	if not has_animation_frames("esp32_equip"):
		return

	if sprite.animation != "esp32_equip":
		sprite.animation = "esp32_equip"

	sprite.stop()
	sprite.frame = (
		sprite.sprite_frames.get_frame_count("esp32_equip") - 1
	)


func update_facing_direction() -> void:
	if velocity.x > 1.0:
		sprite.flip_h = false
	elif velocity.x < -1.0:
		sprite.flip_h = true


# ============================================================
# LAPTOP
# ============================================================

func start_laptop_equip() -> void:
	if (
		is_equipping_laptop
		or is_using_laptop
		or is_equipping_esp32
		or is_using_esp32
	):
		return

	is_equipping_laptop = true
	velocity.x = 0.0

	sprite.flip_h = false
	sprite.scale = LAPTOP_SCALE

	sprite.play("laptop_equip")
	sprite.set_frame_and_progress(0, 0.0)

	await sprite.animation_finished

	if sprite.animation != "laptop_equip":
		is_equipping_laptop = false
		sprite.scale = NORMAL_SCALE
		update_animation()
		return

	is_equipping_laptop = false
	is_using_laptop = true

	sprite.stop()
	sprite.frame = (
		sprite.sprite_frames.get_frame_count("laptop_equip") - 1
	)

	print("Jogador: notebook equipado.")


func finish_laptop_interaction() -> void:
	is_equipping_laptop = false
	is_using_laptop = false

	sprite.scale = NORMAL_SCALE
	sprite.play("idle")

	print("Jogador: interação com notebook finalizada.")


# ============================================================
# ESP32 INPUT
# ============================================================

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey:
		return

	if not event.pressed or event.echo:
		return

	if event.keycode == KEY_G:
		toggle_esp32()


func toggle_esp32() -> void:
	if is_equipping_esp32:
		return

	if is_equipping_laptop or is_using_laptop:
		return

	if is_using_esp32:
		finish_esp32_interaction()
	else:
		start_esp32_equip()


# ============================================================
# ESP32 EQUIPMENT
# ============================================================

func start_esp32_equip() -> void:
	if not has_animation_frames("esp32_equip"):
		push_warning("Animação esp32_equip não encontrada.")
		return

	if esp32_controller == null:
		push_warning("ESP32Controller não encontrado.")
		return

	is_equipping_esp32 = true

	# Do not stop or reset player movement.
	sprite.scale = ESP32_SCALE

	sprite.play("esp32_equip")
	sprite.set_frame_and_progress(0, 0.0)

	print("Jogador: retirando ESP32 em movimento...")

	await sprite.animation_finished

	if sprite.animation != "esp32_equip":
		is_equipping_esp32 = false
		sprite.scale = NORMAL_SCALE
		update_animation()
		return

	is_equipping_esp32 = false
	is_using_esp32 = true

	esp32_controller.set_equipped(true)

	# Immediately switch to running or idle with ESP32.
	update_animation()

	print("Jogador: ESP32 equipado. Corrida liberada.")


func finish_esp32_interaction() -> void:
	if esp32_controller != null:
		esp32_controller.set_equipped(false)

	is_equipping_esp32 = false
	is_using_esp32 = false

	sprite.scale = NORMAL_SCALE
	update_animation()

	print("Jogador: ESP32 guardado.")