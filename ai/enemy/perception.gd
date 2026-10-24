class_name EnemyPerception
extends Node
## Vihollisen havainnointi: näkö (näkökeila + näköyhteys) ja kuulo (EventBus.shot_fired).
##
## Havaintomittari (awareness, 0–1) täyttyy, kun maali näkyy. Täyttymisnopeus riippuu
## etäisyydestä, kasvillisuudesta, maalin asennosta, liikkeestä ja ampumisesta.
## Laskentakaavat ovat staattisia funktioita, jotta niitä voi testata ilman näkymää.

## Laukaus kuultiin; sijainti on arvio laukauksen lähtöpaikasta.
signal noise_heard(position: Vector3)
## Mittari täyttyi: maali on havaittu.
signal target_detected(target: Node3D)
## Maali on ollut piilossa niin kauan, että se on kadotettu.
signal target_lost

const LAYER_WORLD := 1  ## kerros 1
const LAYER_VEGETATION := 1 << 5  ## kerros 6
const SUSPICION_THRESHOLD := 0.35
const DETECTION_THRESHOLD := 1.0
## Valppaus kuullun laukauksen jälkeen. Selvästi epäilyrajan yli, jotta Epäilee-tila kestää hetken.
const HEARD_SHOT_AWARENESS := 0.6
## Kuinka kauan (s) laukaisun jälkeen suuliekki ja ääni helpottavat havaitsemista.
const FIRING_MEMORY := 1.5
## Pelaajan PlayerController.Stance-arvot: STAND=0, CROUCH=1, PRONE=2.
const STANCE_FACTORS: Array[float] = [1.0, 0.6, 0.3]

@export var eyes: Node3D
@export var view_distance: float = 45.0
@export var fov_deg: float = 120.0
## Tämän etäisyyden sisällä maali havaitaan suunnasta riippumatta (ääni, liike).
@export var proximity_radius: float = 3.0
@export var hearing_range: float = 150.0
## Mittarin täyttyminen sekunnissa ihanteellisissa oloissa (lähellä, avoimessa maastossa).
@export var base_detection_rate: float = 1.2
## Mittarin tyhjeneminen sekunnissa, kun maali ei näy.
@export var awareness_decay: float = 0.08
## Näkyvyyskerroin jokaista näkölinjalla olevaa kasvillisuuskerrosta kohden.
@export var vegetation_attenuation: float = 0.45
@export var max_vegetation_layers: int = 4
## Kuinka kauan (s) havaittu maali muistetaan näkymättömänä.
@export var forget_time: float = 12.0
## Konekiväärimiehen painokerroin maalin valinnassa (ensisijainen maali).
@export var machine_gunner_priority: float = 2.0
@export var update_interval: float = 0.1

var awareness: float = 0.0
var detected: bool = false
var current_target: Node3D
var last_known_position: Vector3
## Viimeisin kiinnostava kohta (kuultu laukaus tai vilaukselta nähty maali).
var investigate_position: Vector3
var has_line_of_sight: bool = false
var time_since_seen: float = INF

var _last_shot_time: Dictionary = {}  ## Node3D -> sekunnit (Time.get_ticks_msec)
var _accumulated: float = 0.0


func _ready() -> void:
	EventBus.shot_fired.connect(_on_shot_fired)


func _physics_process(delta: float) -> void:
	time_since_seen += delta
	_accumulated += delta
	if _accumulated < update_interval:
		return
	var step := _accumulated
	_accumulated = 0.0
	_update_vision(step)


# --- Staattinen laskenta (testattava) ---

## Onko piste näkökeilassa ja -etäisyydellä.
static func is_in_view_cone(eye: Vector3, forward: Vector3, point: Vector3, cone_deg: float, max_distance: float) -> bool:
	var to_point := point - eye
	var distance := to_point.length()
	if distance > max_distance:
		return false
	if distance < 0.001:
		return true
	return forward.normalized().dot(to_point / distance) >= cos(deg_to_rad(cone_deg) * 0.5)


