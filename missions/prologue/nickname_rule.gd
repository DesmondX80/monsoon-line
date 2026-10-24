class_name NicknameRule
extends Resource
## Lempinimisääntö: kun ehto (ja mahdolliset lisäehdot) täyttyvät, kersantti Tibbs voi antaa
## tämän nimen. Korkein prioriteetti voittaa; tasatilanteessa aakkosjärjestyksessä ensimmäinen id.
##
## Ehto: asematuloksen avain (key) asemalta station_id verrattuna kynnykseen (threshold)
## tai merkkijonoon (match_value). Puuttuva asema tai avain tarkoittaa, ettei ehto täyty.

enum Comparison { GREATER_OR_EQUAL, GREATER, LESS_OR_EQUAL, LESS, EQUAL, NOT_EQUAL }

@export var id: StringName = &""
## Englanninkielinen lempinimi (ryhmä on yhdysvaltalainen).
@export var nickname: String = ""
@export var priority: int = 0
@export_group("Ehto")
## Asema: obstacle_course, mg_range tai jump_tower.
@export var station_id: StringName = &""
## Tuloksen avain, esim. falls, wire_touches, time_s, hit_ratio (johdettu), overheated, landing.
@export var key: StringName = &""
@export var comparison: Comparison = Comparison.GREATER_OR_EQUAL
## Numeerinen kynnys. Totuusarvot vertautuvat lukuina (true = 1, false = 0).
@export var threshold: float = 0.0
## Merkkijonovertailun arvo (esim. landing == &"hard"). Jos asetettu, vain EQUAL / NOT_EQUAL.
@export var match_value: StringName = &""
@export_group("")
## Valinnaiset lisäehdot, joiden kaikkien on myös täytyttävä (JA).
@export var extra_conditions: Array[NicknameCondition] = []


func matches(results: Dictionary) -> bool:
	if station_id == &"" or key == &"":
		return false
	if not evaluate(results, station_id, key, comparison, threshold, match_value):
		return false
	for condition: NicknameCondition in extra_conditions:
		if condition == null or not condition.is_met(results):
			return false
	return true


## Arvioi yhden ehdon asematuloksista { station_id: { avain: arvo } }.
static func evaluate(results: Dictionary, station: StringName, result_key: StringName,
		op: Comparison, limit: float, text_value: StringName) -> bool:
	var station_data: Variant = results.get(station, results.get(String(station), null))
	if not station_data is Dictionary:
		return false
	var data: Dictionary = station_data
	var value: Variant = data.get(result_key, data.get(String(result_key), null))
	if value == null:
		return false
	if text_value != &"":
		var text := StringName(str(value))
		match op:
			Comparison.EQUAL:
				return text == text_value
			Comparison.NOT_EQUAL:
				return text != text_value
			_:
				return false
	var number: float = 0.0
	match typeof(value):
		TYPE_BOOL:
			number = 1.0 if value else 0.0
		TYPE_INT, TYPE_FLOAT:
			number = float(value)
		_:
			return false
	match op:
		Comparison.GREATER_OR_EQUAL:
			return number >= limit
		Comparison.GREATER:
			return number > limit
		Comparison.LESS_OR_EQUAL:
			return number <= limit
		Comparison.LESS:
			return number < limit
		Comparison.EQUAL:
			return is_equal_approx(number, limit)
		Comparison.NOT_EQUAL:
			return not is_equal_approx(number, limit)
	return false
