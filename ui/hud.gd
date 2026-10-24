class_name Hud
extends CanvasLayer
## Minimaalinen HUD (M1-13). Ei ammuslaskuria: tieto välitetään kehon, aseen ja äänen kautta.
## - tukahdutusvinjetti (shader)
## - punainen reunavälähdys osumasta
## - sykkivä punainen reuna verenvuodosta
## - kuumuusväreily, kun MachineGun.heat > 0,6
## - häivyttyvät vihjeet: nauha tyhjä, piippu ylikuumeni, ase jumissa
## - repliikkien tekstitykset (EventBus.squad_callout, M1-16); myös hyppymestarin komennot
## - M2-06: tehtäväohje (EventBus.objective_prompt, tyhjä piilottaa), otsikkokortti
##   (EventBus.title_card, konekirjoitusefekti ja häivytys noin 4 s), lempinimikortti
##   (EventBus.nickname_assigned) ja FadeLayer-lapsi, joka häivyttää uuden tason näkyviin.
##
## Efektit reagoivat vain pelaajan tilaan. Kaikki pelaajan solmut haetaan
## get_node_or_null- ja `in`-tarkistuksilla, joten HUD toimii vaikka solmuja puuttuisi.

const HEAT_SHIMMER_THRESHOLD: float = 0.6
const HINT_HOLD_SECONDS: float = 2.6
const HINT_FADE_SECONDS: float = 0.8
const HIT_FLASH_DECAY_PER_SECOND: float = 2.2
const PLAYER_SEARCH_INTERVAL: float = 0.5
const MAX_SUBTITLES: int = 3

const HINTS: Dictionary = {
	&"belt_empty": {"fi": "Nauha tyhjä – lataa (R)", "en": "Belt empty – reload (R)"},
	&"overheated": {"fi": "Piippu ylikuumeni – vaihda (B)", "en": "Barrel overheated – change (B)"},
	&"jammed": {"fi": "Ase jumissa – lataa (R)", "en": "Gun jammed – reload (R)"},
}

## Otsikkokortin vaiheet sekunteina: sisään, näkyvissä, ulos (yhteensä noin 4 s).
const TITLE_FADE_IN: float = 0.6
const TITLE_HOLD: float = 2.8
const TITLE_FADE_OUT: float = 0.7
## Kirjoituskone-efekti: merkkiä sekunnissa.
const TYPEWRITER_CPS: float = 28.0
const NICKNAME_FADE_IN: float = 0.25
const NICKNAME_HOLD: float = 3.5
const NICKNAME_FADE_OUT: float = 0.8
const OBJECTIVE_FADE: float = 0.35

const NICKNAME_CAPTION: Dictionary = {"fi": "Lempinimesi:", "en": "Your nickname:"}
const OBJECTIVE_HEADER: Dictionary = {"fi": "TEHTÄVÄ", "en": "OBJECTIVE"}

## Tekstitysten ja vihjeiden kieli: &"fi" tai &"en".
@export var language: StringName = &"fi"

@onready var _effects: ColorRect = $Effects
@onready var _hint_label: Label = $Hint
@onready var _subtitles: RichTextLabel = $Subtitles
@onready var _objective: PanelContainer = $Objective
@onready var _objective_header: Label = $Objective/VBox/Header
@onready var _objective_text: Label = $Objective/VBox/Text
@onready var _title_card: Control = $TitleCard
@onready var _title_label: Label = $TitleCard/Band/VBox/Title
@onready var _title_subtitle: Label = $TitleCard/Band/VBox/Subtitle
@onready var _nickname_card: Control = $NicknameCard
@onready var _nickname_caption: Label = $NicknameCard/Tag/VBox/Caption
@onready var _nickname_label: Label = $NicknameCard/Tag/VBox/Stamp/Name
@onready var _fade_layer: FadeLayer = $FadeLayer as FadeLayer

var _title_tween: Tween
var _nickname_tween: Tween
var _objective_tween: Tween
var _objective_fi: String = ""
var _objective_en: String = ""

