extends GutTest
## Viet Cong -kiväärimiehen testit (M1-07, M1-09).

const ENEMY_SCENE := preload("res://ai/enemy/enemy.tscn")

var enemy: EnemyController


func before_each() -> void:
	enemy = ENEMY_SCENE.instantiate() as EnemyController
	add_child_autofree(enemy)


func test_type56_data() -> void:
	var data := load("res://weapons/resources/type56.tres") as WeaponData
	assert_eq(data.magazine_size, 30)
	assert_almost_eq(data.rounds_per_minute, 650.0, 1.0)
	assert_almost_eq(data.muzzle_velocity, 715.0, 1.0)


func test_enemy_groups_and_components() -> void:
	assert_true(enemy.is_in_group(&"suppressible"))
	assert_true(enemy.is_in_group(&"enemy"))
	assert_not_null(enemy.get_node_or_null("SuppressionComponent"))
	assert_not_null(enemy.get_node_or_null("HealthComponent"))
	assert_eq(enemy.collision_layer, 1 << 3, "Vihollisen kerros 4")


func test_hitboxes_cover_body_parts() -> void:
	var parts: Array[StringName] = []
	for node: Node in enemy.find_children("*", "Hitbox", true, false):
		var hitbox := node as Hitbox
		assert_eq(hitbox.collision_layer, 1 << 4, "Hitbox-kerros 5")
		parts.append(hitbox.body_part)
	for part: StringName in [&"head", &"torso", &"arm_l", &"arm_r", &"leg_l", &"leg_r"]:
		assert_has(parts, part)


func test_starts_patrolling() -> void:
	assert_eq(enemy.state_machine.current.name, &"Patrol")


func test_head_hit_kills() -> void:
	(enemy.get_node("Body/Head/HeadHitbox") as Hitbox).receive_hit(10.0)
	assert_true(enemy.is_dead())
	assert_eq(enemy.state_machine.current.name, &"Dead")
	assert_false(enemy.is_in_group(&"suppressible"))


func test_leg_hit_slows() -> void:
	var before := enemy.speed_multiplier()
	(enemy.get_node("Body/LegL/LegLHitbox") as Hitbox).receive_hit(20.0)
	assert_false(enemy.is_dead())
	assert_lt(enemy.speed_multiplier(), before)


func test_pinned_enemy_goes_prone() -> void:
	for i in 10:
		enemy.suppression.register_near_miss(0.0)
	await wait_physics_frames(2)
	assert_eq(enemy.state_machine.current.name, &"Suppressed")
	assert_eq(enemy.stance, EnemyController.Stance.PRONE)


func test_spread_grows_with_distance_and_suppression() -> void:
	var base := EnemyController.compute_spread_deg(10.0, 0.0, 1.2, 0.06, 8.0, false)
	var far := EnemyController.compute_spread_deg(50.0, 0.0, 1.2, 0.06, 8.0, false)
	var suppressed := EnemyController.compute_spread_deg(10.0, 1.0, 1.2, 0.06, 8.0, false)
	var wounded := EnemyController.compute_spread_deg(10.0, 0.0, 1.2, 0.06, 8.0, true)
	assert_gt(far, base)
	assert_gt(suppressed, base)
	assert_gt(wounded, base)


func test_fire_uses_ammo() -> void:
	var shots: Array[int] = [0]
	var counter := func(shooter: Node3D, _o: Vector3, _d: Vector3) -> void:
		if shooter == enemy:
			shots[0] += 1
	EventBus.shot_fired.connect(counter)
	assert_true(enemy.fire_at(enemy.global_position + Vector3(0, 1.2, -20)))
	EventBus.shot_fired.disconnect(counter)
	assert_eq(shots[0], 1)
	assert_eq(enemy.rounds_in_magazine, enemy.weapon_data.magazine_size - 1)
