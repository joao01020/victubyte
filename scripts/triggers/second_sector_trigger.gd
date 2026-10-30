extends Area2D

# VICTUBYTE - SECOND SECTOR TRIGGER
# Sends mission two after the player enters the next sector.

@export var player_group: StringName = &"player"

const LAPTOP_PATH: NodePath = ^"/root/Main/UI/LaptopDesktop"
const NOTIFICATION_PATH: NodePath = ^"/root/Main/UI/MessageNotification"
const SECOND_MESSAGE_ID: String = "scientist_second_message"

var message_sent: bool = false


func _ready() -> void:
	monitoring = true
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if message_sent or not body.is_in_group(player_group):
		return

	var laptop: Node = get_node_or_null(LAPTOP_PATH)
	if laptop == null:
		push_warning("VICTUBYTE: LaptopDesktop not found.")
		return

	var manager_value: Variant = laptop.get("messages_manager")
	if not (manager_value is Node):
		push_warning("VICTUBYTE: MessagesManager not available.")
		return

	var manager: Node = manager_value as Node
	if not is_instance_valid(manager):
		return

	if not manager.has_method("trigger_second_message"):
		push_warning("VICTUBYTE: trigger_second_message() missing.")
		return

	var sent: bool = bool(manager.call("trigger_second_message"))
	if not sent:
		if not manager.has_method("has_message"):
			return
		if not bool(manager.call("has_message", SECOND_MESSAGE_ID)):
			return

	message_sent = true
	print("VICTUBYTE: Second mission message delivered.")

	# Notify the HUD directly if the signal connection was late.
	var notification_node: Node = get_node_or_null(NOTIFICATION_PATH)
	if notification_node != null and notification_node.has_method("show_new_message_notification"):
		notification_node.call("show_new_message_notification", SECOND_MESSAGE_ID)
	else:
		push_warning("VICTUBYTE: MessageNotification not found or outdated.")
