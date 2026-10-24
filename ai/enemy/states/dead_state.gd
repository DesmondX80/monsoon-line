class_name EnemyDeadState
extends EnemyState
## Kuollut: kaatuu maahan, lopettaa havainnoinnin ja poistuu osuma- ja hahmokerroksilta.


func enter() -> void:
	enemy.stop()
	enemy.set_stance(EnemyController.Stance.PRONE)
	enemy.look_target = null
	perception.set_physics_process(false)
	enemy.remove_from_group(&"enemy")
	enemy.remove_from_group(&"suppressible")
	# Ruumis jää maahan (törmää maailmaan), mutta ei enää ota osumia eikä estä hahmoja.
	enemy.set_deferred("collision_layer", 0)
	for node: Node in enemy.find_children("*", "Hitbox", true, false):
		var hitbox := node as Hitbox
		hitbox.set_deferred("monitorable", false)
		hitbox.set_deferred("collision_layer", 0)
	enemy.body_pivot.rotation.x = deg_to_rad(-90.0)
	enemy.body_pivot.position = EnemyController.BODY_PIVOT_OFFSET[EnemyController.Stance.PRONE] as Vector3
