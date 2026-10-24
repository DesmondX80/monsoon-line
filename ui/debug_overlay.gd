class_name DebugOverlay
extends CanvasLayer
## Kehittäjän debug-näkymä (M1-14). Piilotettu oletuksena, F3 näyttää ja piilottaa.
## Näyttää reaaliajassa: FPS, terveys, verenvuoto, tukahdutus, kuumuus, nauha,
## asento, kestävyys ja kaksijalka. Puuttuvat arvot näytetään viivana.

const STANCE_NAMES: PackedStringArray = ["STAND", "CROUCH", "PRONE"]
const PLAYER_SEARCH_INTERVAL: float = 0.5

@onready var _label: Label = $Panel/Margin/Label

var _player: Node
var _search_timer: float = 0.0


func _ready() -> void:
	visible = false
	set_process(false)


func _unhandled_input(event: InputEvent) -> void:
	var key: InputEventKey = event as InputEventKey
	if key != null and key.pressed and not key.echo and key.keycode == KEY_F3:
		toggle()
		get_viewport().set_input_as_handled()


## Näyttää tai piilottaa näkymän.
func toggle() -> void:
	visible = not visible
	set_process(visible)
	if visible:
		_search_timer = 0.0
		_refresh()


func _process(delta: float) -> void:
	_search_timer -= delta
	if not PlayerLookup.is_valid(_player) and _search_timer <= 0.0:
		_search_timer = PLAYER_SEARCH_INTERVAL
		_player = PlayerLookup.find_player(get_tree())
	_refresh()


func _refresh() -> void:
	var lines: PackedStringArray = PackedStringArray()
	lines.append("FPS          %d" % Engine.get_frames_per_second())
	if not PlayerLookup.is_valid(_player):
		lines.append("pelaajaa ei löydy (ryhmä 'player')")
		_label.text = "\n".join(lines)
		return

	var health: Node = PlayerLookup.get_health(_player)
	var suppression: Node = PlayerLookup.get_suppression(_player)
	var weapon: Node = PlayerLookup.get_weapon(_player)

	var hp: Variant = PlayerLookup.read(health, &"health", null)
	var max_hp: Variant = PlayerLookup.read(health, &"max_health", null)
	lines.append("Terveys      %s / %s" % [_num(hp, "%.1f"), _num(max_hp, "%.0f")])
	lines.append("Verenvuoto   %s haavaa" % _num(PlayerLookup.read(health, &"bleeding_wounds", null), "%d"))
	var parts: Variant = PlayerLookup.read(health, &"disabled_parts", null)
	if parts is Array and not (parts as Array).is_empty():
		lines.append("Vammat       %s" % ", ".join(PackedStringArray(parts as Array)))
	lines.append("Tukahdutus   %s" % _num(PlayerLookup.read(suppression, &"amount", null), "%.2f"))
	lines.append("Kuumuus      %s" % _num(PlayerLookup.read(weapon, &"heat", null), "%.2f"))
	lines.append("Nauha        %s ptr" % _num(PlayerLookup.read(weapon, &"rounds_in_belt", null), "%d"))
	lines.append("Kaksijalka   %s" % _flag(PlayerLookup.read(weapon, &"bipod_deployed", null)))
	lines.append("Jumissa      %s" % _flag(PlayerLookup.read(weapon, &"jammed", null)))
	lines.append("Kiire        %s" % _flag(PlayerLookup.read(weapon, &"busy", null)))
	lines.append("Asento       %s" % _stance(PlayerLookup.read(_player, &"stance", null)))
	lines.append("Kestävyys    %s" % _num(PlayerLookup.read(_player, &"stamina", null), "%.2f"))
	_label.text = "\n".join(lines)


static func _num(value: Variant, fmt: String) -> String:
	if value is int or value is float:
		return fmt % value
	return "–"


static func _flag(value: Variant) -> String:
	if value is bool:
		return "kyllä" if value else "ei"
	return "–"


static func _stance(value: Variant) -> String:
	if value is int:
		var index: int = value
		return STANCE_NAMES[index] if index >= 0 and index < STANCE_NAMES.size() else str(index)
	if value == null:
		return "–"
	return str(value)
