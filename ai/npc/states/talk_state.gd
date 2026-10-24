class_name DrillSergeantTalkState
extends DrillSergeantState
## Puhuu: katsoo pelaajaa, keinuttaa vartaloa ja osoittaa oikealla kädellä.

## Käsivarren nosto eteenpäin (radiaaneina X-akselin ympäri).
@export var point_angle: float = 1.25
@export var point_wave: float = 0.35
@export var bob_height: float = 0.03

var _phase: float = 0.0


func enter() -> void:
	_phase = 0.0
	sergeant.velocity.x = 0.0
	sergeant.velocity.z = 0.0


func exit() -> void:
	sergeant.body_pivot.position = Vector3.ZERO
	sergeant.point_arm.rotation.x = 0.0


func physics_update(delta: float) -> void:
	if sergeant.has_target and not sergeant.has_arrived():
		machine.transition_to(&"Walk")
		return
	if not sergeant.is_talking():
		machine.transition_to(&"Idle")
		return
	_phase += delta
	sergeant.face_player(delta)
	sergeant.body_pivot.position.y = absf(sin(_phase * 8.0)) * bob_height
	var target_angle := point_angle + sin(_phase * 6.0) * point_wave
	sergeant.point_arm.rotation.x = lerpf(sergeant.point_arm.rotation.x, target_angle, minf(10.0 * delta, 1.0))
