class_name EnemyCombatState
extends EnemyState
## Taistelee: ampuu 2–4 laukauksen sarjoja maalia kohti. Ilman näköyhteyttä etenee
## viimeisimpään tunnettuun sijaintiin.

@export var burst_min: int = 2
@export var burst_max: int = 4
@export var pause_min: float = 0.6
@export var pause_max: float = 1.6
## Ennen ensimmäistä sarjaa kuluva reaktioaika.
@export var reaction_time: float = 0.5

var _burst_left: int = 0
var _pause: float = 0.0


func enter() -> void:
	enemy.set_stance(EnemyController.Stance.CROUCH)
	enemy.stop()
	_burst_left = 0
	_pause = reaction_time


func exit() -> void:
	enemy.look_target = null


func physics_update(delta: float) -> void:
	var target := perception.current_target
	if not perception.detected or target == null or not is_instance_valid(target):
		perception.forget_target()
		machine.transition_to(&"Suspicious")
		return
	if perception.has_line_of_sight:
		_engage(target, delta)
	else:
		# Ei näköyhteyttä: edetään viimeksi nähtyyn kohtaan.
		enemy.look_target = null
		var spot := enemy.closest_navigable_point(perception.last_known_position)
		if enemy.has_arrived(2.5) or enemy.is_stuck():
			enemy.stop()
			enemy.look_target = perception.last_known_position
		else:
			enemy.go_to(spot, enemy.run_speed)


func _engage(target: Node3D, delta: float) -> void:
	enemy.look_target = target.global_position
	var distance := enemy.global_position.distance_to(target.global_position)
	if distance > enemy.effective_range:
		enemy.go_to(enemy.closest_navigable_point(target.global_position), enemy.run_speed)
		return
	enemy.stop()
	if not _is_facing(target.global_position):
		return
	if _pause > 0.0:
		_pause -= delta
		if _pause <= 0.0:
			_burst_left = randi_range(burst_min, burst_max)
		return
	if _burst_left <= 0:
		_pause = randf_range(pause_min, pause_max)
		return
	if enemy.fire_at(EnemyPerception.get_aim_point(target)):
		_burst_left -= 1
		if _burst_left == 0:
			_pause = randf_range(pause_min, pause_max)
	elif enemy.reloading:
		_burst_left = 0
		_pause = enemy.weapon_data.reload_time


func _is_facing(point: Vector3) -> bool:
	var to_point := point - enemy.global_position
	to_point.y = 0.0
	if to_point.length() < 0.1:
		return true
	var forward := -enemy.global_basis.z
	forward.y = 0.0
	return forward.normalized().dot(to_point.normalized()) > 0.95
