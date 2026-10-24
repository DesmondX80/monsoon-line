class_name MachineGun
extends Node3D
## Konekiväärin logiikka: nauha, piipun kuumeneminen, piipunvaihto, kaksijalka ja jumitus.
## Ampuminen delegoidaan Ballistics-järjestelmälle.

signal fired
signal reloaded
signal barrel_changed

@export var data: WeaponData
@export var muzzle: Marker3D

var rounds_in_belt: int
var heat: float = 0.0
var bipod_deployed: bool = false
var jammed: bool = false
var busy: bool = false  ## lataus tai piipunvaihto käynnissä

var _cooldown: float = 0.0


func _ready() -> void:
	rounds_in_belt = data.magazine_size


func _process(delta: float) -> void:
	_cooldown = maxf(_cooldown - delta, 0.0)
	heat = maxf(heat - data.cooling_per_second * delta, 0.0)


func can_fire() -> bool:
	return not busy and not jammed and rounds_in_belt > 0 and _cooldown == 0.0 and heat < 1.0


func try_fire(shooter: Node3D) -> bool:
	if not can_fire():
		if rounds_in_belt == 0:
			EventBus.belt_empty.emit(self)
		return false
	_cooldown = 60.0 / data.rounds_per_minute
	rounds_in_belt -= 1
	heat = minf(heat + data.heat_per_shot, 1.0)
	if heat >= 1.0:
		EventBus.barrel_overheated.emit(self)
	if heat > 0.7 and randf() < data.jam_chance_when_hot:
		jammed = true
	var direction := _spread_direction()
	Ballistics.fire(shooter, muzzle.global_position, direction, data)
	fired.emit()
	return true


func current_spread_deg() -> float:
	var spread := data.hip_spread_deg
	if bipod_deployed:
		spread *= data.supported_spread_multiplier
	return spread


func reload() -> void:
	if busy:
		return
	busy = true
	await get_tree().create_timer(data.reload_time).timeout
	rounds_in_belt = data.magazine_size
	jammed = false
	busy = false
	reloaded.emit()


func change_barrel(assisted: bool) -> void:
	if busy:
		return
	busy = true
	var time := data.barrel_change_time * (0.6 if assisted else 1.0)
	await get_tree().create_timer(time).timeout
	heat = 0.0
	busy = false
	barrel_changed.emit()


func clear_jam() -> void:
	jammed = false


func _spread_direction() -> Vector3:
	var forward := -muzzle.global_transform.basis.z
	var spread := deg_to_rad(current_spread_deg())
	var yaw := randf_range(-spread, spread) * 0.5
	var pitch := randf_range(-spread, spread) * 0.5
	return forward.rotated(muzzle.global_transform.basis.y, yaw).rotated(muzzle.global_transform.basis.x, pitch).normalized()
