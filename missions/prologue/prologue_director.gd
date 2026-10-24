class_name PrologueDirector
extends Node
## Prologin ohjaaja (M2-04): Fort Benning, laskuvarjokoulu kesällä 1966.
##
## Vaiheet: WELCOME → OBSTACLE_COURSE → MG_RANGE → JUMP_TOWER → NICKNAME → GRADUATION → DONE,
## jonka jälkeen vaihdetaan sceneen res://world/levels/c130_drop.tscn.
##
## Asemavaiheessa Tibbs kävelee aseman markerille (ryhmä station_<id>), sanoo esittelyrepliikin,
## ohje näytetään (objective_prompt) ja aseman begin() kutsutaan. Ohjaaja odottaa
## EventBus.training_station_completed-signaalia, reagoi training_event-signaaleihin ja
## kiirehtii pelaajaa, jos edistystä ei ole näkynyt hurry_timeout-sekuntiin.
##
## Kaikki world-solmut haetaan ryhmistä (tibbs_spawn, station_<id>, training_station, fade_layer),
## ei koskaan polulla. Puuttuvat solmut eivät kaada ohjaajaa: puuttuva asema ohitetaan varoituksella.
##
## Testattavuus: manual_tick = true pysäyttää oman _process-ajon, jolloin testi kutsuu step(delta).

signal stage_changed(stage: Stage)
signal scene_change_requested(path: String)

enum Stage { NONE, WELCOME, OBSTACLE_COURSE, MG_RANGE, JUMP_TOWER, NICKNAME, GRADUATION, DONE }
## Asemavaiheen alivaihe.
enum Phase { WALKING, ACTIVE, DEBRIEF, WAITING }

const STATION_IDS := {
	Stage.OBSTACLE_COURSE: &"obstacle_course",
	Stage.MG_RANGE: &"mg_range",
	Stage.JUMP_TOWER: &"jump_tower",
}
const INTRO_LINES := {
	&"obstacle_course": [&"tibbs_obstacle_intro"],
	&"mg_range": [&"tibbs_mg_intro", &"tibbs_mg_bipod", &"tibbs_mg_belt", &"tibbs_mg_barrel"],
	&"jump_tower": [&"tibbs_tower_intro"],
}
const PROMPTS := {
	&"obstacle_course": [
		"Suorita esterata: muurin yli, verkon yli, piikkilangan ali ja puomia pitkin.",
		"Run the obstacle course: over the wall, over the net, under the wire and along the beam.",
	],
	&"mg_range": [
		"Ammu maalit konekiväärillä. Kaksijalka V, uusi nauha R, piipunvaihto B.",
		"Engage the targets with the machine gun. Bipod V, new belt R, barrel change B.",
	],
	&"jump_tower": [
		"Kiipeä hyppytorniin ja hyppää. Paina C juuri ennen maata (PLF).",
		"Climb the jump tower and jump. Press C just before you hit the ground (PLF).",
	],
}
const TITLE := "Fort Benning, Georgia"
const SUBTITLE := "Laskuvarjokoulu – kesä 1966"

@export var next_scene: String = "res://world/levels/c130_drop.tscn"
@export var nickname_rules: NicknameRuleSet
## Tibbsin scene, jos Tibbs-lapsisolmua ei ole valmiiksi.
@export var tibbs_scene: PackedScene
@export var auto_start: bool = true
## false = vaihtoa ei tehdä, vain scene_change_requested lähetetään (testit).
@export var change_scene_enabled: bool = true
## true = ohjaaja ei aja itseään, vaan step(delta) kutsutaan ulkoa (testit).
@export var manual_tick: bool = false
@export_group("Ajoitus")
## Pienin väli Tibbsin repliikkien välillä.
@export var line_gap: float = 3.0
@export var welcome_duration: float = 6.0
@export var debrief_duration: float = 4.0
@export var nickname_duration: float = 5.0
@export var graduation_duration: float = 6.0
## Viive häivytyksen alusta scene-vaihtoon.
@export var scene_change_delay: float = 1.5
## Jos pelaaja ei edisty näin moneen sekuntiin, Tibbs kiirehtii.
@export var hurry_timeout: float = 45.0
## Jos Tibbs ei pääse markerille tässä ajassa, hänet siirretään sinne.
@export var walk_timeout: float = 25.0
## Ylikuumenemisrepliikin oma jäähtymisaika.
@export var overheat_line_cooldown: float = 15.0
@export_group("Arviointi")
@export var obstacle_good_max_time_s: float = 120.0
@export var obstacle_good_max_falls: int = 0
@export var obstacle_good_max_wire: int = 1
@export var mg_good_min_hit_ratio: float = 0.4

var stage: Stage = Stage.NONE
var phase: Phase = Phase.WAITING
var tibbs: Node3D
## Kaikkien asemien tulokset { station_id: result }.
var results: Dictionary = {}
var nickname: String = ""
var lines: LineQueue

