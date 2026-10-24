class_name NicknameCondition
extends Resource
## Lempinimisäännön lisäehto (NicknameRule.extra_conditions). Samat kentät kuin säännön pääehdolla.

@export var station_id: StringName = &""
@export var key: StringName = &""
@export var comparison: NicknameRule.Comparison = NicknameRule.Comparison.GREATER_OR_EQUAL
@export var threshold: float = 0.0
@export var match_value: StringName = &""


func is_met(results: Dictionary) -> bool:
	if station_id == &"" or key == &"":
		return false
	return NicknameRule.evaluate(results, station_id, key, comparison, threshold, match_value)
