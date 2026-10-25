class_name AmbushDirector
extends Node
## Viidakkoväijytyksen ohjaaja (M3).
##
## Vertical slicen kulku: PATROL → CONTACT → FIREFIGHT → REGROUP → EXTRACTION → COMPLETE.
## Ohjaaja ei tunne pelaajaa tai aseita suoraan: se käyttää EventBus-signaaleja,
## etsii pelaajan ryhmästä "player" ja extraction-pisteen ryhmästä "extraction_point".
##
## Testattavuus: manual_tick = true pysäyttää oman _process-ajon. spawn_enemies = false
## mahdollistaa vaihekoneen testaamisen ilman vihollisia.

signal stage_changed(stage: Stage)

enum Stage { NONE, PATROL, CONTACT, FIREFIGHT, REGROUP, EXTRACTION, COMPLETE }

const ENEMY_SCRIPT := preload("res://missions/ambush/ambush_enemy.gd")

@export var patrol_duration: float = 12.0
@export var contact_duration: float = 2.0
@export var regroup_duration: float = 6.0
@export var enemy_count: int = 4
@export var enemy_health: float = 3.0
@export var enemy_fire_interval: float = 2.5
@export var ambush_radius: float = 18.0
@export var extraction_radius: float = 4.0
## true = ohjaaja ei aja itseään; testi kutsuu step(delta)-metodia.
@export var manual_tick: bool = false
## false = vihollisia ei luoda (yksikkötestit).
@export var spawn_enemies: bool = true

var stage: Stage = Stage.NONE
var enemies: Array[AmbushEnemy] = []

var _time: float = 0.0


func _ready() -> void:
	EventBus.actor_died.connect(_on_actor_died)


func _process(delta: float) -> void:
	if not manual_tick:
		step(delta)


## Aloittaa viidakkotehtävän patikointivaiheesta.
func start() -> void:
	if stage != Stage.NONE:
		return
	_set_stage(Stage.PATROL)
	EventBus.mission_stage_changed.emit(&"patrol")
	EventBus.objective_prompt.emit(
		"Etene ryhmän kanssa pohjoiseen.",
		"Advance north with the squad."
	)


## Ajaa tehtävän tilakonetta eteenpäin delta sekuntia.
func step(delta: float) -> void:
	_time += delta
	match stage:
		Stage.PATROL:
			if _time >= patrol_duration:
				_begin_ambush()
		Stage.CONTACT:
			if _time >= contact_duration:
				_set_stage(Stage.FIREFIGHT)
				EventBus.mission_stage_changed.emit(&"firefight")
				EventBus.objective_prompt.emit(
					"Tori väijytys M60:llä. Käytä kaksijalkaa, nauhoja ja piippua.",
					"Repel the ambush with the M60. Use the bipod, belts and barrel."
				)
		Stage.FIREFIGHT:
			if alive_enemy_count() == 0:
				_clear_ambush()
		Stage.REGROUP:
			if _time >= regroup_duration:
				_begin_extraction()
		Stage.EXTRACTION:
			_check_extraction()
		Stage.NONE, Stage.COMPLETE:
			pass


## Palauttaa elossa olevien väijytyksen vihollisten määrän.
func alive_enemy_count() -> int:
	var count: int = 0
	for enemy: AmbushEnemy in enemies:
		if is_instance_valid(enemy) and enemy.alive:
			count += 1
	return count


## Aloittaa väijytyksen: luo viholliset pelaajan ympärille ja lähettää signaalin.
func _begin_ambush() -> void:
	_set_stage(Stage.CONTACT)
	EventBus.mission_stage_changed.emit(&"contact")
	EventBus.ambush_started.emit()
	EventBus.objective_prompt.emit(
		"Väijytys! Hakeudu suojaan.",
		"Ambush! Take cover."
	)
	if spawn_enemies:
		_spawn_enemies()


## Luo yksinkertaiset vihollisplaceholderit pelaajan ympärille.
func _spawn_enemies() -> void:
	var player := get_tree().get_first_node_in_group(&"player") as Node3D
	if player == null:
		push_warning("AmbushDirector: pelaajaa ei löytynyt ryhmästä 'player'.")
		return
	for index: int in enemy_count:
		var enemy := AmbushEnemy.new()
		enemy.max_health = enemy_health
		enemy.fire_interval = enemy_fire_interval
		var angle: float = TAU * float(index) / float(enemy_count)
		var offset: Vector3 = Vector3(cos(angle), 0.0, sin(angle)) * ambush_radius
		enemy.global_position = player.global_position + offset
		add_child(enemy)
		enemies.append(enemy)


## Merkitsee väijytyksen torjutuksi ja siirtyy ryhmän kokoamiseen.
func _clear_ambush() -> void:
	_set_stage(Stage.REGROUP)
	EventBus.mission_stage_changed.emit(&"regroup")
	EventBus.ambush_cleared.emit()
	EventBus.objective_prompt.emit(
		"Koko ryhmä ja jatka perääntymistä.",
		"Rally the squad and continue the withdrawal."
	)


## Aloittaa perääntymisen extraction-pisteelle.
func _begin_extraction() -> void:
	_set_stage(Stage.EXTRACTION)
	EventBus.mission_stage_changed.emit(&"extraction")
	EventBus.extraction_started.emit()
	EventBus.objective_prompt.emit(
		"Siirry poistumispisteelle.",
		"Move to the extraction point."
	)


## Tarkistaa, onko pelaaja saapunut extraction-pisteelle.
func _check_extraction() -> void:
	var player := get_tree().get_first_node_in_group(&"player") as Node3D
	var marker := get_tree().get_first_node_in_group(&"extraction_point") as Node3D
	if player == null or marker == null:
		return
	if player.global_position.distance_to(marker.global_position) <= extraction_radius:
		_complete_mission()


## Päättää tehtävän onnistuneesti.
func _complete_mission() -> void:
	if stage == Stage.COMPLETE:
		return
	_set_stage(Stage.COMPLETE)
	EventBus.mission_stage_changed.emit(&"complete")
	EventBus.objective_prompt.emit("", "")
	EventBus.mission_completed.emit({"success": true})


func _set_stage(next: Stage) -> void:
	stage = next
	_time = 0.0
	stage_changed.emit(stage)


func _on_actor_died(actor: Node3D) -> void:
	var enemy := actor as AmbushEnemy
	if enemy != null and enemies.has(enemy):
		enemies.erase(enemy)
