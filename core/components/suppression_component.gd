class_name SuppressionComponent
extends Node
## Tukahdutus: ohi lentävät luodit nostavat arvoa, joka heikentää tähtäystä ja liikettä.
## Toimii sekä pelaajalle että AI:lle.

@export var recovery_per_second: float = 0.15
## Lisäys yhdestä läheltä ohi menneestä luodista, kun etäisyys on 0 m.
@export var snap_strength: float = 0.2
@export var snap_radius: float = 4.0

var amount: float = 0.0  ## 0.0–1.0


func _process(delta: float) -> void:
	if amount > 0.0:
		_set_amount(amount - recovery_per_second * delta)


func register_near_miss(distance: float) -> void:
	if distance > snap_radius:
		return
	var falloff := 1.0 - distance / snap_radius
	_set_amount(amount + snap_strength * falloff)


func is_pinned() -> bool:
	return amount >= 0.7


func _set_amount(value: float) -> void:
	var clamped := clampf(value, 0.0, 1.0)
	if not is_equal_approx(clamped, amount):
		amount = clamped
		EventBus.suppression_changed.emit(owner, amount)
