class_name AmbushEnemy
extends Node3D
## Väijytyksen yksinkertainen vihollisplaceholder (M3).
##
## Tarkoitus on saada vertical slicen taisteluvaihe pelattavaksi ja testattavaksi
## ilman valmista vihollismallia tai navigointia. Vihollinen reagoi EventBusin
## actor_hit-signaaliin ja kuolee, kun terveys loppuu.

signal enemy_died(enemy: AmbushEnemy)

@export var max_health: float = 3.0
@export var fire_interval: float = 2.5
@export var fire_line: StringName = &"enemy_fire"

var health: float = 0.0
var alive: bool = true

var _fire_timer: float = 0.0


func _ready() -> void:
	health = max_health
	_fire_timer = fire_interval
	EventBus.actor_hit.connect(_on_actor_hit)


func _process(delta: float) -> void:
	if not alive:
		return
	_fire_timer -= delta
	if _fire_timer <= 0.0:
		_fire_timer = fire_interval
		EventBus.squad_callout.emit(self, fire_line)


## Vähentää vihollisen terveyttä ja lähettää kuolin-signaalin, jos se kuolee.
func take_hit(damage: float) -> void:
	if not alive:
		return
	health -= damage
	if health <= 0.0:
		alive = false
		EventBus.actor_died.emit(self)
		enemy_died.emit(self)
		queue_free()


func _on_actor_hit(target: Node3D, damage: float, _body_part: StringName) -> void:
	if target == self:
		take_hit(damage)
