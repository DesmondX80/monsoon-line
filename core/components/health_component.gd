class_name HealthComponent
extends Node
## Osakohtainen terveys ja verenvuoto. Sama komponentti pelaajalle, ryhmälle ja vihollisille.

signal died
signal limb_disabled(body_part: StringName)

@export var max_health: float = 100.0
## Kuinka paljon terveyttä menetetään sekunnissa per vuotava haava.
@export var bleed_rate: float = 1.5

var health: float
var bleeding_wounds: int = 0
var disabled_parts: Array[StringName] = []

const DAMAGE_MULTIPLIER := {
	&"head": 4.0,
	&"torso": 1.0,
	&"arm_l": 0.6, &"arm_r": 0.6,
	&"leg_l": 0.6, &"leg_r": 0.6,
}


func _ready() -> void:
	health = max_health


func _process(delta: float) -> void:
	if bleeding_wounds > 0 and health > 0.0:
		_apply(bleed_rate * bleeding_wounds * delta)


func take_hit(damage: float, body_part: StringName) -> void:
	_apply(damage * DAMAGE_MULTIPLIER.get(body_part, 1.0))
	bleeding_wounds += 1
	if body_part != &"torso" and body_part != &"head" and body_part not in disabled_parts:
		disabled_parts.append(body_part)
		limb_disabled.emit(body_part)
	EventBus.actor_hit.emit(owner, damage, body_part)


func bandage() -> void:
	bleeding_wounds = maxi(bleeding_wounds - 1, 0)


func _apply(amount: float) -> void:
	health = maxf(health - amount, 0.0)
	if health == 0.0:
		died.emit()
		EventBus.actor_died.emit(owner)
		set_process(false)
