extends Node2D

@export_group("Movement")
@export_range(1.0, 1000.0, 1.0) var move_speed: float = 95.0
@export_range(1.0, 2000.0, 1.0) var acceleration: float = 350.0
@export_range(0.0, 1000.0, 1.0) var initial_speed: float = 35.0
@export_range(0.1, 3.0, 0.05) var animation_speed_scale: float = 1.25

@export_group("Appearance")
@export_range(0.0, 30.0, 0.1) var initial_delay: float = 0.3
@export var repeat_enabled: bool = false
@export_range(0.0, 300.0, 0.1) var min_repeat_delay: float = 15.0
@export_range(0.0, 300.0, 0.1) var max_repeat_delay: float = 30.0

@export_group("Camera Detection")
@export_range(0.0, 0.45, 0.01) var edge_margin_ratio: float = 0.1
@export var debug_messages: bool = true

@onready var animated_sprite: AnimatedSprite2D = get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
@onready var start_point: Marker2D = get_node_or_null("StartPoint") as Marker2D
@onready var end_point: Marker2D = get_node_or_null("EndPoint") as Marker2D

var is_running: bool = false
var has_run: bool = false
var is_waiting: bool = false
var delay_remaining: float = 0.0
var current_speed: float = 0.0
var start_position: Vector2 = Vector2.ZERO
var end_position: Vector2 = Vector2.ZERO
var _was_in_view: bool = false


func _ready() -> void:
	if animated_sprite == null or start_point == null or end_point == null:
		push_error("LaboratoryRat: required children: AnimatedSprite2D, StartPoint, EndPoint.")
		set_process(false)
		return

	animated_sprite.hide()
	animated_sprite.stop()
	_update_route()

	if animated_sprite.sprite_frames == null or not animated_sprite.sprite_frames.has_animation("run"):
		push_error("LaboratoryRat: AnimatedSprite2D needs a 'run' animation.")
		set_process(false)
		return

	if is_equal_approx(start_position.x, end_position.x):
		push_warning("LaboratoryRat: StartPoint and EndPoint have the same global X; move EndPoint horizontally.")

	if debug_messages:
		print("RAT: ready | start=", start_position, " | end=", end_position)


func _process(delta: float) -> void:
	if is_running:
		current_speed = move_toward(current_speed, move_speed, acceleration * delta)

		animated_sprite.global_position = animated_sprite.global_position.move_toward(
			end_position,
			current_speed * delta
		)

		if animated_sprite.global_position.distance_to(end_position) <= 0.6:
			_finish_running()
		return

	if has_run and not repeat_enabled:
		return

	var visible_now: bool = _is_start_point_on_camera()

	if visible_now and not _was_in_view and debug_messages:
		print("RAT: StartPoint entered camera view")

	_was_in_view = visible_now

	if not visible_now:
		return

	if not is_waiting:
		is_waiting = true

		delay_remaining = initial_delay if not has_run else randf_range(
			minf(min_repeat_delay, max_repeat_delay),
			maxf(min_repeat_delay, max_repeat_delay)
		)

	delay_remaining -= delta

	if delay_remaining <= 0.0:
		is_waiting = false
		_start_running()


func _is_start_point_on_camera() -> bool:
	var screen_position: Vector2 = get_viewport().get_canvas_transform() * start_point.global_position
	var viewport_rect: Rect2 = get_viewport().get_visible_rect()
	var margin: Vector2 = viewport_rect.size * edge_margin_ratio

	var inner_rect: Rect2 = Rect2(
		viewport_rect.position + margin,
		viewport_rect.size - margin * 2.0
	)

	return inner_rect.has_point(screen_position)


func _update_route() -> void:
	start_position = start_point.global_position

	end_position = Vector2(
		end_point.global_position.x,
		start_position.y
	)


func _start_running() -> void:
	if is_running or not is_inside_tree():
		return

	_update_route()

	if is_equal_approx(start_position.x, end_position.x):
		push_warning("LaboratoryRat: move EndPoint left or right from StartPoint.")
		return

	current_speed = minf(initial_speed, move_speed)

	animated_sprite.global_position = start_position
	animated_sprite.flip_h = end_position.x < start_position.x
	animated_sprite.speed_scale = animation_speed_scale

	animated_sprite.show()
	animated_sprite.play("run")

	is_running = true
	has_run = true

	if debug_messages:
		print("RAT: running | start=", start_position, " | end=", end_position)


func _finish_running() -> void:
	is_running = false
	current_speed = 0.0

	animated_sprite.stop()
	animated_sprite.hide()

	if debug_messages:
		print("RAT: finished")
