extends Node2D

@export_group("Spark Timing")
@export var min_interval: float = 2.0
@export var max_interval: float = 6.0

@export_group("Spark Settings")
@export var enabled_sparks: bool = true
@export var spark_count: int = 18

@export_group("Testing")
@export var test_mode: bool = true

@onready var sparks: CPUParticles2D = $Sparks

var burst_timer: Timer


func _ready() -> void:
	sparks.visible = true
	sparks.amount = spark_count
	sparks.lifetime = 0.45
	sparks.one_shot = true
	sparks.explosiveness = 1.0
	sparks.emitting = false

	# Preserve the texture configured in the editor.
	sparks.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	# Keep the effect visible during testing.
	sparks.z_index = 3 if test_mode else -2

	burst_timer = Timer.new()
	burst_timer.one_shot = true
	add_child(burst_timer)

	burst_timer.timeout.connect(_emit_sparks)

	if enabled_sparks:
		_schedule_next_burst()

	print("Sistema de faíscas inicializado.")


func _schedule_next_burst() -> void:
	var minimum: float = maxf(
		0.1,
		minf(min_interval, max_interval)
	)

	var maximum: float = maxf(
		minimum,
		max_interval
	)

	var delay: float = 0.7 if test_mode else randf_range(
		minimum,
		maximum
	)

	burst_timer.start(delay)


func _emit_sparks() -> void:
	if not enabled_sparks:
		return

	sparks.restart()
	sparks.emitting = true

	if test_mode:
		print("Faíscas emitidas: ", global_position)

	_schedule_next_burst()
