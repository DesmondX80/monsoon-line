class_name TrainingStation
extends Node3D
## Harjoitusaseman perusluokka (M2-01). Sopimus: docs/backlog/milestone-2-prologue.json.
##
## - Solmu on ryhmässä "training_station" ja sillä on [member station_id]
##   (obstacle_course, mg_range tai jump_tower).
## - Asema on aluksi pois päältä. Prologin ohjaaja kutsuu [method begin], joka kytkee triggerit
##   päälle ja lähettää EventBus.training_station_started.
## - Kun suoritus on valmis, aliluokka kutsuu [method complete] sopimuksen mukaisella
##   result-sanakirjalla, jolloin lähetetään EventBus.training_station_completed.
## - Tapahtumat radalla (fell, wire_touched, checkpoint, target_hit) lähtevät
##   [method emit_event]-metodilla EventBus.training_event-signaalina.
##
## Asema ei viittaa ohjaajaan eikä Tibbsiin; pelaaja haetaan ryhmästä "player".

## Lähetetään EventBus-signaalin lisäksi paikallisesti (testit ja tason oma logiikka).
signal started
signal completed(result: Dictionary)

const GROUP: StringName = &"training_station"
const PLAYER_GROUP: StringName = &"player"

@export var station_id: StringName = &""

var active: bool = false
## Onko asema suoritettu vähintään kerran.
var finished: bool = false
## Viimeisin tulos (tyhjä ennen ensimmäistä suoritusta).
var last_result: Dictionary = {}


func _ready() -> void:
	add_to_group(GROUP)
	_set_triggers_enabled(false)


## Avaa radan: triggerit päälle, tila nollataan ja EventBus.training_station_started lähtee.
## Uusi kutsu aktiivisena ei tee mitään.
func begin() -> void:
	if active:
		return
	active = true
	_reset_state()
	_set_triggers_enabled(true)
	started.emit()
	EventBus.training_station_started.emit(station_id)


## Suljetaan rata ja lähetetään tulos. Ei tee mitään, jos asema ei ole aktiivinen.
func complete(result: Dictionary) -> void:
	if not active:
		return
	active = false
	finished = true
	last_result = result.duplicate(true)
	_set_triggers_enabled(false)
	completed.emit(last_result)
	EventBus.training_station_completed.emit(station_id, last_result.duplicate(true))


func is_active() -> bool:
	return active


func emit_event(event_id: StringName) -> void:
	EventBus.training_event.emit(station_id, event_id)


## Ensimmäinen solmu ryhmässä "player" tai null.
func find_player() -> Node3D:
	if not is_inside_tree():
		return null
	return get_tree().get_first_node_in_group(PLAYER_GROUP) as Node3D


static func is_player(node: Object) -> bool:
	return node is Node and is_instance_valid(node) and (node as Node).is_in_group(PLAYER_GROUP)


## Siirtää pelaajan merkkiin (esim. kaatumisen jälkeen esteen alkuun) ja nollaa nopeuden.
static func move_player_to(player: Node3D, target: Node3D) -> void:
	if player == null or target == null or not is_instance_valid(player):
		return
	player.global_position = target.global_position
	if player is CharacterBody3D:
		(player as CharacterBody3D).velocity = Vector3.ZERO


# --- Aliluokkien koukut ---

## Nollaa suorituksen tilan begin()-kutsussa.
func _reset_state() -> void:
	pass


## Kytkee aseman triggerit (CourseTrigger-lapset) päälle tai pois.
func _set_triggers_enabled(enabled: bool) -> void:
	for node: Node in find_children("*", "Area3D", true, false):
		if node is CourseTrigger:
			(node as CourseTrigger).set_enabled(enabled)
