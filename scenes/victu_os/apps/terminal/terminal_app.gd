extends "res://scenes/victu_os/ui/ui_theme.gd"

const GREEN := Color("00ee55")
const TEXT_COLOR := Color("bdffdc")
const DEMO_PASSWORD := "victu"
const TERMINAL_USER := "player"
const TERMINAL_HOST := "victu"
const TERMINAL_HOME := "/home/player"
const CommandInterpreter := preload("res://scenes/victu_os/apps/terminal/command_interpreter.gd")

var command_interpreter = CommandInterpreter.new()
var terminal_output: RichTextLabel
var terminal_input: LineEdit
var terminal_scroll: ScrollContainer
var terminal_prompt_label: Label

func _ready() -> void:
    _build_terminal(self)

func _exit_tree() -> void:
    if context != null and is_instance_valid(context):
        context.os_state.terminal_password_pending = false
        context.os_state.terminal_pending_command = ""

func _build_terminal(parent: Control) -> void:
    # A single scrollable terminal surface: history and editable prompt
    # share the same text flow, without a separate command field.
    terminal_scroll = ScrollContainer.new()
    parent.add_child(terminal_scroll)
    terminal_scroll.position = Vector2(8, 8)
    terminal_scroll.size = Vector2(738, 390)
    terminal_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    terminal_scroll.mouse_filter = Control.MOUSE_FILTER_PASS

    var lines := VBoxContainer.new()
    terminal_scroll.add_child(lines)
    lines.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    lines.custom_minimum_size = Vector2(716, 0)
    lines.add_theme_constant_override("separation", 0)

    terminal_output = RichTextLabel.new()
    lines.add_child(terminal_output)
    terminal_output.fit_content = true
    terminal_output.scroll_active = false
    terminal_output.bbcode_enabled = false
    terminal_output.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    terminal_output.add_theme_color_override("default_color", TEXT_COLOR)
    terminal_output.add_theme_font_size_override("normal_font_size", 17)
    terminal_output.add_theme_constant_override("line_separation", 3)
    terminal_output.mouse_filter = Control.MOUSE_FILTER_IGNORE

    var input_row := HBoxContainer.new()
    lines.add_child(input_row)
    input_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    input_row.add_theme_constant_override("separation", 8)

    terminal_prompt_label = Label.new()
    input_row.add_child(terminal_prompt_label)
    terminal_prompt_label.add_theme_color_override("font_color", GREEN)
    terminal_prompt_label.add_theme_font_size_override("font_size", 17)
    terminal_prompt_label.mouse_filter = Control.MOUSE_FILTER_IGNORE

    terminal_input = LineEdit.new()
    input_row.add_child(terminal_input)
    terminal_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    terminal_input.custom_minimum_size = Vector2(60, 28)
    terminal_input.flat = true
    terminal_input.placeholder_text = ""
    terminal_input.caret_blink = true
    terminal_input.add_theme_color_override("font_color", TEXT_COLOR)
    terminal_input.add_theme_color_override("caret_color", GREEN)
    terminal_input.add_theme_font_size_override("font_size", 17)
    for state in ["normal", "focus", "read_only"]:
        terminal_input.add_theme_stylebox_override(state, StyleBoxEmpty.new())
    terminal_input.text_submitted.connect(_on_command_submitted)
    terminal_scroll.gui_input.connect(_on_terminal_surface_input)

    _write_terminal("VICTU OS TERMINAL v1.0")
    _write_terminal(_tx("Terminal intro") + "\n")
    _update_terminal_prompt()
    terminal_input.grab_focus()
    _scroll_terminal_to_bottom.call_deferred()

func _on_terminal_surface_input(event: InputEvent) -> void:
    if event is InputEventMouseButton and event.pressed:
        if is_instance_valid(terminal_input):
            terminal_input.grab_focus()

func _scroll_terminal_to_bottom() -> void:
    if is_instance_valid(terminal_scroll):
        var scroll_bar: VScrollBar = terminal_scroll.get_v_scroll_bar()
        terminal_scroll.scroll_vertical = int(scroll_bar.max_value)

func _terminal_prompt() -> String:
    var shown_path: String = context.os_state.current_directory
    if context.os_state.current_directory == TERMINAL_HOME:
        shown_path = "~"
    elif context.os_state.current_directory.begins_with(TERMINAL_HOME + "/"):
        shown_path = "~" + context.os_state.current_directory.substr(TERMINAL_HOME.length())
    var marker: String = "#" if context.os_state.terminal_username == "root" else "$"
    return "%s@%s:%s%s" % [context.os_state.terminal_username, TERMINAL_HOST, shown_path, marker]

func _update_terminal_prompt() -> void:
    if not is_instance_valid(terminal_prompt_label):
        return
    terminal_prompt_label.text = "[sudo] password for %s:" % TERMINAL_USER if context.os_state.terminal_password_pending else _terminal_prompt()
    if is_instance_valid(terminal_input):
        terminal_input.secret = context.os_state.terminal_password_pending
        terminal_input.placeholder_text = ""
    _scroll_terminal_to_bottom.call_deferred()

func _write_terminal(message: String) -> void:
    if is_instance_valid(terminal_output):
        terminal_output.append_text(message + "\n")
        _scroll_terminal_to_bottom.call_deferred()

func _on_command_submitted(command: String) -> void:
    if not is_instance_valid(terminal_input):
        return
    terminal_input.clear()
    if context.os_state.terminal_password_pending:
        # The password must not appear in terminal history.
        _write_terminal(terminal_prompt_label.text)
        context.os_state.terminal_password_pending = false
        var pending: String = context.os_state.terminal_pending_command
        context.os_state.terminal_pending_command = ""
        if command == DEMO_PASSWORD:
            command_interpreter.execute(pending, true, self)
        else:
            _write_terminal("sudo: incorrect password")
        if is_instance_valid(terminal_input):
            _update_terminal_prompt()
            terminal_input.grab_focus()
        return

    var trimmed: String = command.strip_edges()
    _write_terminal(_terminal_prompt() + " " + command)
    if trimmed.is_empty():
        _update_terminal_prompt()
        terminal_input.grab_focus()
        return
    if trimmed == "sudo -l":
        _write_terminal("User player may run the following commands as root: ALL")
    elif trimmed == "sudo" or trimmed.begins_with("sudo "):
        if context.os_state.terminal_username == "root":
            command_interpreter.execute(trimmed.substr(5).strip_edges(), true, self)
        else:
            var sudo_command: String = trimmed.substr(5).strip_edges()
            if sudo_command.is_empty():
                _write_terminal("usage: sudo COMMAND")
            else:
                context.os_state.terminal_pending_command = sudo_command
                context.os_state.terminal_password_pending = true
    else:
        command_interpreter.execute(trimmed, context.os_state.terminal_username == "root", self)
    if is_instance_valid(terminal_input) and not terminal_input.is_queued_for_deletion():
        _update_terminal_prompt()
        terminal_input.grab_focus()
