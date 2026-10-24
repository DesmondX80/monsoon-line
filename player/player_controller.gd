class_name PlayerController
extends CharacterBody3D
## Pelaajan liike ja kamera. Konekiväärimiehen kuorma hidastaa liikettä.

enum Stance { STAND, CROUCH, PRONE }

@export var walk_speed: float = 3.2
@export var sprint_speed: float = 5.0
@export var crouch_speed: float = 1.8
@export var prone_speed: float = 0.7
@export var mouse_sensitivity: float = 0.0025
## Kantokuorma kiloina. M60 noin 10,5 kg + nauhat. Hidastaa liikettä ja kestävyyttä.
@export var carried_load_kg: float = 25.0

@onready var head: Node3D = $Head
@onready var weapon: MachineGun = $Head/MachineGun
@onready var health: HealthComponent = $HealthComponent
@onready var suppression: SuppressionComponent = $SuppressionComponent

var stance: Stance = Stance.STAND
var stamina: float = 1.0

const STANCE_HEIGHT := { Stance.STAND: 1.65, Stance.CROUCH: 1.1, Stance.PRONE: 0.35 }


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var sensitivity := mouse_sensitivity * (0.4 if weapon.bipod_deployed else 1.0)
		rotate_y(-event.relative.x * sensitivity)
		head.rotate_x(-event.relative.y * sensitivity)
		head.rotation.x = clampf(head.rotation.x, deg_to_rad(-85), deg_to_rad(85))
	elif event.is_action_pressed("crouch"):
		stance = Stance.STAND if stance == Stance.CROUCH else Stance.CROUCH
	elif event.is_action_pressed("prone"):
		stance = Stance.STAND if stance == Stance.PRONE else Stance.PRONE
	elif event.is_action_pressed("bipod"):
		_toggle_bipod()
	elif event.is_action_pressed("reload"):
		weapon.reload()
	elif event.is_action_pressed("barrel_change"):
		weapon.change_barrel(false)
	elif event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta
	head.position.y = lerpf(head.position.y, STANCE_HEIGHT[stance], 10.0 * delta)

	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := (transform.basis * Vector3(input.x, 0, input.y)).normalized()
	var speed := _current_speed()
	if weapon.bipod_deployed and direction != Vector3.ZERO:
		weapon.bipod_deployed = false
	velocity.x = direction.x * speed
	velocity.z = direction.z * speed
	move_and_slide()

	if Input.is_action_pressed("fire"):
		weapon.try_fire(self)


func _current_speed() -> float:
	var base: float
	match stance:
		Stance.CROUCH: base = crouch_speed
		Stance.PRONE: base = prone_speed
		_: base = sprint_speed if Input.is_action_pressed("sprint") and stamina > 0.1 else walk_speed
	var load_factor := clampf(1.0 - (carried_load_kg - 15.0) / 60.0, 0.6, 1.0)
	var leg_factor := 0.5 if health.disabled_parts.has(&"leg_l") or health.disabled_parts.has(&"leg_r") else 1.0
	return base * load_factor * leg_factor


func _toggle_bipod() -> void:
	# Kaksijalka vaatii makuuasennon tai tuen. TODO: tuen tunnistus säteellä eteen.
	if stance == Stance.PRONE:
		weapon.bipod_deployed = not weapon.bipod_deployed
