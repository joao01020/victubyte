extends "res://scenes/victu_os/ui/ui_theme.gd"

const PANEL := Color("041611")
const PANEL_ALT := Color("071d17")
const HEADER := Color("09251e")
const BG := Color("020b08")
const GREEN := Color("00ee55")
const TEXT_COLOR := Color("bdffdc")
const MUTED := Color("83b39d")

func _ready() -> void:
    _build_settings(self)

func _build_settings(parent: Control, section: String = "language") -> void:
    for child in parent.get_children():
        parent.remove_child(child)
        child.queue_free()

    var padding: float = 8.0
    var gap: float = 10.0
    var panel_height: float = parent.size.y - padding * 2.0
    var sidebar_width: float = 190.0
    var content_x: float = padding + sidebar_width + gap
    var content_width: float = parent.size.x - content_x - padding

    var sidebar: Panel = _panel(parent, Vector2(padding, padding), Vector2(sidebar_width, panel_height), PANEL, 7)
    _label(sidebar, _tx("Settings"), Vector2(12, 12), Vector2(sidebar_width - 24.0, 30), 18, GREEN)

    var sections: Array[String] = ["appearance", "language", "sound", "system"]
    for index in range(sections.size()):
        var section_id: String = sections[index]
        var section_title: String = _tx(section_id.capitalize())
        var button: Button = _button(sidebar, section_title, Vector2(10, 48 + index * 49), Vector2(sidebar_width - 20.0, 38), func() -> void:
            _build_settings(parent, section_id)
        )
        _apply_sidebar_button_style(button, section == section_id)
        button.add_theme_font_size_override("font_size", 15)

    var content_panel: Panel = _panel(parent, Vector2(content_x, padding), Vector2(content_width, panel_height), BG, 7)
    _label(content_panel, _tx(section.capitalize()), Vector2(18, 14), Vector2(content_width - 36.0, 34), 21, GREEN)

    match section:
        "language":
            _label(content_panel, _tx("Choose language"), Vector2(18, 54), Vector2(content_width - 36.0, 24), 16, MUTED)
            var button_width: float = content_width - 36.0
            var pt_button: Button = _button(content_panel, "Português (Brasil)", Vector2(18, 96), Vector2(button_width, 44), func() -> void:
                context.settings_manager.change_language("pt_BR")
            )
            var en_button: Button = _button(content_panel, "English", Vector2(18, 150), Vector2(button_width, 44), func() -> void:
                context.settings_manager.change_language("en")
            )
            if context.settings_manager.current_locale == "pt_BR":
                pt_button.add_theme_stylebox_override("normal", _style(HEADER, GREEN))
            else:
                en_button.add_theme_stylebox_override("normal", _style(HEADER, GREEN))
            _label(content_panel, _tx("Settings saved"), Vector2(18, panel_height - 58.0), Vector2(content_width - 36.0, 24), 14, MUTED)
        "appearance":
            _label(content_panel, _tx("Active theme") + ": VICTU Green", Vector2(18, 74), Vector2(content_width - 36.0, 28), 17, TEXT_COLOR)
            var appearance_note := _label(content_panel, _tx("Theme fixed"), Vector2(18, 113), Vector2(content_width - 36.0, 54), 14, MUTED)
            appearance_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        "sound":
            _label(content_panel, _tx("Game audio"), Vector2(18, 70), Vector2(content_width - 36.0, 28), 17, TEXT_COLOR)
            var volume_label: Label = _label(content_panel, "%d%%" % roundi(context.settings_manager.settings_volume * 100.0), Vector2(18, 108), Vector2(content_width - 36.0, 24), 18, GREEN)
            var volume_slider: HSlider = HSlider.new()
            content_panel.add_child(volume_slider)
            volume_slider.position = Vector2(18, 146)
            volume_slider.size = Vector2(content_width - 36.0, 26)
            volume_slider.min_value = 0.0
            volume_slider.max_value = 100.0
            volume_slider.step = 1.0
            volume_slider.value = context.settings_manager.settings_volume * 100.0
            volume_slider.value_changed.connect(func(value: float) -> void:
                context.settings_manager.settings_volume = value / 100.0
                volume_label.text = "%d%%" % roundi(value)
                context.settings_manager.apply_audio_volume()
                context.settings_manager.save_settings()
            )
            _label(content_panel, _tx("Settings saved"), Vector2(18, panel_height - 58.0), Vector2(content_width - 36.0, 24), 14, MUTED)
        "system":
            _label(content_panel, "%s: VICTU OS v1.0.1" % _tx("System version"), Vector2(18, 70), Vector2(content_width - 36.0, 28), 17)
            _label(content_panel, "%s: 1280 × 720" % _tx("Display"), Vector2(18, 108), Vector2(content_width - 36.0, 28), 17)
            _label(content_panel, "%s: %s" % [_tx("Logged user"), context.os_state.terminal_username], Vector2(18, 146), Vector2(content_width - 36.0, 28), 17)
