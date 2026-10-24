class_name EnemyPatrolState
extends EnemyState
## Partioi: kävelee partiopisteiden välillä tai satunnaisesti spawnin ympärillä.

@export var wait_min: float = 1.5
@export var wait_max: float = 4.0

var _index: int = 0
var _wait: float = 0.0


func enter() -> void:
	enemy.set_stance(EnemyController.Stance.STAND)
	enemy.look_target = null
	_wait = randf_range(0.2, 1.0)
	enemy.stop()


func physics_update(delta: float) -> void:
	if perception.detected:
		machine.transition_to(&"Combat")
		return
	if perception.is_suspicious():
		machine.transition_to(&"Suspicious")
		return
	if _wait > 0.0:
		_wait -= delta
		if _wait <= 0.0:
			enemy.go_to(_next_point(), enemy.walk_speed)
		return
	if enemy.has_arrived(1.0) or enemy.is_stuck():
		enemy.stop()
		_wait = randf_range(wait_min, wait_max)


func _next_point() -> Vector3:
	var points: Array[Node3D] = []
	for point in enemy.patrol_points:
		if is_instance_valid(point):
			points.append(point)
	if points.is_empty():
		return enemy.random_patrol_point()
	_index = (_index + 1) % points.size()
	return enemy.closest_navigable_point(points[_index].global_position)
