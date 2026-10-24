extends GutTest
## Lempinimisääntöjen ja NicknameResolverin testit (M2-04).

const RULES_PATH := "res://missions/prologue/nickname_rules.tres"

var rule_set: NicknameRuleSet


func before_each() -> void:
	rule_set = load(RULES_PATH) as NicknameRuleSet


## Keskinkertainen suoritus, joka ei laukaise yhtään sääntöä.
func _plain_results() -> Dictionary:
	return {
		&"obstacle_course": {"time_s": 95.0, "falls": 1, "wire_touches": 1},
		&"mg_range": {"shots": 60, "hits": 24, "bipod_used": true, "belt_reloaded": false,
				"barrel_changed": false, "overheated": false},
		&"jump_tower": {"landing": &"good"},
	}


func _with(station: StringName, overrides: Dictionary) -> Dictionary:
	var results := _plain_results()
	var data: Dictionary = results[station]
	data.merge(overrides, true)
	return results


func _resolve(results: Dictionary) -> String:
	return NicknameResolver.resolve_with_set(rule_set, results)


func test_rule_set_loads_with_enough_rules() -> void:
	assert_not_null(rule_set)
	assert_eq(rule_set.default_nickname, "Cherry")
	assert_gte(rule_set.rules.size(), 8)
	var ids: Array[StringName] = []
	for rule: NicknameRule in rule_set.rules:
		assert_false(rule.id in ids, "Säännön id on yksilöllinen: %s" % rule.id)
		ids.append(rule.id)


func test_default_is_cherry() -> void:
	assert_eq(_resolve(_plain_results()), "Cherry")


func test_empty_results_default() -> void:
	assert_eq(_resolve({}), "Cherry")
	assert_eq(NicknameResolver.resolve_with_set(null, {}), "Cherry")


func test_each_rule_alone() -> void:
	var cases: Array[Array] = [
		["Humpty", _with(&"jump_tower", {"landing": &"injured"})],
		["Hot Barrel", _with(&"mg_range", {"overheated": true})],
		["Stumbles", _with(&"obstacle_course", {"falls": 3})],
		["Barbwire", _with(&"obstacle_course", {"wire_touches": 4})],
		["Lawn Dart", _with(&"jump_tower", {"landing": &"hard"})],
		["Sandbag", _with(&"obstacle_course", {"time_s": 180.0})],
		["Garden Hose", _with(&"mg_range", {"shots": 100, "hits": 10})],
		["Bullseye", _with(&"mg_range", {"shots": 40, "hits": 32})],
		["Professor", _with(&"mg_range", {"belt_reloaded": true, "barrel_changed": true})],
		["Jackrabbit", _with(&"obstacle_course", {"time_s": 50.0, "falls": 0})],
	]
	for case: Array in cases:
		assert_eq(_resolve(case[1] as Dictionary), case[0] as String)


func test_string_landing_also_matches_string_type() -> void:
	assert_eq(_resolve(_with(&"jump_tower", {"landing": "hard"})), "Lawn Dart")


func test_thresholds_are_exclusive_below() -> void:
	assert_eq(_resolve(_with(&"obstacle_course", {"falls": 2})), "Cherry")
	assert_eq(_resolve(_with(&"obstacle_course", {"wire_touches": 2})), "Cherry")
	# Bullseye vaatii vähintään 20 laukausta.
	assert_eq(_resolve(_with(&"mg_range", {"shots": 10, "hits": 10})), "Cherry")
	# Jackrabbit vaatii nollan kaatumista.
	assert_eq(_resolve(_with(&"obstacle_course", {"time_s": 50.0, "falls": 1})), "Cherry")


func test_priority_highest_wins() -> void:
	var results := _with(&"obstacle_course", {"falls": 5, "wire_touches": 5, "time_s": 200.0})
	assert_eq(_resolve(results), "Stumbles", "Stumbles (60) > Barbwire (55) > Sandbag (40)")
	(results[&"mg_range"] as Dictionary)["overheated"] = true
	assert_eq(_resolve(results), "Hot Barrel")
	(results[&"jump_tower"] as Dictionary)["landing"] = &"injured"
	assert_eq(_resolve(results), "Humpty")


func test_tie_breaks_by_id_deterministically() -> void:
	var a := _make_rule(&"b_rule", "Bravo", 10)
	var b := _make_rule(&"a_rule", "Alpha", 10)
	var rules: Array[NicknameRule] = [a, b]
	var results := {&"obstacle_course": {"falls": 1}}
	assert_eq(NicknameResolver.resolve(rules, results), "Alpha")
	rules.reverse()
	assert_eq(NicknameResolver.resolve(rules, results), "Alpha")


func test_missing_station_does_not_match() -> void:
	var rules: Array[NicknameRule] = [_make_rule(&"x", "X", 1)]
	assert_eq(NicknameResolver.resolve(rules, {&"mg_range": {"shots": 1}}, "Default"), "Default")


func test_resolver_does_not_mutate_input() -> void:
	var results := _plain_results()
	NicknameResolver.resolve_with_set(rule_set, results)
	assert_false((results[&"mg_range"] as Dictionary).has("hit_ratio"))


func test_string_keys_accepted() -> void:
	var results := {"obstacle_course": {"falls": 4}}
	assert_eq(_resolve(results), "Stumbles")


func _make_rule(id: StringName, nick: String, priority: int) -> NicknameRule:
	var rule := NicknameRule.new()
	rule.id = id
	rule.nickname = nick
	rule.priority = priority
	rule.station_id = &"obstacle_course"
	rule.key = &"falls"
	rule.comparison = NicknameRule.Comparison.GREATER_OR_EQUAL
	rule.threshold = 1.0
	return rule
