extends RefCounted

const HOME := "/home/player"
const USER := "player"
const HOST := "victu"

var current_directory: String = HOME
var terminal_username: String = USER
var terminal_password_pending: bool = false
var terminal_pending_command: String = ""
var opened_from_inventory: bool = false
var previous_pause_state: bool = false
