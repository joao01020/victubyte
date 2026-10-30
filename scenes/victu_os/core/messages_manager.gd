extends Node

# VICTU OS - MESSAGES MANAGER

signal message_received(message_id: String)
signal message_read(message_id: String)
signal unread_count_changed(count: int)

const INITIAL_MESSAGE_ID := "scientist_first_message"
const SECOND_MESSAGE_ID := "scientist_second_message"
const THIRD_MESSAGE_ID := "scientist_third_message"
const SHARED_VERIFICATION_CODE := "30312111"

var messages: Array[Dictionary] = []


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


# Call this after the player crosses the first door.
func trigger_second_message() -> bool:
	if has_message(SECOND_MESSAGE_ID):
		return false

	return add_message(
		SECOND_MESSAGE_ID,
		"Desconhecido",
		"Sistema de vigilância do laboratório",
		"""Você conseguiu passar pela primeira porta!

Mas tenha cuidado. O próximo setor está protegido por câmeras de vigilância. Se elas detectarem você, poderão acionar o sistema de segurança.

O ESP32 que você carrega possui um interceptador capaz de interferir temporariamente nas câmeras próximas.

COMO USAR O ESP32:
- Pressione TAB ou G para encontrar e acessar o ESP32.
- Aproxime-se de uma câmera de segurança.
- Pressione F para ativar o interceptador quando houver uma câmera próxima.

A interferência é temporária. Aproveite o momento para atravessar a área monitorada antes que a câmera volte a funcionar.

Não se exponha desnecessariamente. Ainda não sabemos quem está observando este setor.

Tome cuidado. Estou contando com você."""
	)


# Call this after the player safely crosses the camera sector.
func trigger_third_message() -> bool:
	if has_message(THIRD_MESSAGE_ID):
		return false

	return add_message(
		THIRD_MESSAGE_ID,
		"Desconhecido",
		"Protocolo de comunicação segura",
		"""Você conseguiu passar pelas câmeras. Muito bem!

Mas agora preciso te alertar sobre algo importante.

Você não pode confiar em tudo o que vê neste laboratório. Nem mesmo nas mensagens que parecem ter sido enviadas por mim. Sempre desconfie.

Precisamos estabelecer um código secreto para reconhecer nossas próximas mensagens de orientação.

NOSSO CÓDIGO: 30312111

A partir de agora, confira se essa sequência aparece em cada nova mensagem de orientação que eu enviar.

Se uma mensagem não tiver o código 30312111, considere-a suspeita. Ela pode ter sido interceptada ou alterada. Não siga as instruções antes de verificar.

Guarde essa sequência e não a revele.

CÓDIGO DE VERIFICAÇÃO: %s

Tome cuidado. Não sabemos até onde vai o controle deles.""" % SHARED_VERIFICATION_CODE
	)


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


func remove_message(message_id: String) -> bool:
	for index: int in range(messages.size()):
		if str(messages[index].get("id", "")) != message_id:
			continue

		messages.remove_at(index)
		unread_count_changed.emit(get_unread_count())
		return true

	return false


func reset_messages() -> void:
	messages.clear()
	unread_count_changed.emit(0)
	_initialize_messages()
