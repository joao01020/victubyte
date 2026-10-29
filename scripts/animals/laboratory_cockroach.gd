extends Node2D

# Attach to LaboratoryCockroach (Node2D).
# Direct children: AnimatedSprite2D, StartPoint, EndPoint.
# SpriteFrames animations: "idle" and "run".
# Route: StartPoint -> run -> pause -> slow walk -> run -> EndPoint.

@export_group("Movement")
@export_range(10.0, 250.0, 1.0) var run_speed: float = 75.0
@export_range(5.0, 150.0, 1.0) var slow_speed: float = 25.0
@export_range(10.0, 800.0, 1.0) var acceleration: float = 180.0
@export_range(10.0, 800.0, 1.0) var deceleration: float = 220.0

@export_group("Behavior")
@export_range(0.0, 5.0, 0.1) var initial_delay: float = 0.3
@export_range(0.05, 0.85, 0.01) var pause_at_progress: float = 0.25
@export_range(0.0, 5.0, 0.1) var pause_duration: float = 0.8
@export_range(0.15, 0.95, 0.01) var resume_normal_at_progress: float = 0.60
@export var hide_when_finished: bool = false

@export_group("Camera Detection")
@export_range(0.0, 0.45, 0.01) var edge_margin_ratio: float = 0.08
@export var pause_when_offscreen: bool = true
@export var debug_messages: bool = false

@onready var animated_sprite: AnimatedSprite2D = get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
@onready var start_point: Marker2D = get_node_or_null("StartPoint") as Marker2D
@onready var end_point: Marker2D = get_node_or_null("EndPoint") as Marker2D

var is_running: bool = false
var has_run: bool = false
var is_waiting: bool = true
var start_position: Vector2 = Vector2.ZERO
var end_position: Vector2 = Vector2.ZERO

var _state: StringName = &"waiting"
var _timer: float = 0.0
var _current_speed: float = 0.0
var _pause_x: float = 0.0
var _resume_x: float = 0.0
var _direction: float = 1.0
var _activated: bool = false


func _ready() -> void:
    if animated_sprite == null or start_point == null or end_point == null:
        push_error("LaboratoryCockroach: missing AnimatedSprite2D, StartPoint or EndPoint.")
        set_process(false)
        return

    if animated_sprite.sprite_frames == null:
        push_error("LaboratoryCockroach: assign SpriteFrames to AnimatedSprite2D.")
        set_process(false)
        return

    if not animated_sprite.sprite_frames.has_animation("idle") or not animated_sprite.sprite_frames.has_animation("run"):
        push_error("LaboratoryCockroach: animations must be named idle and run.")
        set_process(false)
        return

    start_position = start_point.global_position
    end_position = Vector2(end_point.global_position.x, start_position.y)

    if absf(end_position.x - start_position.x) < 2.0:
        push_error("LaboratoryCockroach: StartPoint and EndPoint need different X positions.")
        set_process(false)
        return

    _direction = 1.0 if end_position.x > start_position.x else -1.0
    var pause_progress: float = clampf(pause_at_progress, 0.05, 0.85)
    var resume_progress: float = clampf(resume_normal_at_progress, pause_progress + 0.05, 0.95)
    _pause_x = lerpf(start_position.x, end_position.x, pause_progress)
    _resume_x = lerpf(start_position.x, end_position.x, resume_progress)

    animated_sprite.global_position = start_position
    animated_sprite.flip_h = _direction < 0.0
    animated_sprite.speed_scale = 1.0
    animated_sprite.play("idle")
    animated_sprite.hide()
    _timer = maxf(initial_delay, 0.0)


func _process(delta: float) -> void:
    if _state == &"finished":
        return

    # The camera only triggers the cockroach once. After activation,
    # it completes its route even when the camera moves away.
    if not _activated:
        if not _is_route_on_camera():
            return
        _activated = true
        if debug_messages:
            print("COCKROACH: camera activated route")

    # Optional offscreen pause after activation.
    if pause_when_offscreen and not _is_route_on_camera():
        return

    match _state:
        &"waiting":
            _timer -= delta
            if _timer <= 0.0:
                _start_movement()
        &"running_first":
            _move_to(_pause_x, run_speed, delta, &"pause", true)
        &"pause":
            _timer -= delta
            if _timer <= 0.0:
                _state = &"running_slow"
                _current_speed = 0.0
                is_running = true
                is_waiting = false
                animated_sprite.play("run")
        &"running_slow":
            _move_to(_resume_x, slow_speed, delta, &"running_final", false)
        &"running_final":
            _move_to(end_position.x, run_speed, delta, &"finished", true)


func _start_movement() -> void:
    _state = &"running_first"
    has_run = true
    is_running = true
    is_waiting = false
    _current_speed = 0.0
    animated_sprite.show()
    animated_sprite.play("run")
    if debug_messages:
        print("COCKROACH: movement started")


func _move_to(target_x: float, target_speed: float, delta: float, next_state: StringName, brake_at_end: bool) -> void:
    var remaining: float = absf(target_x - animated_sprite.global_position.x)
    if remaining <= 0.5:
        animated_sprite.global_position.x = target_x
        _enter_state(next_state)
        return

    var desired_speed: float = target_speed
    if brake_at_end:
        var braking_speed: float = sqrt(2.0 * deceleration * remaining)
        desired_speed = minf(target_speed, braking_speed)

    var change_rate: float = acceleration if desired_speed > _current_speed else deceleration
    _current_speed = move_toward(_current_speed, desired_speed, change_rate * delta)

    var movement: float = minf(_current_speed * delta, remaining)
    animated_sprite.global_position.x += _direction * movement
    animated_sprite.speed_scale = clampf(_current_speed / maxf(run_speed, 1.0), 0.3, 1.0)

    if absf(target_x - animated_sprite.global_position.x) <= 0.5:
        animated_sprite.global_position.x = target_x
        _enter_state(next_state)


func _enter_state(next_state: StringName) -> void:
    _state = next_state
    match next_state:
        &"pause":
            _timer = maxf(pause_duration, 0.0)
            _current_speed = 0.0
            is_running = false
            is_waiting = true
            animated_sprite.speed_scale = 1.0
            animated_sprite.play("idle")
        &"running_final":
            # Keep the slow segment's speed and accelerate smoothly.
            animated_sprite.play("run")
        &"finished":
            _current_speed = 0.0
            is_running = false
            is_waiting = false
            animated_sprite.speed_scale = 1.0
            animated_sprite.play("idle")
            if hide_when_finished:
                animated_sprite.hide()
            if debug_messages:
                print("COCKROACH: reached EndPoint")


func _is_route_on_camera() -> bool:
    var canvas_transform: Transform2D = get_viewport().get_canvas_transform()
    var viewport_rect: Rect2 = get_viewport().get_visible_rect()
    var margin: Vector2 = viewport_rect.size * edge_margin_ratio
    var inner_rect: Rect2 = Rect2(
        viewport_rect.position + margin,
        viewport_rect.size - margin * 2.0
    )

    var start_screen: Vector2 = canvas_transform * start_point.global_position
    var end_screen: Vector2 = canvas_transform * end_point.global_position
    var center_screen: Vector2 = (start_screen + end_screen) * 0.5
    var cockroach_screen: Vector2 = canvas_transform * animated_sprite.global_position

    return (
        inner_rect.has_point(start_screen)
        or inner_rect.has_point(end_screen)
        or inner_rect.has_point(center_screen)
        or inner_rect.has_point(cockroach_screen)
    )
