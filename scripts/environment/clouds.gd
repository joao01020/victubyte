extends Node2D

# ============================================================
# VICTUBYTE - SIMPLE CLOUD SYSTEM
# ============================================================

@export_group("Cloud Movement")
@export var cloud_speed: float = 15.0
@export var movement_enabled: bool = true

@export_group("Cloud Settings")
@export var spawn_delay: float = 3.0
@export var spawn_padding: float = 30.0

@export_group("Cloud Optimization")
@export var hide_outside_camera: bool = true

var clouds: Array[Sprite2D] = []
var active_cloud: Sprite2D = null
var camera: Camera2D = null

var spawn_timer: float = 0.0
var random_generator: RandomNumberGenerator = RandomNumberGenerator.new()


func _ready() -> void:
	random_generator.randomize()

	camera = get_viewport().get_camera_2d()

	# Register and hide all clouds.
	for child in get_children():
		if child is Sprite2D:
			var cloud: Sprite2D = child as Sprite2D

			clouds.append(cloud)
			cloud.visible = false

	spawn_timer = 1.0


func _process(delta: float) -> void:
	if camera == null or not is_instance_valid(camera):
		camera = get_viewport().get_camera_2d()

	if camera == null:
		return

	if not movement_enabled:
		return

	# Wait before spawning another cloud.
	if active_cloud == null:
		spawn_timer -= delta

		if spawn_timer <= 0.0:
			spawn_cloud()

		return

	update_cloud(delta)


# ============================================================
# CAMERA
# ============================================================

func get_camera_left() -> float:
	var viewport_width: float = get_viewport_rect().size.x

	var visible_width: float = (
		viewport_width
		/ maxf(absf(camera.zoom.x), 0.001)
	)

	return (
		camera.get_screen_center_position().x
		- visible_width / 2.0
	)


func get_camera_right() -> float:
	var viewport_width: float = get_viewport_rect().size.x

	var visible_width: float = (
		viewport_width
		/ maxf(absf(camera.zoom.x), 0.001)
	)

	return (
		camera.get_screen_center_position().x
		+ visible_width / 2.0
	)


# ============================================================
# CLOUD DIMENSIONS
# ============================================================

func get_cloud_half_width(cloud: Sprite2D) -> float:
	if cloud.texture == null:
		return 0.0

	return (
		float(cloud.texture.get_width())
		* absf(cloud.global_scale.x)
		* 0.5
	)


# ============================================================
# CLOUD SPAWNING
# ============================================================

func spawn_cloud() -> void:
	if clouds.is_empty():
		return

	var available_clouds: Array[Sprite2D] = []

	for cloud in clouds:
		if cloud.texture != null:
			available_clouds.append(cloud)

	if available_clouds.is_empty():
		return

	var random_index: int = random_generator.randi_range(
		0,
		available_clouds.size() - 1
	)

	active_cloud = available_clouds[random_index]

	var half_width: float = get_cloud_half_width(active_cloud)

	# Keep the cloud's original vertical position.
	active_cloud.global_position.x = (
		get_camera_right()
		+ half_width
		+ spawn_padding
	)

	active_cloud.visible = false


# ============================================================
# CLOUD MOVEMENT
# ============================================================

func update_cloud(delta: float) -> void:
	if active_cloud == null:
		return

	var half_width: float = get_cloud_half_width(active_cloud)

	# Move cloud from right to left.
	active_cloud.global_position.x -= cloud_speed * delta

	var cloud_left: float = (
		active_cloud.global_position.x - half_width
	)

	var cloud_right: float = (
		active_cloud.global_position.x + half_width
	)

	var camera_left: float = get_camera_left()
	var camera_right: float = get_camera_right()

	# Cloud has completely left the camera.
	if cloud_right < camera_left:
		deactivate_cloud()
		return

	# Render only when inside the camera.
	if hide_outside_camera:
		active_cloud.visible = (
			cloud_right >= camera_left
			and cloud_left <= camera_right
		)
	else:
		active_cloud.visible = true


# ============================================================
# CLOUD DEACTIVATION
# ============================================================

func deactivate_cloud() -> void:
	if active_cloud != null:
		active_cloud.visible = false

	active_cloud = null
	spawn_timer = maxf(spawn_delay, 0.0)