var _phase_time: float = 0.0
var _idle_time: float = 0.0
var _overheat_cooldown: float = 0.0
var _current_station: Node
var _scene_change_pending: bool = false


func _ready() -> void:
	lines = LineQueue.new(line_gap)
	if nickname_rules == null and ResourceLoader.exists("res://missions/prologue/nickname_rules.tres"):
		nickname_rules = load("res://missions/prologue/nickname_rules.tres") as NicknameRuleSet
	tibbs = get_node_or_null(^"Tibbs") as Node3D
	if tibbs == null and tibbs_scene != null:
		tibbs = tibbs_scene.instantiate() as Node3D
		tibbs.name = &"Tibbs"
		add_child(tibbs)
	EventBus.training_station_started.connect(_on_station_started)
	EventBus.training_station_completed.connect(_on_station_completed)
	EventBus.training_event.connect(_on_training_event)
	EventBus.barrel_overheated.connect(_on_barrel_overheated)
	if auto_start:
		start.call_deferred()


func _process(delta: float) -> void:
	if not manual_tick:
		step(delta)


## Aloittaa prologin alusta.
func start() -> void:
	if stage != Stage.NONE:
		return
	_place_tibbs_at_spawn()
	EventBus.title_card.emit(TITLE, SUBTITLE)
	_enter_stage(Stage.WELCOME)


## Ajaa ohjaajaa eteenpäin delta sekuntia.
func step(delta: float) -> void:
	lines.tick(delta)
	_phase_time += delta
	_overheat_cooldown = maxf(_overheat_cooldown - delta, 0.0)
	match stage:
		Stage.WELCOME:
			if _phase_time >= welcome_duration and lines.is_empty():
				_enter_stage(Stage.OBSTACLE_COURSE)
		Stage.OBSTACLE_COURSE, Stage.MG_RANGE, Stage.JUMP_TOWER:
			_step_station(delta)
		Stage.NICKNAME:
			if _phase_time >= nickname_duration and lines.is_empty():
				_enter_stage(Stage.GRADUATION)
		Stage.GRADUATION:
			if _phase_time >= graduation_duration and lines.is_empty():
				_enter_stage(Stage.DONE)
		Stage.DONE:
			if _scene_change_pending and _phase_time >= scene_change_delay:
				_scene_change_pending = false
				_change_scene()


func current_station_id() -> StringName:
	return STATION_IDS.get(stage, &"")


# --- Vaiheet ---

func _enter_stage(next: Stage) -> void:
	stage = next
	_phase_time = 0.0
	_idle_time = 0.0
	stage_changed.emit(stage)
	match stage:
		Stage.WELCOME:
			phase = Phase.WAITING
			_say(&"tibbs_welcome")
		Stage.OBSTACLE_COURSE, Stage.MG_RANGE, Stage.JUMP_TOWER:
			_begin_station_stage()
		Stage.NICKNAME:
			phase = Phase.WAITING
			_assign_nickname()
		Stage.GRADUATION:
			phase = Phase.WAITING
			EventBus.objective_prompt.emit("", "")
			_walk_tibbs_to_group(&"tibbs_spawn")
			_say(&"tibbs_graduation")
		Stage.DONE:
			phase = Phase.WAITING
			_request_fade()
			_scene_change_pending = true


func _begin_station_stage() -> void:
	var station_id := current_station_id()
	_current_station = _find_station(station_id)
	phase = Phase.WALKING
	if not _walk_tibbs_to_group(StringName("station_%s" % station_id)):
		_activate_station()


func _step_station(delta: float) -> void:
	match phase:
		Phase.WALKING:
			if _tibbs_arrived():
				_activate_station()
			elif _phase_time >= walk_timeout:
				_teleport_tibbs_to_group(StringName("station_%s" % current_station_id()))
				_activate_station()
		Phase.ACTIVE:
			_idle_time += delta
			if _idle_time >= hurry_timeout:
				_idle_time = 0.0
				_say(&"tibbs_idle_hurry")
		Phase.DEBRIEF:
			if _phase_time >= debrief_duration and lines.is_empty():
				_enter_stage((stage + 1) as Stage)


func _activate_station() -> void:
	var station_id := current_station_id()
	phase = Phase.ACTIVE
	_phase_time = 0.0
	_idle_time = 0.0
	for line_id: StringName in INTRO_LINES.get(station_id, []):
		_say(line_id)
	var prompt: Array = PROMPTS.get(station_id, ["", ""])
	EventBus.objective_prompt.emit(prompt[0] as String, prompt[1] as String)
	if _current_station == null or not is_instance_valid(_current_station):
		push_warning("PrologueDirector: asemaa '%s' ei löydy ryhmästä training_station, ohitetaan." % station_id)
		_complete_station({})
		return
	if _current_station.has_method(&"begin"):
		_current_station.call(&"begin")
	else:
		push_warning("PrologueDirector: asemalla '%s' ei ole begin()-metodia." % station_id)


