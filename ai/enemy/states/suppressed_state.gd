class_name EnemySuppressedState
extends EnemyState
## Tukahdutettu: painuu maahan eikä ammu, kunnes tukahdutus laskee.

## Tukahdutuksen taso, jonka alapuolella vihollinen palaa taisteluun.
@export var recover_threshold: float = 0.3
@export var min_time: float = 1.5

var _timer: float = 0.0


func enter() -> void:
	enemy.set_stance(EnemyController.Stance.PRONE)
	enemy.stop()
	_timer = 0.0
	# Ohi viuhuvat luodit kertovat, että joku ampuu: vähintään epäluulo.
	perception.alert(perception.investigate_position)


func physics_update(delta: float) -> void:
	_timer += delta
	if _timer < min_time or enemy.suppression.amount > recover_threshold:
		return
	if perception.detected:
		machine.transition_to(&"Combat")
	else:
		machine.transition_to(&"Suspicious")