var _player: Node
var _search_timer: float = 0.0
var _hit_flash: float = 0.0
var _heart_phase: float = 0.0
var _hint_time_left: float = 0.0
var _was_jammed: bool = false
## Repliikit muodossa { "text": String, "time": float }.
var _subtitle_queue: Array[Dictionary] = []
var _material: ShaderMaterial


func _ready() -> void:
	_material = _effects.material as ShaderMaterial
	_hint_label.modulate.a = 0.0
	_subtitles.text = ""
	EventBus.actor_hit.connect(_on_actor_hit)
	EventBus.barrel_overheated.connect(_on_barrel_overheated)
	EventBus.belt_empty.connect(_on_belt_empty)
	EventBus.squad_callout.connect(_on_squad_callout)
	EventBus.objective_prompt.connect(show_objective)
	EventBus.title_card.connect(show_title_card)
	EventBus.nickname_assigned.connect(show_nickname_card)
	_objective.visible = false
	_title_card.visible = false
	_nickname_card.visible = false
	_find_player()


func _process(delta: float) -> void:
	if not PlayerLookup.is_valid(_player):
		_search_timer -= delta
		if _search_timer <= 0.0:
			_find_player()
	_update_effects(delta)
	_update_hint(delta)
	_update_subtitles(delta)


# --- Julkinen rajapinta -------------------------------------------------------

## Näyttää häivyttyvän vihjeen. `key` on HINTS-taulukon avain tai suora teksti.
func show_hint(key: StringName) -> void:
	var entry: Variant = HINTS.get(key)
	if entry is Dictionary:
		_hint_label.text = (entry as Dictionary).get(String(language), (entry as Dictionary)["fi"])
	else:
		_hint_label.text = String(key)
	_hint_time_left = HINT_HOLD_SECONDS + HINT_FADE_SECONDS


## Näyttää tekstityksen suoraan (ilman katalogia), esim. skriptatuille hetkille.
func show_subtitle(speaker_name: String, text: String) -> void:
	var line_text: String = "[color=#d8c890]%s:[/color] %s" % [speaker_name, text] if not speaker_name.is_empty() else text
	var duration: float = clampf(2.0 + text.length() * 0.06, 2.5, 8.0)
	_subtitle_queue.append({"text": line_text, "time": duration})
	while _subtitle_queue.size() > MAX_SUBTITLES:
		_subtitle_queue.pop_front()
	_refresh_subtitles()


## Näyttää tehtäväohjeen HUDin kulmassa. Molemmat tekstit tyhjiä = piilota.
## Kieli valitaan `language`-asetuksesta; puuttuva käännös korvataan toisella kielellä.
func show_objective(text_fi: String, text_en: String) -> void:
	_objective_fi = text_fi
	_objective_en = text_en
	if _objective_tween != null and _objective_tween.is_valid():
		_objective_tween.kill()
	var text: String = _pick(text_fi, text_en)
	if text.is_empty():
		_objective_text.text = ""
		_objective.visible = false
		_objective.modulate.a = 1.0
		return
	_objective_header.text = String(OBJECTIVE_HEADER.get(String(language), OBJECTIVE_HEADER["fi"]))
	_objective_text.text = text
	_objective.reset_size()
	_objective.visible = true
	_objective.modulate.a = 0.0
	_objective_tween = create_tween()
	_objective_tween.tween_property(_objective, ^"modulate:a", 1.0, OBJECTIVE_FADE)


## Nykyinen näkyvä tehtäväohje (tyhjä, jos piilossa).
func get_objective_text() -> String:
	return _objective_text.text if _objective.visible else ""


