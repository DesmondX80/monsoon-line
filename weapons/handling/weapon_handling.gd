class_name WeaponHandling
extends RefCounted
## Aseen käsittely: rekyyli ja huojunta. Puhdas logiikkaluokka ilman solmuja, jotta se on testattavissa.
## Kaikki säätöarvot tulevat WeaponDatasta (.tres), koodissa ei ole säätöarvoja.
##
## Tulos on kulmapoikkeama asteina: x = pystykulma (ylös positiivinen), y = sivukulma
## (vasemmalle positiivinen, kuten rotate_y). Pelaaja lisää poikkeaman muutoksen kameraan
## joka ruudulla, joten kamera ja piippu liikkuvat yhdessä.

var data: WeaponData
## Kertynyt rekyyli asteina.
var recoil: Vector2 = Vector2.ZERO
## Nykyinen huojuntapoikkeama asteina.
var sway: Vector2 = Vector2.ZERO
## Pehmennetty huojunnan amplitudi asteina.
var sway_amplitude: float = 0.0
var rng: RandomNumberGenerator = RandomNumberGenerator.new()

var _phase: float = 0.0
var _since_shot: float = INF


func _init(weapon_data: WeaponData, rng_seed: int = -1) -> void:
	data = weapon_data
	if rng_seed >= 0:
		rng.seed = rng_seed
	else:
		rng.randomize()
	sway_amplitude = data.sway if data else 0.0


## Lisää yhden laukauksen rekyylin. Palauttaa lisätyn potkun asteina.
func add_shot(supported: bool) -> Vector2:
	var multiplier := recoil_multiplier(data, supported)
	var kick := Vector2(
		data.recoil_vertical * multiplier,
		rng.randf_range(-data.recoil_horizontal, data.recoil_horizontal) * multiplier
	)
	recoil += kick
	_since_shot = 0.0
	return kick


## Päivittää rekyylin palautuksen ja huojunnan. stamina ja suppression ovat välillä 0–1.
func update(delta: float, stamina: float, suppression: float, supported: bool) -> void:
	_since_shot += delta
	# Rekyyli palautuu vasta, kun sarja taukoaa: jatkuva lonkkasarja kiipeää hallitsemattomasti.
	if _since_shot >= data.recoil_recovery_delay:
		recoil *= exp(-data.recoil_recovery * delta)
		if recoil.length_squared() < 0.000001:
			recoil = Vector2.ZERO
	var target := compute_sway_amplitude(data, stamina, suppression, supported)
	sway_amplitude = lerpf(sway_amplitude, target, clampf(4.0 * delta, 0.0, 1.0))
	# Väsyneenä hengitys kiihtyy: taajuus kasvaa kestävyyden laskiessa.
	var frequency := data.sway_frequency * (2.0 - clampf(stamina, 0.0, 1.0))
	_phase = fmod(_phase + TAU * frequency * delta, TAU * 2.0)
	# Lissajous-kuvio (kahdeksikko): sivuliike kaksinkertaisella taajuudella.
	sway = Vector2(sin(_phase), sin(_phase * 2.0) * 0.5) * sway_amplitude


## Kokonaispoikkeama asteina (rekyyli + huojunta).
func get_offset() -> Vector2:
	return recoil + sway


static func recoil_multiplier(weapon_data: WeaponData, supported: bool) -> float:
	return weapon_data.supported_recoil_multiplier if supported else 1.0


## Huojunnan amplitudi asteina: perusarvo, jota väsymys ja tukahdutus kasvattavat ja tuki pienentää.
static func compute_sway_amplitude(weapon_data: WeaponData, stamina: float, suppression: float, supported: bool) -> float:
	var fatigue := 1.0 - clampf(stamina, 0.0, 1.0)
	var amplitude := weapon_data.sway
	amplitude *= 1.0 + weapon_data.stamina_sway_factor * fatigue
	amplitude *= 1.0 + weapon_data.suppression_sway_factor * clampf(suppression, 0.0, 1.0)
	if supported:
		amplitude *= weapon_data.supported_sway_multiplier
	return amplitude
