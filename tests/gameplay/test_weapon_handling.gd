extends GutTest
## M1-04: rekyyli ja huojunta. Arvot luetaan M60:n .tres-tiedostosta.

var data: WeaponData


func before_each() -> void:
	data = load("res://weapons/resources/m60.tres") as WeaponData


func _burst_climb(supported: bool, shots: int) -> float:
	var handling := WeaponHandling.new(data, 1)
	var interval := 60.0 / data.rounds_per_minute
	for i in shots:
		handling.add_shot(supported)
		handling.update(interval, 1.0, 0.0, supported)
	return handling.recoil.x


func test_shot_kicks_camera_up() -> void:
	var handling := WeaponHandling.new(data, 1)
	var kick := handling.add_shot(false)
	assert_almost_eq(kick.x, data.recoil_vertical, 0.0001)
	assert_lte(absf(kick.y), data.recoil_horizontal)


func test_supported_recoil_is_smaller() -> void:
	var handling := WeaponHandling.new(data, 1)
	var kick := handling.add_shot(true)
	assert_almost_eq(kick.x, data.recoil_vertical * data.supported_recoil_multiplier, 0.0001)


func test_hip_burst_climbs_much_more_than_bipod_burst() -> void:
	var hip := _burst_climb(false, 15)
	var bipod := _burst_climb(true, 15)
	assert_gt(hip, 20.0, "Lonkalta 15 laukauksen sarja nousee yli 20 astetta")
	assert_lt(bipod, hip * 0.25)


func test_recoil_recovers_after_burst() -> void:
	var handling := WeaponHandling.new(data, 1)
	for i in 5:
		handling.add_shot(false)
	var peak := handling.recoil.length()
	for i in 120:
		handling.update(1.0 / 60.0, 1.0, 0.0, false)
	assert_lt(handling.recoil.length(), peak * 0.05)


func test_recoil_does_not_recover_during_burst() -> void:
	var handling := WeaponHandling.new(data, 1)
	handling.add_shot(false)
	var after_shot := handling.recoil.x
	handling.update(data.recoil_recovery_delay * 0.5, 1.0, 0.0, false)
	assert_eq(handling.recoil.x, after_shot)


func test_suppression_increases_sway_clearly() -> void:
	var calm := WeaponHandling.compute_sway_amplitude(data, 1.0, 0.0, false)
	var pinned := WeaponHandling.compute_sway_amplitude(data, 1.0, 1.0, false)
	assert_gt(pinned, calm * 2.0)


func test_low_stamina_increases_sway() -> void:
	var rested := WeaponHandling.compute_sway_amplitude(data, 1.0, 0.0, false)
	var tired := WeaponHandling.compute_sway_amplitude(data, 0.0, 0.0, false)
	assert_almost_eq(tired, rested * (1.0 + data.stamina_sway_factor), 0.0001)


func test_bipod_reduces_sway() -> void:
	var free := WeaponHandling.compute_sway_amplitude(data, 1.0, 0.5, false)
	var supported := WeaponHandling.compute_sway_amplitude(data, 1.0, 0.5, true)
	assert_almost_eq(supported, free * data.supported_sway_multiplier, 0.0001)


func test_sway_amplitude_converges_to_target() -> void:
	var handling := WeaponHandling.new(data, 1)
	for i in 300:
		handling.update(1.0 / 60.0, 1.0, 1.0, false)
	var target := WeaponHandling.compute_sway_amplitude(data, 1.0, 1.0, false)
	assert_almost_eq(handling.sway_amplitude, target, target * 0.02)
	assert_lte(handling.sway.length(), target * 1.2)


func test_values_come_from_resource() -> void:
	var custom := data.duplicate() as WeaponData
	custom.recoil_vertical = 9.0
	var handling := WeaponHandling.new(custom, 1)
	assert_almost_eq(handling.add_shot(false).x, 9.0, 0.0001)
