extends GutTest
## SaveManagerin testit: tallennus ja lataus user://campaign.json-tiedostoon.
## Olemassa oleva tallennus ja GameStaten tila palautetaan testien jälkeen.

var _had_save: bool = false
var _save_backup: String = ""
var _state_backup: Dictionary = {}


func before_all() -> void:
	_had_save = FileAccess.file_exists(SaveManager.SAVE_PATH)
	if _had_save:
		_save_backup = FileAccess.get_file_as_string(SaveManager.SAVE_PATH)
	_state_backup = GameState.to_dict().duplicate(true)


func before_each() -> void:
	_remove_save()


func after_each() -> void:
	GameState.from_dict(_state_backup.duplicate(true))


func after_all() -> void:
	_remove_save()
	if _had_save:
		var file: FileAccess = FileAccess.open(SaveManager.SAVE_PATH, FileAccess.WRITE)
		file.store_string(_save_backup)
		file.close()


func _remove_save() -> void:
	if FileAccess.file_exists(SaveManager.SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SaveManager.SAVE_PATH))


func test_load_without_save_returns_false() -> void:
	assert_false(SaveManager.load_campaign())


func test_save_creates_file() -> void:
	SaveManager.save_campaign()
	assert_true(FileAccess.file_exists(SaveManager.SAVE_PATH))


func test_save_and_load_round_trip() -> void:
	GameState.player_rank = GameState.Rank.SERGEANT
	GameState.player_role = GameState.Role.SQUAD_LEADER
	GameState.player_nickname = "Hoss"
	GameState.current_mission = &"junction_city_03"
	GameState.squad_alive.assign([&"doc", &"rivera"])
	SaveManager.save_campaign()

	GameState.from_dict({})
	assert_eq(GameState.player_nickname, "")

	assert_true(SaveManager.load_campaign())
	assert_eq(GameState.player_rank, GameState.Rank.SERGEANT)
	assert_eq(GameState.player_role, GameState.Role.SQUAD_LEADER)
	assert_eq(GameState.player_nickname, "Hoss")
	assert_eq(GameState.current_mission, &"junction_city_03")
	assert_eq(GameState.squad_alive, [&"doc", &"rivera"] as Array[StringName])


func test_corrupt_save_returns_false() -> void:
	var file: FileAccess = FileAccess.open(SaveManager.SAVE_PATH, FileAccess.WRITE)
	file.store_string("ei json")
	file.close()
	GameState.player_nickname = "Koskematon"
	assert_false(SaveManager.load_campaign())
	assert_eq(GameState.player_nickname, "Koskematon")
