extends Area2D

# VICTUBYTE - THIRD SECTOR TRIGGER
# Delivers the third message and displays the existing HUD notification.

@export var player_group: StringName = &"player"

const LAPTOP_PATH: NodePath = ^"/root/Main/UI/LaptopDesktop"
const NOTIFICATION_PATH: NodePath = ^"/root/Main/UI/MessageNotification"
const THIRD_MESSAGE_ID: String = "scientist_third_message"

var message_sent: bool = false


func _ready() -> void:
	monitoring = true
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if message_sent or not body.is_in_group(player_group):
		return

	var laptop_node: Node = get_node_or_null(LAPTOP_PATH)
	if laptop_node == null:
		push_warning("VICTUBYTE: LaptopDesktop not found.")
		return

	var manager_value: Variant = laptop_node.get("messages_manager")
	if not (manager_value is Node):
		push_warning("VICTUBYTE: MessagesManager not available.")
		return

	var manager_node: Node = manager_value as Node
	if not is_instance_valid(manager_node):
		return

	if not manager_node.has_method("trigger_third_message"):
		push_warning("VICTUBYTE: trigger_third_message() missing.")
		return

	var delivered: bool = bool(manager_node.call("trigger_third_message"))
	var already_exists: bool = false
	if manager_node.has_method("has_message"):
		already_exists = bool(manager_node.call("has_message", THIRD_MESSAGE_ID))

	if not delivered and not already_exists:
		push_warning("VICTUBYTE: Third mission message was not added.")
		return

	message_sent = true
	print("VICTUBYTE: Third mission message delivered.")

	# Reuse the same on-screen pop-up used by mission two.
	var notification_node: Node = get_node_or_null(NOTIFICATION_PATH)
	if notification_node == null:
		push_warning("VICTUBYTE: MessageNotification node missing.")
		return

	if not notification_node.has_method("show_new_message_notification"):
		push_warning("VICTUBYTE: MessageNotification script lacks show_new_message_notification().")
		return

	notification_node.call("show_new_message_notification", THIRD_MESSAGE_ID)
	print("VICTUBYTE: Third mission HUD notification requested.")
