class_name AmbushHitbox
extends Hitbox
## Väijytyksen vihollisen osuma-alue.
##
## Bullet kutsuu vain Hitbox-luokan receive_hit-metodia, joten tämä luokka
## välittää osuman AmbushEnemylle. Tämä pitää vihollisen osumapolun yhteensopivana
## projektin olemassa olevan ballistiikan kanssa.

var enemy: AmbushEnemy


func receive_hit(damage: float) -> void:
	if enemy != null and is_instance_valid(enemy):
		enemy.take_hit(damage)
