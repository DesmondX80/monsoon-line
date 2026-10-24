extends GutTest
## C-130-hypyn ohjaajan sekvenssi valepelaajalla (M2-05).

const FakeParachute := preload("res://tests/missions/fake_parachute.gd")
const FakeJumpLight := preload("res://tests/missions/fake_jump_light.gd")
const DIRECTOR_SCRIPT := preload("res://missions/drop/drop_director.gd")

var director: DropDirector
var player: Node3D
var chute: Node
var light: Node3D
var door: Marker3D
## Tapahtumat järjestyksessä: "cmd:<x>", "line:<x>", "prompt:<fi>", "title:<x>", "jump".
var log: Array[String] = []
var requested: Array[String] = []


func before_each() -> void:
	log.clear()
	requested.clear()
	EventBus.jumpmaster_command.connect(_on_command)
	EventBus.squad_callout.connect(_on_callout)
	EventBus.objective_prompt.connect(_on_prompt)
	EventBus.title_card.connect(_on_title)
	EventBus.jump_started.connect(_on_jump_started)
	player = Node3D.new()
	player.name = &"Player"
	player.add_to_group(&"player")
	chute = FakeParachute.new()
	chute.name = &"ParachuteController"
	player.add_child(chute)
	add_child_autofree(player)
	light = FakeJumpLight.new()
	add_child_autofree(light)
	door = Marker3D.new()
	door.add_to_group(&"jump_door")
	add_child_autofree(door)
	door.global_position = Vector3(2.0, 300.0, -5.0)
	# Ovi katsoo ulos +X-suuntaan, kone kulkee -Z.
	door.rotation.y = -PI / 2.0
	director = DIRECTOR_SCRIPT.new() as DropDirector
	director.auto_start = false
	director.manual_tick = true
	director.change_scene_enabled = false
	director.scene_change_requested.connect(func(path: String) -> void: requested.append(path))
	add_child_autofree(director)


func after_each() -> void:
	EventBus.jumpmaster_command.disconnect(_on_command)
	EventBus.squad_callout.disconnect(_on_callout)
	EventBus.objective_prompt.disconnect(_on_prompt)
	EventBus.title_card.disconnect(_on_title)
	EventBus.jump_started.disconnect(_on_jump_started)


func _on_command(command: StringName) -> void:
	log.append("cmd:%s" % command)


func _on_callout(_speaker: Node3D, line_id: StringName) -> void:
	log.append("line:%s" % line_id)


func _on_prompt(text_fi: String, _text_en: String) -> void:
	if not text_fi.is_empty():
		log.append("prompt:%s" % text_fi)


func _on_title(title: String, _subtitle: String) -> void:
	log.append("title:%s" % title)


func _on_jump_started(jumper: Node3D) -> void:
	log.append("jump:%s" % (jumper.name if jumper else "null"))


func _advance(seconds: float, step_size: float = 0.25) -> void:
	var t := 0.0
	while t < seconds:
		director.step(step_size)
		t += step_size


func test_sequence_order_and_waits_for_player() -> void:
	director.start()
	assert_false(light.get(&"green") as bool)
	_advance(40.0)
	assert_eq(director.phase, DropDirector.Phase.READY_TO_JUMP, "Odottaa pelaajan hyppyä")
	assert_true(light.get(&"green") as bool)
	var expected: Array[String] = ["title:Katum, Tay Ninh"]
	for command: String in ["stand_up", "hook_up", "check_equipment", "stand_in_door", "go"]:
		expected.append("cmd:%s" % command)
		expected.append("line:jumpmaster_%s" % command)
	expected.append("prompt:%s" % DropDirector.PROMPT_FI)
	assert_eq(log, expected)
	assert_eq(director.issued_commands, [&"stand_up", &"hook_up", &"check_equipment", &"stand_in_door", &"go"])


func test_jump_moves_player_and_starts_parachute() -> void:
	director.start()
	_advance(40.0)
	assert_true(director.request_jump())
	assert_eq(director.phase, DropDirector.Phase.AIRBORNE)
	assert_almost_eq(player.global_position, door.global_position, Vector3.ONE * 0.01)
	var velocities: Array[Vector3] = chute.get(&"exit_velocities")
	assert_eq(velocities.size(), 1)
	var v: Vector3 = velocities[0]
	assert_almost_eq(v.z, -director.aircraft_speed, 0.01, "Koneen nopeus eteenpäin")
	assert_almost_eq(v.x, director.door_push, 0.01, "Potku ulos ovesta")


func test_cannot_jump_before_green() -> void:
	director.start()
	_advance(5.0)
	assert_false(director.request_jump())
	var velocities: Array[Vector3] = chute.get(&"exit_velocities")
	assert_eq(velocities.size(), 0)


func test_key_press_triggers_jump() -> void:
	director.start()
	_advance(40.0)
	var key := InputEventKey.new()
	key.physical_keycode = KEY_F
	key.keycode = KEY_F
	key.pressed = true
	director._unhandled_input(key)
	assert_eq(director.phase, DropDirector.Phase.AIRBORNE)


func test_npc_jumpers_exit_before_player() -> void:
	var npcs: Array[Node3D] = []
	for i in 3:
		var npc := Node3D.new()
		npc.name = StringName("Npc%d" % i)
		npc.add_to_group(&"npc_jumper")
		add_child(npc)
		npcs.append(npc)
	director.start()
	while director.phase != DropDirector.Phase.READY_TO_JUMP:
		director.step(0.1)
	assert_false(director.request_jump(), "NPC:t ensin")
	_advance(4.0)
	await wait_physics_frames(1)
	for npc: Node3D in npcs:
		assert_false(is_instance_valid(npc), "Paikkamerkki-NPC poistuu")
	var first_npc := log.find("jump:Npc0")
	var prompt := log.find("prompt:%s" % DropDirector.PROMPT_FI)
	assert_gt(first_npc, -1)
	assert_gt(prompt, first_npc, "Ohje vasta NPC:iden jälkeen")
	assert_true(director.request_jump())
	assert_gt(log.find("jump:Player"), prompt)


func test_landing_leads_to_jungle() -> void:
	director.start()
	_advance(40.0)
	director.request_jump()
	var other := Node3D.new()
	add_child_autofree(other)
	EventBus.landed.emit(other, &"good")  # muu hyppääjä: ei vaikutusta
	assert_eq(director.phase, DropDirector.Phase.AIRBORNE)
	EventBus.landed.emit(player, &"good")
	assert_eq(director.phase, DropDirector.Phase.LANDED)
	assert_eq(log.back(), "line:squad_landed")
	_advance(10.0)
	assert_eq(requested, ["res://world/levels/jungle_test.tscn"])


func test_without_parachute_goes_straight_to_jungle() -> void:
	player.remove_child(chute)
	chute.free()
	director.start()
	_advance(40.0)
	assert_true(director.request_jump())
	assert_eq(director.phase, DropDirector.Phase.DONE)
	_advance(3.0)
	assert_eq(requested, ["res://world/levels/jungle_test.tscn"])