## Otsikkokortti keskelle ruutua: iso sapluunaotsikko ja konekirjoitettu alaotsikko.
## Häivyttyy sisään, kirjoittuu merkki kerrallaan ja häipyy noin 4 sekunnissa.
## Tyhjä otsikko ja alaotsikko piilottavat kortin heti.
func show_title_card(title: String, subtitle: String) -> void:
	if _title_tween != null and _title_tween.is_valid():
		_title_tween.kill()
	if title.is_empty() and subtitle.is_empty():
		_title_card.visible = false
		_title_card.modulate.a = 0.0
		return
	_title_label.text = title.to_upper()
	_title_subtitle.text = subtitle
	_title_label.visible_ratio = 0.0
	_title_subtitle.visible_ratio = 0.0
	_title_card.visible = true
	_title_card.modulate.a = 0.0
	var title_time: float = maxf(title.length() / TYPEWRITER_CPS, 0.05)
	var subtitle_time: float = maxf(subtitle.length() / TYPEWRITER_CPS, 0.05)
	_title_tween = create_tween()
	_title_tween.tween_property(_title_card, ^"modulate:a", 1.0, TITLE_FADE_IN)
	_title_tween.parallel().tween_property(_title_label, ^"visible_ratio", 1.0, minf(title_time, TITLE_FADE_IN + 0.6))
	_title_tween.tween_property(_title_subtitle, ^"visible_ratio", 1.0, minf(subtitle_time, 1.4))
	var typed: float = minf(subtitle_time, 1.4)
	_title_tween.tween_interval(maxf(TITLE_HOLD - typed, 0.6))
	_title_tween.tween_property(_title_card, ^"modulate:a", 0.0, TITLE_FADE_OUT)
	_title_tween.tween_callback(_title_card.hide)


## Onko otsikkokortti näkyvissä.
func is_title_card_visible() -> bool:
	return _title_card.visible


## Lempinimikortti: "Lempinimesi: <nimi>" leimasimena, häipyy noin 4,5 sekunnissa.
func show_nickname_card(nickname: String) -> void:
	if _nickname_tween != null and _nickname_tween.is_valid():
		_nickname_tween.kill()
	if nickname.is_empty():
		_nickname_card.visible = false
		return
	_nickname_caption.text = String(NICKNAME_CAPTION.get(String(language), NICKNAME_CAPTION["fi"]))
	_nickname_label.text = nickname.to_upper()
	_nickname_card.visible = true
	_nickname_card.modulate.a = 0.0
	_nickname_label.scale = Vector2.ONE
	_nickname_tween = create_tween()
	_nickname_tween.tween_property(_nickname_card, ^"modulate:a", 1.0, NICKNAME_FADE_IN)
	_nickname_tween.tween_interval(NICKNAME_HOLD)
	_nickname_tween.tween_property(_nickname_card, ^"modulate:a", 0.0, NICKNAME_FADE_OUT)
	_nickname_tween.tween_callback(_nickname_card.hide)


## Lempinimikortin koko teksti, esim. "Lempinimesi: STUMBLES" (tyhjä, jos piilossa).
func get_nickname_card_text() -> String:
	if not _nickname_card.visible:
		return ""
	return "%s %s" % [_nickname_caption.text, _nickname_label.text]


## HUDin oma FadeLayer (häivyttää tason näkyviin automaattisesti käynnistyessä).
func get_fade_layer() -> FadeLayer:
	return _fade_layer


# --- Signaalit -----------------------------------------------------------------

func _on_actor_hit(target: Node3D, damage: float, _body_part: StringName) -> void:
	if not PlayerLookup.is_player(target, _player):
		return
	_hit_flash = clampf(_hit_flash + 0.45 + damage / 60.0, 0.0, 1.0)


func _on_barrel_overheated(weapon: Node) -> void:
	if PlayerLookup.belongs_to_player(weapon, _player):
		show_hint(&"overheated")


func _on_belt_empty(weapon: Node) -> void:
	if PlayerLookup.belongs_to_player(weapon, _player):
		show_hint(&"belt_empty")


func _on_squad_callout(_speaker: Node3D, line_id: StringName) -> void:
	var catalog: VoiceLineCatalog = VoiceLineCatalog.get_default()
	var line: VoiceLine = catalog.find(line_id) if catalog != null else null
	if line == null:
		push_warning("HUD: tuntematon repliikki '%s'" % line_id)
		return
	var nickname: String = String(PlayerLookup.read(get_node_or_null(^"/root/GameState"), &"player_nickname", ""))
	show_subtitle(line.get_speaker_name(language), line.get_text(language, nickname))


