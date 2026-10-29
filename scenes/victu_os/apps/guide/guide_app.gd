extends "res://scenes/victu_os/ui/ui_theme.gd"

func _ready() -> void:
    var description: String = _tx("Guide info") if context.settings_manager.current_locale == "pt_BR" else "Your mission notes and downloaded documents will appear here.\n\nThe field guide will evolve as you investigate the laboratory."
    _build_info(self, _tx("FIELD GUIDE"), description)
