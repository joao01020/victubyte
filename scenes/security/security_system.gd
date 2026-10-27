extends Node

signal alarm_triggered(source: Node)
signal alarm_cleared

@export var alarm_duration: float = 15.0

var is_alarm_active: bool = false
var alarm_timer: float = 0.0


func _ready() -> void:
    call_deferred("connect_security_cameras")


func connect_security_cameras() -> void:
    for camera in get_tree().get_nodes_in_group("security_cameras"):
        if not camera.has_signal("player_detected"):
            continue

        camera.connect(
            "player_detected",
            _on_camera_detected.bind(camera)
        )

        print("SECURITY CAMERA CONNECTED: ", camera.name)


func _on_camera_detected(camera: Node) -> void:
    print("CAMERA DETECTED PLAYER: ", camera.name)
    activate_alarm(camera)


func activate_alarm(source: Node = null) -> void:
    alarm_timer = alarm_duration

    if is_alarm_active:
        return

    is_alarm_active = true

    for alarm in get_tree().get_nodes_in_group("security_alarms"):
        if alarm.has_method("activate_alarm"):
            alarm.activate_alarm()

    alarm_triggered.emit(source)

    print("SECURITY ALERT ACTIVATED")


func _process(delta: float) -> void:
    if not is_alarm_active:
        return

    alarm_timer -= delta

    if alarm_timer <= 0.0:
        deactivate_alarm()


func deactivate_alarm() -> void:
    if not is_alarm_active:
        return

    is_alarm_active = false
    alarm_timer = 0.0

    for alarm in get_tree().get_nodes_in_group("security_alarms"):
        if alarm.has_method("deactivate_alarm"):
            alarm.deactivate_alarm()

    alarm_cleared.emit()

    print("SECURITY ALERT CLEARED")