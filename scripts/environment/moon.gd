extends Node2D

@export var float_amplitude: float = 3.0
@export var float_speed: float = 0.25

var initial_position: Vector2
var elapsed_time: float = 0.0


func _ready() -> void:
    initial_position = position


func _process(delta: float) -> void:
    elapsed_time += delta

    position.y = initial_position.y + sin(
        elapsed_time * float_speed
    ) * float_amplitude