extends Node2D


func _ready() -> void:
	print("VICTUBYTE iniciado com sucesso!")

	# Get the security terminal and door nodes.
	var security_terminal := $SecurityTerminal
	var door := $Door

	# Connect the terminal's access signal to the door.
	if not security_terminal.access_granted.is_connected(door.open_door):
		security_terminal.access_granted.connect(door.open_door)

	print("VICTUBYTE: terminal conectado ao sistema da porta.")
