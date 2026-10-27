extends CharacterBody2D

# ============================================================
# VICTUBYTE - BYTE SECURITY AGENT
# ============================================================

signal capture_started
signal capture_completed

@export_category("Activation")
@export var activation_camera: Node2D

@export_category("Target")
@export var player: CharacterBody2D

@export_category("Spawn")
@export var spawn_points: Array[Marker2D] = []
@export var minimum_spawn_distance: float = 200.0
@export var spawn_clearance: float = 8.0
@export_flags_2d_physics var spawn_collision_mask: int = 1

@export_category("Movement")
@export var movement_speed: float = 115.0
@export var acceleration: float = 700.0
@export var stopping_distance: float = 18.0
@export var gravity: float = 850.0

@export_category("Capture")
@export var capture_duration: float = 1.5

@export_category("Debug")
@export var enable_debug: bool = false

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var body_collision: CollisionShape2D = $CollisionShape2D
@onready var capture_area: Area2D = $CaptureArea

var is_active: bool = false
var is_spawning: bool = false
var is_capturing: bool = false

var random_generator: RandomNumberGenerator = RandomNumberGenerator.new()
var debug_timer: float = 0.0
var capture_sequence_id: int = 0


# ============================================================
# INITIALIZATION
# ============================================================

func _ready() -> void:
	random_generator.randomize()
	capture_area.body_entered.connect(_on_capture_area_body_entered)
	deactivate_agent()

	if not is_instance_valid(player):
		push_warning("BYTE: Player not assigned.")

	if activation_camera == null:
		push_warning("BYTE: Activation camera not assigned.")
		return

	if not activation_camera.has_signal("player_detected"):
		push_error("BYTE: Camera detection signal not found.")
		return

	var detection_callback: Callable = Callable(self, "_on_camera_player_detected")

	if not activation_camera.is_connected("player_detected", detection_callback):
		activation_camera.connect("player_detected", detection_callback)

	print("BYTE: Security agent initialized.")
	print("BYTE: Connected to ", activation_camera.name)


# ============================================================
# CAMERA DETECTION
# ============================================================

func _on_camera_player_detected() -> void:
	if is_active or is_spawning or is_capturing:
		return

	is_spawning = true
	print("BYTE: Alarm received.")
	print("BYTE: Immediate deployment requested.")
	call_deferred("_deploy_agent")


func _deploy_agent() -> void:
	if not is_inside_tree() or not is_spawning:
		return

	if not is_instance_valid(player):
		is_spawning = false
		push_warning("BYTE: Player target unavailable.")
		return

	var selected_position: Vector2 = find_safe_spawn_position()

	if selected_position == Vector2.INF:
		get_tree().create_timer(0.5).timeout.connect(_deploy_agent)
		return

	global_position = selected_position
	is_spawning = false
	activate_agent()


# ============================================================
# SPAWN SELECTION
# ============================================================

func find_safe_spawn_position() -> Vector2:
	var offscreen_points: Array[Marker2D] = []

	for point: Marker2D in spawn_points:
		if not is_instance_valid(point) or not point.is_inside_tree():
			continue

		if not is_position_on_screen(point.global_position):
			offscreen_points.append(point)

	if offscreen_points.is_empty():
		return Vector2.INF

	var index: int = random_generator.randi_range(0, offscreen_points.size() - 1)
	return offscreen_points[index].global_position


func is_position_on_screen(world_position: Vector2) -> bool:
	var viewport_size: Vector2 = get_viewport_rect().size
	var screen_position: Vector2 = get_viewport().get_canvas_transform() * world_position
	var margin: float = 64.0
	var screen_rect: Rect2 = Rect2(
		Vector2(-margin, -margin),
		viewport_size + Vector2.ONE * margin * 2.0
	)
	return screen_rect.has_point(screen_position)


# ============================================================
# PHYSICS
# ============================================================

func _physics_process(delta: float) -> void:
	if not is_active:
		return

	if is_capturing:
		velocity = Vector2.ZERO
		return

	if not is_on_floor():
		velocity.y += gravity * delta
	elif velocity.y > 0.0:
		velocity.y = 0.0

	if is_instance_valid(player):
		chase_player(delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, acceleration * delta)

	move_and_slide()
	update_animation()

	if enable_debug:
		debug_timer += delta
		if debug_timer >= 1.0:
			debug_timer = 0.0
			var player_position_text: String = "NULL"
			if is_instance_valid(player):
				player_position_text = str(player.global_position)
			print(
				"BYTE DEBUG | Position: ", global_position,
				" | Velocity: ", velocity,
				" | Player: ", player_position_text,
				" | On floor: ", is_on_floor(),
				" | Visible: ", is_visible_in_tree()
			)


# ============================================================
# PLAYER PURSUIT
# ============================================================

func chase_player(delta: float) -> void:
	if not is_instance_valid(player):
		return

	var distance: float = player.global_position.x - global_position.x

	if absf(distance) <= stopping_distance:
		velocity.x = move_toward(velocity.x, 0.0, acceleration * delta)
		return

	var direction: float = signf(distance)
	velocity.x = move_toward(
		velocity.x,
		direction * movement_speed,
		acceleration * delta
	)
	sprite.flip_h = direction < 0.0


# ============================================================
# ANIMATION
# ============================================================

func update_animation() -> void:
	if not is_active or is_capturing:
		return

	if sprite.sprite_frames == null:
		return

	if not sprite.sprite_frames.has_animation("run_flashlight"):
		return

	if sprite.animation != "run_flashlight" or not sprite.is_playing():
		sprite.play("run_flashlight")


# ============================================================
# CAPTURE SYSTEM
# ============================================================

func _on_capture_area_body_entered(body: Node2D) -> void:
	if not is_active or is_capturing:
		return

	if body != player:
		return

	start_capture()


func start_capture() -> void:
	if not is_active or is_capturing or not is_instance_valid(player):
		return

	is_capturing = true
	capture_sequence_id += 1
	var current_sequence: int = capture_sequence_id

	velocity = Vector2.ZERO
	sprite.stop()
	capture_area.set_deferred("monitoring", false)

	# Temporary player lock. The containment scene will replace this step.
	player.velocity = Vector2.ZERO
	player.set_physics_process(false)
	player.set_process_input(false)
	player.set_process_unhandled_input(false)

	print("BYTE: Capture started.")
	capture_started.emit()

	await get_tree().create_timer(capture_duration).timeout

	if not is_inside_tree() or not is_capturing:
		return

	if current_sequence != capture_sequence_id:
		return

	print("BYTE: Capture completed.")
	capture_completed.emit()


# ============================================================
# ACTIVATION
# ============================================================

func activate_agent() -> void:
	if is_active:
		return

	is_active = true
	is_spawning = false
	is_capturing = false

	show()
	sprite.show()
	sprite.modulate.a = 1.0

	body_collision.set_deferred("disabled", false)
	capture_area.set_deferred("monitoring", true)

	velocity = Vector2.ZERO
	debug_timer = 0.0
	update_animation()

	print("BYTE: Security agent activated.")
	print("BYTE: Spawn position: ", global_position)
	print("BYTE: Starting player pursuit.")


# ============================================================
# DEACTIVATION
# ============================================================

func deactivate_agent() -> void:
	is_active = false
	is_spawning = false
	is_capturing = false
	capture_sequence_id += 1

	hide()
	body_collision.set_deferred("disabled", true)
	capture_area.set_deferred("monitoring", false)
	velocity = Vector2.ZERO
	sprite.stop()

	print("BYTE: Security agent inactive.")


# ============================================================
# STATUS
# ============================================================

func is_agent_active() -> bool:
	return is_active
