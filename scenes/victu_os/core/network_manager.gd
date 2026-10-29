extends Node

signal network_changed(ssid: String)

var selected_network: String = ""
var connected_network: String = ""
var networks: Array[Dictionary] = [
    {"ssid": "LAB-EXT", "signal": 5, "quality": "Excellent", "security": "WPA2"},
    {"ssid": "LAB", "signal": 3, "quality": "Fair", "security": "WPA2"},
    {"ssid": "LAB-SYSTEM", "signal": 1, "quality": "Weak", "security": "WPA2"}
]
var passwords: Dictionary = {
    "LAB-EXT": "labext2026",
    "LAB": "lab2026secure",
    "LAB-SYSTEM": "system2026secure"
}

func connect_network(ssid: String, password: String) -> bool:
    if not passwords.has(ssid) or password != str(passwords[ssid]):
        return false
    connected_network = ssid
    selected_network = ssid
    network_changed.emit(ssid)
    return true

func disconnect_wifi() -> void:
    connected_network = ""
    network_changed.emit("")
