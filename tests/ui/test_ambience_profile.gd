extends GutTest
## M2-06: AudioDirectorin ambienssiprofiilit, automaattinen valinta tiedostonimestä
## ja hypyn äänitilat. Globaali tila palautetaan jokaisen testin jälkeen.

var _saved_enabled: bool
var _saved_override: bool
var _saved_profile: StringName


func before_each() -> void:
	_saved_enabled = AudioDirector.ambience_enabled
	_saved_override = AudioDirector.is_ambience_profile_overridden()
	_saved_profile = AudioDirector.get_ambience_profile()
	AudioDirector.set_ambience_enabled(true)


func after_each() -> void:
	if _saved_override:
		AudioDirector.set_ambience_profile(_saved_profile)
	else:
		AudioDirector.set_ambience_profile(&"")
	AudioDirector.set_ambience_enabled(_saved_enabled)


func test_profile_for_scene_path() -> void:
	assert_eq(AudioDirector.profile_for_scene_path("res://world/levels/fort_benning.tscn"), &"fort_benning")
	assert_eq(AudioDirector.profile_for_scene_path("res://world/levels/c130_drop.tscn"), &"aircraft")
	assert_eq(AudioDirector.profile_for_scene_path("res://world/levels/jungle_test.tscn"), &"jungle")
	assert_eq(AudioDirector.profile_for_scene_path("res://world/levels/test_range.tscn"), &"jungle")
	assert_eq(AudioDirector.profile_for_scene_path(""), &"jungle")


func test_switch_to_fort_benning() -> void:
	assert_true(AudioDirector.set_ambience_profile(&"fort_benning"))
	assert_eq(AudioDirector.get_ambience_profile(), &"fort_benning")
	assert_true(AudioDirector.is_ambience_profile_overridden())
	var playing: PackedStringArray = AudioDirector.get_playing_ambience_layer_names()
	assert_true(playing.has("BenningInsects"), "Georgian hyönteiset soivat")
	assert_true(playing.has("BenningCadence"), "kaukainen marssimumina soi")
	assert_false(playing.has("Insects"), "viidakon hyönteiset hiljaa")
	assert_false(playing.has("EngineCabin"), "moottori hiljaa")


func test_switch_to_aircraft() -> void:
	assert_true(AudioDirector.set_ambience_profile(&"aircraft"))
	var playing: PackedStringArray = AudioDirector.get_playing_ambience_layer_names()
	assert_true(playing.has("EngineCabin"), "rungon läpi kuuluva jylinä")
	assert_true(playing.has("EngineDoor"), "oven jylinä (äänenvoimakkuus oven etäisyydestä)")
	assert_false(playing.has("BenningInsects"))
	assert_false(playing.has("Rustle"))


func test_switch_back_to_jungle() -> void:
	AudioDirector.set_ambience_profile(&"aircraft")
	AudioDirector.set_ambience_profile(&"jungle")
	var playing: PackedStringArray = AudioDirector.get_playing_ambience_layer_names()
	assert_true(playing.has("Insects"))
	assert_true(playing.has("Rustle"))
	assert_false(playing.has("EngineCabin"))


func test_unknown_profile_rejected() -> void:
	AudioDirector.set_ambience_profile(&"jungle")
	assert_false(AudioDirector.set_ambience_profile(&"disco"))
	assert_eq(AudioDirector.get_ambience_profile(), &"jungle", "profiili ei muutu")


func test_empty_profile_restores_auto() -> void:
	AudioDirector.set_ambience_profile(&"aircraft")
	AudioDirector.set_ambience_profile(&"")
	assert_false(AudioDirector.is_ambience_profile_overridden())
	# GUT-ajossa scene on GUTin oma, joten automaattinen valinta on viidakko.
	assert_eq(AudioDirector.get_ambience_profile(), &"jungle")


func test_disabled_ambience_silences_all_layers() -> void:
	AudioDirector.set_ambience_profile(&"fort_benning")
	AudioDirector.set_ambience_enabled(false)
	assert_eq(AudioDirector.get_playing_ambience_layer_names().size(), 0)
	assert_eq(AudioDirector.get_ambience_profile(), &"fort_benning", "profiili säilyy")
	AudioDirector.set_ambience_enabled(true)
	assert_true(AudioDirector.get_playing_ambience_layer_names().has("BenningInsects"))


func test_layer_names_follow_profile() -> void:
	AudioDirector.set_ambience_profile(&"aircraft")
	assert_eq(AudioDirector.get_ambience_layer_names(), PackedStringArray(["EngineCabin", "EngineDoor"]))


func test_wind_follows_jump_events() -> void:
	var jumper: Node3D = Node3D.new()
	jumper.add_to_group(&"player")
	add_child_autofree(jumper)
	EventBus.jump_started.emit(jumper)
	assert_true(AudioDirector.is_freefall_wind_active(), "tuuli alkaa hypystä")
	EventBus.chute_opened.emit(jumper)
	assert_false(AudioDirector.is_freefall_wind_active(), "tuuli loppuu kuvun auetessa")
	EventBus.landed.emit(jumper, &"hard")
	assert_false(AudioDirector.is_freefall_wind_active())


func test_non_player_jump_ignored() -> void:
	var npc: Node3D = Node3D.new()
	add_child_autofree(npc)
	EventBus.jump_started.emit(npc)
	assert_false(AudioDirector.is_freefall_wind_active(), "NPC-hyppääjä ei käynnistä pelaajan tuulta")
