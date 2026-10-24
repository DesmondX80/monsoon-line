class_name DrillSergeantIdleState
extends DrillSergeantState
## Seisoo paikallaan ja katsoo pelaajaa.


func enter() -> void:
	sergeant.velocity.x = 0.0
	sergeant.velocity.z = 0.0


func physics_update(delta: float) -> void:
	if sergeant.has_target and not sergeant.has_arrived():
		machine.transition_to(&"Walk")
		return
	if sergeant.is_talking():
		machine.transition_to(&"Talk")
		return
	sergeant.face_player(delta)
