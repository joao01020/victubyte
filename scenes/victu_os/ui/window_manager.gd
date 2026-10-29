extends Node

const WINDOW_SCENE := preload("res://scenes/victu_os/ui/app_window.tscn")
const WINDOW_SIZE := Vector2(790.0, 470.0)
const PANEL_ALT := Color("071d17")
const BORDER := Color("087e49")
const HEADER := Color("09251e")
const GREEN := Color("00ee55")
const MUTED := Color("83b39d")
const BASE_SIZE := Vector2(1280.0, 720.0)
const WINDOW_ORIGIN := Vector2(245.0, 135.0)

const APP_SCENES := {
    "terminal": preload("res://scenes/victu_os/apps/terminal/terminal_app.tscn"),
    "files": preload("res://scenes/victu_os/apps/files/files_app.tscn"),
    "network": preload("res://scenes/victu_os/apps/network/network_app.tscn"),
    "cameras": preload("res://scenes/victu_os/apps/cameras/cameras_app.tscn"),
    "settings": preload("res://scenes/victu_os/apps/settings/settings_app.tscn"),
    "guide": preload("res://scenes/victu_os/apps/guide/guide_app.tscn"),
    "hardware": preload("res://scenes/victu_os/apps/hardware/hardware_app.tscn")
}

var host = null
var windows: Dictionary = {}
var minimized: Dictionary = {}
var drag_window: Panel = null

func setup(desktop: Node) -> void:
    host = desktop

func open_app(app_id: String) -> void:
    if windows.has(app_id) and is_instance_valid(windows[app_id]):
        var existing: Control = windows[app_id]
        existing.show()
        minimized[app_id] = false
        host.window_layer.move_child(existing, host.window_layer.get_child_count() - 1)
        refresh_taskbar()
        return
    if not APP_SCENES.has(app_id):
        push_warning("VICTU OS: Unknown app: " + app_id)
        return
    var window_offset: float = float(windows.size() % 5) * 25.0
    var window: Panel = WINDOW_SCENE.instantiate() as Panel
    host.window_layer.add_child(window)
    window.position = WINDOW_ORIGIN + Vector2(window_offset, window_offset)
    window.size = WINDOW_SIZE
    window.mouse_filter = Control.MOUSE_FILTER_STOP
    var window_style: StyleBoxFlat = host._style(PANEL_ALT, BORDER, 9)
    window_style.shadow_color = Color(0.0, 0.0, 0.0, 0.95)
    window_style.shadow_size = 12
    window_style.shadow_offset = Vector2.ZERO
    window.add_theme_stylebox_override("panel", window_style)
    windows[app_id] = window
    minimized[app_id] = false

    var title_bar: Panel = host._panel(window, Vector2.ZERO, Vector2(WINDOW_SIZE.x, 46.0), HEADER, 8)
    title_bar.mouse_filter = Control.MOUSE_FILTER_STOP
    title_bar.gui_input.connect(func(event: InputEvent) -> void: _on_title_bar_input(event, window))
    var title_label: Label = host._label(title_bar, host._app_title(app_id), Vector2(18, 10), Vector2(650, 29), 20, GREEN)
    title_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
    host._button(title_bar, "—", Vector2(692, 5), Vector2(42, 35), func() -> void: minimize_app(app_id))
    host._button(title_bar, "×", Vector2(741, 5), Vector2(40, 35), func() -> void: close_app(app_id))

    var app: Control = APP_SCENES[app_id].instantiate() as Control
    app.configure(host)
    app.position = Vector2(18, 60)
    app.size = Vector2(754, 390)
    window.add_child(app)
    refresh_taskbar()

func close_app(app_id: String) -> void:
    if not windows.has(app_id):
        return
    var window: Control = windows[app_id]
    windows.erase(app_id)
    minimized.erase(app_id)
    if is_instance_valid(window):
        window.queue_free()
    refresh_taskbar()

func minimize_app(app_id: String) -> void:
    if not windows.has(app_id):
        return
    var window: Control = windows[app_id]
    window.hide()
    minimized[app_id] = true
    refresh_taskbar()

func close_all() -> void:
    for app_id in windows.keys():
        var window: Control = windows[app_id]
        if is_instance_valid(window):
            window.queue_free()
    windows.clear()
    minimized.clear()
    drag_window = null
    refresh_taskbar()

func refresh_taskbar() -> void:
    if not is_instance_valid(host.taskbar_apps):
        return
    for child in host.taskbar_apps.get_children():
        child.queue_free()
    for app_id in windows.keys():
        var shortcut: Button = Button.new()
        shortcut.text = host._app_title(str(app_id))
        shortcut.clip_text = true
        shortcut.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
        shortcut.custom_minimum_size = Vector2(124, 36)
        shortcut.add_theme_color_override("font_color", GREEN if not minimized.get(app_id, false) else MUTED)
        shortcut.add_theme_stylebox_override("normal", host._style(PANEL_ALT))
        shortcut.pressed.connect(func() -> void: open_app(str(app_id)))
        host.taskbar_apps.add_child(shortcut)

func _on_title_bar_input(event: InputEvent, window: Panel) -> void:
    if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
        if event.pressed:
            drag_window = window
            host.window_layer.move_child(window, host.window_layer.get_child_count() - 1)
        else:
            drag_window = null
    elif event is InputEventMouseMotion and drag_window == window:
        var scale_factor: float = maxf(host.canvas.scale.x, 0.001)
        var mouse_motion: InputEventMouseMotion = event as InputEventMouseMotion
        var next_position: Vector2 = window.position + mouse_motion.relative / scale_factor
        window.position.x = clampf(next_position.x, 0.0, BASE_SIZE.x - window.size.x)
        window.position.y = clampf(next_position.y, 78.0, 645.0 - window.size.y)