## Näkyvyys (0–1) kasvillisuuskerrosten määrän mukaan.
static func vegetation_visibility(layers: int, attenuation: float, max_layers: int) -> float:
	if layers >= max_layers:
		return 0.0
	return pow(attenuation, layers)


## Asennon vaikutus havaittavuuteen. Tuntematon asento lasketaan seisovaksi.
static func stance_factor(stance: int) -> float:
	if stance < 0 or stance >= STANCE_FACTORS.size():
		return 1.0
	return STANCE_FACTORS[stance]


## Mittarin täyttymisnopeus sekunnissa. Palauttaa 0, jos maali on näkömatkan ulkopuolella.
static func detection_rate(distance: float, max_distance: float, visibility: float, stance_mult: float,
		target_speed: float, fired_recently: bool, base_rate: float) -> float:
	if distance > max_distance or visibility <= 0.0:
		return 0.0
	var closeness := clampf(1.0 - distance / max_distance, 0.0, 1.0)
	var distance_factor := 0.2 + 1.8 * closeness
	var motion_factor := 1.0 + clampf(target_speed / 3.0, 0.0, 1.0)
	var firing_factor := 3.0 if fired_recently else 1.0
	return base_rate * distance_factor * visibility * stance_mult * motion_factor * firing_factor


## Yksi mittarin päivitysaskel. Kun maali näkyy (rate > 0), mittari ei tyhjene.
static func step_awareness(current: float, rate: float, decay: float, delta: float) -> float:
	if rate > 0.0:
		return clampf(current + rate * delta, 0.0, 1.0)
	return clampf(current - decay * delta, 0.0, 1.0)


# --- Julkinen rajapinta ---

## Tähtäyspiste maalissa: noin rintakehän korkeus asennosta riippumatta.
static func get_aim_point(target: Node3D) -> Vector3:
	var head := target.get_node_or_null("Head") as Node3D
	if head:
		return head.global_position.lerp(target.global_position, 0.3)
	return target.global_position + Vector3.UP * 1.1


## Nostaa valppautta esim. osuman jälkeen.
func alert(position: Vector3, level: float = HEARD_SHOT_AWARENESS) -> void:
	awareness = maxf(awareness, level)
	investigate_position = position


func is_suspicious() -> bool:
	return awareness >= SUSPICION_THRESHOLD


func forget_target() -> void:
	detected = false
	current_target = null
	awareness = minf(awareness, SUSPICION_THRESHOLD)


# --- Sisäinen ---

func _body() -> Node3D:
	if owner is Node3D:
		return owner as Node3D
	return get_parent() as Node3D


func _eye_position() -> Vector3:
	if eyes:
		return eyes.global_position
	return _body().global_position + Vector3.UP * 1.6


## Katsesuunta on vartalon vaakasuunta (pää kallistuu makuulla, mutta katse pysyy eteenpäin).
func _forward() -> Vector3:
	return -_body().global_basis.z


func _candidates() -> Array[Node3D]:
	var result: Array[Node3D] = []
	for group: StringName in [&"player", &"squad"]:
		for node: Node in get_tree().get_nodes_in_group(group):
			if node is Node3D and not result.has(node) and not _is_dead(node):
				result.append(node as Node3D)
	return result


static func _is_dead(node: Node) -> bool:
	var health := node.get_node_or_null("HealthComponent") as HealthComponent
	return health != null and health.health <= 0.0


static func _is_machine_gunner(node: Node) -> bool:
	return node.is_in_group(&"machine_gunner") or node.has_node("Head/MachineGun")


