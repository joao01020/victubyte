extends RefCounted

var file_system

func _init(fs: RefCounted) -> void:
    file_system = fs

func can_access(path: String, operation: String, as_root: bool) -> bool:
    if as_root:
        return true
    var mode: String = str(file_system.file_permissions.get(path, "000"))
    var file_owner: String = str(file_system.file_owners.get(path, "root"))
    var digit_index: int = 0 if file_owner == "player" else 2
    if mode.length() != 3:
        return false
    var bits: int = int(mode.substr(digit_index, 1))
    var required: int = 4 if operation == "r" else (2 if operation == "w" else 1)
    return (bits & required) != 0

func mode_text(mode: String) -> String:
    var result: String = ""
    for digit in mode:
        var bits: int = int(digit)
        result += "r" if (bits & 4) != 0 else "-"
        result += "w" if (bits & 2) != 0 else "-"
        result += "x" if (bits & 1) != 0 else "-"
    return result
