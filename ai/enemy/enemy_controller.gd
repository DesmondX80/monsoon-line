class_name EnemyController
extends CharacterBody3D
## Viet Cong -kiväärimies (9. divisioona). Liike, asennot ja ampuminen.
## Päätöksenteko on tilakoneen tiloissa (ai/enemy/states/), havainnointi EnemyPerception-solmussa.
##
## Tilat asettavat move_target/move_speed-arvot ja kutsuvat fire_at(); tämä luokka hoitaa
## navigoinnin NavigationAgent3D:llä ja yhteiset siirtymät (tukahdutus, kuolema).

enum Stance { STAND, CROUCH, PRONE }

## Vartalon (Body) sijainti asennoittain. Makuulla vartalo kallistetaan ja keskitetään juureen.
const BODY_PIVOT_OFFSET := {
	Stance.STAND: Vector3.ZERO,
	Stance.CROUCH: Vector3(0.0, -0.45, 0.0),
	Stance.PRONE: Vector3(0.0, 0.2, 0.85),
}
## Törmäyskapselin korkeus asennoittain. Kapseli on tarkoituksella hitboxeja kapeampi,
## jotta luodin säde osuu hitboxiin ennen vartalon törmäysmuotoa.
const CAPSULE_HEIGHT := { Stance.STAND: 1.5, Stance.CROUCH: 1.0, Stance.PRONE: 0.3 }

@export var weapon_data: WeaponData
@export var walk_speed: float = 1.6
@export var run_speed: float = 3.6
@export var turn_speed: float = 6.0
## Partiopisteet. Jos tyhjä, partioidaan satunnaisesti spawn-pisteen ympärillä.
@export var patrol_points: Array[Node3D] = []
@export var patrol_radius: float = 12.0
@export_group("Tarkkuus")
## Perushajonta asteina lähietäisyydellä.
@export var base_spread_deg: float = 1.2
## Lisähajonta asteina metriä kohden.
@export var spread_per_meter: float = 0.06
## Lisähajonta asteina täydellä tukahdutuksella.
@export var suppression_spread_deg: float = 8.0
@export var effective_range: float = 60.0

@onready var health: HealthComponent = $HealthComponent
@onready var suppression: SuppressionComponent = $SuppressionComponent
@onready var perception: EnemyPerception = $Perception
@onready var nav_agent: NavigationAgent3D = $NavigationAgent3D
@onready var state_machine: StateMachine = $StateMachine
@onready var body_pivot: Node3D = $Body
@onready var muzzle: Marker3D = $Body/Head/Rifle/Muzzle
@onready var collision_shape: CollisionShape3D = $CollisionShape3D

var stance: Stance = Stance.STAND
var move_target: Vector3
var move_speed: float = 0.0
## Kohta, jota kohti katsotaan, kun ei liikuta. null = liikesuunta.
var look_target: Variant = null
var spawn_position: Vector3
var rounds_in_magazine: int = 0
var reloading: bool = false
var arm_wounded: bool = false
var leg_wounded: bool = false

var _fire_cooldown: float = 0.0
var _stuck_time: float = 0.0


func _ready() -> void:
	add_to_group(&"enemy")
	add_to_group(&"suppressible")
	# Jokaisella instanssilla oma kapseli, koska sitä muutetaan asennon mukaan.
	collision_shape.shape = collision_shape.shape.duplicate() as Shape3D
	spawn_position = global_position
	move_target = global_position
	if weapon_data == null:
		weapon_data = load("res://weapons/resources/type56.tres") as WeaponData
	rounds_in_magazine = weapon_data.magazine_size
	health.died.connect(_on_died)
	health.limb_disabled.connect(_on_limb_disabled)
	EventBus.actor_hit.connect(_on_actor_hit)
	state_machine.transition_to(&"Patrol")


func _physics_process(delta: float) -> void:
	_fire_cooldown = maxf(_fire_cooldown - delta, 0.0)
	if is_dead():
		_apply_gravity_only(delta)
		return
	if suppression.is_pinned() and state_machine.current and state_machine.current.name != &"Suppressed":
		state_machine.transition_to(&"Suppressed")
	_update_movement(delta)
	body_pivot.position = body_pivot.position.lerp(BODY_PIVOT_OFFSET[stance] as Vector3, 8.0 * delta)
	var target_tilt := deg_to_rad(-90.0) if stance == Stance.PRONE else 0.0
	body_pivot.rotation.x = lerp_angle(body_pivot.rotation.x, target_tilt, 6.0 * delta)


# --- Liike ---

## Liikkuu kohteeseen annetulla nopeudella (m/s).
func go_to(target: Vector3, speed: float) -> void:
	if not move_target.is_equal_approx(target):
		move_target = target
		nav_agent.target_position = target
	move_speed = speed


func stop() -> void:
	move_speed = 0.0
	move_target = global_position


func has_arrived(tolerance: float = 1.0) -> bool:
	var flat := Vector2(global_position.x - move_target.x, global_position.z - move_target.z)
	return flat.length() <= tolerance


## Onko vihollinen yrittänyt liikkua, mutta jumittanut paikalleen (este tai saavuttamaton kohde).
func is_stuck() -> bool:
	return _stuck_time > 2.0


func set_stance(value: Stance) -> void:
	if value == stance:
		return
	stance = value
	# Törmäyskapseli madaltuu asennon mukana, jotta se ei peitä hitboxeja eikä estä tulta.
	var capsule := collision_shape.shape as CapsuleShape3D
	if capsule:
		capsule.height = maxf(CAPSULE_HEIGHT[stance], capsule.radius * 2.0)
		collision_shape.position.y = capsule.height * 0.5


