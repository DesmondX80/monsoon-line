extends Node
## Testien vale-ParachuteController: tallentaa start_jump-kutsun.

var exit_velocities: Array[Vector3] = []
var airborne: bool = false


func start_jump(exit_velocity: Vector3) -> void:
	exit_velocities.append(exit_velocity)
	airborne = true
	EventBus.jump_started.emit(get_parent() as Node3D)


func is_airborne() -> bool:
	return airborne
