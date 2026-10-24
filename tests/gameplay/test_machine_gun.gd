extends GutTest
## M1-06: MachineGunin julkiset metodit. Käyttää kopiota M60-datasta, jotta ajat ovat lyhyitä.

var data: WeaponData
var gun: MachineGun
var shooter: Node3D


func before_each() -> void:
	data = (load("res://weapons/resources/m60.tres") as WeaponData).duplicate() as WeaponData
	data.reload_time = 0.05
	data.barrel_change_time = 0.05
	data.jam_chance_when_hot = 0.0
	gun = MachineGun.new()
	gun.data = data
	add_child_autofree(gun)
	gun.rng.seed = 1234
	# Ampuja ilman puuta: laukaus lasketaan, mutta luotia ei luoda kohtaukseen.
	shooter = Node3D.new()
	autofree(shooter)


func _fire_ready() -> bool:
	gun.tick(60.0 / data.rounds_per_minute)
	# tick jäähdyttää myös piippua; testit, jotka mittaavat lämpöä, ottavat sen huomioon.
	return gun.try_fire(shooter)


func test_ready_fills_belt() -> void:
	assert_eq(gun.rounds_in_belt, data.magazine_size)
	assert_not_null(gun.handling)


func test_can_fire_initially() -> void:
	assert_true(gun.can_fire())


func test_try_fire_consumes_round_and_emits() -> void:
	watch_signals(gun)
	assert_true(gun.try_fire(shooter))
	assert_eq(gun.rounds_in_belt, data.magazine_size - 1)
	assert_signal_emitted(gun, "fired")


func test_rate_of_fire_cooldown() -> void:
	gun.try_fire(shooter)
	assert_false(gun.can_fire(), "seuraava laukaus vasta tulinopeuden viiveen jälkeen")
	gun.tick(60.0 / data.rounds_per_minute)
	assert_true(gun.can_fire())


func test_firing_heats_barrel() -> void:
	gun.try_fire(shooter)
	assert_almost_eq(gun.heat, data.heat_per_shot, 0.00001)


func test_barrel_cools_over_time() -> void:
	gun.heat = 0.5
	gun.tick(1.0)
	assert_almost_eq(gun.heat, 0.5 - data.cooling_per_second, 0.00001)
	gun.tick(1000.0)
	assert_eq(gun.heat, 0.0)


func test_overheated_cannot_fire_and_emits() -> void:
	watch_signals(EventBus)
	gun.heat = 1.0 - data.heat_per_shot * 0.5
	assert_true(gun.try_fire(shooter))
	assert_eq(gun.heat, 1.0)
	assert_signal_emitted(EventBus, "barrel_overheated")
	gun.tick(60.0 / data.rounds_per_minute)
	gun.heat = 1.0
	assert_false(gun.can_fire())


func test_empty_belt_cannot_fire_and_emits() -> void:
	watch_signals(EventBus)
	gun.rounds_in_belt = 0
	assert_false(gun.can_fire())
	assert_false(gun.try_fire(shooter))
	assert_signal_emitted(EventBus, "belt_empty")


func test_busy_cannot_fire() -> void:
	gun.busy = true
	assert_false(gun.can_fire())
	assert_false(gun.try_fire(shooter))


func test_jammed_cannot_fire_and_clear_jam() -> void:
	gun.jammed = true
	assert_false(gun.can_fire())
	gun.clear_jam()
	assert_true(gun.can_fire())


func test_hot_barrel_can_jam() -> void:
	data.jam_chance_when_hot = 1.0
	gun.heat = 0.8
	gun.try_fire(shooter)
	assert_true(gun.jammed)


func test_cool_barrel_does_not_jam() -> void:
	data.jam_chance_when_hot = 1.0
	gun.heat = 0.0
	gun.try_fire(shooter)
	assert_false(gun.jammed)


func test_reload_fills_belt_and_clears_jam() -> void:
	watch_signals(gun)
	gun.rounds_in_belt = 3
	gun.jammed = true
	gun.reload()
	assert_true(gun.busy)
	assert_false(gun.can_fire())
	await wait_for_signal(gun.reloaded, 1.0)
	assert_eq(gun.rounds_in_belt, data.magazine_size)
	assert_false(gun.jammed)
	assert_false(gun.busy)
	assert_signal_emitted(gun, "reloaded")


func test_reload_ignored_while_busy() -> void:
	gun.busy = true
	gun.rounds_in_belt = 3
	gun.reload()
	await wait_seconds(0.15)
	assert_eq(gun.rounds_in_belt, 3)


func test_change_barrel_resets_heat() -> void:
	watch_signals(gun)
	gun.heat = 0.9
	gun.change_barrel(false)
	assert_true(gun.busy)
	await wait_for_signal(gun.barrel_changed, 1.0)
	assert_eq(gun.heat, 0.0)
	assert_false(gun.busy)
	assert_signal_emitted(gun, "barrel_changed")


func test_assisted_barrel_change_is_faster() -> void:
	data.barrel_change_time = 0.5
	gun.heat = 0.9
	gun.change_barrel(true)
	await wait_seconds(0.4)
	assert_false(gun.busy, "avustettu vaihto 0,6 x 0,5 s = 0,3 s")


func test_spread_smaller_on_bipod() -> void:
	var hip := gun.current_spread_deg()
	assert_almost_eq(hip, data.hip_spread_deg, 0.0001)
	gun.bipod_deployed = true
	assert_lt(gun.current_spread_deg(), hip)


func test_bipod_changed_signal() -> void:
	watch_signals(gun)
	gun.deploy_bipod(true, false)
	assert_signal_emitted_with_parameters(gun, "bipod_changed", [true])
	gun.retract_bipod()
	assert_signal_emitted_with_parameters(gun, "bipod_changed", [false])


func test_firing_adds_recoil_to_aim_offset() -> void:
	assert_eq(gun.get_aim_offset(), Vector2.ZERO)
	gun.try_fire(shooter)
	assert_gt(gun.get_aim_offset().x, 0.0)


func test_bipod_recoil_smaller() -> void:
	gun.try_fire(shooter)
	var hip_kick := gun.handling.recoil.x
	gun.handling.recoil = Vector2.ZERO
	gun.deploy_bipod(true, false)
	_fire_ready()
	assert_lt(gun.handling.recoil.x, hip_kick)


func test_update_handling_recovers_recoil() -> void:
	gun.try_fire(shooter)
	var kicked := gun.handling.recoil.x
	for i in 120:
		gun.update_handling(1.0 / 60.0, 1.0, 0.0)
	assert_lt(gun.handling.recoil.x, kicked * 0.05)


func test_full_belt_can_be_emptied() -> void:
	var fired := 0
	for i in data.magazine_size + 5:
		if _fire_ready():
			fired += 1
	assert_eq(fired, data.magazine_size)
	assert_eq(gun.rounds_in_belt, 0)
