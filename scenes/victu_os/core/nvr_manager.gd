extends RefCounted

var api_key: String = "victu-lab-cctv-demo-key"

var users: Dictionary = {
    "operator": {"password": "operator2026", "role": "viewer"},
    "admin": {"password": "admin2026", "role": "admin"}
}
var cameras: Array[Dictionary] = [
    {"id": "CAM-01", "location": "Entrance", "status": "ONLINE"},
    {"id": "CAM-02", "location": "Laboratory", "status": "ONLINE"},
    {"id": "CAM-03", "location": "Storage", "status": "ONLINE"},
    {"id": "CAM-04", "location": "Restricted Wing", "status": "ONLINE"}
]
var username: String = ""
var role: String = ""
var selected_camera: String = "CAM-01"
var show_api: bool = false
var api_key_visible: bool = false

func sign_in(account_name: String, password: String) -> bool:
    var account: Dictionary = users.get(account_name, {})
    if account.is_empty() or password != str(account.get("password", "")):
        return false
    username = account_name
    role = str(account.get("role", "viewer"))
    show_api = false
    return true

func sign_out() -> void:
    username = ""
    role = ""
    show_api = false
    api_key_visible = false

func can_view(camera_id: String) -> bool:
    return role == "admin" or camera_id != "CAM-04"
