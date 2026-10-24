class_name ParachuteController
extends Node
## Laskuvarjohyppy (T-10, staattinen vaijeri) ja laskeutumisen arviointi (PLF).
## Pelaajan lapsisolmu "ParachuteController". PlayerController kutsuu joka fysiikka-askeleella
## tick()-metodia ennen move_and_slidea ja report_motion()-metodia sen jälkeen, joten logiikka
## on testattavissa ilman todellista fysiikkaa.
##
## Vaiheet (Phase): IDLE (maassa, ei hyppyä) → EXIT (ulos ovesta, vaijeri vetää kuvun auki noin 3,5 s,
## putoaminen ilmanvastuksella) → CANOPY (kupu auki, vajoaminen noin 5 m/s, hidas ohjaus)
## → LANDED (laskeutunut; ase käytössä).
##
## Laskeutuminen arvioidaan LandingEvaluatorilla. Sama arvio tehdään tavallisille yli 2 m
## pudotuksille (hyppytorni). Lähettää EventBus.jump_started, chute_opened ja landed.

enum Phase { IDLE, EXIT, CANOPY, LANDED }

@export_group("Ulos koneesta")
## Aika ovelta kuvun aukeamiseen (staattinen vaijeri vetää kuvun auki).
@export var exit_duration: float = 3.5
## Neliöllinen ilmanvastus (1/m). 0,0032 → rajanopeus noin 55 m/s.
@export var exit_drag: float = 0.0032
@export_group("Kupu")
## Kuvun vakaa vajoamisnopeus (m/s).
@export var canopy_descent_speed: float = 5.0
## Kuinka nopeasti pystynopeus lähestyy vajoamisnopeutta kuvun auettua (1/s).
## Määrää avautumisnykäyksen jyrkkyyden.
@export var canopy_vertical_response: float = 3.0
## Ohjauksella saavutettava vaakanopeus (m/s).
@export var steer_speed: float = 3.0
## Kuinka nopeasti vaakanopeus lähestyy ohjausta (1/s). Pieni = hidas, raskas ohjaus.
@export var steer_response: float = 0.8
## Tuulen aiheuttama ajelehtiminen (m/s, vaakataso).
@export var wind: Vector3 = Vector3.ZERO
@export_group("Kamera")
## Avautumisnykäyksen kameran heilahdus asteina (negatiivinen = pää painuu alas).
@export var opening_jolt_deg: float = -12.0
## Heilahduksen vaimeneminen (1/s).
@export var jolt_decay: float = 5.0

var phase: Phase = Phase.IDLE
var evaluator: LandingEvaluator = LandingEvaluator.new()
## Satunnaisuus loukkaantuvan jalan valintaan. Testit voivat asettaa siemenen.
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
## Viimeisimmän laskeutumisen laatu (&"" ennen ensimmäistä).
var last_landing: StringName = &""

var _health: HealthComponent
var _stamina: StaminaModel
var _gravity: float = 9.8
var _phase_time: float = 0.0
var _since_plf: float = INF
var _stun_left: float = 0.0
var _jolt_deg: float = 0.0
## Hypyn aikana: onko hyppääjä jo irronnut lattiasta (estää kosketuksen heti ovella).
var _left_ground: bool = false
## Tavallisen pudotuksen seuranta.
var _falling: bool = false
var _fall_peak_y: float = 0.0
var _exit_velocity: Vector3 = Vector3.ZERO
## Seuraava tick korvaa nopeuden _exit_velocitylla (EXIT-vaiheen alku tai suora kupulaskeutuminen).
var _pending_velocity: bool = false


func _ready() -> void:
	rng.randomize()
	_gravity = float(ProjectSettings.get_setting("physics/3d/default_gravity", 9.8))


## Kytkee terveyden ja kestävyyden, joihin laskeutumisen seuraukset kohdistuvat. Molemmat valinnaisia.
func setup(health: HealthComponent, stamina: StaminaModel) -> void:
	_health = health
	_stamina = stamina


## Aloittaa hypyn ovelta. exit_velocity = hyppääjän nopeus irtautuessa (koneen vauhti + ponnistus).
func start_jump(exit_velocity: Vector3) -> void:
	if is_airborne():
		return
	phase = Phase.EXIT
	_phase_time = 0.0
	_left_ground = false
	_falling = false
	_since_plf = INF
	_stun_left = 0.0
	_exit_velocity = exit_velocity
	_pending_velocity = true
	EventBus.jump_started.emit(_jumper())


## Aloittaa laskeutumisen suoraan kuvun varassa ilman EXIT-vaihetta (esim. hyppytornin valjaat tai
## kupu valmiiksi auki). Lähettää jump_started ja chute_opened. Avautumisnykäystä ei tule.
func start_canopy_descent(initial_velocity: Vector3) -> void:
	if is_airborne():
		return
	start_jump(initial_velocity)
	_open_canopy()
	_jolt_deg = 0.0
	# Ensimmäinen kupuaskel käyttää annettua nopeutta.
	_pending_velocity = true


