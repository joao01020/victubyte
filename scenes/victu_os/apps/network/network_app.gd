extends "res://scenes/victu_os/ui/ui_theme.gd"

const PANEL := Color("041611")
const PANEL_ALT := Color("071d17")
const HEADER := Color("09251e")
const BG := Color("020b08")
const GREEN := Color("00ee55")
const TEXT_COLOR := Color("bdffdc")
const MUTED := Color("83b39d")

func _ready() -> void:
    _build_network(self)

func _build_network(parent: Control) -> void:
    _label(parent, _tx("WIRELESS NETWORKS"), Vector2(12, 10), Vector2(470, 38), 24, GREEN)
    _label(parent, _tx("Available connections"), Vector2(12, 51), Vector2(490, 30), 16, MUTED)
    _button(parent, _tx("Refresh"), Vector2(604, 14), Vector2(128, 39), func() -> void:
        if is_instance_valid(parent):
            _refresh_network(parent)
    )
    _panel(parent, Vector2(10, 92), Vector2(730, 226), PANEL)
    for index in range(context.network_manager.networks.size()):
        var network_data: Dictionary = context.network_manager.networks[index]
        var ssid: String = str(network_data["ssid"])
        var strength: int = int(network_data["signal"])
        var row_y: float = 101.0 + float(index) * 70.0
        var selected: bool = context.network_manager.selected_network == ssid
        var row_button: Button = _button(parent, "", Vector2(20, row_y), Vector2(710, 61), func() -> void:
            context.network_manager.selected_network = ssid
            _refresh_network(parent)
            if context.network_manager.connected_network != ssid:
                _show_wifi_password_dialog(parent, ssid)
        )
        if selected:
            row_button.add_theme_stylebox_override("normal", _style(HEADER, GREEN))
        _icon(row_button, "icon_wifi.svg", "W", Vector2(13, 13), Vector2(30, 31))
        _label(row_button, ssid, Vector2(58, 9), Vector2(250, 28), 19, TEXT_COLOR)
        _label(row_button, "%s  ·  %s" % [_tx(str(network_data["quality"])), str(network_data["security"])], Vector2(58, 36), Vector2(290, 20), 13, MUTED)
        _draw_signal_bars(row_button, Vector2(492, 17), strength)
        _label(row_button, _tx("CONNECTED") if context.network_manager.connected_network == ssid else _tx("LOCKED"), Vector2(605, 21), Vector2(102, 24), 13, GREEN if context.network_manager.connected_network == ssid else MUTED)
    if context.network_manager.selected_network.is_empty():
        _label(parent, _tx("Select a network to see its details."), Vector2(14, 334), Vector2(695, 38), 17, MUTED)
    else:
        var chosen: Dictionary = {}
        for entry in context.network_manager.networks:
            if str(entry["ssid"]) == context.network_manager.selected_network:
                chosen = entry
                break
        if not chosen.is_empty():
            _label(parent, _tx("SELECTED") + ": " + context.network_manager.selected_network, Vector2(14, 328), Vector2(695, 28), 17, GREEN)
            var connection_message: String = _tx("CONNECTED") if context.network_manager.connected_network == context.network_manager.selected_network else _tx("Authentication required")
            _label(parent, "%s: %s (%d/5)   |   %s: %s   |   %s" % [_tx("Signal"), _tx(str(chosen["quality"])), int(chosen["signal"]), _tx("Security"), str(chosen["security"]), connection_message], Vector2(14, 359), Vector2(730, 27), 14, MUTED)


# Password prompt stays inside the Network window without changing the desktop.

