extends Area2D

signal access_granted
signal laptop_ready

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var interaction_label: Label = $InteractionLabel

var player_near: bool = false
var unlocked: bool = false
var busy: bool = false

var current_player: CharacterBody2D = null


func _ready() -> void:
	interaction_label.hide()
	sprite.play("idle")

	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

	print("Terminal de segurança: inicializado com sucesso.")


func _unhandled_input(event: InputEvent) -> void:
	if not player_near or busy or unlocked:
		return

	if event.is_action_pressed("interact") and not event.is_echo():
		get_viewport().set_input_as_handled()
		start_access()


func start_access() -> void:
	if busy or unlocked:
		return

	if not is_instance_valid(current_player):
		print("Terminal de segurança: nenhum jogador disponível.")
		return

	if not current_player.has_method("start_laptop_equip"):
		push_warning(
			"Terminal de segurança: o jogador não possui a função start_laptop_equip()."
		)
		return

	busy = true
	interaction_label.hide()

	print("Terminal de segurança: interação iniciada.")
	print("Terminal de segurança: aguardando o jogador retirar o notebook.")

	# Wait until the player finishes equipping the laptop.
	await current_player.start_laptop_equip()

	if not busy or unlocked:
		return

	if not is_instance_valid(current_player):
		cancel_access()
		return

	print("Terminal de segurança: notebook equipado.")

	# Start the terminal's interaction animation.
	sprite.play("interacting")

	# Notify the laptop desktop that it can open.
	print("Terminal de segurança: solicitando abertura do VICTU OS.")
	laptop_ready.emit()
	print("Terminal de segurança: sinal de abertura enviado.")

	# Keep the terminal busy while the laptop interface is in use.


func complete_access() -> void:
	if not busy or unlocked:
		return

	print("Terminal de segurança: processando solicitação de acesso.")

	# Processing and unlocked animations must not loop.
	sprite.play("processing")
	await sprite.animation_finished

	if not busy or unlocked:
		return

	sprite.play("unlocked")
	await sprite.animation_finished

	if not busy or unlocked:
		return

	unlocked = true
	busy = false
	interaction_label.hide()

	print("Terminal de segurança: acesso autorizado.")
	print("Terminal de segurança: enviando sinal para liberar a porta.")

	access_granted.emit()


func cancel_access() -> void:
	if unlocked:
		return

	busy = false
	sprite.play("idle")

	if player_near and is_instance_valid(current_player):
		interaction_label.show()
	else:
		interaction_label.hide()

	print("Terminal de segurança: interação cancelada.")


func _on_body_entered(body: Node2D) -> void:
	if body is CharacterBody2D and body.name == "Player":
		current_player = body
		player_near = true

		print("Terminal de segurança: jogador entrou na área de interação.")

		if not unlocked and not busy:
			interaction_label.show()


func _on_body_exited(body: Node2D) -> void:
	if body == current_player:
		player_near = false
		current_player = null
		interaction_label.hide()

		print("Terminal de segurança: jogador saiu da área de interação.")
