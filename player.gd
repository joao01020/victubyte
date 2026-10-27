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

# Capture system
var is_captured: bool = false

# Prevent interrupted equipment animations from resuming.
var equipment_generation: int = 0


# ============================================================
# INITIALIZATION
# ============================================================

func _ready() -> void:
	add_to_group("player")

	sprite.scale = NORMAL_SCALE
	sprite.play("idle")

	if esp32_controller != null:
		esp32_controller.set_equipped(false)


# ============================================================
# MOVEMENT
# ============================================================

func _physics_process(delta: float) -> void:
	# Disable movement during capture.
	if is_captured:
		velocity = Vector2.ZERO
		return

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
	if is_captured:
		return

	# Do not interrupt equipment animations.
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
	if is_captured:
		return

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
		sprite.sprite_frames != null
		and sprite.sprite_frames.has_animation(animation_name)
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
		is_captured
		or is_equipping_laptop
		or is_using_laptop
		or is_equipping_esp32
		or is_using_esp32
	):
		return

	if not has_animation_frames("laptop_equip"):
		push_warning("Animation laptop_equip not found.")
		return

	is_equipping_laptop = true
	velocity.x = 0.0

	sprite.flip_h = false
	sprite.scale = LAPTOP_SCALE

	equipment_generation += 1
	var current_generation := equipment_generation

	sprite.play("laptop_equip")
	sprite.set_frame_and_progress(0, 0.0)

	await sprite.animation_finished

	# Ignore an animation invalidated by capture or respawn.
	if current_generation != equipment_generation:
		return

	if is_captured:
		return

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

	print("PLAYER: Laptop equipped.")


func finish_laptop_interaction() -> void:
	if is_captured:
		return

	equipment_generation += 1

	is_equipping_laptop = false
	is_using_laptop = false

	sprite.scale = NORMAL_SCALE
	sprite.play("idle")

	print("PLAYER: Laptop interaction finished.")


# ============================================================
# ESP32 INPUT
# ============================================================

func _unhandled_key_input(event: InputEvent) -> void:
	if is_captured:
		return

	if not event is InputEventKey:
		return

	if not event.pressed or event.echo:
		return

	if event.keycode == KEY_G:
		toggle_esp32()


func toggle_esp32() -> void:
	if is_captured:
		return

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
	if (
		is_captured
		or is_equipping_esp32
		or is_using_esp32
		or is_equipping_laptop
		or is_using_laptop
	):
		return

	if not has_animation_frames("esp32_equip"):
		push_warning("Animation esp32_equip not found.")
		return

	if esp32_controller == null:
		push_warning("ESP32Controller not found.")
		return

	is_equipping_esp32 = true

	# ESP32 does not interrupt player movement.
	sprite.scale = ESP32_SCALE

	equipment_generation += 1
	var current_generation := equipment_generation

	sprite.play("esp32_equip")
	sprite.set_frame_and_progress(0, 0.0)

	print("PLAYER: Equipping ESP32 while moving...")

	await sprite.animation_finished

	# Ignore an animation invalidated by capture or respawn.
	if current_generation != equipment_generation:
		return

	if is_captured:
		return

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

	print("PLAYER: ESP32 equipped. Movement enabled.")


func finish_esp32_interaction() -> void:
	if is_captured:
		return

	equipment_generation += 1

	if esp32_controller != null:
		esp32_controller.set_equipped(false)

	is_equipping_esp32 = false
	is_using_esp32 = false

	sprite.scale = NORMAL_SCALE
	update_animation()

	print("PLAYER: ESP32 stored.")


# ============================================================
# CAPTURE SYSTEM
# ============================================================

func capture() -> void:
	if is_captured:
		return

	is_captured = true
	velocity = Vector2.ZERO

	# Invalidate pending equipment animations.
	equipment_generation += 1

	# Cancel equipment states.
	is_equipping_laptop = false
	is_using_laptop = false

	is_equipping_esp32 = false
	is_using_esp32 = false

	if esp32_controller != null:
		esp32_controller.set_equipped(false)

	# Restore normal appearance.
	sprite.scale = NORMAL_SCALE
	sprite.stop()

	print("PLAYER CAPTURED")


# ============================================================
# RESPAWN SYSTEM
# ============================================================

func respawn(respawn_position: Vector2) -> void:
	# Keep movement locked while restoring the player.
	is_captured = true

	# Invalidate pending equipment animations.
	equipment_generation += 1

	# Reset movement.
	velocity = Vector2.ZERO

	# Reset laptop state.
	is_equipping_laptop = false
	is_using_laptop = false

	# Reset ESP32 state.
	is_equipping_esp32 = false
	is_using_esp32 = false

	if esp32_controller != null:
		esp32_controller.set_equipped(false)

	# Restore normal appearance.
	sprite.scale = NORMAL_SCALE
	sprite.flip_h = false

	# Return to the last checkpoint.
	global_position = respawn_position

	# Restore the idle animation.
	sprite.play("idle")

	# Unlock movement.
	is_captured = false

	print("PLAYER RESPAWNED AT: ", respawn_position)