func _update_vision(step: float) -> void:
	var body := _body()
	if body == null or not body.is_inside_tree():
		return
	var eye := _eye_position()
	var forward := _forward()
	var best: Node3D = null
	var best_rate := 0.0
	var best_score := 0.0
	for target in _candidates():
		var point := get_aim_point(target)
		var distance := eye.distance_to(point)
		var in_cone := is_in_view_cone(eye, forward, point, fov_deg, view_distance) or distance <= proximity_radius
		if not in_cone:
			continue
		var visibility := _line_of_sight_visibility(eye, point, target)
		if visibility <= 0.0:
			continue
		var stance_value: Variant = target.get("stance")
		var stance_mult := stance_factor(stance_value as int) if stance_value is int else 1.0
		var speed := 0.0
		if target is CharacterBody3D:
			var v := (target as CharacterBody3D).velocity
			speed = Vector2(v.x, v.z).length()
		var rate := detection_rate(distance, view_distance, visibility, stance_mult, speed,
				_fired_recently(target), base_detection_rate)
		var score := rate * (machine_gunner_priority if _is_machine_gunner(target) else 1.0)
		# Jo havaittu maali pidetään, ellei parempaa löydy selvästi.
		if target == current_target:
			score *= 1.5
		if score > best_score:
			best_score = score
			best_rate = rate
			best = target

	has_line_of_sight = best != null
	if best:
		awareness = step_awareness(awareness, best_rate, awareness_decay, step)
		current_target = best
		last_known_position = best.global_position
		investigate_position = best.global_position
		time_since_seen = 0.0
		if awareness >= DETECTION_THRESHOLD and not detected:
			detected = true
			target_detected.emit(best)
	else:
		if not detected:
			awareness = step_awareness(awareness, 0.0, awareness_decay, step)
		elif time_since_seen > forget_time:
			forget_target()
			target_lost.emit()


## Näkyvyys 0–1: world-kerros estää täysin, jokainen kasvillisuuskerros heikentää.
func _line_of_sight_visibility(from: Vector3, to: Vector3, target: Node3D) -> float:
	var space := _body().get_world_3d().direct_space_state
	var exclude: Array[RID] = []
	if _body() is CollisionObject3D:
		exclude.append((_body() as CollisionObject3D).get_rid())
	if target is CollisionObject3D:
		exclude.append((target as CollisionObject3D).get_rid())

	var world_query := PhysicsRayQueryParameters3D.create(from, to, LAYER_WORLD, exclude)
	if not space.intersect_ray(world_query).is_empty():
		return 0.0

	var layers := 0
	var veg_exclude: Array[RID] = exclude.duplicate()
	while layers < max_vegetation_layers:
		var query := PhysicsRayQueryParameters3D.create(from, to, LAYER_VEGETATION, veg_exclude)
		query.collide_with_areas = true
		var hit := space.intersect_ray(query)
		if hit.is_empty():
			break
		veg_exclude.append(hit.rid as RID)
		layers += 1
	return vegetation_visibility(layers, vegetation_attenuation, max_vegetation_layers)


func _fired_recently(target: Node3D) -> bool:
	if not _last_shot_time.has(target):
		return false
	return _now() - (_last_shot_time[target] as float) <= FIRING_MEMORY


static func _now() -> float:
	return Time.get_ticks_msec() / 1000.0


func _on_shot_fired(shooter: Node3D, origin: Vector3, _direction: Vector3) -> void:
	var body := _body()
	if shooter == body or body == null or not body.is_inside_tree() or not is_physics_processing():
		return
	if is_instance_valid(shooter):
		_last_shot_time[shooter] = _now()
		# Omien laukaukset eivät ole uhka.
		if shooter.is_in_group(&"enemy"):
			return
	var distance := origin.distance_to(body.global_position)
	if distance > hearing_range:
		return
	# Suunta-arvio epätarkkenee etäisyyden myötä.
	var error := distance * 0.08
	var estimate := origin + Vector3(randf_range(-error, error), 0.0, randf_range(-error, error))
	alert(estimate)
	noise_heard.emit(estimate)
