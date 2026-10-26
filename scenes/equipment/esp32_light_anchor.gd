extends Node2D

# ============================================================
# VICTUBYTE — ESP32 LIGHT ANCHOR
# ============================================================

# ============================================================
# CONFIGURATION
# ============================================================

@export var player_sprite: AnimatedSprite2D

# Position of the LED when the player is standing still.
# Coordinates are relative to the Player node.
@export var idle_position: Vector2 = Vector2(11, -2)

# LED position for each frame of esp32_run.
@export var run_positions: Array[Vector2] = [
	Vector2(11, -2),
	Vector2(12, -3),
	Vector2(11, -4),
	Vector2(10, -3),
	Vector2(11, -2),
	Vector2(12, -3),
	Vector2(11, -4),
	Vector2(10, -3)
]

# Global correction for the LED position.
# Adjust this in the Inspector without changing frame positions.
@export var light_offset: Vector2 = Vector2.ZERO

# Mirror the LED position when the player faces left.
@export var mirror_with_player: bool = true

# ============================================================
# LIGHT CONFIGURATION
# ============================================================

const LIGHT_COLOR: Color = Color("#E8FFF1")

const IDLE_ENERGY: float = 0.25
const MIN_JAMMING_ENERGY: float = 0.35
const MAX_JAMMING_ENERGY: float = 0.85
const PULSE_SPEED: float = 7.0

# ============================================================
# NODES
# ============================================================

@onready var esp32_light: PointLight2D = $ESP32Light

@onready var controller: Node2D = (
	get_parent().get_node_or_null("ESP32Controller") as Node2D
)

# ============================================================
# STATE
# ============================================================

var last_animation: StringName = &""
var last_frame: int = -1
var last_flip_h: bool = false

var is_equipped: bool = false
var is_jamming: bool = false

var pulse_time: float = 0.0

# ============================================================
# INITIALIZATION
# ============================================================

func _ready() -> void:
	# Keep the actual light centered on the anchor.
	esp32_light.position = Vector2.ZERO

	esp32_light.color = LIGHT_COLOR
	esp32_light.energy = 0.0
	esp32_light.enabled = false

	if not is_instance_valid(controller):
		push_warning(
			"ESP32LightAnchor: ESP32Controller não encontrado."
		)

	if not is_instance_valid(player_sprite):
		push_warning(
			"ESP32LightAnchor: AnimatedSprite2D não configurado."
		)
		return

	update_light_position()


# ============================================================
# PROCESS
# ============================================================

func _process(delta: float) -> void:
	update_animation_tracking()
	update_light_state(delta)


# ============================================================
# ANIMATION TRACKING
# ============================================================

func update_animation_tracking() -> void:
	if not is_instance_valid(player_sprite):
		return

	var current_animation: StringName = player_sprite.animation
	var current_frame: int = player_sprite.frame
	var current_flip_h: bool = player_sprite.flip_h

	# Update only when the animation, frame or direction changes.
	if (
		current_animation == last_animation
		and current_frame == last_frame
		and current_flip_h == last_flip_h
	):
		return

	last_animation = current_animation
	last_frame = current_frame
	last_flip_h = current_flip_h

	update_light_position()


# ============================================================
# LIGHT POSITION
# ============================================================

func update_light_position() -> void:
	if not is_instance_valid(player_sprite):
		return

	var current_animation: StringName = player_sprite.animation
	var current_frame: int = player_sprite.frame

	var target_position: Vector2 = idle_position

	# --------------------------------------------------------
	# RUN ANIMATION
	# --------------------------------------------------------

	if current_animation == &"esp32_run":
		if not run_positions.is_empty():
			var index: int = clampi(
				current_frame,
				0,
				run_positions.size() - 1
			)

			target_position = run_positions[index]

	# --------------------------------------------------------
	# MIRROR POSITION
	# --------------------------------------------------------

	if mirror_with_player and player_sprite.flip_h:
		target_position.x = - target_position.x

	# --------------------------------------------------------
	# APPLY OFFSET
	# --------------------------------------------------------

	position = target_position + light_offset


# ============================================================
# LIGHT STATE
# ============================================================

func update_light_state(delta: float) -> void:
	if not is_instance_valid(controller):
		disable_light()
		return

	is_equipped = bool(controller.get("is_equipped"))
	is_jamming = bool(controller.get("is_jamming"))

	# --------------------------------------------------------
	# DEVICE STORED
	# --------------------------------------------------------

	if not is_equipped:
		disable_light()
		return

	# --------------------------------------------------------
	# DEVICE EQUIPPED
	# --------------------------------------------------------

	esp32_light.enabled = true

	if not is_jamming:
		pulse_time = 0.0
		esp32_light.energy = IDLE_ENERGY
		return

	# --------------------------------------------------------
	# ACTIVE JAMMING
	# --------------------------------------------------------

	pulse_time += delta * PULSE_SPEED

	var pulse: float = (
		sin(pulse_time) + 1.0
	) * 0.5

	esp32_light.energy = lerpf(
		MIN_JAMMING_ENERGY,
		MAX_JAMMING_ENERGY,
		pulse
	)


# ============================================================
# LIGHT CONTROL
# ============================================================

func disable_light() -> void:
	esp32_light.enabled = false
	esp32_light.energy = 0.0
	pulse_time = 0.0


# ============================================================
# CONTROLLER COMPATIBILITY
# ============================================================

func set_jamming(_active: bool) -> void:
	# The controller state is the source of truth.
	# This method is retained for compatibility.
	pass