func speed_multiplier() -> float:
	var factor := 0.5 if leg_wounded else 1.0
	match stance:
		Stance.CROUCH: factor *= 0.6
		Stance.PRONE: factor *= 0.25
	return factor


## Satunnainen navigoitava piste spawnin ympäriltä.
func random_patrol_point() -> Vector3:
	var angle := randf() * TAU
	var radius := randf_range(patrol_radius * 0.3, patrol_radius)
	var point := spawn_position + Vector3(cos(angle), 0.0, sin(angle)) * radius
	return closest_navigable_point(point)


func closest_navigable_point(point: Vector3) -> Vector3:
	var map := nav_agent.get_navigation_map()
	if map.is_valid() and NavigationServer3D.map_get_iteration_id(map) > 0:
		return NavigationServer3D.map_get_closest_point(map, point)
	return point


func _update_movement(delta: float) -> void:
	var horizontal := Vector3.ZERO
	var speed := move_speed * speed_multiplier()
	if speed > 0.0 and not has_arrived(nav_agent.target_desired_distance):
		var next := _next_path_point()
		var to_next := next - global_position
		to_next.y = 0.0
		if to_next.length() > 0.05:
			horizontal = to_next.normalized() * speed
	velocity.x = horizontal.x
	velocity.z = horizontal.z
	if not is_on_floor():
		velocity += get_gravity() * delta
	elif velocity.y < 0.0:
		velocity.y = 0.0
	var before := global_position
	move_and_slide()
	if horizontal != Vector3.ZERO and before.distance_to(global_position) < speed * delta * 0.2:
		_stuck_time += delta
	else:
		_stuck_time = 0.0

	var face_dir := Vector3.ZERO
	if look_target is Vector3:
		face_dir = (look_target as Vector3) - global_position
	elif horizontal != Vector3.ZERO:
		face_dir = horizontal
	face_dir.y = 0.0
	if face_dir.length() > 0.05:
		var yaw := atan2(-face_dir.x, -face_dir.z)
		rotation.y = lerp_angle(rotation.y, yaw, turn_speed * delta)


## Seuraava reittipiste. Ilman navigaatiokarttaa kuljetaan suoraan kohti.
func _next_path_point() -> Vector3:
	var map := nav_agent.get_navigation_map()
	if not map.is_valid() or NavigationServer3D.map_get_iteration_id(map) == 0:
		return move_target
	if nav_agent.is_navigation_finished():
		return move_target if not nav_agent.is_target_reachable() else global_position
	return nav_agent.get_next_path_position()


func _apply_gravity_only(delta: float) -> void:
	velocity.x = 0.0
	velocity.z = 0.0
	if not is_on_floor():
		velocity += get_gravity() * delta
	move_and_slide()


# --- Ase ---

func can_fire() -> bool:
	return not reloading and rounds_in_magazine > 0 and _fire_cooldown == 0.0 and not is_dead()


## Hajonta asteina etäisyyden, tukahdutuksen ja haavojen mukaan.
static func compute_spread_deg(distance: float, suppression_amount: float, base_deg: float,
		per_meter: float, suppression_deg: float, arm_hit: bool) -> float:
	var spread := base_deg + distance * per_meter + suppression_amount * suppression_deg
	if arm_hit:
		spread *= 1.8
	return spread


## Ampuu yhden laukauksen kohti pistettä. Palauttaa true, jos laukaus lähti.
func fire_at(point: Vector3) -> bool:
	if not can_fire():
		if rounds_in_magazine == 0:
			reload()
		return false
	_fire_cooldown = 60.0 / weapon_data.rounds_per_minute
	rounds_in_magazine -= 1
	var origin := muzzle.global_position
	var aim := (point - origin).normalized()
	var spread := deg_to_rad(compute_spread_deg(origin.distance_to(point), suppression.amount,
			base_spread_deg, spread_per_meter, suppression_spread_deg, arm_wounded))
	var side := aim.cross(Vector3.UP)
	if side.length() < 0.01:
		side = Vector3.RIGHT
	side = side.normalized()
	var up := side.cross(aim).normalized()
	var direction := aim.rotated(up, randf_range(-spread, spread) * 0.5)
	direction = direction.rotated(side, randf_range(-spread, spread) * 0.5).normalized()
	Ballistics.fire(self, origin, direction, weapon_data)
	return true


func reload() -> void:
	if reloading or is_dead():
		return
	reloading = true
	await get_tree().create_timer(weapon_data.reload_time).timeout
	if not is_instance_valid(self):
		return
	rounds_in_magazine = weapon_data.magazine_size
	reloading = false


# --- Terveys ---

func is_dead() -> bool:
	return health == null or health.health <= 0.0


func _on_limb_disabled(body_part: StringName) -> void:
	if body_part == &"leg_l" or body_part == &"leg_r":
		leg_wounded = true
	elif body_part == &"arm_l" or body_part == &"arm_r":
		arm_wounded = true


func _on_actor_hit(target: Node3D, _damage: float, body_part: StringName) -> void:
	if target != self or is_dead():
		return
	# Osuma päähän on aina kuolettava, aseen vahingosta riippumatta.
	if body_part == &"head":
		health.take_hit(health.health + 1.0, &"torso")
		return
	# Osuma paljastaa ampujan suunnan: valppaus nousee lähes havaintoon.
	var player := get_tree().get_first_node_in_group(&"player") as Node3D
	var source := player.global_position if player else global_position
	perception.alert(source, 0.8)


func _on_died() -> void:
	remove_from_group(&"suppressible")
	state_machine.transition_to(&"Dead")