# --- Sisäiset ------------------------------------------------------------------

func _pick(text_fi: String, text_en: String) -> String:
	if language == &"en":
		return text_en if not text_en.is_empty() else text_fi
	return text_fi if not text_fi.is_empty() else text_en


func _find_player() -> void:
	_search_timer = PLAYER_SEARCH_INTERVAL
	_player = PlayerLookup.find_player(get_tree())


func _update_effects(delta: float) -> void:
	var suppression: float = 0.0
	var bleeding: int = 0
	var alive: bool = true
	var heat: float = 0.0
	var jammed: bool = false

	if PlayerLookup.is_valid(_player):
		var supp_node: Node = PlayerLookup.get_suppression(_player)
		suppression = float(PlayerLookup.read(supp_node, &"amount", 0.0))
		var health_node: Node = PlayerLookup.get_health(_player)
		bleeding = int(PlayerLookup.read(health_node, &"bleeding_wounds", 0))
		alive = float(PlayerLookup.read(health_node, &"health", 1.0)) > 0.0
		var weapon: Node = PlayerLookup.get_weapon(_player)
		heat = float(PlayerLookup.read(weapon, &"heat", 0.0))
		jammed = bool(PlayerLookup.read(weapon, &"jammed", false))

	if jammed and not _was_jammed:
		show_hint(&"jammed")
	_was_jammed = jammed

	_hit_flash = maxf(_hit_flash - HIT_FLASH_DECAY_PER_SECOND * delta, 0.0)

	var bleed_pulse: float = 0.0
	if bleeding > 0 and alive:
		# Syke kiihtyy haavojen myötä: 70 bpm + 15 bpm per haava.
		var bpm: float = minf(70.0 + 15.0 * bleeding, 150.0)
		_heart_phase = fmod(_heart_phase + delta * bpm / 60.0, 1.0)
		var lub: float = exp(-pow((_heart_phase - 0.05) * 18.0, 2.0))
		var dub: float = exp(-pow((_heart_phase - 0.28) * 18.0, 2.0)) * 0.6
		bleed_pulse = (lub + dub) * clampf(0.3 + 0.15 * bleeding, 0.0, 0.9)
	else:
		_heart_phase = 0.0

	var shimmer: float = 0.0
	if heat > HEAT_SHIMMER_THRESHOLD:
		shimmer = clampf((heat - HEAT_SHIMMER_THRESHOLD) / (1.0 - HEAT_SHIMMER_THRESHOLD), 0.0, 1.0)

	var active: bool = suppression > 0.001 or _hit_flash > 0.001 or bleed_pulse > 0.001 or shimmer > 0.001
	_effects.visible = active
	if active and _material != null:
		_material.set_shader_parameter(&"suppression", suppression)
		_material.set_shader_parameter(&"hit_flash", _hit_flash)
		_material.set_shader_parameter(&"bleed_pulse", bleed_pulse)
		_material.set_shader_parameter(&"heat_shimmer", shimmer)


func _update_hint(delta: float) -> void:
	if _hint_time_left <= 0.0:
		_hint_label.modulate.a = 0.0
		return
	_hint_time_left = maxf(_hint_time_left - delta, 0.0)
	_hint_label.modulate.a = clampf(_hint_time_left / HINT_FADE_SECONDS, 0.0, 1.0)


func _update_subtitles(delta: float) -> void:
	if _subtitle_queue.is_empty():
		return
	var changed: bool = false
	for entry: Dictionary in _subtitle_queue:
		entry["time"] = float(entry["time"]) - delta
	while not _subtitle_queue.is_empty() and float(_subtitle_queue[0]["time"]) <= 0.0:
		_subtitle_queue.pop_front()
		changed = true
	if changed:
		_refresh_subtitles()


func _refresh_subtitles() -> void:
	var parts: PackedStringArray = PackedStringArray()
	for entry: Dictionary in _subtitle_queue:
		parts.append(String(entry["text"]))
	_subtitles.text = "[center]%s[/center]" % "\n".join(parts) if not parts.is_empty() else ""
