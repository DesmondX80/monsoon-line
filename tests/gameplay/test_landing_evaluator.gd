extends GutTest
## M2-03: laskeutumisen arviointi (PLF-ajoitus ja nopeusrajat).

var evaluator: LandingEvaluator


func before_each() -> void:
	evaluator = LandingEvaluator.new()


func test_plf_inside_window_is_good() -> void:
	assert_eq(evaluator.evaluate(5.0, 0.1), LandingEvaluator.GOOD)
	assert_eq(evaluator.evaluate(5.0, 0.3), LandingEvaluator.GOOD)
	assert_eq(evaluator.evaluate(5.0, 0.5), LandingEvaluator.GOOD)


func test_plf_too_late_is_hard() -> void:
	assert_eq(evaluator.evaluate(5.0, 0.05), LandingEvaluator.HARD)
	assert_eq(evaluator.evaluate(5.0, 0.0), LandingEvaluator.HARD)


func test_plf_too_early_is_hard() -> void:
	assert_eq(evaluator.evaluate(5.0, 0.51), LandingEvaluator.HARD)
	assert_eq(evaluator.evaluate(5.0, 2.0), LandingEvaluator.HARD)


func test_no_plf_is_hard() -> void:
	assert_eq(evaluator.evaluate(5.0, INF), LandingEvaluator.HARD)


func test_speed_at_limit_is_not_injury() -> void:
	assert_eq(evaluator.evaluate(8.0, 0.3), LandingEvaluator.GOOD)


func test_speed_over_limit_is_injured_even_with_plf() -> void:
	assert_eq(evaluator.evaluate(8.01, 0.3), LandingEvaluator.INJURED)
	assert_eq(evaluator.evaluate(30.0, INF), LandingEvaluator.INJURED)


func test_jump_tower_height_is_significant_fall() -> void:
	assert_true(evaluator.is_significant_fall(10.0))
	assert_true(evaluator.is_significant_fall(2.1))
	assert_false(evaluator.is_significant_fall(2.0))
	assert_false(evaluator.is_significant_fall(0.5))


func test_consequences_grow_with_severity() -> void:
	assert_lt(evaluator.get_stamina_cost(LandingEvaluator.GOOD), evaluator.get_stamina_cost(LandingEvaluator.HARD))
	assert_lt(evaluator.get_stamina_cost(LandingEvaluator.HARD), evaluator.get_stamina_cost(LandingEvaluator.INJURED))
	assert_eq(evaluator.get_stun_time(LandingEvaluator.GOOD), 0.0)
	assert_gt(evaluator.get_stun_time(LandingEvaluator.HARD), 0.0)


func test_injured_leg_is_left_or_right() -> void:
	assert_eq(evaluator.injured_leg(0.1), LandingEvaluator.LEG_LEFT)
	assert_eq(evaluator.injured_leg(0.9), LandingEvaluator.LEG_RIGHT)
