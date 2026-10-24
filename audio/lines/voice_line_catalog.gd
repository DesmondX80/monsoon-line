class_name VoiceLineCatalog
extends Resource
## Repliikkikatalogi. Oletuskatalogi ladataan kerran ja jaetaan HUDin ja AudioDirectorin kesken.

const DEFAULT_PATH := "res://audio/lines/voice_lines.tres"

@export var lines: Array[VoiceLine] = []

static var _default: VoiceLineCatalog

var _by_id: Dictionary = {}


## Palauttaa oletuskatalogin tai null, jos sitä ei löydy.
static func get_default() -> VoiceLineCatalog:
	if _default == null and ResourceLoader.exists(DEFAULT_PATH):
		_default = load(DEFAULT_PATH) as VoiceLineCatalog
	return _default


## Hakee repliikin tunnisteella. Palauttaa null, jos tunnistetta ei ole.
func find(line_id: StringName) -> VoiceLine:
	if _by_id.size() != lines.size():
		_by_id.clear()
		for line: VoiceLine in lines:
			if line != null:
				_by_id[line.id] = line
	return _by_id.get(line_id) as VoiceLine


## Kaikki tietyn roolin repliikit, esim. satunnaista valintaa varten.
func lines_for_role(role: StringName) -> Array[VoiceLine]:
	var result: Array[VoiceLine] = []
	for line: VoiceLine in lines:
		if line != null and line.speaker_role == role:
			result.append(line)
	return result
