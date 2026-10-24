extends GutTest
## M1-02: ohilentotukahdutus. Janan ja pisteen etäisyys sekä Bulletin ohilentorekisteröinti.


func _make_actor(position: Vector3) -> Node3D:
	var actor := Node3D.new()
	var suppression := SuppressionComponent.new()
	suppression.name = "SuppressionComponent"
	suppression.listener_height = 0.0
	actor.add_child(suppression)
	add_child_autofree(actor)
	actor.global_position = position
	actor.add_to_group(Bullet.SUPPRESSIBLE_GROUP)
	return actor


func _suppression_of(actor: Node3D) -> SuppressionComponent:
	return actor.get_node("SuppressionComponent") as SuppressionComponent


func _make_bullet(shooter: Node3D = null) -> Bullet:
	var bullet := Bullet.new()
	bullet.shooter = shooter
	bullet.set_physics_process(false)
	add_child_autofree(bullet)
	return bullet


# --- Ballistics.distance_point_to_segment ---

func test_distance_perpendicular_to_middle() -> void:
	var d := Ballistics.distance_point_to_segment(Vector3(0, 2, 5), Vector3.ZERO, Vector3(0, 0, 10))
	assert_almost_eq(d, 2.0, 0.0001)


func test_distance_before_segment_start_uses_endpoint_a() -> void:
	var d := Ballistics.distance_point_to_segment(Vector3(0, 0, -3), Vector3.ZERO, Vector3(0, 0, 10))
	assert_almost_eq(d, 3.0, 0.0001)


func test_distance_past_segment_end_uses_endpoint_b() -> void:
	var d := Ballistics.distance_point_to_segment(Vector3(3, 0, 14), Vector3.ZERO, Vector3(0, 0, 10))
	assert_almost_eq(d, 5.0, 0.0001)


func test_distance_point_on_segment_is_zero() -> void:
	var d := Ballistics.distance_point_to_segment(Vector3(1, 1, 1), Vector3.ZERO, Vector3(2, 2, 2))
	assert_almost_eq(d, 0.0, 0.0001)


func test_distance_degenerate_segment() -> void:
	var d := Ballistics.distance_point_to_segment(Vector3(0, 4, 0), Vector3(0, 1, 0), Vector3(0, 1, 0))
	assert_almost_eq(d, 3.0, 0.0001)


# --- Bullet.check_near_misses ---

func test_near_bullet_raises_suppression() -> void:
	var actor := _make_actor(Vector3(1.0, 0, 5))
	var bullet := _make_bullet()
	var count := bullet.check_near_misses(Vector3.ZERO, Vector3(0, 0, 10), [actor] as Array[Node])
	assert_eq(count, 1)
	assert_gt(_suppression_of(actor).amount, 0.0)


func test_far_bullet_does_not_raise_suppression() -> void:
	var actor := _make_actor(Vector3(20.0, 0, 5))
	var bullet := _make_bullet()
	var count := bullet.check_near_misses(Vector3.ZERO, Vector3(0, 0, 10), [actor] as Array[Node])
	assert_eq(count, 0)
	assert_eq(_suppression_of(actor).amount, 0.0)


func test_same_bullet_registers_actor_only_once() -> void:
	var actor := _make_actor(Vector3(1.0, 0, 5))
	var bullet := _make_bullet()
	var actors: Array[Node] = [actor]
	bullet.check_near_misses(Vector3.ZERO, Vector3(0, 0, 4), actors)
	var after_first := _suppression_of(actor).amount
	var second := bullet.check_near_misses(Vector3(0, 0, 4), Vector3(0, 0, 8), actors)
	assert_eq(second, 0)
	assert_eq(_suppression_of(actor).amount, after_first)


func test_different_bullets_both_register() -> void:
	var actor := _make_actor(Vector3(1.0, 0, 5))
	var actors: Array[Node] = [actor]
	_make_bullet().check_near_misses(Vector3.ZERO, Vector3(0, 0, 10), actors)
	var after_first := _suppression_of(actor).amount
	_make_bullet().check_near_misses(Vector3.ZERO, Vector3(0, 0, 10), actors)
	assert_gt(_suppression_of(actor).amount, after_first)


func test_shooter_is_not_suppressed_by_own_bullet() -> void:
	var shooter := _make_actor(Vector3.ZERO)
	var bullet := _make_bullet(shooter)
	var count := bullet.check_near_misses(Vector3.ZERO, Vector3(0, 0, 10), [shooter] as Array[Node])
	assert_eq(count, 0)
	assert_eq(_suppression_of(shooter).amount, 0.0)


func test_actor_without_component_is_ignored() -> void:
	var plain := Node3D.new()
	add_child_autofree(plain)
	var bullet := _make_bullet()
	assert_eq(bullet.check_near_misses(Vector3.ZERO, Vector3(0, 0, 10), [plain] as Array[Node]), 0)


func test_bullet_snap_signal_emitted() -> void:
	watch_signals(EventBus)
	var actor := _make_actor(Vector3(0.5, 0, 5))
	_make_bullet().check_near_misses(Vector3.ZERO, Vector3(0, 0, 10), [actor] as Array[Node])
	assert_signal_emitted(EventBus, "bullet_snap")


func test_listener_uses_head_node_when_present() -> void:
	var actor := _make_actor(Vector3.ZERO)
	var head := Node3D.new()
	head.name = "Head"
	actor.add_child(head)
	head.position = Vector3(0, 1.65, 0)
	assert_almost_eq(_suppression_of(actor).listener_position().y, 1.65, 0.0001)
