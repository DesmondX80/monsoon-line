extends GutTest
## GameState-autoloadin testit: ylennys ja sarjallistus. Globaali tila palautetaan jokaisen testin jälkeen.

var _saved_rank: int
var _saved_role: int
var _saved_nickname: String
var _saved_mission: StringName
var _saved_squad: Array[StringName] = []


func before_each() -> void:
	_saved_rank = GameState.player_rank
	_saved_role = GameState.player_role
	_saved_nickname = GameState.player_nickname
	_saved_mission = GameState.current_mission
	_saved_squad = GameState.squad_alive.duplicate()


func after_each() -> void:
	GameState.player_rank = _saved_rank as GameState.Rank
	GameState.player_role = _saved_role as GameState.Role
	GameState.player_nickname = _saved_nickname
	GameState.current_mission = _saved_mission
	GameState.squad_alive = _saved_squad.duplicate()


func test_promote_increments_rank() -> void:
	GameState.player_rank = GameState.Rank.PRIVATE
	GameState.promote()
	assert_eq(GameState.player_rank, GameState.Rank.PRIVATE_FIRST_CLASS)


func test_promote_stops_at_staff_sergeant() -> void:
	GameState.player_rank = GameState.Rank.STAFF_SERGEANT
	GameState.promote()
	assert_eq(GameState.player_rank, GameState.Rank.STAFF_SERGEANT)


func test_promote_through_all_ranks() -> void:
	GameState.player_rank = GameState.Rank.PRIVATE
	for i in 10:
		GameState.promote()
	assert_eq(GameState.player_rank, GameState.Rank.STAFF_SERGEANT)


func test_to_dict_contains_all_fields() -> void:
	GameState.player_rank = GameState.Rank.SERGEANT
	GameState.player_role = GameState.Role.SQUAD_LEADER
	GameState.player_nickname = "Hoss"
	GameState.current_mission = &"junction_city_01"
	GameState.squad_alive.assign([&"doc", &"rivera"])
	var d: Dictionary = GameState.to_dict()
	assert_eq(d["rank"], GameState.Rank.SERGEANT)
	assert_eq(d["role"], GameState.Role.SQUAD_LEADER)
	assert_eq(d["nickname"], "Hoss")
	assert_eq(d["mission"], &"junction_city_01")
	assert_eq(d["squad_alive"].size(), 2)


func test_from_dict_round_trip() -> void:
	GameState.player_rank = GameState.Rank.SPECIALIST_4
	GameState.player_role = GameState.Role.SQUAD_LEADER
	GameState.player_nickname = "Tex"
	GameState.current_mission = &"junction_city_02"
	GameState.squad_alive.assign([&"doc"])
	var d: Dictionary = GameState.to_dict().duplicate(true)
	GameState.from_dict({})
	GameState.from_dict(d)
	assert_eq(GameState.player_rank, GameState.Rank.SPECIALIST_4)
	assert_eq(GameState.player_role, GameState.Role.SQUAD_LEADER)
	assert_eq(GameState.player_nickname, "Tex")
	assert_eq(GameState.current_mission, &"junction_city_02")
	assert_eq(GameState.squad_alive, [&"doc"] as Array[StringName])


func test_from_dict_empty_uses_defaults() -> void:
	GameState.player_rank = GameState.Rank.SERGEANT
	GameState.player_nickname = "X"
	GameState.from_dict({})
	assert_eq(GameState.player_rank, GameState.Rank.PRIVATE)
	assert_eq(GameState.player_role, GameState.Role.MACHINE_GUNNER)
	assert_eq(GameState.player_nickname, "")
	assert_eq(GameState.current_mission, &"prologue_fort_benning")
	assert_eq(GameState.squad_alive.size(), 0)


func test_from_dict_accepts_json_types() -> void:
	# JSON palauttaa luvut float-tyyppisinä ja StringNamet String-tyyppisinä.
	var d: Variant = JSON.parse_string(JSON.stringify(
		{"rank": 3, "role": 1, "nickname": "Tex", "mission": "m2", "squad_alive": ["doc", "rivera"]}))
	GameState.from_dict(d as Dictionary)
	assert_eq(GameState.player_rank, GameState.Rank.SERGEANT)
	assert_eq(GameState.player_role, GameState.Role.SQUAD_LEADER)
	assert_eq(GameState.current_mission, &"m2")
	assert_eq(GameState.squad_alive, [&"doc", &"rivera"] as Array[StringName])
