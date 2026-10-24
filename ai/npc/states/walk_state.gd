class_name DrillSergeantWalkState
extends DrillSergeantState
## Kävelee kohteeseen. Perillä lähettää arrived-signaalin ja jää katsomaan pelaajaa.


func physics_update(delta: float) -> void:
	if not sergeant.has_target or sergeant.has_arrived():
		var was_moving := sergeant.has_target
		sergeant.stop()
		if was_moving:
			sergeant.arrived.emit()
		machine.transition_to(&"Talk" if sergeant.is_talking() else &"Idle")
		return
	var horizontal := sergeant.move_along_path()
	if horizontal != Vector3.ZERO:
		sergeant.face_toward(sergeant.global_position + horizontal, delta)