func _show_wifi_password_dialog(parent: Control, ssid: String) -> void:
    if not is_instance_valid(parent):
        return

    var overlay: Control = Control.new()
    parent.add_child(overlay)
    overlay.position = Vector2.ZERO
    overlay.size = parent.size
    overlay.mouse_filter = Control.MOUSE_FILTER_STOP

    var shade: ColorRect = ColorRect.new()
    overlay.add_child(shade)
    shade.size = parent.size
    shade.color = Color(0.0, 0.0, 0.0, 0.66)
    shade.mouse_filter = Control.MOUSE_FILTER_STOP

    var dialog_width: float = 488.0
    var dialog_height: float = 270.0
    var dialog_x: float = (parent.size.x - dialog_width) * 0.5
    var dialog_y: float = (parent.size.y - dialog_height) * 0.5
    var dialog: Panel = _panel(overlay, Vector2(dialog_x, dialog_y), Vector2(dialog_width, dialog_height), PANEL_ALT, 10)
    dialog.mouse_filter = Control.MOUSE_FILTER_STOP
    _panel(dialog, Vector2.ZERO, Vector2(dialog_width, 44), HEADER, 8)
    _label(dialog, _tx("Wi-Fi password"), Vector2(18, 9), Vector2(405, 28), 20, GREEN)
    _button(dialog, "×", Vector2(439, 6), Vector2(35, 32), func() -> void:
        overlay.queue_free()
    )
    _label(dialog, ssid, Vector2(18, 56), Vector2(450, 30), 19, TEXT_COLOR)
    _label(dialog, _tx("Enter password"), Vector2(18, 91), Vector2(450, 26), 15, MUTED)

    var password_input: LineEdit = LineEdit.new()
    dialog.add_child(password_input)
    password_input.position = Vector2(18, 130)
    password_input.size = Vector2(324, 43)
    password_input.secret = true
    password_input.max_length = 64
    password_input.placeholder_text = _tx("Password")
    password_input.add_theme_color_override("font_color", TEXT_COLOR)
    password_input.add_theme_color_override("caret_color", GREEN)
    password_input.add_theme_font_size_override("font_size", 17)
    password_input.add_theme_stylebox_override("normal", _style(BG))
    password_input.add_theme_stylebox_override("focus", _style(BG, GREEN))

    var show_button: Button = _button(dialog, _tx("Show"), Vector2(351, 130), Vector2(118, 43), func() -> void:
        password_input.secret = not password_input.secret
    )
    show_button.pressed.connect(func() -> void:
        show_button.text = _tx("Show") if password_input.secret else _tx("Hide")
    )

    var error_label: Label = _label(dialog, "", Vector2(18, 179), Vector2(452, 24), 14, Color("ff8585"))
    _button(dialog, _tx("Cancel"), Vector2(218, 215), Vector2(115, 40), func() -> void:
        overlay.queue_free()
    )
    _button(dialog, _tx("Connect"), Vector2(345, 215), Vector2(124, 40), func() -> void:
        _attempt_wifi_connection(parent, overlay, ssid, password_input, error_label)
    )
    password_input.text_submitted.connect(func(_entered_password: String) -> void:
        _attempt_wifi_connection(parent, overlay, ssid, password_input, error_label)
    )
    password_input.call_deferred("grab_focus")

func _attempt_wifi_connection(parent: Control, overlay: Control, ssid: String, password_input: LineEdit, error_label: Label) -> void:
    if not is_instance_valid(parent) or not is_instance_valid(overlay) or not is_instance_valid(password_input):
        return
    var submitted_password: String = password_input.text
    if submitted_password.is_empty():
        error_label.text = _tx("Password required")
        password_input.grab_focus()
        return
    if submitted_password != str(context.network_manager.passwords.get(ssid, "")):
        error_label.text = _tx("Incorrect password")
        password_input.clear()
        password_input.grab_focus()
        return

    password_input.clear()
    context.network_manager.connect_network(ssid, submitted_password)
    _refresh_network(parent)
    # Camera monitors listen for network_changed.

func _draw_signal_bars(parent: Control, position_value: Vector2, strength: int) -> void:
    for index in range(5):
        var bar_height: float = 9.0 + float(index) * 5.0
        var indicator: ColorRect = ColorRect.new()
        parent.add_child(indicator)
        indicator.position = position_value + Vector2(float(index) * 11.0, 30.0 - bar_height)
        indicator.size = Vector2(7.0, bar_height)
        indicator.color = GREEN if index < strength else Color("24513c")
        indicator.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _refresh_network(parent: Control) -> void:
    if not is_instance_valid(parent):
        return
    for child in parent.get_children():
        parent.remove_child(child)
        child.queue_free()
    _build_network(parent)


# The NVR web interface uses an account login. API credentials are for software
# integrations and are not required to sign into the operator console.
