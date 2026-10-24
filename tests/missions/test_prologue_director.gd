extends GutTest
## Prologin ohjaajan vaihekone simuloiduilla asemasignaaleilla (M2-04).

const FakeStation := preload("res://tests/missions/fake_training_station.gd")
const DIRECTOR_SCRIPT := preload("res://missions/prologue/prologue_director.gd")

var director: PrologueDirector
var stations: Dictionary = {}  ## station_id -> FakeStation
var lines: Array[StringName] = []
var prompts: Array[String] = []
var titles: Array[String] = []
var nicknames: Array[String] = []
var _saved_nickname: String = ""


func before_each() -> void:
	_saved_nickname = GameState.player_nickname
	lines.clear()
	prompts.clear()
	titles.clear()
	nicknames.clear()
	stations.clear()
	EventBus.squad_callout.connect(_on_callout)
	EventBus.objective_prompt.connect(_on_prompt)
	EventBus.title_card.connect(_on_title)
	EventBus.nickname_assigned.connect(_on_nickname)
	for id: StringName in [&"obstacle_course", &"mg_range", &"jump_tower"]:
		var station := FakeStation.new()
		station.station_id = id
		add_child_autofree(station)
		stations[id] = station
	director = DIRECTOR_SCRIPT.new() as PrologueDirector
	director.auto_start = false
	director.manual_tick = true
	director.change_scene_enabled = false
	add_child_autofree(director)


func after_each() -> void:
	EventBus.squad_callout.disconnect(_on_callout)
	EventBus.objective_prompt.disconnect(_on_prompt)
	EventBus.title_card.disconnect(_on_title)
	EventBus.nickname_assigned.disconnect(_on_nickname)
	GameState.player_nickname = _saved_nickname


func _on_callout(_speaker: Node3D, line_id: StringName) -> void:
	lines.append(line_id)


func _on_prompt(text_fi: String, _text_en: String) -> void:
	prompts.append(text_fi)


func _on_title(title: String, _subtitle: String) -> void:
	titles.append(title)


func _on_nickname(nick: String) -> void:
	nicknames.append(nick)


## Ajaa ohjaajaa simuloitua aikaa pienin askelin.
func _advance(seconds: float, step_size: float = 0.25) -> void:
	var t := 0.0
	while t < seconds:
		director.step(step_size)
		t += step_size


func _station(id: StringName) -> Node:
	return stations[id] as Node


func _complete(id: StringName, result: Dictionary) -> void:
	EventBus.training_station_completed.emit(id, result)


func _run_to(stage: PrologueDirector.Stage, max_seconds: float = 60.0) -> void:
	var t := 0.0
	while director.stage != stage and t < max_seconds:
		director.step(0.25)
		t += 0.25


func test_start_emits_title_and_welcome() -> void:
	director.start()
	assert_eq(director.stage, PrologueDirector.Stage.WELCOME)
	assert_eq(titles, ["Fort Benning, Georgia"])
	assert_eq(lines, [&"tibbs_welcome"])


func test_full_flow_to_scene_change() -> void:
	var requested: Array[String] = []
	director.scene_change_requested.connect(func(path: String) -> void: requested.append(path))
	director.start()
	_run_to(PrologueDirector.Stage.OBSTACLE_COURSE)
	assert_eq(director.stage, PrologueDirector.Stage.OBSTACLE_COURSE)
	assert_eq(director.phase, PrologueDirector.Phase.ACTIVE)
	assert_eq(_station(&"obstacle_course").get(&"begin_calls"), 1)
	assert_eq(_station(&"mg_range").get(&"begin_calls"), 0, "Vain nykyinen asema avataan")
	assert_true(prompts.back().begins_with("Suorita esterata"))

	_complete(&"obstacle_course", {"time_s": 80.0, "falls": 4, "wire_touches": 0})
	assert_eq(director.phase, PrologueDirector.Phase.DEBRIEF)
	_run_to(PrologueDirector.Stage.MG_RANGE)
	assert_eq(_station(&"mg_range").get(&"begin_calls"), 1)

	_complete(&"mg_range", {"shots": 100, "hits": 60, "bipod_used": true, "belt_reloaded": true,
			"barrel_changed": false, "overheated": false})
	_run_to(PrologueDirector.Stage.JUMP_TOWER)
	assert_eq(_station(&"jump_tower").get(&"begin_calls"), 1)

	_complete(&"jump_tower", {"landing": &"good"})
	_run_to(PrologueDirector.Stage.NICKNAME)
	assert_eq(nicknames, ["Stumbles"])
	assert_eq(GameState.player_nickname, "Stumbles")
	_run_to(PrologueDirector.Stage.DONE)
	_advance(3.0)
	assert_eq(requested, ["res://world/levels/c130_drop.tscn"])

	for line_id: StringName in [&"tibbs_welcome", &"tibbs_obstacle_intro", &"tibbs_obstacle_done_bad",
			&"tibbs_mg_intro", &"tibbs_mg_done_good", &"tibbs_tower_intro", &"tibbs_tower_good",
			&"tibbs_nickname", &"tibbs_graduation"]:
		assert_has(lines, line_id)
	assert_lt(lines.find(&"tibbs_nickname"), lines.find(&"tibbs_graduation"))


func test_ignores_completion_of_other_station() -> void:
	director.start()
	_run_to(PrologueDirector.Stage.OBSTACLE_COURSE)
	_complete(&"mg_range", {"shots": 1, "hits": 1})
	assert_eq(director.phase, PrologueDirector.Phase.ACTIVE)
	assert_false(director.results.has(&"mg_range"))


