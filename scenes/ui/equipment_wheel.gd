extends Control

signal equipment_selected(item_id: String)

@export var player_path: NodePath = NodePath("../../Player")
@export var laptop_desktop_path: NodePath = NodePath("../../LaptopDesktop")

@onready var wheel_panel: Control = $WheelPanel
@onready var wheel: Control = $WheelPanel/Wheel
@onready var backpack_indicator: PanelContainer = $BackpackIndicator

@onready var player: Node = get_node_or_null(player_path)
@onready var laptop_desktop: CanvasLayer = get_node_or_null(laptop_desktop_path) as CanvasLayer

const WHEEL_SIZE := Vector2(250.0, 250.0)
const WHEEL_SCALE := 0.40
const SCREEN_MARGIN := 24.0
const DISPLAY_SIZE := WHEEL_SIZE * WHEEL_SCALE

var is_open: bool = false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	mouse_filter = Control.MOUSE_FILTER_IGNORE
	wheel_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	wheel_panel.set_anchors_and_offsets_preset(
		Control.PRESET_TOP_LEFT
	)

	wheel_panel.position = Vector2.ZERO
	wheel_panel.size = DISPLAY_SIZE
	wheel_panel.scale = Vector2.ONE

	wheel.set_anchors_and_offsets_preset(
		Control.PRESET_TOP_LEFT
	)

	wheel.position = Vector2.ZERO
	wheel.size = WHEEL_SIZE
	wheel.scale = Vector2.ONE * WHEEL_SCALE
	wheel.pivot_offset = Vector2.ZERO
	wheel.mouse_filter = Control.MOUSE_FILTER_STOP

	backpack_indicator.visible = false
	backpack_indicator.mouse_filter = Control.MOUSE_FILTER_IGNORE

	wheel_panel.visible = false
	is_open = false

	var selection_callback := Callable(
		self,
		"_on_equipment_selected"
	)

	if not wheel.is_connected(
		"equipment_selected",
		selection_callback
	):
		wheel.connect(
			"equipment_selected",
			selection_callback
		)

	get_viewport().size_changed.connect(_update_positions)

	_update_positions()


func _update_positions() -> void:
	var viewport_size := get_viewport_rect().size

	wheel_panel.position = Vector2(
		viewport_size.x - DISPLAY_SIZE.x - SCREEN_MARGIN,
		viewport_size.y - DISPLAY_SIZE.y - SCREEN_MARGIN
	)


func _unhandled_key_input(event: InputEvent) -> void:
	if not event.pressed or event.echo:
		return

	match event.keycode:
		KEY_TAB:
			toggle_inventory()
			get_viewport().set_input_as_handled()

		KEY_ESCAPE:
			if is_open:
				close_inventory()
				get_viewport().set_input_as_handled()

		KEY_ENTER, KEY_KP_ENTER:
			if is_open:
				wheel.call("confirm_selection")
				get_viewport().set_input_as_handled()


func toggle_inventory() -> void:
	if is_open:
		close_inventory()
	else:
		open_inventory()


func open_inventory() -> void:
	if is_open:
		return

	if get_tree().paused:
		return

	is_open = true
	wheel_panel.visible = true
	backpack_indicator.visible = false

	_update_positions()
	wheel.queue_redraw()


func close_inventory() -> void:
	is_open = false
	wheel_panel.visible = false
	backpack_indicator.visible = false


func _on_equipment_selected(item_id: String) -> void:
	close_inventory()

	equipment_selected.emit(item_id)

	match item_id:
		"esp32":
			_toggle_esp32()

		"notebook":
			_open_notebook()

		"headphones":
			print("Headphones: coming soon.")

		"documents":
			print("Documents: coming soon.")


func _toggle_esp32() -> void:
	if not is_instance_valid(player):
		push_warning("Equipment: Player not found.")
		return

	if not player.has_method("toggle_esp32"):
		push_warning("Equipment: toggle_esp32() not found.")
		return

	player.call("toggle_esp32")

	print("Equipment: ESP32 toggled.")


func _open_notebook() -> void:
	if not is_instance_valid(player):
		push_warning("Equipment: Player not found.")
		return

	if not is_instance_valid(laptop_desktop):
		push_warning("Equipment: LaptopDesktop not found.")
		return

	if not player.has_method("start_laptop_equip"):
		push_warning("Equipment: start_laptop_equip() not found.")
		return

	if not laptop_desktop.has_method("open_from_inventory"):
		push_warning("Equipment: open_from_inventory() not found.")
		return

	if laptop_desktop.visible:
		return

	if player.get("is_equipping_laptop") == true:
		return

	if player.get("is_equipping_esp32") == true:
		return

	# Put away the ESP32 before using the notebook.
	if player.get("is_using_esp32") == true:
		if player.has_method("finish_esp32_interaction"):
			player.call("finish_esp32_interaction")

	# Play the existing notebook animation.
	if player.get("is_using_laptop") != true:
		await player.call("start_laptop_equip")

	if not is_inside_tree():
		return

	if not is_instance_valid(player):
		return

	if not is_instance_valid(laptop_desktop):
		return

	# Do not open the OS if the animation was interrupted.
	if player.get("is_using_laptop") != true:
		return

	# Open the VICTU OS outside the security terminal.
	laptop_desktop.call("open_from_inventory")

	print("Equipment: VICTU OS opened.")


func get_inventory_state() -> bool:
	return is_open


func get_selected_equipment() -> String:
	return str(wheel.call("get_selected_equipment"))
