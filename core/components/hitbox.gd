class_name Hitbox
extends Area3D
## Ruumiinosan osuma-alue. Välittää osuman omistajan HealthComponentille.

@export var body_part: StringName = &"torso"
@export var health: HealthComponent


func receive_hit(damage: float) -> void:
	if health:
		health.take_hit(damage, body_part)
