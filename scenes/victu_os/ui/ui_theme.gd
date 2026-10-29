extends Control

# Common view adapter. Desktop owns styling; apps own their layouts and actions.
var context = null

func configure(desktop: Node) -> void:
    context = desktop

func _tx(key: String) -> String:
    return context.settings_manager.tx(key)

func _panel(parent: Node, position_value: Vector2, size_value: Vector2, fill: Color, radius: int = 9) -> Panel:
    return context._panel(parent, position_value, size_value, fill, radius)

func _label(parent: Node, content: String, position_value: Vector2, size_value: Vector2, font_size: int = 17, tint: Color = Color("bdffdc")) -> Label:
    return context._label(parent, content, position_value, size_value, font_size, tint)

func _button(parent: Node, content: String, position_value: Vector2, size_value: Vector2, callback: Callable) -> Button:
    return context._button(parent, content, position_value, size_value, callback)

func _icon(parent: Node, filename: String, fallback: String, position_value: Vector2, size_value: Vector2) -> void:
    context._icon(parent, filename, fallback, position_value, size_value)

func _style(fill: Color, outline: Color = Color("087e49"), radius: int = 9) -> StyleBoxFlat:
    return context._style(fill, outline, radius)

func _apply_sidebar_button_style(button: Button, selected: bool = false) -> void:
    context._apply_sidebar_button_style(button, selected)

func _build_info(parent: Control, heading: String, description: String) -> void:
    _label(parent, heading, Vector2(12, 12), Vector2(690, 38), 23, Color("00ee55"))
    var message: Label = _label(parent, description, Vector2(12, 67), Vector2(710, 270), 18)
    message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
