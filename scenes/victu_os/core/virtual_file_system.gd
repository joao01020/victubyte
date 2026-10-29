extends RefCounted

var file_permissions: Dictionary = {
    "/home/player": "755", "/home/player/Documents": "755",
    "/home/player/Downloads": "755", "/home/player/FieldGuide": "755",
    "/home/player/Documents/welcome.txt": "644",
    "/remote": "755", "/remote/SEC-TERM-01": "750",
    "/remote/SEC-TERM-01/README.txt": "640",
    "/etc": "755", "/etc/lab.conf": "640",
    "/root": "700", "/root/admin_notes.txt": "600"
}
var file_owners: Dictionary = {
    "/home/player": "player", "/home/player/Documents": "player",
    "/home/player/Downloads": "player", "/home/player/FieldGuide": "player",
    "/home/player/Documents/welcome.txt": "player",
    "/remote": "root", "/remote/SEC-TERM-01": "root",
    "/remote/SEC-TERM-01/README.txt": "root",
    "/etc": "root", "/etc/lab.conf": "root",
    "/root": "root", "/root/admin_notes.txt": "root"
}

# Initial system files. A dedicated filesystem component will replace this.
var directories: Dictionary = {
    "/home/player": ["Documents", "Downloads", "FieldGuide"],
    "/home/player/Documents": ["welcome.txt"],
    "/home/player/Downloads": [],
    "/home/player/FieldGuide": [],
    "/remote": ["SEC-TERM-01"],
    "/remote/SEC-TERM-01": ["README.txt"],
    "/etc": ["lab.conf"],
    "/root": ["admin_notes.txt"]
}
var contents: Dictionary = {
    "/home/player/Documents/welcome.txt": "Welcome to VICTU OS.\nExplore the desktop and open a terminal.",
    "/remote/SEC-TERM-01/README.txt": "LAB SECURITY TERMINAL\nMaintenance documents will be added in the first mission.",
    "/etc/lab.conf": "DEVICE=SEC-TERM-01\nACCESS=restricted",
    "/root/admin_notes.txt": "Restricted laboratory maintenance notes."
}

func resolve_path(argument: String, current_directory: String) -> String:
    if argument.is_empty() or argument == "~":
        return "/home/player"
    var segments: PackedStringArray = PackedStringArray()
    var raw_path: String = argument if argument.begins_with("/") else current_directory.path_join(argument)
    for segment in raw_path.split("/", false):
        if segment == ".":
            continue
        if segment == "..":
            if not segments.is_empty():
                segments.remove_at(segments.size() - 1)
        else:
            segments.append(segment)
    return "/" + "/".join(segments)

func absolute_path(value: String, current_path: String) -> String:
    var path_value: String = value.strip_edges()
    if path_value == "~":
        return "/home/player"
    if path_value.begins_with("~/"):
        path_value = "/home/player" + path_value.substr(1)
    return resolve_path(path_value, current_path)

func create_file(path: String, file_owner: String = "player") -> bool:
    if contents.has(path) or directories.has(path):
        return true
    var parent_dir: String = path.get_base_dir()
    if not directories.has(parent_dir):
        return false
    contents[path] = ""
    var names: Array = directories[parent_dir]
    names.append(path.get_file())
    directories[parent_dir] = names
    file_permissions[path] = "644"
    file_owners[path] = file_owner
    return true
