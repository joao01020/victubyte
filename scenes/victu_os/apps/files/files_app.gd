extends "res://scenes/victu_os/ui/ui_theme.gd"

const TERMINAL_HOME := "/home/player"
const BG := Color("020b08")
const PANEL := Color("041611")
const PANEL_ALT := Color("071d17")
const HEADER := Color("09251e")
const GREEN := Color("00ee55")
const TEXT_COLOR := Color("bdffdc")
const MUTED := Color("83b39d")

var explorer_path: String = TERMINAL_HOME
var explorer_history: Array[String] = [TERMINAL_HOME]
var explorer_history_index: int = 0
var explorer_status: Label = null

func _ready() -> void:
    _build_files(self)

func _build_files(parent: Control) -> void:
    _render_explorer(parent)

func _clear_explorer(parent: Control) -> void:
    for child in parent.get_children():
        parent.remove_child(child)
        child.queue_free()

func _explorer_navigate(parent: Control, path: String, record_history: bool = true) -> void:
    if not context.file_system.directories.has(path):
        return
    if not context.permission_manager.can_access(path, "x", context.os_state.terminal_username == "root"):
        _show_explorer_notice(parent, _tx("Permission denied") + ": " + path)
        return
    explorer_path = path
    if record_history:
        while explorer_history.size() > explorer_history_index + 1:
            explorer_history.remove_at(explorer_history.size() - 1)
        explorer_history.append(path)
        explorer_history_index = explorer_history.size() - 1
    _render_explorer(parent)

func _explorer_back(parent: Control) -> void:
    if explorer_history_index <= 0:
        return
    explorer_history_index -= 1
    _explorer_navigate(parent, explorer_history[explorer_history_index], false)

func _explorer_forward(parent: Control) -> void:
    if explorer_history_index + 1 >= explorer_history.size():
        return
    explorer_history_index += 1
    _explorer_navigate(parent, explorer_history[explorer_history_index], false)

func _explorer_up(parent: Control) -> void:
    if explorer_path == "/":
        return
    var parent_path: String = explorer_path.get_base_dir()
    if parent_path.is_empty():
        parent_path = "/"
    if context.file_system.directories.has(parent_path):
        _explorer_navigate(parent, parent_path)

func _explorer_home(parent: Control) -> void:
    _explorer_navigate(parent, TERMINAL_HOME)

func _show_explorer_notice(_parent: Control, message: String) -> void:
    if is_instance_valid(explorer_status):
        explorer_status.text = message

