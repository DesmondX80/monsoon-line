@tool
class_name CourseTrigger
extends Area3D
## Harjoitusradan triggeri (lähtö, välietappi, maali, kaatumisalue, piikkilanka-alue,
## korokkeen yläpuoli, yleinen alue kuten ampuma-asema tai tornin ovi).
##
## Laatikon muotoinen alue, jonka koko on [member size] (keskitetty solmun origoon).
## Havaitsee vain pelaajan kerroksen (2). Asema kytkee triggerit päälle begin()-kutsussa.
## Triggeri ei tee päätöksiä itse: se lähettää [signal player_entered] ja [signal player_exited],
## ja asema päättää, mitä tapahtuu. Triggeri muistaa sisällä olevan pelaajan ([member player_inside]),
## jotta piikkilanka-alue voi tarkistaa asennon joka fysiikka-askeleella.

signal player_entered(trigger: CourseTrigger, player: Node3D)
signal player_exited(trigger: CourseTrigger, player: Node3D)

enum Kind { START, CHECKPOINT, FINISH, FALL, WIRE, ELEVATED, ZONE }

const PLAYER_LAYER: int = 1 << 1

@export var kind: Kind = Kind.CHECKPOINT
## Välietapin järjestysnumero (0 = ensimmäinen). Muille tyypeille ei merkitystä.
@export var index: int = 0
@export var size: Vector3 = Vector3(4.0, 2.5, 1.0):
	set(value):
		size = value
		_update_shape()
## Kaatumisalue: mihin pelaaja palautetaan (esim. puomin alkuun). Valinnainen.
@export var reset_point: Node3D

var player_inside: Node3D = null
var enabled: bool = false

var _shape: CollisionShape3D


func _ready() -> void:
	collision_layer = 0
	collision_mask = PLAYER_LAYER
	monitorable = false
	_update_shape()
	if Engine.is_editor_hint():
		return
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


## Kytkee havainnoinnin. Pois kytkettäessä sisällä olleen pelaajan tieto unohdetaan.
func set_enabled(value: bool) -> void:
	enabled = value
	if not value:
		player_inside = null
	if is_inside_tree():
		set_deferred(&"monitoring", value)
	else:
		monitoring = value


func _update_shape() -> void:
	if not is_inside_tree():
		return
	if _shape == null:
		_shape = get_node_or_null(^"Shape") as CollisionShape3D
	if _shape == null:
		_shape = CollisionShape3D.new()
		_shape.name = "Shape"
		add_child(_shape)
	var box := BoxShape3D.new()
	box.size = size
	_shape.shape = box


func _on_body_entered(body: Node3D) -> void:
	if not enabled or not TrainingStation.is_player(body):
		return
	player_inside = body
	player_entered.emit(self, body)


func _on_body_exited(body: Node3D) -> void:
	if not TrainingStation.is_player(body):
		return
	if player_inside == body:
		player_inside = null
	if enabled:
		player_exited.emit(self, body)
