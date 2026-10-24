extends GutTest
## Tester-agentin löydös: kuollutta toimijaa osuva luoti ei saa lähettää signaaleja uudelleen.

var health: HealthComponent


func before_each() -> void:
	health = HealthComponent.new()
	add_child_autofree(health)


func test_hit_after_death_is_ignored() -> void:
	health.take_hit(1000.0, &"torso")
	assert_true(health.is_dead())
	var wounds := health.bleeding_wounds
	watch_signals(health)
	watch_signals(EventBus)
	health.take_hit(50.0, &"arm_l")
	assert_signal_not_emitted(health, "died")
	assert_signal_not_emitted(health, "limb_disabled")
	assert_signal_not_emitted(EventBus, "actor_died")
	assert_signal_not_emitted(EventBus, "actor_hit")
	assert_eq(health.bleeding_wounds, wounds)
	assert_false(health.disabled_parts.has(&"arm_l"))


func test_died_emitted_once() -> void:
	watch_signals(health)
	health.take_hit(1000.0, &"head")
	health.take_hit(1000.0, &"head")
	assert_signal_emit_count(health, "died", 1)
