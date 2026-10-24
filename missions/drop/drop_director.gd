class_name DropDirector
extends Node
## C-130-hypyn ohjaaja (M2-05): Katumin pudotusalue, 22.2.1967, Operaatio Junction City.
##
## Sekvenssi: otsikkokortti → hyppymestarin komennot ajastettuna (stand_up, hook_up,
## check_equipment, stand_in_door) → hyppyvalo vihreäksi → go → NPC-hyppääjät ulos →
## ohje "Hyppää ovesta" → pelaaja painaa F tai välilyöntiä → siirto ovelle ja
## ParachuteController.start_jump() → EventBus.landed → squad_landed → scene-vaihto viidakkoon.
##
## Solmut haetaan ryhmistä (player, jump_door, jump_light, npc_jumper, fade_layer).
## Ilman ParachuteControlleria hypyn jälkeen siirrytään suoraan viidakkotasolle varoituksella.
## Näppäimet käsitellään suoraan _unhandled_input-funktiossa, ettei project.godot muutu.
##
## Testattavuus: manual_tick = true, jolloin testi kutsuu step(delta) ja request_jump().

signal phase_changed(phase: Phase)
signal scene_change_requested(path: String)

enum Phase { NONE, BRIEFING, COMMANDS, READY_TO_JUMP, AIRBORNE, LANDED, DONE }

const TITLE := "Katum, Tay Ninh"
const SUBTITLE := "22. helmikuuta 1967 – Operaatio Junction City"
## Hyppymestarin komennot järjestyksessä. "go" annetaan vasta vihreän valon kanssa.
const COMMANDS: Array[StringName] = [&"stand_up", &"hook_up", &"check_equipment", &"stand_in_door"]
const PROMPT_FI := "Hyppää ovesta – paina F tai välilyönti"
const PROMPT_EN := "Jump through the door – press F or Space"
const PARACHUTE_NODE := &"ParachuteController"

@export var next_scene: String = "res://world/levels/jungle_test.tscn"
@export var auto_start: bool = true
@export var change_scene_enabled: bool = true
@export var manual_tick: bool = false
@export_group("Ajoitus")
## Otsikkokortin jälkeinen tauko ennen ensimmäistä komentoa.
@export var briefing_duration: float = 4.0
## Komentojen väli (s).
@export var command_interval: float = 3.5
## NPC-hyppääjien väli ovella (s); C-130:n ovelta noin sekunnin välein.
@export var npc_exit_interval: float = 0.8
## Laskeutumisen jälkeen ennen scene-vaihtoa.
@export var post_landing_delay: float = 4.0
@export var scene_change_delay: float = 1.5
## Varmistus: jos landed-signaalia ei tule tässä ajassa hypystä, jatketaan silti.
@export var airborne_timeout: float = 90.0
@export_group("Hyppy")
## Koneen nopeus (noin 60 m/s eli ~115 solmua hyppynopeudella).
@export var aircraft_speed: float = 60.0
## Ulospäin suuntautuva potku ovesta (m/s).
@export var door_push: float = 2.0
## Koneen kulkusuunta maailmassa. Nolla = jump_door-markerin -Z.
@export var aircraft_forward: Vector3 = Vector3.ZERO

var phase: Phase = Phase.NONE
var player: Node3D
## Lähetetyt komennot järjestyksessä (myös testien seurantaan).
var issued_commands: Array[StringName] = []

var _time: float = 0.0
var _command_index: int = 0
var _npc_queue: Array[Node3D] = []
var _npc_timer: float = 0.0
var _scene_change_timer: float = -1.0


func _ready() -> void:
	EventBus.landed.connect(_on_landed)
	if auto_start:
		start.call_deferred()


func _process(delta: float) -> void:
	if not manual_tick:
		step(delta)


func _unhandled_input(event: InputEvent) -> void:
	if phase != Phase.READY_TO_JUMP:
		return
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo \
			and (key.physical_keycode == KEY_F or key.physical_keycode == KEY_SPACE
				or key.keycode == KEY_F or key.keycode == KEY_SPACE):
		get_viewport().set_input_as_handled()
		request_jump()


func start() -> void:
	if phase != Phase.NONE:
		return
	player = get_tree().get_first_node_in_group(&"player") as Node3D
	EventBus.title_card.emit(TITLE, SUBTITLE)
	_set_light_green(false)
	_set_phase(Phase.BRIEFING)


func step(delta: float) -> void:
	_time += delta
	match phase:
		Phase.BRIEFING:
			if _time >= briefing_duration:
				_set_phase(Phase.COMMANDS)
				_issue_next_command()
		Phase.COMMANDS:
			if _time >= command_interval:
				_issue_next_command()
		Phase.READY_TO_JUMP:
			_step_npc_jumpers(delta)
		Phase.AIRBORNE:
			if _time >= airborne_timeout:
				push_warning("DropDirector: landed-signaalia ei tullut, jatketaan viidakkoon.")
				_on_player_landed(&"hard")
		Phase.LANDED:
			if _time >= post_landing_delay:
				_set_phase(Phase.DONE)
				_request_fade()
				_scene_change_timer = scene_change_delay
		Phase.DONE:
			if _scene_change_timer >= 0.0:
				_scene_change_timer -= delta
				if _scene_change_timer < 0.0:
					_change_scene()


