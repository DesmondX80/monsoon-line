class_name MachineGun
extends Node3D
## Konekiväärin logiikka: nauha, piipun kuumeneminen, piipunvaihto, kaksijalka, jumitus,
## rekyyli ja huojunta (WeaponHandling). Ampuminen delegoidaan Ballistics-järjestelmälle.
## Kaikki säätöarvot tulevat WeaponData-resurssista.

signal fired
signal reloaded
signal barrel_changed
signal bipod_changed(deployed: bool)

## Lämpö, jonka yläpuolella ase voi jumittua.
const JAM_HEAT_THRESHOLD := 0.7

@export var data: WeaponData
@export var muzzle: Marker3D
@export_group("Ulkoinen malli")
## Polku FBX/GLTF-malliin. Jos tiedosto puuttuu, mallia ei ladata.
@export var external_model_path: String = "res://weapons/models/m60/m60.fbx"
## false = ulkoista mallia ei ladata edes jos tiedosto löytyy.
@export var external_model_enabled: bool = true
@export var external_model_scale: Vector3 = Vector3.ONE
@export var external_model_rotation_degrees: Vector3 = Vector3.ZERO
@export var external_model_position: Vector3 = Vector3.ZERO

var rounds_in_belt: int = 0
var heat: float = 0.0
var bipod_deployed: bool = false:
	set(value):
		if bipod_deployed != value:
			bipod_deployed = value
			bipod_changed.emit(value)
var jammed: bool = false
var busy: bool = false  ## lataus tai piipunvaihto käynnissä
## Rekyyli ja huojunta. Luodaan _readyssä datan perusteella.
var handling: WeaponHandling
## Satunnaisuus hajonnalle ja jumitukselle. Testit voivat asettaa siemenen.
var rng: RandomNumberGenerator = RandomNumberGenerator.new()

var _cooldown: float = 0.0


func _ready() -> void:
	rng.randomize()
	if data == null:
		push_error("MachineGun ilman WeaponDataa: %s" % get_path())
		set_process(false)
		return
	rounds_in_belt = data.magazine_size
	handling = WeaponHandling.new(data)
	_load_external_model()


func _process(delta: float) -> void:
	tick(delta)


## Ajan kulku: tulinopeuden viive ja piipun jäähtyminen. Erillään _processista testattavuuden vuoksi.
func tick(delta: float) -> void:
	_cooldown = maxf(_cooldown - delta, 0.0)
	heat = maxf(heat - data.cooling_per_second * delta, 0.0)


func can_fire() -> bool:
	return not busy and not jammed and rounds_in_belt > 0 and _cooldown == 0.0 and heat < 1.0


## Yrittää ampua yhden laukauksen. Palauttaa true, jos laukaus lähti.
func try_fire(shooter: Node3D) -> bool:
	if not can_fire():
		if rounds_in_belt == 0 and not busy:
			EventBus.belt_empty.emit(self)
		return false
	_cooldown = 60.0 / data.rounds_per_minute
	rounds_in_belt -= 1
	heat = minf(heat + data.heat_per_shot, 1.0)
	if heat >= 1.0:
		EventBus.barrel_overheated.emit(self)
	if heat > JAM_HEAT_THRESHOLD and rng.randf() < data.jam_chance_when_hot:
		jammed = true
	var direction := _spread_direction()
	if handling:
		handling.add_shot(bipod_deployed)
	if muzzle != null and shooter != null and shooter.is_inside_tree():
		Ballistics.fire(shooter, muzzle.global_position, direction, data)
	fired.emit()
	return true


func current_spread_deg() -> float:
	var spread := data.hip_spread_deg
	if bipod_deployed:
		spread *= data.supported_spread_multiplier
	return spread


## Yrittää laskea kaksijalan. Makuulla aina, muuten vain, jos piipun edessä on tuki.
## Palauttaa true, jos kaksijalka on laskettuna kutsun jälkeen.
func deploy_bipod(prone: bool, has_rest: bool) -> bool:
	if BipodSupport.can_deploy(data.has_bipod, prone, has_rest):
		bipod_deployed = true
	return bipod_deployed


func retract_bipod() -> void:
	bipod_deployed = false


## Päivittää rekyylin palautuksen ja huojunnan. stamina ja suppression 0–1.
func update_handling(delta: float, stamina: float, suppression: float) -> void:
	if handling:
		handling.update(delta, stamina, suppression, bipod_deployed)


## Rekyylin ja huojunnan yhteinen kulmapoikkeama asteina (x = pysty, y = sivu).
func get_aim_offset() -> Vector2:
	return handling.get_offset() if handling else Vector2.ZERO


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


## Lataa ulkoisen M60-mallin, jos se on lisätty projektiin.
## Godot tuo FBX-tiedostot yleensä PackedScene-resurssina, joten ne on instansioitava.
func _load_external_model() -> void:
	if not external_model_enabled or external_model_path.is_empty():
		return
	if not ResourceLoader.exists(external_model_path):
		push_warning("MachineGun: ulkoista mallia ei löytynyt polusta %s." % external_model_path)
		return
	var resource := load(external_model_path)
	if resource == null:
		push_warning("MachineGun: mallia ei voitu ladata polusta %s." % external_model_path)
		return
	var model := _instantiate_model(resource)
	if model == null:
		push_warning("MachineGun: malli ei ole Node3D eikä PackedScene: %s." % external_model_path)
		return
	model.name = &"ExternalM60Model"
	model.scale = external_model_scale
	model.rotation_degrees = external_model_rotation_degrees
	model.position = external_model_position
	add_child(model)


## Luo Node3D:n joko suoraan Node3D-resurssista tai PackedScene-instanssista.
func _instantiate_model(resource: Resource) -> Node3D:
	if resource is Node3D:
		return resource as Node3D
	if resource is PackedScene:
		var scene := resource as PackedScene
		return scene.instantiate() as Node3D
	return null


func _spread_direction() -> Vector3:
	var basis := transform.basis
	if muzzle != null and muzzle.is_inside_tree():
		basis = muzzle.global_transform.basis
	elif is_inside_tree():
		basis = global_transform.basis
	var forward := -basis.z
	var spread := deg_to_rad(current_spread_deg())
	var yaw := rng.randf_range(-spread, spread) * 0.5
	var pitch := rng.randf_range(-spread, spread) * 0.5
	return forward.rotated(basis.y.normalized(), yaw).rotated(basis.x.normalized(), pitch).normalized()
