extends GutTest
## M2-03: laskuvarjohypyn vaiheet ja laskeutumisen seuraukset. Simuloidaan tick()- ja
## report_motion()-kutsuilla ilman todellista fysiikkaa.

const STEP := 1.0 / 60.0

var jumper: Node3D
var chute: ParachuteController
var health: HealthComponent
var stamina: StaminaModel


func before_each() -> void:
	jumper = Node3D.new()
	chute = ParachuteController.new()
	jumper.add_child(chute)
	add_child_autofree(jumper)
	chute.rng.seed = 42
	health = HealthComponent.new()
	add_child_autofree(health)
	stamina = StaminaModel.new()
	chute.setup(health, stamina)


## Simuloi hypyn alkaen korkeudelta height. Palauttaa laskeutumisen laadun.
## plf_lead = sekunteja ennen kosketusta, jolloin crouch painetaan (< 0 = ei painallusta).
func _simulate_jump(height: float, plf_lead: float = -1.0, max_time: float = 300.0) -> StringName:
	var velocity := Vector3(4.0, 0.0, 0.0)
	var y := height
	var t := 0.0
	var plf_done := false
	while t < max_time:
		velocity = chute.tick(STEP, velocity, Vector3.ZERO)
		var fall_speed := -velocity.y
		y += velocity.y * STEP
		var on_floor := y <= 0.0
		if not plf_done and plf_lead >= 0.0 and velocity.y < 0.0 and y + velocity.y * plf_lead <= 0.0:
			chute.register_plf()
			plf_done = true
		var quality := chute.report_motion(on_floor, maxf(y, 0.0), fall_speed)
		if quality != &"":
			return quality
		t += STEP
	return &""


func test_starts_idle_on_ground() -> void:
	assert_eq(chute.get_phase(), ParachuteController.Phase.IDLE)
	assert_false(chute.is_airborne())


func test_start_jump_enters_exit_and_emits() -> void:
	watch_signals(EventBus)
	chute.start_jump(Vector3(3.0, 0.0, 0.0))
	assert_eq(chute.phase, ParachuteController.Phase.EXIT)
	assert_true(chute.is_airborne())
	assert_signal_emitted_with_parameters(EventBus, "jump_started", [jumper])


func test_first_exit_tick_uses_exit_velocity() -> void:
	chute.start_jump(Vector3(6.0, 1.0, 0.0))
	var v := chute.tick(STEP, Vector3.ZERO, Vector3.ZERO)
	assert_almost_eq(v.x, 6.0, 0.1)


func test_canopy_opens_automatically_after_exit_duration() -> void:
	watch_signals(EventBus)
	chute.start_jump(Vector3.ZERO)
	var velocity := Vector3.ZERO
	var t := 0.0
	while t < chute.exit_duration - 0.1:
		velocity = chute.tick(STEP, velocity, Vector3.ZERO)
		t += STEP
	assert_eq(chute.phase, ParachuteController.Phase.EXIT)
	assert_signal_not_emitted(EventBus, "chute_opened")
	for i in 12:
		velocity = chute.tick(STEP, velocity, Vector3.ZERO)
	assert_eq(chute.phase, ParachuteController.Phase.CANOPY)
	assert_signal_emitted_with_parameters(EventBus, "chute_opened", [jumper])
	assert_lt(chute.get_camera_jolt_deg(), 0.0, "avautumisnykäys heilauttaa kameraa")


func test_exit_drag_limits_fall_speed() -> void:
	chute.exit_duration = 100.0
	chute.start_jump(Vector3.ZERO)
	var velocity := Vector3.ZERO
	for i in 60 * 30:
		velocity = chute.tick(STEP, velocity, Vector3.ZERO)
	assert_lt(-velocity.y, 60.0)
	assert_gt(-velocity.y, 45.0)


func test_canopy_settles_to_descent_speed() -> void:
	chute.start_jump(Vector3.ZERO)
	var velocity := Vector3.ZERO
	for i in int((chute.exit_duration + 6.0) / STEP):
		velocity = chute.tick(STEP, velocity, Vector3.ZERO)
	assert_eq(chute.phase, ParachuteController.Phase.CANOPY)
	assert_almost_eq(-velocity.y, chute.canopy_descent_speed, 0.1)


func test_canopy_steering_is_slow_and_capped() -> void:
	chute.start_jump(Vector3.ZERO)
	var velocity := Vector3.ZERO
	for i in int(chute.exit_duration / STEP) + 2:
		velocity = chute.tick(STEP, velocity, Vector3.ZERO)
	velocity = Vector3(0.0, velocity.y, 0.0)
	velocity = chute.tick(STEP, velocity, Vector3(0.0, 0.0, -1.0))
	assert_lt(absf(velocity.z), 0.5, "ohjaus reagoi hitaasti")
	for i in 60 * 10:
		velocity = chute.tick(STEP, velocity, Vector3(0.0, 0.0, -1.0))
	assert_almost_eq(velocity.z, -chute.steer_speed, 0.1)