func _complete_station(result: Dictionary) -> void:
	var station_id := current_station_id()
	results[station_id] = result.duplicate(true)
	phase = Phase.DEBRIEF
	_phase_time = 0.0
	EventBus.objective_prompt.emit("", "")
	if not result.is_empty():
		_say(debrief_line(station_id, result))


## Arviolinja aseman tuloksesta: done_good/done_bad tai tornilla good/hard.
func debrief_line(station_id: StringName, result: Dictionary) -> StringName:
	match station_id:
		&"obstacle_course":
			var good := float(result.get("time_s", INF)) <= obstacle_good_max_time_s \
					and int(result.get("falls", 0)) <= obstacle_good_max_falls \
					and int(result.get("wire_touches", 0)) <= obstacle_good_max_wire
			return &"tibbs_obstacle_done_good" if good else &"tibbs_obstacle_done_bad"
		&"mg_range":
			var shots := int(result.get("shots", 0))
			var ratio := float(result.get("hits", 0)) / float(shots) if shots > 0 else 0.0
			var good := ratio >= mg_good_min_hit_ratio and not bool(result.get("overheated", false))
			return &"tibbs_mg_done_good" if good else &"tibbs_mg_done_bad"
		&"jump_tower":
			var landing := StringName(str(result.get("landing", &"hard")))
			return &"tibbs_tower_good" if landing == &"good" else &"tibbs_tower_hard"
	return &""


func _assign_nickname() -> void:
	nickname = NicknameResolver.resolve_with_set(nickname_rules, results)
	GameState.player_nickname = nickname
	EventBus.nickname_assigned.emit(nickname)
	_say(&"tibbs_nickname")


# --- Signaalit ---

func _on_station_started(station_id: StringName) -> void:
	if station_id == current_station_id():
		_idle_time = 0.0


func _on_station_completed(station_id: StringName, result: Dictionary) -> void:
	if station_id != current_station_id() or phase != Phase.ACTIVE:
		return
	_complete_station(result)


func _on_training_event(station_id: StringName, event_id: StringName) -> void:
	if station_id != current_station_id() or phase != Phase.ACTIVE:
		return
	_idle_time = 0.0
	match event_id:
		&"fell":
			_say(&"tibbs_obstacle_fell")
		&"wire_touched":
			_say(&"tibbs_obstacle_wire")


func _on_barrel_overheated(_weapon: Node) -> void:
	if stage != Stage.MG_RANGE or phase != Phase.ACTIVE or _overheat_cooldown > 0.0:
		return
	_overheat_cooldown = overheat_line_cooldown
	_idle_time = 0.0
	_say(&"tibbs_mg_overheat")


# --- Tibbs ja maailma ---

func _say(line_id: StringName) -> void:
	if line_id == &"":
		return
	lines.push(tibbs if is_instance_valid(tibbs) else null, line_id)
	if is_instance_valid(tibbs) and tibbs.has_method(&"say"):
		tibbs.call(&"say", line_id, line_gap)


func _find_station(station_id: StringName) -> Node:
	for node: Node in get_tree().get_nodes_in_group(&"training_station"):
		if StringName(str(node.get(&"station_id"))) == station_id:
			return node
	return null


func _first_marker(group: StringName) -> Node3D:
	return get_tree().get_first_node_in_group(group) as Node3D


func _place_tibbs_at_spawn() -> void:
	if not is_instance_valid(tibbs):
		return
	var marker := _first_marker(&"tibbs_spawn")
	if marker == null:
		push_warning("PrologueDirector: tibbs_spawn-markeria ei löydy.")
		return
	if tibbs.has_method(&"teleport_to"):
		tibbs.call(&"teleport_to", marker.global_transform)
	else:
		tibbs.global_transform = marker.global_transform


## Lähettää Tibbsin ryhmän ensimmäiselle markerille. Palauttaa false, jos kävelyä ei aloitettu.
func _walk_tibbs_to_group(group: StringName) -> bool:
	var marker := _first_marker(group)
	if marker == null or not is_instance_valid(tibbs) or not tibbs.has_method(&"walk_to"):
		return false
	tibbs.call(&"walk_to", marker.global_position)
	return true


func _teleport_tibbs_to_group(group: StringName) -> void:
	var marker := _first_marker(group)
	if marker != null and is_instance_valid(tibbs) and tibbs.has_method(&"teleport_to"):
		tibbs.call(&"teleport_to", marker.global_transform)


func _tibbs_arrived() -> bool:
	if not is_instance_valid(tibbs) or not tibbs.has_method(&"has_arrived"):
		return true
	return bool(tibbs.call(&"has_arrived"))


func _request_fade() -> void:
	var fade := get_tree().get_first_node_in_group(&"fade_layer")
	if fade != null and fade.has_method(&"fade_out"):
		fade.call(&"fade_out")


func _change_scene() -> void:
	scene_change_requested.emit(next_scene)
	if not change_scene_enabled:
		return
	if not ResourceLoader.exists(next_scene):
		push_warning("PrologueDirector: scene '%s' puuttuu." % next_scene)
		return
	get_tree().change_scene_to_file(next_scene)
