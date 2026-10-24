extends GutTest
## EnemyPerception-luokan näkökeilan ja havaintomittarin laskennan testit (M1-08).

const BASE_RATE := 1.2
const VIEW := 45.0


func test_point_ahead_is_in_cone() -> void:
	assert_true(EnemyPerception.is_in_view_cone(Vector3.ZERO, Vector3.FORWARD, Vector3(0, 0, -10), 120.0, VIEW))


func test_point_behind_is_not_in_cone() -> void:
	assert_false(EnemyPerception.is_in_view_cone(Vector3.ZERO, Vector3.FORWARD, Vector3(0, 0, 10), 120.0, VIEW))


func test_cone_edge() -> void:
	# 50° sivuun on 120° keilan sisällä, 70° ei ole.
	var inside := Vector3.FORWARD.rotated(Vector3.UP, deg_to_rad(50.0)) * 10.0
	var outside := Vector3.FORWARD.rotated(Vector3.UP, deg_to_rad(70.0)) * 10.0
	assert_true(EnemyPerception.is_in_view_cone(Vector3.ZERO, Vector3.FORWARD, inside, 120.0, VIEW))
	assert_false(EnemyPerception.is_in_view_cone(Vector3.ZERO, Vector3.FORWARD, outside, 120.0, VIEW))


func test_point_beyond_view_distance_is_not_in_cone() -> void:
	assert_false(EnemyPerception.is_in_view_cone(Vector3.ZERO, Vector3.FORWARD, Vector3(0, 0, -60), 120.0, VIEW))


func test_vegetation_reduces_visibility() -> void:
	assert_eq(EnemyPerception.vegetation_visibility(0, 0.45, 4), 1.0)
	assert_lt(EnemyPerception.vegetation_visibility(1, 0.45, 4), 1.0)
	assert_lt(EnemyPerception.vegetation_visibility(2, 0.45, 4), EnemyPerception.vegetation_visibility(1, 0.45, 4))
	assert_eq(EnemyPerception.vegetation_visibility(4, 0.45, 4), 0.0)


func test_prone_is_harder_to_see_than_standing() -> void:
	assert_lt(EnemyPerception.stance_factor(2), EnemyPerception.stance_factor(0))
	assert_eq(EnemyPerception.stance_factor(99), 1.0)


func test_rate_zero_outside_range() -> void:
	assert_eq(EnemyPerception.detection_rate(50.0, VIEW, 1.0, 1.0, 0.0, false, BASE_RATE), 0.0)


func test_closer_target_fills_faster() -> void:
	var near := EnemyPerception.detection_rate(5.0, VIEW, 1.0, 1.0, 0.0, false, BASE_RATE)
	var far := EnemyPerception.detection_rate(35.0, VIEW, 1.0, 1.0, 0.0, false, BASE_RATE)
	assert_gt(near, far)


func test_movement_and_firing_fill_faster() -> void:
	var still := EnemyPerception.detection_rate(20.0, VIEW, 1.0, 1.0, 0.0, false, BASE_RATE)
	var moving := EnemyPerception.detection_rate(20.0, VIEW, 1.0, 1.0, 3.0, false, BASE_RATE)
	var firing := EnemyPerception.detection_rate(20.0, VIEW, 1.0, 1.0, 0.0, true, BASE_RATE)
	assert_gt(moving, still)
	assert_gt(firing, moving)


func test_prone_in_vegetation_detected_much_later() -> void:
	var standing_open := EnemyPerception.detection_rate(20.0, VIEW, 1.0, EnemyPerception.stance_factor(0), 0.0, false, BASE_RATE)
	var prone_bush := EnemyPerception.detection_rate(20.0, VIEW, EnemyPerception.vegetation_visibility(1, 0.45, 4),
			EnemyPerception.stance_factor(2), 0.0, false, BASE_RATE)
	var time_open := _time_to_detect(standing_open)
	var time_bush := _time_to_detect(prone_bush)
	assert_gt(time_bush, time_open * 4.0, "Makuulla pensaassa havaitaan selvästi myöhemmin")


func test_awareness_clamped_and_decays() -> void:
	assert_eq(EnemyPerception.step_awareness(0.9, 10.0, 0.1, 1.0), 1.0)
	assert_almost_eq(EnemyPerception.step_awareness(0.5, 0.0, 0.1, 1.0), 0.4, 0.0001)
	assert_eq(EnemyPerception.step_awareness(0.05, 0.0, 0.1, 1.0), 0.0)


func test_heard_shot_makes_suspicious() -> void:
	var perception := EnemyPerception.new()
	add_child_autofree(perception)
	perception.alert(Vector3(5, 0, 5))
	assert_true(perception.is_suspicious())
	assert_eq(perception.investigate_position, Vector3(5, 0, 5))


func _time_to_detect(rate: float) -> float:
	var awareness := 0.0
	var time := 0.0
	while awareness < EnemyPerception.DETECTION_THRESHOLD and time < 120.0:
		awareness = EnemyPerception.step_awareness(awareness, rate, 0.08, 0.1)
		time += 0.1
	return time
