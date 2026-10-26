extends Marker2D

# ============================================================
# VICTUBYTE — ESP32 LIGHT ANCHOR
# ============================================================

# ============================================================
# CONFIGURATION
# ============================================================

const LIGHT_COLOR: Color = Color("#E8FFF1")

const IDLE_ENERGY: float = 0.25
const MIN_ENERGY: float = 0.35
const MAX_ENERGY: float = 0.85
const PULSE_SPEED: float = 7.0

# ============================================================
# NODES
# ============================================================

@onready var esp32_light: PointLight2D = $ESP32Light
@onready var controller: Node2D = get_parent().get_node_or_null(
	"ESP32Controller"
) as Node2D

# ============================================================
# STATE
# ============================================================

var is_equipped: bool = false
var is_jamming: bool = false
var pulse_time: float = 0.0

# ============================================================
# INITIALIZATION
# ============================================================

func _ready() -> void:
	esp32_light.color = LIGHT_COLOR
	esp32_light.energy = 0.0
	esp32_light.enabled = false

	if controller == null:
		push_warning(
			"ESP32LightAnchor: ESP32Controller não encontrado."
		)

# ============================================================
# PROCESS
# ============================================================

func _process(delta: float) -> void:
	if not is_instance_valid(controller):
		disable_light()
		return

	is_equipped = bool(controller.get("is_equipped"))
	is_jamming = bool(controller.get("is_jamming"))

	# Device stored: completely disable the light.
	if not is_equipped:
		disable_light()
		return

	esp32_light.enabled = true

	# Device equipped but not jamming.
	if not is_jamming:
		pulse_time = 0.0
		esp32_light.energy = IDLE_ENERGY
		return

	# Device actively jamming: pulse the light.
	pulse_time += delta * PULSE_SPEED

	var pulse: float = (
		sin(pulse_time) + 1.0
	) * 0.5

	esp32_light.energy = lerpf(
		MIN_ENERGY,
		MAX_ENERGY,
		pulse
	)

# ============================================================
# LIGHT CONTROL
# ============================================================

func disable_light() -> void:
	esp32_light.enabled = false
	esp32_light.energy = 0.0
	pulse_time = 0.0


func set_jamming(active: bool) -> void:
	is_jamming = active

	if not is_equipped:
		disable_light()
		return

	esp32_light.enabled = true

	if active:
		pulse_time = 0.0
		esp32_light.energy = MIN_ENERGY
	else:
		esp32_light.energy = IDLE_ENERGY