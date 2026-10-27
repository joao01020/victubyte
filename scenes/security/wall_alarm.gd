extends Node2D

@onready var alarm_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var alarm_light: PointLight2D = $PointLight2D
@onready var alarm_sound: AudioStreamPlayer2D = $AlarmSound

@export_group("Alarm Light")
@export var blink_speed: float = 8.0
@export var minimum_energy: float = 0.2
@export var maximum_energy: float = 3.0

@export_group("Alarm Audio")
@export var initial_volume_db: float = 0.0
@export var sustained_volume_db: float = -12.0
@export var loud_duration: float = 2.0
@export var fade_duration: float = 1.0

var is_active: bool = false
var blink_timer: float = 0.0
var audio_timer: float = 0.0


func _ready() -> void:
	add_to_group("security_alarms")
	deactivate_alarm()


func _process(delta: float) -> void:
	if not is_active:
		return

	# Pulse the red warning light.
	blink_timer += delta * blink_speed

	var intensity: float = (sin(blink_timer) + 1.0) * 0.5

	alarm_light.energy = lerpf(
		minimum_energy,
		maximum_energy,
		intensity
	)

	# Keep the siren loud initially, then reduce its volume.
	audio_timer += delta

	if audio_timer <= loud_duration:
		alarm_sound.volume_db = initial_volume_db
	else:
		var fade_progress: float = clampf(
			(audio_timer - loud_duration) / maxf(fade_duration, 0.01),
			0.0,
			1.0
		)

		alarm_sound.volume_db = lerpf(
			initial_volume_db,
			sustained_volume_db,
			fade_progress
		)


func activate_alarm() -> void:
	if is_active:
		return

	is_active = true
	blink_timer = 0.0
	audio_timer = 0.0

	# Start warning animation.
	alarm_sprite.play("alert")

	# Activate red light.
	alarm_light.enabled = true
	alarm_light.energy = minimum_energy

	# Start siren at full volume.
	alarm_sound.volume_db = initial_volume_db

	if alarm_sound.stream != null:
		alarm_sound.play()
	else:
		push_warning("WallAlarm: No audio stream assigned.")

	print("WALL ALARM ACTIVATED")


func deactivate_alarm() -> void:
	is_active = false
	blink_timer = 0.0
	audio_timer = 0.0

	# Restore idle animation.
	alarm_sprite.play("idle")

	# Turn off red light.
	alarm_light.enabled = false
	alarm_light.energy = minimum_energy

	# Stop siren.
	alarm_sound.stop()
	alarm_sound.volume_db = initial_volume_db

	print("WALL ALARM DEACTIVATED")
