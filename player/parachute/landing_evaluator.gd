class_name LandingEvaluator
extends RefCounted
## Laskeutumisen arviointi (PLF, parachute landing fall). Puhdas logiikkaluokka ilman fysiikkaa.
## Sama arvio koskee laskuvarjolaskeutumista ja tavallista yli min_fall_height-metrin pudotusta
## (Fort Benningin 34 jalan hyppytorni).
##
## good    = crouch-toiminto painettu plf_min_lead–plf_max_lead sekuntia ennen maakosketusta
## hard    = PLF liian aikaisin, liian myöhään tai ei ollenkaan
## injured = pystysuora nopeus yli injury_speed (esim. kupu ei auennut), PLF ei auta

const GOOD := &"good"
const HARD := &"hard"
const INJURED := &"injured"
const LEG_LEFT := &"leg_l"
const LEG_RIGHT := &"leg_r"

## PLF-ikkunan alku: painallus vähintään näin monta sekuntia ennen kosketusta.
var plf_min_lead: float = 0.1
## PLF-ikkunan loppu: painallus enintään näin monta sekuntia ennen kosketusta.
var plf_max_lead: float = 0.5
## Pystysuora nopeus (m/s), jonka ylittävä laskeutuminen vammauttaa aina.
var injury_speed: float = 8.0
## Tavallinen pudotus arvioidaan vasta tätä korkeammalta (m).
var min_fall_height: float = 2.0
## Jalkavamman perusvahinko HealthComponent.take_hitille (jalan kerroin 0,6 → noin 18 hp).
var injury_damage: float = 30.0

## Kestävyyden menetys (0–1) laadun mukaan.
var stamina_cost := { GOOD: 0.05, HARD: 0.2, INJURED: 0.4 }
## Lyhyt tainnutus (s), jonka aikana pelaaja ei liiku eikä ammu.
var stun_time := { GOOD: 0.0, HARD: 0.6, INJURED: 1.5 }


## Arvioi laskeutumisen. vertical_speed = putoamisnopeus kosketushetkellä (m/s, positiivinen alas).
## time_since_plf = sekunnit viimeisimmästä crouch-painalluksesta (INF, jos ei painettu).
func evaluate(vertical_speed: float, time_since_plf: float) -> StringName:
	if vertical_speed > injury_speed:
		return INJURED
	if time_since_plf >= plf_min_lead and time_since_plf <= plf_max_lead:
		return GOOD
	return HARD


## Arvioidaanko tavallinen pudotus (ilman laskuvarjoa) laskeutumisena.
func is_significant_fall(fall_height: float) -> bool:
	return fall_height > min_fall_height


func get_stamina_cost(quality: StringName) -> float:
	return float(stamina_cost.get(quality, 0.0))


func get_stun_time(quality: StringName) -> float:
	return float(stun_time.get(quality, 0.0))


## Valitsee loukkaantuvan jalan. roll 0–1 (satunnaisluku kutsujalta, testattavuuden vuoksi).
func injured_leg(roll: float) -> StringName:
	return LEG_LEFT if roll < 0.5 else LEG_RIGHT
