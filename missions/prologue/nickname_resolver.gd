class_name NicknameResolver
extends RefCounted
## Puhdas lempinimen valitsija. Ottaa kaikkien asemien tulokset ja palauttaa lempinimen.
## Deterministinen: korkein prioriteetti voittaa, tasatilanteessa pienin id. Oletus "Cherry".

const DEFAULT_NICKNAME := "Cherry"


## results: { station_id: result-sanakirja } sopimuksen mukaisilla avaimilla.
static func resolve(rules: Array[NicknameRule], results: Dictionary,
		default_nickname: String = DEFAULT_NICKNAME) -> String:
	var rule := best_rule(rules, results)
	return rule.nickname if rule != null else default_nickname


static func resolve_with_set(rule_set: NicknameRuleSet, results: Dictionary) -> String:
	if rule_set == null:
		return DEFAULT_NICKNAME
	var fallback := rule_set.default_nickname if not rule_set.default_nickname.is_empty() else DEFAULT_NICKNAME
	return resolve(rule_set.rules, results, fallback)


## Paras täyttyvä sääntö tai null.
static func best_rule(rules: Array[NicknameRule], results: Dictionary) -> NicknameRule:
	var enriched := with_derived_values(results)
	var best: NicknameRule = null
	for rule: NicknameRule in rules:
		if rule == null or rule.nickname.is_empty() or not rule.matches(enriched):
			continue
		if best == null or rule.priority > best.priority \
				or (rule.priority == best.priority and String(rule.id) < String(best.id)):
			best = rule
	return best


## Lisää johdetut arvot: mg_range.hit_ratio = hits / shots (0, jos ei laukauksia).
static func with_derived_values(results: Dictionary) -> Dictionary:
	var enriched: Dictionary = {}
	for station: Variant in results.keys():
		var value: Variant = results[station]
		enriched[StringName(str(station))] = (value as Dictionary).duplicate() if value is Dictionary else value
	var mg: Variant = enriched.get(&"mg_range", null)
	if mg is Dictionary:
		var data: Dictionary = mg
		var shots: float = float(data.get("shots", 0))
		var hits: float = float(data.get("hits", 0))
		data["hit_ratio"] = hits / shots if shots > 0.0 else 0.0
	return enriched
