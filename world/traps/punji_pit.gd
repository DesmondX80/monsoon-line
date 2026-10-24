class_name PunjiPit
extends Area3D
## Punji-ansa (M1-12): naamioitu kuoppa, jonka pohjalla on teroitettuja bambupaaluja.
##
## Kun pelaaja astuu kannen päälle, ansa laukeaa KERRAN: kutsuu kohteen
## HealthComponent.take_hit(damage, body_part), mikä vahingoittaa jalkaa ja avaa vuotavan haavan.
## Kansi romahtaa ja paalut paljastuvat, jolloin laukaistu ansa on selvästi näkyvä.
##
## Huomattavuus: kansi on hieman ympäristöä vaaleampi ja kuivempi lehtikasa, ja yksi paalun
## kärki pilkistää reunasta – tarkkaavainen pelaaja voi kiertää sen.

signal triggered(victim: Node3D)

@export var damage: float = 30.0
@export var body_part: StringName = &"leg_l"

@onready var _lid: Node3D = $Lid
@onready var _revealed: Node3D = $Revealed

var _triggered: bool = false


func _ready() -> void:
	add_to_group(&"trap")
	_revealed.visible = false
	body_entered.connect(_on_body_entered)


## Onko ansa jo lauennut?
func is_triggered() -> bool:
	return _triggered


func _on_body_entered(body: Node3D) -> void:
	if _triggered:
		return
	var health: HealthComponent = _find_health(body)
	if health == null:
		return
	_triggered = true
	set_deferred(&"monitoring", false)
	health.take_hit(damage, body_part)
	_lid.visible = false
	_revealed.visible = true
	triggered.emit(body)


func _find_health(body: Node) -> HealthComponent:
	for child: Node in body.get_children():
		if child is HealthComponent:
			return child as HealthComponent
	return null
