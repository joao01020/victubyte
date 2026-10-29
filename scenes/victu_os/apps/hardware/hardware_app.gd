extends "res://scenes/victu_os/ui/ui_theme.gd"

func _ready() -> void:
    var description: String = _tx("Hardware info") if context.settings_manager.current_locale == "pt_BR" else "ESP32 modules and electronic experiments will be available in future missions."
    _build_info(self, _tx("HARDWARE"), description)