func _render_explorer(parent: Control) -> void:
    if not is_instance_valid(parent):
        return
    _clear_explorer(parent)

    # Standard file-manager toolbar, navigation buttons and address bar.
    var toolbar: Panel = _panel(parent, Vector2(0, 0), Vector2(parent.size.x, 48), HEADER, 7)
    _button(toolbar, "‹", Vector2(8, 6), Vector2(38, 36), func() -> void: _explorer_back(parent))
    _button(toolbar, "›", Vector2(50, 6), Vector2(38, 36), func() -> void: _explorer_forward(parent))
    _button(toolbar, "↑", Vector2(92, 6), Vector2(38, 36), func() -> void: _explorer_up(parent))
    _button(toolbar, "⌂", Vector2(134, 6), Vector2(38, 36), func() -> void: _explorer_home(parent))
    var address: LineEdit = LineEdit.new()
    toolbar.add_child(address)
    address.position = Vector2(184, 7)
    address.size = Vector2(474, 34)
    address.text = explorer_path
    address.add_theme_color_override("font_color", TEXT_COLOR)
    address.add_theme_font_size_override("font_size", 15)
    address.add_theme_stylebox_override("normal", _style(PANEL))
    address.text_submitted.connect(func(value: String) -> void:
        var target: String = _explorer_absolute_path(value)
        if context.file_system.directories.has(target):
            _explorer_navigate(parent, target)
        else:
            _show_explorer_notice(parent, _tx("Directory not found") + ": " + target)
    )
    _button(toolbar, "⟳", Vector2(670, 6), Vector2(38, 36), func() -> void: _render_explorer(parent))
    _button(toolbar, "▦", Vector2(710, 6), Vector2(35, 36), func() -> void: _render_explorer(parent))

    # Places sidebar similar to Dolphin's familiar 'Locais' panel.
    var sidebar: Panel = _panel(parent, Vector2(0, 56), Vector2(184, 297), PANEL, 5)
    _label(sidebar, _tx("PLACES"), Vector2(11, 10), Vector2(147, 25), 15, MUTED)
    var places: Array[Dictionary] = [
        {"label": "⌂  " + _tx("Home"), "path": TERMINAL_HOME},
        {"label": "▣  " + _tx("Documents"), "path": TERMINAL_HOME + "/Documents"},
        {"label": "⇩  " + _tx("Downloads"), "path": TERMINAL_HOME + "/Downloads"},
        {"label": "▤  " + _tx("Manual"), "path": TERMINAL_HOME + "/FieldGuide"},
        {"label": "◉  " + _tx("Remote"), "path": "/remote"}
    ]
    for i in range(places.size()):
        var place: Dictionary = places[i]
        var destination: String = str(place["path"])
        var place_button: Button = _button(sidebar, str(place["label"]), Vector2(8, 39 + i * 45), Vector2(168, 39), func() -> void:
            _explorer_navigate(parent, destination)
        )
        _apply_sidebar_button_style(place_button, explorer_path == destination)
        place_button.add_theme_font_size_override("font_size", 14)

    # Icon grid with a scroll area; the list comes from context.file_system.directories.
    var area: Panel = _panel(parent, Vector2(191, 56), Vector2(563, 297), BG, 5)
    var scroll: ScrollContainer = ScrollContainer.new()
    area.add_child(scroll)
    scroll.position = Vector2(6, 8)
    scroll.size = Vector2(551, 278)
    scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    var grid: GridContainer = GridContainer.new()
    scroll.add_child(grid)
    grid.columns = 4
    grid.custom_minimum_size = Vector2(525, 0)
    grid.add_theme_constant_override("h_separation", 6)
    grid.add_theme_constant_override("v_separation", 12)

    var contents: Array = context.file_system.directories.get(explorer_path, [])
    if contents.is_empty():
        _label(area, _tx("This folder is empty"), Vector2(155, 122), Vector2(280, 35), 17, MUTED)
    for entry in contents:
        var entry_name: String = str(entry)
        var full_path: String = explorer_path.path_join(entry_name)
        var is_directory: bool = context.file_system.directories.has(full_path)
        var tile: Button = Button.new()
        grid.add_child(tile)
        tile.custom_minimum_size = Vector2(126, 105)
        tile.text = ""
        tile.add_theme_stylebox_override("normal", _style(BG, BG, 6))
        tile.add_theme_stylebox_override("hover", _style(PANEL_ALT, GREEN, 6))
        tile.add_theme_stylebox_override("pressed", _style(HEADER, GREEN, 6))
        if is_directory:
            _icon(tile, "icon_folder.svg", "▣", Vector2(41, 9), Vector2(44, 42))
        else:
            _icon(tile, "icon_file.svg", "▤", Vector2(41, 9), Vector2(44, 42))
        var file_label: Label = _label(tile, entry_name, Vector2(4, 58), Vector2(118, 44), 13, TEXT_COLOR)
        file_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        file_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        file_label.max_lines_visible = 2
        tile.pressed.connect(func() -> void:
            if is_directory:
                _explorer_navigate(parent, full_path)
            else:
                _explorer_open_file(parent, full_path)
        )

    explorer_status = _label(parent, "%d %s    •    %s" % [contents.size(), _tx("Items"), explorer_path], Vector2(6, 361), Vector2(744, 27), 14, MUTED)

func _explorer_absolute_path(raw_path: String) -> String:
    var value: String = raw_path.strip_edges()
    if value == "~":
        return TERMINAL_HOME
    if value.begins_with("~/"):
        value = TERMINAL_HOME + value.substr(1)
    elif not value.begins_with("/"):
        value = explorer_path.path_join(value)
    var segments: PackedStringArray = PackedStringArray()
    for segment in value.split("/", false):
        if segment == ".":
            continue
        if segment == "..":
            if not segments.is_empty():
                segments.remove_at(segments.size() - 1)
        else:
            segments.append(segment)
    return "/" + "/".join(segments)

func _explorer_open_file(parent: Control, path: String) -> void:
    _clear_explorer(parent)
    var toolbar: Panel = _panel(parent, Vector2.ZERO, Vector2(754, 48), HEADER)
    _button(toolbar, "‹  " + _tx("Back"), Vector2(8, 6), Vector2(112, 35), func() -> void: _render_explorer(parent))
    _label(toolbar, path.get_file(), Vector2(136, 10), Vector2(588, 27), 18, GREEN)
    var text_view: TextEdit = TextEdit.new()
    parent.add_child(text_view)
    text_view.position = Vector2(10, 62)
    text_view.size = Vector2(733, 285)
    text_view.text = str(context.file_system.contents.get(path, _tx("Unable to open file.")))
    text_view.editable = false
    text_view.add_theme_color_override("font_color", TEXT_COLOR)
    text_view.add_theme_font_size_override("font_size", 17)
    text_view.add_theme_stylebox_override("normal", _style(BG))
    explorer_status = _label(parent, _tx("FILE") + "    •    " + path, Vector2(6, 360), Vector2(736, 27), 14, MUTED)