## Pelaaja hyppää (F / välilyönti). Toimii vain, kun vihreä valo palaa ja NPC:t ovat ulkona.
func request_jump() -> bool:
	if phase != Phase.READY_TO_JUMP or not _npc_queue.is_empty():
		return false
	if not is_instance_valid(player):
		player = get_tree().get_first_node_in_group(&"player") as Node3D
	EventBus.objective_prompt.emit("", "")
	var door := get_tree().get_first_node_in_group(&"jump_door") as Node3D
	var forward := _aircraft_forward(door)
	if is_instance_valid(player) and door != null:
		player.global_position = door.global_position
	var chute := _find_parachute()
	if chute == null:
		push_warning("DropDirector: pelaajalta puuttuu ParachuteController, siirrytään suoraan viidakkoon.")
		_set_phase(Phase.DONE)
		_request_fade()
		_scene_change_timer = scene_change_delay
		return true
	_set_phase(Phase.AIRBORNE)
	chute.call(&"start_jump", exit_velocity(forward, _door_outward(door, forward)))
	return true


## Hypyn alkunopeus: koneen nopeus eteenpäin + pieni potku ulos ovesta.
func exit_velocity(forward: Vector3, outward: Vector3) -> Vector3:
	return forward.normalized() * aircraft_speed + outward.normalized() * door_push


# --- Sisäiset ---

func _set_phase(next: Phase) -> void:
	phase = next
	_time = 0.0
	phase_changed.emit(phase)


func _issue_next_command() -> void:
	_time = 0.0
	if _command_index < COMMANDS.size():
		var command: StringName = COMMANDS[_command_index]
		_command_index += 1
		_command(command)
		return
	# Kaikki valmistelukomennot annettu: vihreä valo ja "go".
	_set_light_green(true)
	_command(&"go")
	_npc_queue.clear()
	for node: Node in get_tree().get_nodes_in_group(&"npc_jumper"):
		if node is Node3D:
			_npc_queue.append(node as Node3D)
	_npc_timer = 0.0
	_set_phase(Phase.READY_TO_JUMP)
	if _npc_queue.is_empty():
		_show_jump_prompt()


func _command(command: StringName) -> void:
	issued_commands.append(command)
	EventBus.jumpmaster_command.emit(command)
	EventBus.squad_callout.emit(null, StringName("jumpmaster_%s" % command))


func _step_npc_jumpers(delta: float) -> void:
	if _npc_queue.is_empty():
		return
	_npc_timer -= delta
	if _npc_timer > 0.0:
		return
	_npc_timer = npc_exit_interval
	var jumper: Node3D = _npc_queue.pop_front()
	if is_instance_valid(jumper):
		if jumper.has_method(&"jump"):
			jumper.call(&"jump")
		else:
			# Paikkamerkki-NPC: poistuu ovesta näkyvistä.
			EventBus.jump_started.emit(jumper)
			jumper.queue_free()
	if _npc_queue.is_empty():
		_show_jump_prompt()


func _show_jump_prompt() -> void:
	EventBus.objective_prompt.emit(PROMPT_FI, PROMPT_EN)


func _set_light_green(green: bool) -> void:
	var light := get_tree().get_first_node_in_group(&"jump_light")
	if light == null:
		return
	if green and light.has_method(&"set_green"):
		light.call(&"set_green")
	elif not green and light.has_method(&"set_red"):
		light.call(&"set_red")
	elif light is Light3D:
		(light as Light3D).light_color = Color(0.1, 1.0, 0.2) if green else Color(1.0, 0.1, 0.1)


func _find_parachute() -> Node:
	if not is_instance_valid(player):
		return null
	var chute := player.get_node_or_null(NodePath(PARACHUTE_NODE))
	if chute == null:
		for child: Node in player.find_children("*", "", true, false):
			if child.has_method(&"start_jump"):
				chute = child
				break
	if chute != null and chute.has_method(&"start_jump"):
		return chute
	return null


## Koneen kulkusuunta: export aircraft_forward, ryhmän "aircraft" solmun -Z tai maailman -Z.
func _aircraft_forward(_door: Node3D) -> Vector3:
	if aircraft_forward != Vector3.ZERO:
		return aircraft_forward.normalized()
	var aircraft := get_tree().get_first_node_in_group(&"aircraft") as Node3D
	if aircraft != null:
		var f := -aircraft.global_transform.basis.z
		f.y = 0.0
		if f.length() > 0.01:
			return f.normalized()
	return Vector3.FORWARD


## Ulospäin ovesta: jump_door-markerin -Z (marker katsoo ulos), jos se ei ole kulkusuunnan
## suuntainen. Muuten kohtisuoraan kulkusuuntaan, sille puolelle, jolla ovi on koneeseen nähden.
func _door_outward(door: Node3D, forward: Vector3) -> Vector3:
	var side := Vector3.UP.cross(forward).normalized()
	if door == null:
		return side
	var look := -door.global_transform.basis.z
	look.y = 0.0
	if look.length() > 0.01 and absf(look.normalized().dot(forward)) < 0.7:
		return look.normalized()
	var aircraft := get_tree().get_first_node_in_group(&"aircraft") as Node3D
	if aircraft != null and (door.global_position - aircraft.global_position).dot(side) < 0.0:
		return -side
	return side


func _on_landed(jumper: Node3D, quality: StringName) -> void:
	if phase != Phase.AIRBORNE:
		return
	if jumper != null and is_instance_valid(player) and jumper != player \
			and not jumper.is_in_group(&"player"):
		return
	_on_player_landed(quality)


func _on_player_landed(_quality: StringName) -> void:
	_set_phase(Phase.LANDED)
	EventBus.squad_callout.emit(null, &"squad_landed")


func _request_fade() -> void:
	var fade := get_tree().get_first_node_in_group(&"fade_layer")
	if fade != null and fade.has_method(&"fade_out"):
		fade.call(&"fade_out")


func _change_scene() -> void:
	scene_change_requested.emit(next_scene)
	if not change_scene_enabled:
		return
	if not ResourceLoader.exists(next_scene):
		push_warning("DropDirector: scene '%s' puuttuu." % next_scene)
		return
	get_tree().change_scene_to_file(next_scene)
