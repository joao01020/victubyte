extends RefCounted

const TERMINAL_USER := "player"
const TERMINAL_HOME := "/home/player"

var terminal = null

func _write_terminal(message: String) -> void:
    terminal._write_terminal(message)

func _resolve_path(argument: String) -> String:
    return terminal.context.file_system.resolve_path(argument, terminal.context.os_state.current_directory)

func _can_access(path: String, operation: String, as_root: bool) -> bool:
    return terminal.context.permission_manager.can_access(path, operation, as_root)

func _mode_text(mode: String) -> String:
    return terminal.context.permission_manager.mode_text(mode)

func execute(command: String, as_root: bool, current_terminal: Control) -> void:
    terminal = current_terminal
    var parts: PackedStringArray = command.split(" ", false)
    if parts.is_empty():
        return
    var verb: String = parts[0].to_lower()
    var argument: String = parts[1] if parts.size() > 1 else ""
    match verb:
        "help":
            _write_terminal("help  ls [-l]  pwd  cd  cat  whoami  id  sudo -l")
            _write_terminal("chmod MODE FILE  touch FILE  clear  exit  sudo -i")
        "pwd":
            _write_terminal(terminal.context.os_state.current_directory)
        "whoami":
            _write_terminal("root" if as_root else terminal.context.os_state.terminal_username)
        "id":
            _write_terminal("uid=0(root) gid=0(root)" if as_root else "uid=1000(player) gid=1000(player) groups=1000(player),27(sudo)")
        "ls":
            var detailed: bool = argument == "-l"
            var path_arg: String = parts[2] if detailed and parts.size() > 2 else (argument if not detailed else "")
            var target: String = terminal.context.os_state.current_directory if path_arg.is_empty() else _resolve_path(path_arg)
            if not terminal.context.file_system.directories.has(target):
                _write_terminal("ls: cannot access '%s': No such directory" % target)
            elif not _can_access(target, "r", as_root):
                _write_terminal("ls: cannot open directory '%s': Permission denied" % target)
            else:
                var names: Array = terminal.context.file_system.directories[target]
                for item in names:
                    var full_path: String = target.path_join(str(item))
                    if detailed:
                        var mode: String = str(terminal.context.file_system.file_permissions.get(full_path, "644"))
                        var prefix: String = "d" if terminal.context.file_system.directories.has(full_path) else "-"
                        _write_terminal("%s%s  %-7s %s" % [prefix, _mode_text(mode), str(terminal.context.file_system.file_owners.get(full_path, "player")), item])
                    else:
                        _write_terminal(str(item))
        "cd":
            var target: String = _resolve_path(argument)
            if not terminal.context.file_system.directories.has(target):
                _write_terminal("cd: %s: No such directory" % argument)
            elif not _can_access(target, "x", as_root):
                _write_terminal("cd: %s: Permission denied" % argument)
            else:
                terminal.context.os_state.current_directory = target
        "cat":
            if argument.is_empty():
                _write_terminal("cat: missing file operand")
            else:
                var target: String = _resolve_path(argument)
                if not terminal.context.file_system.contents.has(target):
                    _write_terminal("cat: %s: No such file" % argument)
                elif not _can_access(target, "r", as_root):
                    _write_terminal("cat: %s: Permission denied" % argument)
                else:
                    _write_terminal(str(terminal.context.file_system.contents[target]))
        "chmod":
            if parts.size() < 3:
                _write_terminal("usage: chmod MODE FILE (e.g. chmod 600 welcome.txt)")
            else:
                var mode: String = parts[1]
                var path: String = _resolve_path(parts[2])
                if mode.length() != 3 or not mode.is_valid_int() or int(mode) < 0 or int(mode) > 777 or mode.contains("8") or mode.contains("9"):
                    _write_terminal("chmod: invalid mode: " + mode)
                elif not terminal.context.file_system.file_permissions.has(path):
                    _write_terminal("chmod: cannot access '%s'" % path)
                elif not as_root and str(terminal.context.file_system.file_owners.get(path, "root")) != TERMINAL_USER:
                    _write_terminal("chmod: changing permissions of '%s': Operation not permitted" % path)
                else:
                    terminal.context.file_system.file_permissions[path] = mode
        "touch":
            if argument.is_empty():
                _write_terminal("touch: missing file operand")
            else:
                var path: String = _resolve_path(argument)
                var parent_dir: String = path.get_base_dir()
                if not terminal.context.file_system.directories.has(parent_dir):
                    _write_terminal("touch: cannot touch '%s': No such directory" % argument)
                elif not _can_access(parent_dir, "w", as_root):
                    _write_terminal("touch: cannot touch '%s': Permission denied" % argument)
                elif terminal.context.file_system.directories.has(path):
                    _write_terminal("touch: '%s' is a directory" % argument)
                else:
                    if not terminal.context.file_system.contents.has(path):
                        terminal.context.file_system.contents[path] = ""
                        var contents: Array = terminal.context.file_system.directories[parent_dir]
                        contents.append(path.get_file())
                        terminal.context.file_system.directories[parent_dir] = contents
                        terminal.context.file_system.file_permissions[path] = "644"
                        terminal.context.file_system.file_owners[path] = "root" if as_root else TERMINAL_USER
        "-i":
            if not as_root:
                _write_terminal("-i: permission denied")
            else:
                terminal.context.os_state.terminal_username = "root"
                terminal.context.os_state.current_directory = "/root"
                _write_terminal("Root session started. Type 'exit' to return to player.")
        "clear":
            if is_instance_valid(terminal.terminal_output):
                terminal.terminal_output.clear()
                terminal._scroll_terminal_to_bottom.call_deferred()
        "exit":
            if terminal.context.os_state.terminal_username == "root":
                terminal.context.os_state.terminal_username = TERMINAL_USER
                terminal.context.os_state.current_directory = TERMINAL_HOME
                _write_terminal("Returned to player session.")
            else:
                terminal.context.close_app("terminal")
        _:
            _write_terminal("%s: command not found. Try 'help'." % verb)
