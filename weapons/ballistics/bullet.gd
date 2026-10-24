class_name Bullet
extends Node3D
## Yksittäinen ammus. Etenee fysiikka-askelittain ja tarkistaa osuman säteellä edellisestä sijainnista.
## Jokaisella askeleella tarkistetaan myös ohilennot: ryhmän "suppressible" toimijat, joiden
## kuuntelupiste on alle snap_radiuksen päässä luodin janasta, saavat register_near_miss-kutsun
## kerran per luoti.

const MAX_LIFETIME := 4.0
const SUPPRESSIBLE_GROUP := &"suppressible"

var shooter: Node3D
var velocity: Vector3
var damage: float
## Törmäystarkistuksesta pois jätettävät RID:t (ampuja ja sen hitboxit).
var exclude: Array[RID] = []

var _age: float = 0.0
## Toimijat (instance id), joille tämä luoti on jo rekisteröinyt ohilennon.
var _snapped: Dictionary = {}


func _physics_process(delta: float) -> void:
	_age += delta
	if _age > MAX_LIFETIME:
		queue_free()
		return
	velocity.y -= Ballistics.GRAVITY * delta
	var from := global_position
	var to := from + velocity * delta
	var query := PhysicsRayQueryParameters3D.create(from, to, Ballistics.BULLET_COLLISION_MASK, exclude)
	query.collide_with_areas = true
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	var segment_end: Vector3 = to if hit.is_empty() else hit.position
	check_near_misses(from, segment_end, get_tree().get_nodes_in_group(SUPPRESSIBLE_GROUP))
	if hit.is_empty():
		global_position = to
		return
	var collider: Object = hit.collider
	if collider is Hitbox:
		(collider as Hitbox).receive_hit(damage)
	queue_free()


## Tarkistaa janan from–to ohilennot annetuille toimijoille. Palauttaa tällä kutsulla
## rekisteröityjen toimijoiden määrän. Erillinen funktio, jotta logiikka on testattavissa ilman fysiikkaa.
func check_near_misses(from: Vector3, to: Vector3, actors: Array[Node]) -> int:
	var registered := 0
	for node: Node in actors:
		var actor := node as Node3D
		if actor == null or actor == shooter or not actor.is_inside_tree():
			continue
		var id := actor.get_instance_id()
		if _snapped.has(id):
			continue
		var suppression := actor.get_node_or_null(^"SuppressionComponent") as SuppressionComponent
		if suppression == null:
			continue
		var distance := Ballistics.distance_point_to_segment(suppression.listener_position(), from, to)
		if distance > suppression.snap_radius:
			continue
		_snapped[id] = true
		suppression.register_near_miss(distance)
		EventBus.bullet_snap.emit(actor, distance)
		registered += 1
	return registered
