class_name EnemySuspiciousState
extends EnemyState
## Epäilee: kyyristyy, kääntyy äänen suuntaan ja hiipii tutkimaan.
## Palaa partioon, jos mitään ei löydy.

@export var listen_time: float = 1.5
@export var give_up_time: float = 15.0

var _timer: float = 0.0
var _listening: float = 0.0
var _spot: Vector3


func enter() -> void:
	enemy.set_stance(EnemyController.Stance.CROUCH)
	enemy.stop()
	_spot = perception.investigate_position
	enemy.look_target = _spot
	_timer = 0.0
	_listening = listen_time


func exit() -> void:
	enemy.look_target = null


func physics_update(delta: float) -> void:
	if perception.detected:
		machine.transition_to(&"Combat")
		return
	_timer += delta
	# Uusi ääni: käännytään ja kuunnellaan uudelleen.
	if not perception.investigate_position.is_equal_approx(_spot):
		_spot = perception.investigate_position
		_listening = listen_time * 0.5
		_timer = 0.0
		enemy.stop()
	if _listening > 0.0:
		_listening -= delta
		enemy.look_target = _spot
		return
	if enemy.has_arrived(2.0) or enemy.is_stuck():
		enemy.stop()
		enemy.look_target = _spot
	else:
		enemy.look_target = null
		enemy.go_to(enemy.closest_navigable_point(_spot), enemy.walk_speed)
	if _timer > give_up_time:
		perception.awareness = 0.0
		machine.transition_to(&"Patrol")
