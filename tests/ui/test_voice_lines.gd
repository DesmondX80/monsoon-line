extends GutTest
## M2-06: repliikkikatalogin sopimus. Jokainen milestone-2-sopimuksen line_id on olemassa,
## tekstit fi/en eivät ole tyhjiä, puhujaroolit ovat oikein ja {nickname} korvautuu.

const CONTRACT_PATH: String = "res://docs/backlog/milestone-2-prologue.json"
## Varalista, jos sopimustiedostoa ei ole viety (export) – pidetään samana kuin JSON.
const CONTRACT_LINE_IDS: Array[StringName] = [
	&"tibbs_welcome", &"tibbs_obstacle_intro", &"tibbs_obstacle_fell", &"tibbs_obstacle_wire",
	&"tibbs_obstacle_done_good", &"tibbs_obstacle_done_bad",
	&"tibbs_mg_intro", &"tibbs_mg_bipod", &"tibbs_mg_belt", &"tibbs_mg_barrel", &"tibbs_mg_overheat",
	&"tibbs_mg_done_good", &"tibbs_mg_done_bad",
	&"tibbs_tower_intro", &"tibbs_tower_good", &"tibbs_tower_hard", &"tibbs_idle_hurry",
	&"tibbs_nickname", &"tibbs_graduation",
	&"jumpmaster_stand_up", &"jumpmaster_hook_up", &"jumpmaster_check_equipment",
	&"jumpmaster_stand_in_door", &"jumpmaster_go", &"squad_landed",
]

var _catalog: VoiceLineCatalog


func before_all() -> void:
	_catalog = load(VoiceLineCatalog.DEFAULT_PATH) as VoiceLineCatalog


func _contract_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	if FileAccess.file_exists(CONTRACT_PATH):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(CONTRACT_PATH))
		if parsed is Dictionary:
			var contracts: Variant = (parsed as Dictionary).get("contracts", {})
			if contracts is Dictionary:
				for id: Variant in (contracts as Dictionary).get("line_ids", []):
					ids.append(StringName(str(id)))
	if ids.is_empty():
		ids = CONTRACT_LINE_IDS.duplicate()
	return ids


func test_catalog_loads() -> void:
	assert_not_null(_catalog, "oletuskatalogi latautuu")


func test_contract_file_matches_fallback_list() -> void:
	var ids: Array[StringName] = _contract_ids()
	for id: StringName in CONTRACT_LINE_IDS:
		assert_true(ids.has(id), "varalistan id %s on sopimuksessa" % id)
	assert_eq(ids.size(), CONTRACT_LINE_IDS.size(), "varalista vastaa sopimusta")


func test_every_contract_line_exists_with_fi_and_en() -> void:
	for id: StringName in _contract_ids():
		var line: VoiceLine = _catalog.find(id)
		assert_not_null(line, "repliikki %s löytyy" % id)
		if line == null:
			continue
		assert_false(line.text_fi.strip_edges().is_empty(), "%s: suomenkielinen teksti" % id)
		assert_false(line.text_en.strip_edges().is_empty(), "%s: englanninkielinen teksti" % id)
		assert_false(line.speaker_name_fi.is_empty(), "%s: puhujan nimi fi" % id)
		assert_false(line.speaker_name_en.is_empty(), "%s: puhujan nimi en" % id)


func test_speaker_roles() -> void:
	for id: StringName in _contract_ids():
		var line: VoiceLine = _catalog.find(id)
		if line == null:
			continue
		var id_text: String = String(id)
		if id_text.begins_with("tibbs_"):
			assert_eq(line.speaker_role, &"drill_sergeant", "%s: Tibbs" % id)
			assert_eq(line.speaker_name_en, "Sgt. Tibbs")
		elif id_text.begins_with("jumpmaster_"):
			assert_eq(line.speaker_role, &"jumpmaster", "%s: hyppymestari" % id)
		elif id_text.begins_with("squad_"):
			assert_true(line.speaker_role in [&"squad", &"squad_leader"], "%s: ryhmä" % id)


func test_ids_are_unique() -> void:
	var seen: Dictionary = {}
	for line: VoiceLine in _catalog.lines:
		assert_false(seen.has(line.id), "id %s on yksilöllinen" % line.id)
		seen[line.id] = true


func test_existing_lines_kept() -> void:
	for id: StringName in [&"tibbs_nickname_intro", &"tibbs_nickname_given", &"sl_contact_front", &"ag_new_belt", &"rifleman_man_down"]:
		assert_not_null(_catalog.find(id), "vanha repliikki %s säilyy" % id)


func test_tibbs_nickname_contains_placeholder() -> void:
	var line: VoiceLine = _catalog.find(&"tibbs_nickname")
	assert_not_null(line)
	assert_string_contains(line.text_fi, "{nickname}")
	assert_string_contains(line.text_en, "{nickname}")


func test_nickname_substitution() -> void:
	var line: VoiceLine = _catalog.find(&"tibbs_nickname")
	var fi: String = line.get_text(&"fi", "Stumbles")
	var en: String = line.get_text(&"en", "Stumbles")
	assert_string_contains(fi, "Stumbles")
	assert_string_contains(en, "Stumbles")
	assert_false(fi.contains("{nickname}"), "paikka korvautuu (fi)")
	assert_false(en.contains("{nickname}"), "paikka korvautuu (en)")


func test_nickname_fallback_when_empty() -> void:
	var line: VoiceLine = _catalog.find(&"tibbs_nickname")
	assert_string_contains(line.get_text(&"en", ""), "trooper")
	assert_string_contains(line.get_text(&"fi", ""), "sotilas")


func test_no_unreplaced_placeholders_other_than_nickname() -> void:
	var regex: RegEx = RegEx.create_from_string("\\{(\\w+)\\}")
	for line: VoiceLine in _catalog.lines:
		for text: String in [line.text_fi, line.text_en]:
			for m: RegExMatch in regex.search_all(text):
				assert_eq(m.get_string(1), "nickname", "%s: vain {nickname}-paikka sallittu" % line.id)


func test_jumpmaster_commands_cover_event_bus_commands() -> void:
	# EventBus.jumpmaster_command-komennot: stand_up, hook_up, check_equipment, stand_in_door, go.
	for command: String in ["stand_up", "hook_up", "check_equipment", "stand_in_door", "go"]:
		assert_not_null(_catalog.find(StringName("jumpmaster_" + command)), "komento %s" % command)
	var check: VoiceLine = _catalog.find(&"jumpmaster_check_equipment")
	assert_string_contains(check.text_en.to_lower(), "sound off")
