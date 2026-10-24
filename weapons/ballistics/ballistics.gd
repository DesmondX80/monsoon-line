class_name Ballistics
extends RefCounted
## Realistinen ballistiikka: jokainen luoti on ammus, jolla on lentoaika ja pudotus.
## TODO(gameplay-agentti): läpäisy, kimmokkeet ja ohilentojen "snap" (EventBus.bullet_snap).

const GRAVITY := 9.81


static func fire(shooter: Node3D, origin: Vector3, direction: Vector3, data: WeaponData) -> void:
	EventBus.shot_fired.emit(shooter, origin, direction)
	var bullet := Bullet.new()
	bullet.shooter = shooter
	bullet.velocity = direction * data.muzzle_velocity
	bullet.damage = data.damage
	shooter.get_tree().current_scene.add_child(bullet)
	bullet.global_position = origin
