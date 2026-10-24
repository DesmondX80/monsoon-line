extends GutTest
## Kersantti Tibbsin ja repliikkijonon testit (M2-04).

const TIBBS_SCENE := preload("res://ai/npc/drill_sergeant.tscn")

var tibbs: DrillSergeant


func before_each() -> void:
	tibbs = TIBBS_SCENE.instantiate() as DrillSergeant
	add_child_autofree(tibbs)


func test_not_enemy_or_suppressible() -> void:
	assert_false(tibbs.is_in_group(&"enemy"))
	assert_false(tibbs.is_in_group(&"suppressible"))
	assert_true(tibbs.is_in_group(&"drill_sergeant"))
	assert_eq(tibbs.state_machine.current.name, &"Idle")


func test_walk_to_switches_state_and_arrives() -> void:
	tibbs.walk_to(Vector3(0.0, 0.0, -3.0))
	assert_eq(tibbs.state_machine.current.name, &"Walk")
	assert_true(tibbs.is_walking())
	watch_signals(tibbs)
	await wait_physics_frames(120)
	assert_true(tibbs.has_arrived(), "Ilman navigaatioverkkoa kuljetaan suoraan kohti")
	assert_signal_emitted(tibbs, "arrived")
	assert_ne(tibbs.state_machine.current.name, &"Walk")


func test_say_switches_to_talk_and_back() -> void:
	tibbs.say(&"tibbs_welcome", 0.3)
	assert_eq(tibbs.state_machine.current.name, &"Talk")
	await wait_physics_frames(40)
	assert_eq(tibbs.state_machine.current.name, &"Idle")
	assert_almost_eq(tibbs.point_arm.rotation.x, 0.0, 0.001, "Käsi laskee puheen jälkeen")


func test_faces_player_when_idle() -> void:
	var player := Node3D.new()
	player.add_to_group(&"player")
	add_child_autofree(player)
	player.global_position = Vector3(5.0, 0.0, 0.0)
	await wait_physics_frames(90)
	var forward := -tibbs.global_transform.basis.z
	assert_gt(forward.dot(Vector3.RIGHT), 0.9, "Tibbs kääntyy pelaajaa kohti")


func test_line_queue_rate_limits_and_dedupes() -> void:
	var queue := LineQueue.new(3.0)
	queue.emit_to_event_bus = false
	var emitted: Array[StringName] = []
	queue.line_emitted.connect(func(_s: Node3D, line_id: StringName) -> void: emitted.append(line_id))
	queue.push(null, &"a")
	queue.push(null, &"b")
	queue.push(null, &"b")
	assert_eq(emitted, [&"a"])
	queue.tick(2.9)
	assert_eq(emitted, [&"a"])
	queue.tick(0.2)
	assert_eq(emitted, [&"a", &"b"])
	queue.tick(3.1)
	assert_true(queue.is_idle())
