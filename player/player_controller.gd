class_name PlayerController
extends CharacterBody3D
## Pelaajan liike ja kamera. Konekiväärimiehen kuorma hidastaa liikettä ja kuluttaa kestävyyttä.
## Rekyyli ja huojunta tulevat MachineGunilta (WeaponData), kaksijalan tuki BipodSupportilta.

enum Stance { STAND, CROUCH, PRONE }

const PLAYER_GROUP := &"player"
const SUPPRESSIBLE_GROUP := &"suppressible"

@export var walk_speed: float = 3.2
@export var sprint_speed: float = 5.0
@export var crouch_speed: float = 1.8
@export var prone_speed: float = 0.7
@export var mouse_sensitivity: float = 0.0025
## Kantokuorma kiloina. M60 noin 10,5 kg + nauhat. Hidastaa liikettä ja kuluttaa kestävyyttä.
@export var carried_load_kg: float = 25.0
@export_group("Kestävyys")
## Juoksun kulutus sekunnissa 20 kg:n viitekuormalla.
@export var sprint_drain_per_second: float = 0.1
@export var stamina_reference_load_kg: float = 20.0
@export var stamina_load_exponent: float = 1.5
@export var stamina_rest_regen_per_second: float = 0.12

@onready var head: Node3D = $Head
@onready var weapon: MachineGun = $Head/MachineGun
@onready var health: HealthComponent = $HealthComponent
@onready var suppression: SuppressionComponent = $SuppressionComponent

var stance: Stance = Stance.STAND
var stamina_model: StaminaModel = StaminaModel.new()
## Kestävyys 0–1 (luku vain; StaminaModel omistaa arvon). HUD ja debug-näkymä lukevat tätä.
var stamina: float:
	get:
		return stamina_model.value
var is_sprinting: bool = false

const STANCE_HEIGHT := { Stance.STAND: 1.65, Stance.CROUCH: 1.1, Stance.PRONE: 0.35 }

## Kameraan viimeksi lisätty rekyyli/huojunta-poikkeama asteina. Vain muutos lisätään joka ruudulla,
## joten hiiren tähtäys ja poikkeama eivät kumoa toisiaan.
var _applied_offset: Vector2 = Vector2.ZERO


func _ready() -> void:
	add_to_group(PLAYER_GROUP)
	add_to_group(SUPPRESSIBLE_GROUP)
	stamina_model.sprint_drain_per_second = sprint_drain_per_second
	stamina_model.reference_load_kg = stamina_reference_load_kg
	stamina_model.load_exponent = stamina_load_exponent
	stamina_model.rest_regen_per_second = stamina_rest_regen_per_second
	if not DisplayServer.get_name() == "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var motion := event as InputEventMouseMotion
		var sensitivity := mouse_sensitivity * (0.4 if weapon.bipod_deployed else 1.0)
		rotate_y(-motion.relative.x * sensitivity)
		head.rotate_x(-motion.relative.y * sensitivity)
		_clamp_pitch()
	elif event.is_action_pressed("crouch"):
		_set_stance(Stance.STAND if stance == Stance.CROUCH else Stance.CROUCH)
	elif event.is_action_pressed("prone"):
		_set_stance(Stance.STAND if stance == Stance.PRONE else Stance.PRONE)
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
	var moving := direction != Vector3.ZERO
	# Liike nostaa kaksijalan automaattisesti.
	if moving and weapon.bipod_deployed:
		weapon.retract_bipod()
	var wants_sprint := moving and stance == Stance.STAND and Input.is_action_pressed("sprint")
	is_sprinting = stamina_model.update(delta, wants_sprint, moving, carried_load_kg)
	var speed := _current_speed()
	velocity.x = direction.x * speed
	velocity.z = direction.z * speed
	move_and_slide()

	weapon.update_handling(delta, stamina, suppression.amount)
	_apply_aim_offset()

	if Input.is_action_pressed("fire") and not is_sprinting:
		weapon.try_fire(self)


func _current_speed() -> float:
	var base: float
	match stance:
		Stance.CROUCH: base = crouch_speed
		Stance.PRONE: base = prone_speed
		_: base = sprint_speed if is_sprinting else walk_speed
	var load_factor := clampf(1.0 - (carried_load_kg - 15.0) / 60.0, 0.6, 1.0)
	var leg_factor := 0.5 if health.disabled_parts.has(&"leg_l") or health.disabled_parts.has(&"leg_r") else 1.0
	return base * load_factor * leg_factor


func _set_stance(value: Stance) -> void:
	stance = value
	# Makuulta noustessa tuki häviää; kyykkyyn/seisomaan siirtyessä tuki tarkistetaan uudelleen.
	if weapon.bipod_deployed and not _bipod_allowed():
		weapon.retract_bipod()


func _toggle_bipod() -> void:
	if weapon.bipod_deployed:
		weapon.retract_bipod()
	else:
		weapon.deploy_bipod(stance == Stance.PRONE, _has_rest())


func _bipod_allowed() -> bool:
	return BipodSupport.can_deploy(weapon.data.has_bipod, stance == Stance.PRONE, _has_rest())


## Onko piipun edessä rintakorkeudella tukeva pinta (world-kerros).
func _has_rest() -> bool:
	if weapon.muzzle == null:
		return false
	var exclude: Array[RID] = Ballistics.collect_exclude_rids(self)
	var forward := -head.global_transform.basis.z
	return BipodSupport.find_rest(get_world_3d().direct_space_state, weapon.muzzle.global_position, forward, exclude)


## Lisää kameraan rekyylin ja huojunnan muutoksen edelliseen ruutuun verrattuna.
func _apply_aim_offset() -> void:
	var offset := weapon.get_aim_offset()
	var change := offset - _applied_offset
	_applied_offset = offset
	head.rotation.x += deg_to_rad(change.x)
	rotate_y(deg_to_rad(change.y))
	_clamp_pitch()


func _clamp_pitch() -> void:
	head.rotation.x = clampf(head.rotation.x, deg_to_rad(-85), deg_to_rad(85))
