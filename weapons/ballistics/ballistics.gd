class_name Ballistics
extends RefCounted
## Realistinen ballistiikka: jokainen luoti on ammus, jolla on lentoaika ja pudotus.
## Ohilennot tunnistetaan Bullet-luokassa (EventBus.bullet_snap).
## TODO(gameplay-agentti): läpäisy ja kimmokkeet.

const GRAVITY := 9.81
## Luotien törmäysmaski: world (1) ja hitbox (5). Toimijoiden kapselit (2–4) eivät pysäytä luotia,
## jotta osuma menee hitboxille. Kasvillisuus (6) ei pysäytä luotia ennen läpäisymallia.
const BULLET_COLLISION_MASK := (1 << 0) | (1 << 4)


static func fire(shooter: Node3D, origin: Vector3, direction: Vector3, data: WeaponData) -> void:
	EventBus.shot_fired.emit(shooter, origin, direction)
	var bullet := Bullet.new()
	bullet.shooter = shooter
	bullet.velocity = direction.normalized() * data.muzzle_velocity
	bullet.damage = data.damage
	bullet.exclude = collect_exclude_rids(shooter)
	var parent: Node = shooter.get_tree().current_scene
	if parent == null:
		parent = shooter.get_tree().root
	parent.add_child(bullet)
	bullet.global_position = origin


## Ampujan omat törmäysobjektit (runko ja hitboxit), joihin oma luoti ei saa osua.
static func collect_exclude_rids(shooter: Node) -> Array[RID]:
	var rids: Array[RID] = []
	if shooter == null:
		return rids
	if shooter is CollisionObject3D:
		rids.append((shooter as CollisionObject3D).get_rid())
	# find_children tunnistaa vain moottorin luokat, joten Hitbox tarkistetaan erikseen.
	for node: Node in shooter.find_children("*", "Area3D", true, false):
		if node is Hitbox:
			rids.append((node as Area3D).get_rid())
	return rids


## Pisteen lyhin etäisyys janaan a–b. Jos jana on pisteen mittainen, palauttaa etäisyyden pisteeseen a.
static func distance_point_to_segment(point: Vector3, a: Vector3, b: Vector3) -> float:
	var ab := b - a
	var length_sq := ab.length_squared()
	if length_sq < 0.000001:
		return point.distance_to(a)
	var t := clampf((point - a).dot(ab) / length_sq, 0.0, 1.0)
	return point.distance_to(a + ab * t)
