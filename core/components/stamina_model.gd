class_name StaminaModel
extends RefCounted
## Kestävyyden laskenta: juoksu kuluttaa sitä nopeammin, mitä raskaampi kantokuorma.
## Lepo palauttaa nopeimmin, kävely hitaammin, juoksun aikana ei palautumista.
## Puhdas logiikkaluokka, jota pelaaja (ja myöhemmin AI) käyttää.

## Kestävyys 0–1.
var value: float = 1.0
## Kestävyys loppui: juoksu estetty, kunnes arvo on palautunut sprint_resume_threshold-tasolle.
var exhausted: bool = false

## Juoksun kulutus sekunnissa viitekuormalla (1 / sekuntia täydestä tyhjään).
var sprint_drain_per_second: float = 0.1
## Kuorma, jolla kulutus on täsmälleen sprint_drain_per_second.
var reference_load_kg: float = 20.0
## Kuorman vaikutuksen jyrkkyys: kulutus ~ (kuorma / viitekuorma) ^ eksponentti.
var load_exponent: float = 1.5
## Palautuminen sekunnissa paikallaan levätessä.
var rest_regen_per_second: float = 0.12
## Palautumisen kerroin kävellessä (0–1).
var walk_regen_multiplier: float = 0.4
## Viive juoksun loppumisesta ennen kuin palautuminen alkaa (s).
var regen_delay: float = 1.0
## Uupumuksen jälkeen juosta voi taas, kun kestävyys on vähintään tämän verran.
var sprint_resume_threshold: float = 0.25

var _since_sprint: float = INF


## Kulutus sekunnissa annetulla kuormalla.
func drain_rate(load_kg: float) -> float:
	var ratio := maxf(load_kg, 0.0) / maxf(reference_load_kg, 0.001)
	return sprint_drain_per_second * pow(ratio, load_exponent)


## Palautuminen sekunnissa. moving = kävelee (ei juokse).
func regen_rate(moving: bool) -> float:
	return rest_regen_per_second * (walk_regen_multiplier if moving else 1.0)


func can_sprint() -> bool:
	return not exhausted and value > 0.0


## Päivittää kestävyyden. sprinting = pelaaja yrittää juosta ja liikkuu.
## Palauttaa true, jos juoksu tällä askeleella onnistui.
func update(delta: float, sprinting: bool, moving: bool, load_kg: float) -> bool:
	if sprinting and can_sprint():
		value = maxf(value - drain_rate(load_kg) * delta, 0.0)
		_since_sprint = 0.0
		if value <= 0.0:
			exhausted = true
		return true
	_since_sprint += delta
	if _since_sprint >= regen_delay:
		value = minf(value + regen_rate(moving) * delta, 1.0)
	if exhausted and value >= sprint_resume_threshold:
		exhausted = false
	return false


## Kuinka monta sekuntia täydellä kestävyydellä voi juosta annetulla kuormalla.
func sprint_duration(load_kg: float) -> float:
	var rate := drain_rate(load_kg)
	return INF if rate <= 0.0 else 1.0 / rate
