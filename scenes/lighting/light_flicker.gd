extends PointLight2D

@export_group("Light Flicker")
@export_range(0.1, 3.0, 0.05) var base_energy: float = 0.85
@export_range(0.0, 0.30, 0.01) var variation: float = 0.10
@export_range(0.0, 1.0, 0.01) var failure_brightness: float = 0.05

@export_group("Failure Timing")
@export_range(0.5, 30.0, 0.5) var min_failure_interval: float = 4.0
@export_range(0.5, 30.0, 0.5) var max_failure_interval: float = 11.0

@export_group("Testing")
@export var test_mode: bool = false

var slow_noise: FastNoiseLite = FastNoiseLite.new()
var fast_noise: FastNoiseLite = FastNoiseLite.new()

var elapsed: float = 0.0
var time_until_failure: float = 0.0
var time_until_toggle: float = 0.0

var flashes_remaining: int = 0
var is_failing: bool = false


func _ready() -> void:
	slow_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	slow_noise.frequency = 0.45
	slow_noise.seed = randi()

	fast_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	fast_noise.frequency = 2.4
	fast_noise.seed = randi()

	elapsed = randf_range(10.0, 1000.0)
	energy = base_energy

	schedule_next_failure()


func _process(delta: float) -> void:
	elapsed += delta

	# Smooth independent fluctuations.
	var movement: float = (
		slow_noise.get_noise_1d(elapsed) * 0.7
		+ fast_noise.get_noise_1d(elapsed) * 0.3
	)

	var target_energy: float = base_energy * (
		1.0 + movement * variation
	)

	# Random power failures.
	if flashes_remaining > 0:
		time_until_toggle -= delta

		if time_until_toggle <= 0.0:
			is_failing = not is_failing
			flashes_remaining -= 1

			if is_failing:
				time_until_toggle = randf_range(0.07, 0.17)
			else:
				time_until_toggle = randf_range(0.09, 0.25)

			if flashes_remaining == 0:
				is_failing = false
				schedule_next_failure()

	else:
		time_until_failure -= delta

		if time_until_failure <= 0.0:
			start_failure()

	# Reduce brightness immediately during a failure.
	if is_failing:
		target_energy *= failure_brightness

	energy = maxf(0.0, target_energy)


func start_failure() -> void:
	is_failing = true
	flashes_remaining = randi_range(2, 6)

	if test_mode:
		time_until_toggle = randf_range(0.12, 0.25)
	else:
		time_until_toggle = randf_range(0.07, 0.17)

	print("Falha elétrica na luminária: ", name)


func schedule_next_failure() -> void:
	if test_mode:
		# Frequent failures for visual testing.
		time_until_failure = randf_range(0.5, 1.5)
	else:
		# Irregular intervals during gameplay.
		var minimum := minf(
			min_failure_interval,
			max_failure_interval
		)
		var maximum := maxf(
			min_failure_interval,
			max_failure_interval
		)

		time_until_failure = randf_range(minimum, maximum)
