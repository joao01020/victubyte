extends Area2D

signal access_granted

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var interaction_label: Label = $InteractionLabel

var player_near := false
var unlocked := false
var busy := false


func _ready() -> void:
    interaction_label.hide()
    sprite.play("idle")

    body_entered.connect(_on_body_entered)
    body_exited.connect(_on_body_exited)


func _unhandled_input(event: InputEvent) -> void:
    if not player_near or busy or unlocked:
        return

    if event.is_action_pressed("interact") and not event.is_echo():
        get_viewport().set_input_as_handled()
        start_access()


func start_access() -> void:
    busy = true
    interaction_label.hide()

    sprite.play("interacting")
    await sprite.animation_finished

    sprite.play("processing")
    await sprite.animation_finished

    sprite.play("unlocked")
    await sprite.animation_finished

    unlocked = true
    busy = false

    access_granted.emit()


func _on_body_entered(body: Node2D) -> void:
    if body is CharacterBody2D:
        player_near = true

        if not unlocked and not busy:
            interaction_label.show()


func _on_body_exited(body: Node2D) -> void:
    if body is CharacterBody2D:
        player_near = false
        interaction_label.hide()
