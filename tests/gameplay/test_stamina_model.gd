extends GutTest
## M1-05: kestävyys ja kantokuorma.

var model: StaminaModel


func before_each() -> void:
	model = StaminaModel.new()


func _sprint_until_exhausted(load_kg: float) -> float:
	var time := 0.0
	var step := 0.05
	while model.update(step, true, true, load_kg) and time < 600.0:
		time += step
	return time


func test_drain_grows_with_load() -> void:
	assert_gt(model.drain_rate(25.0), model.drain_rate(15.0))


func test_drain_at_reference_load() -> void:
	assert_almost_eq(model.drain_rate(model.reference_load_kg), model.sprint_drain_per_second, 0.0001)


func test_heavy_load_sprint_is_clearly_shorter() -> void:
	var light := _sprint_until_exhausted(15.0)
	model = StaminaModel.new()
	var heavy := _sprint_until_exhausted(25.0)
	assert_lt(heavy, light * 0.7, "25 kg: %.1f s, 15 kg: %.1f s" % [heavy, light])


func test_sprint_duration_matches_drain() -> void:
	assert_almost_eq(model.sprint_duration(20.0), 1.0 / model.sprint_drain_per_second, 0.001)


func test_sprinting_consumes_stamina() -> void:
	model.update(1.0, true, true, 20.0)
	assert_almost_eq(model.value, 1.0 - model.drain_rate(20.0), 0.0001)


func test_cannot_sprint_when_exhausted() -> void:
	_sprint_until_exhausted(25.0)
	assert_true(model.exhausted)
	assert_false(model.can_sprint())
	assert_false(model.update(0.1, true, true, 25.0))


func test_sprint_resumes_after_recovery() -> void:
	_sprint_until_exhausted(25.0)
	for i in 100:
		model.update(0.1, false, false, 25.0)
	assert_false(model.exhausted)
	assert_true(model.can_sprint())


func test_regen_waits_for_delay() -> void:
	model.value = 0.5
	model.update(0.1, true, true, 20.0)
	var after_sprint := model.value
	model.update(model.regen_delay * 0.5, false, false, 20.0)
	assert_eq(model.value, after_sprint)


func test_rest_regenerates() -> void:
	model.value = 0.2
	model.update(model.regen_delay, false, false, 20.0)
	var before := model.value
	model.update(1.0, false, false, 20.0)
	assert_almost_eq(model.value, before + model.rest_regen_per_second, 0.0001)


func test_walking_regenerates_slower_than_resting() -> void:
	assert_lt(model.regen_rate(true), model.regen_rate(false))


func test_stamina_is_clamped() -> void:
	model.update(100.0, false, false, 20.0)
	model.update(100.0, false, false, 20.0)
	assert_eq(model.value, 1.0)
	_sprint_until_exhausted(40.0)
	assert_eq(model.value, 0.0)
