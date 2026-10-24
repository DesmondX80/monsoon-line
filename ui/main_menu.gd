extends Control
## Päävalikko (M1-17): Aloita, Asetukset (paikkamerkki), Lopeta.
## Ilme: 1960-luvun armeijan kenttäkansio – oliivinvihreä, sapluunakirjaimet, konekirjoitus.

const PRIMARY_LEVEL: String = "res://world/levels/jungle_test.tscn"
const FALLBACK_LEVEL: String = "res://world/levels/test_range.tscn"

@onready var _start_button: Button = %StartButton
@onready var _settings_button: Button = %SettingsButton
@onready var _quit_button: Button = %QuitButton
@onready var _status_label: Label = %StatusLabel


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_set_ambience(false)
	_start_button.pressed.connect(_on_start_pressed)
	_settings_button.pressed.connect(_on_settings_pressed)
	_quit_button.pressed.connect(_on_quit_pressed)
	for button: Button in [_start_button, _settings_button, _quit_button]:
		button.mouse_entered.connect(button.grab_focus)
	_start_button.grab_focus()
	_status_label.text = ""


## Palauttaa ladattavan tason polun: jungle_test, jos se on olemassa, muuten test_range.
static func resolve_level_path() -> String:
	return PRIMARY_LEVEL if ResourceLoader.exists(PRIMARY_LEVEL) else FALLBACK_LEVEL


func _on_start_pressed() -> void:
	_click()
	var path: String = resolve_level_path()
	_status_label.text = "Siirrytään alueelle…"
	_set_ambience(true)
	var err: Error = get_tree().change_scene_to_file(path)
	if err != OK:
		_status_label.text = "Tason lataus epäonnistui (%s)" % error_string(err)
		_set_ambience(false)


func _on_settings_pressed() -> void:
	_click()
	_status_label.text = "Asetukset – tulossa myöhemmin."


func _on_quit_pressed() -> void:
	_click()
	get_tree().quit()


func _click() -> void:
	var director: Node = get_node_or_null(^"/root/AudioDirector")
	if director != null and director.has_method(&"play_ui_click"):
		director.call(&"play_ui_click")


func _set_ambience(enabled: bool) -> void:
	var director: Node = get_node_or_null(^"/root/AudioDirector")
	if director != null and director.has_method(&"set_ambience_enabled"):
		director.call(&"set_ambience_enabled", enabled)