func test_reacts_to_training_events() -> void:
	director.start()
	_run_to(PrologueDirector.Stage.OBSTACLE_COURSE)
	_advance(10.0)
	lines.clear()
	EventBus.training_event.emit(&"obstacle_course", &"fell")
	_advance(4.0)
	EventBus.training_event.emit(&"obstacle_course", &"wire_touched")
	_advance(4.0)
	assert_eq(lines, [&"tibbs_obstacle_fell", &"tibbs_obstacle_wire"])


func test_overheat_line_only_on_mg_range_and_rate_limited() -> void:
	director.start()
	_run_to(PrologueDirector.Stage.OBSTACLE_COURSE)
	EventBus.barrel_overheated.emit(null)
	_advance(10.0)
	assert_does_not_have(lines, &"tibbs_mg_overheat")
	_complete(&"obstacle_course", {"time_s": 60.0, "falls": 0, "wire_touches": 0})
	_run_to(PrologueDirector.Stage.MG_RANGE)
	_advance(15.0)
	lines.clear()
	EventBus.barrel_overheated.emit(null)
	EventBus.barrel_overheated.emit(null)
	_advance(5.0)
	assert_eq(lines.count(&"tibbs_mg_overheat"), 1)


func test_lines_do_not_overlap() -> void:
	var times: Array[float] = []
	var clock := [0.0]
	var record := func(_s: Node3D, _l: StringName) -> void: times.append(clock[0])
	EventBus.squad_callout.connect(record)
	director.start()
	for i in 200:
		director.step(0.1)
		clock[0] += 0.1
		if i == 5:
			EventBus.training_event.emit(&"obstacle_course", &"fell")
	EventBus.squad_callout.disconnect(record)
	for i in range(1, times.size()):
		assert_gte(times[i] - times[i - 1], director.line_gap - 0.11, "Repliikkien väli")


func test_hurry_line_after_idle_and_reset_by_progress() -> void:
	director.start()
	_run_to(PrologueDirector.Stage.OBSTACLE_COURSE)
	_advance(10.0)
	lines.clear()
	_advance(30.0)
	EventBus.training_event.emit(&"obstacle_course", &"checkpoint")
	_advance(40.0)
	assert_does_not_have(lines, &"tibbs_idle_hurry", "Checkpoint nollaa kiirehtimisajan")
	_advance(10.0)
	assert_has(lines, &"tibbs_idle_hurry")


func test_missing_station_is_skipped() -> void:
	(stations[&"mg_range"] as Node).remove_from_group(&"training_station")
	director.start()
	_run_to(PrologueDirector.Stage.OBSTACLE_COURSE)
	_complete(&"obstacle_course", {"time_s": 60.0, "falls": 0, "wire_touches": 0})
	_run_to(PrologueDirector.Stage.JUMP_TOWER)
	assert_eq(director.stage, PrologueDirector.Stage.JUMP_TOWER)


func test_debrief_thresholds() -> void:
	assert_eq(director.debrief_line(&"obstacle_course", {"time_s": 100.0, "falls": 0, "wire_touches": 1}),
			&"tibbs_obstacle_done_good")
	assert_eq(director.debrief_line(&"obstacle_course", {"time_s": 130.0, "falls": 0, "wire_touches": 0}),
			&"tibbs_obstacle_done_bad")
	assert_eq(director.debrief_line(&"mg_range", {"shots": 10, "hits": 5, "overheated": false}),
			&"tibbs_mg_done_good")
	assert_eq(director.debrief_line(&"mg_range", {"shots": 10, "hits": 5, "overheated": true}),
			&"tibbs_mg_done_bad")
	assert_eq(director.debrief_line(&"mg_range", {"shots": 0, "hits": 0}), &"tibbs_mg_done_bad")
	assert_eq(director.debrief_line(&"jump_tower", {"landing": &"good"}), &"tibbs_tower_good")
	assert_eq(director.debrief_line(&"jump_tower", {"landing": &"injured"}), &"tibbs_tower_hard")


func test_tibbs_walks_to_station_marker_before_begin() -> void:
	var marker := Marker3D.new()
	marker.add_to_group(&"station_obstacle_course")
	add_child_autofree(marker)
	marker.global_position = Vector3(5.0, 0.0, 0.0)
	var fake_tibbs := FakeTibbs.new()
	fake_tibbs.name = &"Tibbs"
	director.add_child(fake_tibbs)
	director.tibbs = fake_tibbs
	director.start()
	_run_to(PrologueDirector.Stage.OBSTACLE_COURSE)
	assert_eq(director.phase, PrologueDirector.Phase.WALKING)
	assert_eq(fake_tibbs.target, Vector3(5.0, 0.0, 0.0))
	assert_eq(_station(&"obstacle_course").get(&"begin_calls"), 0)
	fake_tibbs.arrived_flag = true
	director.step(0.1)
	assert_eq(director.phase, PrologueDirector.Phase.ACTIVE)
	assert_eq(_station(&"obstacle_course").get(&"begin_calls"), 1)


class FakeTibbs:
	extends Node3D
	var target: Vector3 = Vector3.INF
	var arrived_flag: bool = false

	func walk_to(point: Vector3) -> void:
		target = point
		arrived_flag = false

	func has_arrived() -> bool:
		return arrived_flag