func test_full_jump_with_plf_lands_good() -> void:
	watch_signals(EventBus)
	chute.start_jump(Vector3(4.0, 0.0, 0.0))
	var quality := _simulate_jump(300.0, 0.3)
	assert_eq(quality, LandingEvaluator.GOOD)
	assert_eq(chute.phase, ParachuteController.Phase.LANDED)
	assert_false(chute.is_airborne())
	assert_signal_emitted_with_parameters(EventBus, "landed", [jumper, LandingEvaluator.GOOD])
	assert_signal_emit_count(EventBus, "chute_opened", 1)


func test_full_jump_without_plf_lands_hard() -> void:
	chute.start_jump(Vector3(4.0, 0.0, 0.0))
	assert_eq(_simulate_jump(300.0), LandingEvaluator.HARD)
	assert_true(chute.is_stunned())
	assert_eq(health.disabled_parts.size(), 0)


func test_no_chute_is_injured_with_leg_hit() -> void:
	chute.exit_duration = 1000.0
	watch_signals(EventBus)
	chute.start_jump(Vector3.ZERO)
	assert_eq(_simulate_jump(100.0, 0.3), LandingEvaluator.INJURED)
	assert_lt(health.health, health.max_health)
	assert_false(health.is_dead())
	assert_eq(health.disabled_parts.size(), 1)
	assert_true(health.disabled_parts[0] == &"leg_l" or health.disabled_parts[0] == &"leg_r")
	assert_eq(health.bleeding_wounds, 0, "tylppä vamma ei vuoda")
	assert_signal_emitted_with_parameters(EventBus, "landed", [jumper, LandingEvaluator.INJURED])


func test_does_not_land_while_still_in_door() -> void:
	chute.start_jump(Vector3(4.0, 0.0, 0.0))
	chute.tick(STEP, Vector3.ZERO, Vector3.ZERO)
	assert_eq(chute.report_motion(true, 300.0, 0.0), &"")
	assert_true(chute.is_airborne())


func test_start_jump_ignored_when_airborne() -> void:
	chute.start_jump(Vector3.ZERO)
	watch_signals(EventBus)
	chute.start_jump(Vector3.ZERO)
	assert_signal_not_emitted(EventBus, "jump_started")


func test_landing_costs_stamina() -> void:
	chute.start_jump(Vector3.ZERO)
	_simulate_jump(50.0)
	assert_lt(stamina.value, 1.0)


## Hyppytorni: tavallinen pudotus noin 10 m, ilman laskuvarjoa (vapaa pudotus, maassa painovoima).
func _simulate_plain_fall(height: float, plf_lead: float, gravity: float = 9.8) -> StringName:
	var vy := 0.0
	var y := height
	var plf_done := false
	chute.report_motion(true, y, 0.0)
	for i in 60 * 10:
		vy -= gravity * STEP
		chute.tick(STEP, Vector3(0.0, vy, 0.0), Vector3.ZERO)
		y += vy * STEP
		if not plf_done and plf_lead >= 0.0 and y + vy * plf_lead <= 0.0:
			chute.register_plf()
			plf_done = true
		var quality := chute.report_motion(y <= 0.0, maxf(y, 0.0), -vy)
		if y <= 0.0:
			return quality
	return &""


func test_short_fall_is_not_evaluated() -> void:
	watch_signals(EventBus)
	assert_eq(_simulate_plain_fall(1.5, -1.0), &"")
	assert_signal_not_emitted(EventBus, "landed")


func test_tower_harness_speed_with_plf_is_good() -> void:
	# Hyppytornin valjaat jarruttavat: vajaa 1 g:n sijaan noin 3 m/s².
	watch_signals(EventBus)
	assert_eq(_simulate_plain_fall(10.0, 0.3, 3.0), LandingEvaluator.GOOD)
	assert_signal_emitted_with_parameters(EventBus, "landed", [jumper, LandingEvaluator.GOOD])


func test_free_fall_from_tower_is_injured() -> void:
	# 10 m vapaata pudotusta → noin 14 m/s.
	assert_eq(_simulate_plain_fall(10.0, 0.3), LandingEvaluator.INJURED)


func test_plain_fall_without_plf_is_hard() -> void:
	assert_eq(_simulate_plain_fall(3.0, -1.0), LandingEvaluator.HARD)


func test_stun_wears_off() -> void:
	chute.start_jump(Vector3.ZERO)
	_simulate_jump(50.0)
	assert_true(chute.is_stunned())
	chute.tick(2.0, Vector3.ZERO, Vector3.ZERO)
	assert_false(chute.is_stunned())


func test_canopy_descent_skips_exit() -> void:
	watch_signals(EventBus)
	chute.start_canopy_descent(Vector3.ZERO)
	assert_eq(chute.phase, ParachuteController.Phase.CANOPY)
	assert_signal_emitted(EventBus, "jump_started")
	assert_signal_emitted(EventBus, "chute_opened")
	assert_eq(_simulate_jump(10.0, 0.3), LandingEvaluator.GOOD)
