class_name Bullet
extends Node3D
## Yksittäinen ammus. Etenee fysiikka-askelittain ja tarkistaa osuman säteellä edellisestä sijainnista.

const MAX_LIFETIME := 4.0

var shooter: Node3D
var velocity: Vector3
var damage: float

var _age: float = 0.0


func _physics_process(delta: float) -> void:
	_age += delta
	if _age > MAX_LIFETIME:
		queue_free()
		return
	velocity.y -= Ballistics.GRAVITY * delta
	var from := global_position
	var to := from + velocity * delta
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collide_with_areas = true
	if shooter is CollisionObject3D:
		query.exclude = [shooter.get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		global_position = to
		return
	var collider: Object = hit.collider
	if collider is Hitbox:
		collider.receive_hit(damage)
	queue_free()
