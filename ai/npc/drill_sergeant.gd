class_name DrillSergeant
extends CharacterBody3D
## Kersantti Roscoe Tibbs (M2-04), laskuvarjokoulun kouluttaja Fort Benningissä 1966.
##
## Ei taistele: liikkuu navigaatiolla asemalta toiselle, kääntyy pelaajaa kohti ja
## elehtii puhuessaan. Päätöksenteko on tilakoneen tiloissa (ai/npc/states/):
## Idle (katsoo pelaajaa), Walk (navigoi kohteeseen), Talk (elehtii ja katsoo pelaajaa).
##
## Ohjaaja (PrologueDirector) kutsuu walk_to() ja say(); repliikin tekstitys ja ääni
## kulkevat EventBus.squad_callout-signaalilla, jonka ohjaaja lähettää.
## Tibbs ei kuulu ryhmiin "enemy" eikä "suppressible".

signal arrived

@export var walk_speed: float = 2.4
@export var turn_speed: float = 6.0
## Kuinka lähellä kohdetta (vaakatasossa) katsotaan perille päästyksi.
@export var arrive_tolerance: float = 0.8
## Elehdinnän oletuskesto, jos say() ei saa kestoa.
@export var talk_duration: float = 2.5

@onready var nav_agent: NavigationAgent3D = $NavigationAgent3D
@onready var state_machine: StateMachine = $StateMachine
@onready var body_pivot: Node3D = $Body
@onready var point_arm: Node3D = $Body/ArmR

var move_target: Vector3 = Vector3.ZERO
var has_target: bool = false
var current_line: StringName = &""
var talk_time_left: float = 0.0

var _player: Node3D
var _player_search: float = 0.0


func _ready() -> void:
	add_to_group(&"npc")
	add_to_group(&"drill_sergeant")
	move_target = global_position
	state_machine.transition_to(&"Idle")


func _physics_process(delta: float) -> void:
	talk_time_left = maxf(talk_time_left - delta, 0.0)
	_player_search -= delta
	if not is_instance_valid(_player) or _player_search <= 0.0:
		_player_search = 0.5
		_player = get_tree().get_first_node_in_group(&"player") as Node3D
	if not is_on_floor():
		velocity += get_gravity() * delta
	elif velocity.y < 0.0:
		velocity.y = 0.0
	move_and_slide()


# --- Ohjaajan rajapinta ---

## Kävelee kohteeseen navigaatioverkkoa pitkin. Ilman verkkoa kuljetaan suoraan kohti.
func walk_to(target: Vector3) -> void:
	move_target = target
	has_target = true
	nav_agent.target_position = target
	if state_machine.current == null or state_machine.current.name != &"Walk":
		state_machine.transition_to(&"Walk")


func stop() -> void:
	has_target = false
	move_target = global_position
	velocity.x = 0.0
	velocity.z = 0.0


## Siirtää Tibbsin heti paikalleen (spawn tai jumiutumisen varatoiminto).
func teleport_to(target: Transform3D) -> void:
	global_transform = target
	stop()


func has_arrived() -> bool:
	var flat := Vector2(global_position.x - move_target.x, global_position.z - move_target.z)
	return flat.length() <= arrive_tolerance


## Aloittaa puhe-elehdinnän. Itse repliikin lähettää ohjaaja EventBusiin.
func say(line_id: StringName, duration: float = -1.0) -> void:
	current_line = line_id
	talk_time_left = duration if duration > 0.0 else talk_duration
	if state_machine.current != null and state_machine.current.name == &"Idle":
		state_machine.transition_to(&"Talk")


func is_talking() -> bool:
	return talk_time_left > 0.0


func is_walking() -> bool:
	return state_machine.current != null and state_machine.current.name == &"Walk"


func get_player() -> Node3D:
	return _player if is_instance_valid(_player) else null


# --- Tilojen apufunktiot ---

## Liikuttaa vaakatasossa kohti seuraavaa reittipistettä. Palauttaa liikesuunnan.
func move_along_path() -> Vector3:
	var next := _next_path_point()
	var to_next := next - global_position
	to_next.y = 0.0
	var horizontal := Vector3.ZERO
	if to_next.length() > 0.05:
		horizontal = to_next.normalized() * walk_speed
	velocity.x = horizontal.x
	velocity.z = horizontal.z
	return horizontal


## Kääntyy vaakatasossa kohti pistettä.
func face_toward(point: Vector3, delta: float) -> void:
	var dir := point - global_position
	dir.y = 0.0
	if dir.length() > 0.05:
		var yaw := atan2(-dir.x, -dir.z)
		rotation.y = lerp_angle(rotation.y, yaw, turn_speed * delta)


func face_player(delta: float) -> void:
	var player := get_player()
	if player:
		face_toward(player.global_position, delta)


func _next_path_point() -> Vector3:
	var map := nav_agent.get_navigation_map()
	if not map.is_valid() or NavigationServer3D.map_get_iteration_id(map) == 0 \
			or NavigationServer3D.map_get_regions(map).is_empty():
		return move_target
	# get_next_path_position() päivittää reitin tarvittaessa, joten sitä kutsutaan ensin.
	var next := nav_agent.get_next_path_position()
	if nav_agent.get_current_navigation_path().is_empty():
		return move_target
	if nav_agent.is_navigation_finished():
		return move_target if not nav_agent.is_target_reachable() else global_position
	return next
