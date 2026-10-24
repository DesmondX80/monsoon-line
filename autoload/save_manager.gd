extends Node
## Kampanjan tallennus JSON-tiedostoon.

const SAVE_PATH := "user://campaign.json"


func save_campaign() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("Tallennus epäonnistui: %s" % FileAccess.get_open_error())
		return
	file.store_string(JSON.stringify(GameState.to_dict()))


func load_campaign() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return false
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	var data: Variant = JSON.parse_string(file.get_as_text())
	if data is Dictionary:
		GameState.from_dict(data)
		return true
	return false
