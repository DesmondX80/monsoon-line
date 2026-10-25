extends GutTest
## GUT-testit AmbushDirectorin vaihekoneelle (M3).

var director: AmbushDirector
var completed_results: Array[Dictionary] = []


func before_each() -> void:
	director = AmbushDirector.new()
	director.manual_tick = true
	director.spawn_enemies = false
	add_child_autofree(director)
	completed_results.clear()
	EventBus.mission_completed.connect(_on_mission_completed)


func after_each() -> void:
	if EventBus.mission_completed.is_connected(_on_mission_completed):
		EventBus.mission_completed.disconnect(_on_mission_completed)


func _on_mission_completed(result: Dictionary) -> void:
	completed_results.append(result)


func test_patrol_transitions_to_contact() -> void:
	director.start()
	assert_eq(director.stage, AmbushDirector.Stage.PATROL)
	director.step(director.patrol_duration + 0.1)
	assert_eq(director.stage, AmbushDirector.Stage.CONTACT)


func test_contact_transitions_to_firefight() -> void:
	director.start()
	director.step(director.patrol_duration + 0.1)
	director.step(director.contact_duration + 0.1)
	assert_eq(director.stage, AmbushDirector.Stage.FIREFIGHT)


func test_cleared_ambush_reaches_extraction() -> void:
	director.start()
	director.step(director.patrol_duration + 0.1)
	director.step(director.contact_duration + 0.1)
	director._clear_ambush()
	director.step(director.regroup_duration + 0.1)
	assert_eq(director.stage, AmbushDirector.Stage.EXTRACTION)


func test_mission_completes_at_extraction() -> void:
	director.start()
	director.step(director.patrol_duration + 0.1)
	director.step(director.contact_duration + 0.1)
	director._clear_ambush()
	director.step(director.regroup_duration + 0.1)
	director._complete_mission()
	assert_eq(director.stage, AmbushDirector.Stage.COMPLETE)
	assert_eq(completed_results.size(), 1)
	assert_true(completed_results[0].get("success", false))
