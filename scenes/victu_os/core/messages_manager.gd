extends Node

# ============================================================
# VICTU OS - MESSAGES MANAGER
# ============================================================

signal message_received(message_id: String)
signal message_read(message_id: String)
signal unread_count_changed(count: int)

const INITIAL_MESSAGE_ID := "scientist_first_message"

var messages: Array[Dictionary] = []


# ============================================================
# INITIALIZATION
# ============================================================

func _ready() -> void:
	_initialize_messages()


func _initialize_messages() -> void:
	if has_message(INITIAL_MESSAGE_ID):
		return

	add_message(
		INITIAL_MESSAGE_ID,
		"Desconhecido",
		"Informações sobre o laboratório",
		"""Você conseguiu entrar?

Não temos muito tempo.

Existe uma porta de segurança que dá acesso ao interior do laboratório.

Encontrei um código antigo nos registros do sistema.

CÓDIGO: 4826

Espero que ainda funcione...

Tome cuidado."""
	)


# ============================================================
# ADD MESSAGE
# ============================================================

func add_message(
	message_id: String,
	sender: String,
	subject: String,
	body: String
) -> bool:
	if message_id.strip_edges().is_empty():
		push_warning("VICTU OS: Message ID cannot be empty.")
		return false

	if has_message(message_id):
		push_warning("VICTU OS: Duplicate message ID: " + message_id)
		return false

	var message: Dictionary = {
		"id": message_id,
		"sender": sender,
		"subject": subject,
		"body": body,
		"read": false,
		"received_at": Time.get_unix_time_from_system()
	}

	messages.append(message)
	message_received.emit(message_id)
	unread_count_changed.emit(get_unread_count())
	return true


# ============================================================
# GET MESSAGES
# ============================================================

func get_messages() -> Array[Dictionary]:
	return messages.duplicate(true)


func get_message(message_id: String) -> Dictionary:
	for message: Dictionary in messages:
		if str(message.get("id", "")) == message_id:
			return message.duplicate(true)
	return {}


func has_message(message_id: String) -> bool:
	for message: Dictionary in messages:
		if str(message.get("id", "")) == message_id:
			return true
	return false


# ============================================================
# UNREAD MESSAGES
# ============================================================

func get_unread_count() -> int:
	var count: int = 0
	for message: Dictionary in messages:
		if not bool(message.get("read", false)):
			count += 1
	return count


func get_unread_messages() -> Array[Dictionary]:
	var unread_messages: Array[Dictionary] = []
	for message: Dictionary in messages:
		if not bool(message.get("read", false)):
			unread_messages.append(message.duplicate(true))
	return unread_messages


func is_message_read(message_id: String) -> bool:
	for message: Dictionary in messages:
		if str(message.get("id", "")) == message_id:
			return bool(message.get("read", false))
	return false


# ============================================================
# MARK MESSAGE AS READ
# ============================================================

func mark_as_read(message_id: String) -> bool:
	for index: int in range(messages.size()):
		if str(messages[index].get("id", "")) != message_id:
			continue

		if bool(messages[index].get("read", false)):
			return false

		messages[index]["read"] = true
		message_read.emit(message_id)
		unread_count_changed.emit(get_unread_count())
		return true

	return false


# ============================================================
# MARK MESSAGE AS UNREAD
# ============================================================

func mark_as_unread(message_id: String) -> bool:
	for index: int in range(messages.size()):
		if str(messages[index].get("id", "")) != message_id:
			continue

		if not bool(messages[index].get("read", false)):
			return false

		messages[index]["read"] = false
		unread_count_changed.emit(get_unread_count())
		return true

	return false


# ============================================================
# MARK ALL AS READ
# ============================================================

func mark_all_as_read() -> void:
	var changed: bool = false
	for index: int in range(messages.size()):
		if bool(messages[index].get("read", false)):
			continue

		messages[index]["read"] = true
		changed = true
		message_read.emit(str(messages[index].get("id", "")))

	if changed:
		unread_count_changed.emit(get_unread_count())


# ============================================================
# REMOVE MESSAGE
# ============================================================

func remove_message(message_id: String) -> bool:
	for index: int in range(messages.size()):
		if str(messages[index].get("id", "")) != message_id:
			continue

		messages.remove_at(index)
		unread_count_changed.emit(get_unread_count())
		return true

	return false


# ============================================================
# RESET MESSAGES
# ============================================================

func reset_messages() -> void:
	messages.clear()
	unread_count_changed.emit(0)
	_initialize_messages()