## Hyppy käynnissä (EXIT tai CANOPY). Ilmassa ei ammuta, ei kaksijalkaa eikä juosta.
func is_airborne() -> bool:
	return phase == Phase.EXIT or phase == Phase.CANOPY


func get_phase() -> Phase:
	return phase


## Laskeutumisen jälkeinen tainnutus päällä: ei liikettä eikä ampumista.
func is_stunned() -> bool:
	return _stun_left > 0.0


## Kameran lisäpoikkeama (pitch, asteina) avautumisnykäyksestä.
func get_camera_jolt_deg() -> float:
	return _jolt_deg


## Crouch-toimintoa painettiin: PLF-ajoitus alkaa.
func register_plf() -> void:
	_since_plf = 0.0


## Aika edetään ja palautetaan uusi nopeus. Maassa (ei hyppyä) nopeus palautetaan sellaisenaan.
## move_dir = maailman vaakasuuntainen ohjaus (pituus 0–1).
func tick(delta: float, velocity: Vector3, move_dir: Vector3) -> Vector3:
	_since_plf += delta
	_stun_left = maxf(_stun_left - delta, 0.0)
	_jolt_deg *= exp(-jolt_decay * delta)
	if _pending_velocity and is_airborne():
		# Ensimmäisellä askeleella käytetään irtautumisnopeutta.
		velocity = _exit_velocity
		_pending_velocity = false
	match phase:
		Phase.EXIT:
			return _tick_exit(delta, velocity)
		Phase.CANOPY:
			return _tick_canopy(delta, velocity, move_dir)
	return velocity


## Kutsutaan move_and_slide-kutsun jälkeen. fall_speed = putoamisnopeus ennen siirtoa (m/s, alas
## positiivinen), height = hahmon korkeus. Palauttaa laskeutumisen laadun tai &"", jos ei laskeutunut.
func report_motion(on_floor: bool, height: float, fall_speed: float) -> StringName:
	if is_airborne():
		if not on_floor:
			_left_ground = true
			return &""
		if not _left_ground:
			return &""
		phase = Phase.LANDED
		return resolve_landing(fall_speed)
	# Tavallinen pudotus (hyppytorni, kielekkeet).
	if not on_floor:
		if not _falling:
			_falling = true
			_fall_peak_y = height
		else:
			_fall_peak_y = maxf(_fall_peak_y, height)
		return &""
	if _falling:
		_falling = false
		if evaluator.is_significant_fall(_fall_peak_y - height):
			return resolve_landing(fall_speed)
	return &""


## Arvioi laskeutumisen, soveltaa seuraukset ja lähettää EventBus.landed.
func resolve_landing(fall_speed: float) -> StringName:
	var quality := evaluator.evaluate(fall_speed, _since_plf)
	_since_plf = INF
	last_landing = quality
	_stun_left = evaluator.get_stun_time(quality)
	if _stamina != null:
		_stamina.value = maxf(_stamina.value - evaluator.get_stamina_cost(quality), 0.0)
	if quality == LandingEvaluator.INJURED and _health != null:
		# Nyrjähdys tai murtuma: jalka vammautuu, mutta ei avointa vuotavaa haavaa.
		_health.take_hit(evaluator.injury_damage, evaluator.injured_leg(rng.randf()), false)
	EventBus.landed.emit(_jumper(), quality)
	return quality



func _tick_exit(delta: float, velocity: Vector3) -> Vector3:
	_phase_time += delta
	velocity.y -= _gravity * delta
	var speed := velocity.length()
	velocity -= velocity * minf(exit_drag * speed * delta, 1.0)
	if _phase_time >= exit_duration:
		_open_canopy()
	return velocity


func _tick_canopy(delta: float, velocity: Vector3, move_dir: Vector3) -> Vector3:
	_phase_time += delta
	var vertical_weight := 1.0 - exp(-canopy_vertical_response * delta)
	velocity.y = lerpf(velocity.y, -canopy_descent_speed, vertical_weight)
	var horizontal := Vector3(velocity.x, 0.0, velocity.z)
	var target := Vector3(move_dir.x, 0.0, move_dir.z).limit_length(1.0) * steer_speed + Vector3(wind.x, 0.0, wind.z)
	horizontal = horizontal.lerp(target, 1.0 - exp(-steer_response * delta))
	velocity.x = horizontal.x
	velocity.z = horizontal.z
	return velocity


func _open_canopy() -> void:
	phase = Phase.CANOPY
	_phase_time = 0.0
	_jolt_deg = opening_jolt_deg
	EventBus.chute_opened.emit(_jumper())


func _jumper() -> Node3D:
	return get_parent() as Node3D
