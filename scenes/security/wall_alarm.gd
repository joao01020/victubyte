extends Node2D

# ============================================================
# VICTUBYTE - WALL ALARM SYSTEM
# ============================================================

@onready var alarm_sprite: AnimatedSprite2D = get_node_or_null("AnimatedSprite2D")
@onready var alarm_light: PointLight2D = get_node_or_null("PointLight2D")
@onready var alarm_sound: AudioStreamPlayer2D = get_node_or_null("AlarmSound")


# ============================================================
# ALARM LIGHT SETTINGS
# ============================================================

@export_group("Alarm Light")

@export var blink_speed: float = 8.0
@export var minimum_energy: float = 0.2
@export var maximum_energy: float = 3.0


# ============================================================
# ALARM AUDIO SETTINGS
# ============================================================

@export_group("Alarm Audio")

@export var initial_volume_db: float = 0.0
@export var sustained_volume_db: float = -12.0
@export var loud_duration: float = 2.0
@export var fade_duration: float = 1.0


# ============================================================
# ALARM STATE
# ============================================================

var is_active: bool = false

var blink_timer: float = 0.0
var audio_timer: float = 0.0


# ============================================================
# INITIALIZATION
# ============================================================

func _ready() -> void:
	add_to_group("security_alarms")

	if alarm_sprite == null:
		push_warning("WallAlarm: AnimatedSprite2D not found.")

	if alarm_light == null:
		push_warning("WallAlarm: PointLight2D not found.")

	if alarm_sound == null:
		push_warning("WallAlarm: AlarmSound not found.")

	deactivate_alarm()


# ============================================================
# PROCESS
# ============================================================

func _process(delta: float) -> void:
	if not is_active:
		return

	update_alarm_light(delta)
	update_alarm_audio(delta)


# ============================================================
# LIGHT ANIMATION
# ============================================================

func update_alarm_light(delta: float) -> void:
	if alarm_light == null:
		return

	blink_timer += delta * blink_speed

	var intensity: float = (sin(blink_timer) + 1.0) * 0.5

	alarm_light.energy = lerpf(
		minimum_energy,
		maximum_energy,
		intensity
	)


# ============================================================
# AUDIO CONTROL
# ============================================================

func update_alarm_audio(delta: float) -> void:
	if alarm_sound == null:
		return

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


# ============================================================
# ACTIVATE ALARM
# ============================================================

func activate_alarm() -> void:
	if is_active:
		return

	is_active = true

	blink_timer = 0.0
	audio_timer = 0.0

	# Start warning animation.

	if alarm_sprite != null:
		if alarm_sprite.sprite_frames != null:
			if alarm_sprite.sprite_frames.has_animation("alert"):
				alarm_sprite.play("alert")


	# Enable warning light.

	if alarm_light != null:
		alarm_light.enabled = true
		alarm_light.energy = minimum_energy


	# Start alarm audio.

	if alarm_sound != null:
		alarm_sound.volume_db = initial_volume_db

		if alarm_sound.stream != null:
			if not alarm_sound.playing:
				alarm_sound.play()

		else:
			push_warning("WallAlarm: No audio stream assigned.")


	print("WALL ALARM ACTIVATED: ", name)


# ============================================================
# DEACTIVATE ALARM
# ============================================================

func deactivate_alarm() -> void:
	is_active = false

	blink_timer = 0.0
	audio_timer = 0.0


	# Restore idle animation.

	if alarm_sprite != null:
		if alarm_sprite.sprite_frames != null:
			if alarm_sprite.sprite_frames.has_animation("idle"):
				alarm_sprite.play("idle")


	# Disable warning light.

	if alarm_light != null:
		alarm_light.enabled = false
		alarm_light.energy = minimum_energy


	# Stop alarm audio.

	if alarm_sound != null:
		alarm_sound.stop()
		alarm_sound.volume_db = initial_volume_db


	print("WALL ALARM DEACTIVATED: ", name)