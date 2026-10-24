extends Node
## Pelin äänijohtaja: ambienssi, laukaukset 3D-äänenä, ohilentojen snap,
## tukahdutuksen alipäästö SFX-väylällä ja sotilaiden repliikit.
##
## Kaikki äänet ovat paikkamerkkejä, jotka syntetisoidaan koodissa
## (AudioStreamWAV), joten ääntä kuuluu ilman yhtään äänitiedostoa.
## Eläimet (hyönteiset ja linnut) hiljenevät laukausten jälkeen noin 20 sekunniksi.
##
## M2-06: ambienssiprofiilit (jungle, fort_benning, aircraft), C-130:n moottorin jylinä
## (kovempi avoimen oven lähellä), tuulen kohina vapaapudotuksessa (jump_started → chute_opened),
## kuvun avautumisnykäys, laskeutumisen tömähdys (raskaampi kovalle/loukkaantuneelle)
## sekä otsikkokortin kirjoituskone ja lempinimikortin leimasin.
## Profiili päätellään nykyisen scenen tiedostonimestä, ellei sitä aseteta
## set_ambience_profile()-kutsulla. Käsin asetettu profiili on voimassa sen scenen ajan,
## jossa se asetettiin; scenen vaihtuessa palataan automaattiseen valintaan.

const MIX_RATE: int = 22050
## Kuinka kauan viidakon eläimet ovat hiljaa viimeisen laukauksen jälkeen.
const WILDLIFE_QUIET_SECONDS: float = 20.0
## Häivytysnopeudet (taso 0–1 sekunnissa): hiljeneminen nopeaa, palautuminen hidasta.
const WILDLIFE_FADE_OUT_PER_SECOND: float = 1.2
const WILDLIFE_FADE_IN_PER_SECOND: float = 0.15
## SFX-väylän alipäästön rajataajuudet: ei tukahdutusta / täysi tukahdutus.
const LOWPASS_OPEN_HZ: float = 20000.0
const LOWPASS_SUPPRESSED_HZ: float = 900.0
const SHOT_POOL_SIZE: int = 16
const SHOT_MAX_DISTANCE: float = 900.0

const BUS_SFX: StringName = &"SFX"
const BUS_AMBIENCE: StringName = &"Ambience"
const BUS_VOICE: StringName = &"Voice"
const BUS_UI: StringName = &"UI"

const PROFILE_JUNGLE: StringName = &"jungle"
const PROFILE_FORT_BENNING: StringName = &"fort_benning"
const PROFILE_AIRCRAFT: StringName = &"aircraft"
const PROFILES: Array[StringName] = [&"jungle", &"fort_benning", &"aircraft"]
## Etäisyys (m) avoimesta ovesta, jolta oven vaikutus moottorin ääneen alkaa.
const DOOR_RANGE: float = 9.0
## Kuinka nopeasti kone etääntyy äänellisesti hypyn jälkeen (taso 0–1 sekunnissa).
const ENGINE_DEPART_PER_SECOND: float = 0.22
const WIND_FREEFALL_DB: float = -2.0
const WIND_CANOPY_DB: float = -22.0
const SILENT_DB: float = -80.0

## Onko ambienssi päällä. Päävalikko kytkee sen pois.
var ambience_enabled: bool = true
## Eläinäänten nykyinen taso 0–1 (0 = hiljaa laukausten takia).
var wildlife_level: float = 1.0
## Koneen läsnäolo 0–1: 1 = kone ympärillä, laskee hypyn jälkeen koneen etääntyessä.
var engine_presence: float = 1.0
## Avoimen oven läheisyys 0–1 (kamerasta lähimpään jump_door-ryhmän solmuun).
var door_factor: float = 0.0

var _quiet_left: float = 0.0
var _suppression_target: float = 0.0
var _suppression_smoothed: float = 0.0
var _bird_cooldown: float = 2.0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

var _shot_stream: AudioStreamWAV
var _snap_stream: AudioStreamWAV
var _click_stream: AudioStreamWAV
var _bird_streams: Array[AudioStreamWAV] = []
var _landing_soft_stream: AudioStreamWAV
var _landing_heavy_stream: AudioStreamWAV

var _shot_pool: Array[AudioStreamPlayer3D] = []
var _shot_index: int = 0
var _snap_player: AudioStreamPlayer
var _ui_player: AudioStreamPlayer
var _voice_player: AudioStreamPlayer
var _voice_player_3d: AudioStreamPlayer3D
var _bird_player_3d: AudioStreamPlayer3D
var _bird_player: AudioStreamPlayer
var _rustle_player: AudioStreamPlayer
var _insect_player: AudioStreamPlayer
var _benning_insect_player: AudioStreamPlayer
var _cadence_player: AudioStreamPlayer
var _engine_cabin_player: AudioStreamPlayer
var _engine_door_player: AudioStreamPlayer
var _wind_player: AudioStreamPlayer
var _canopy_player: AudioStreamPlayer
var _landing_player: AudioStreamPlayer
var _typewriter_player: AudioStreamPlayer
var _stamp_player: AudioStreamPlayer

var _profile: StringName = PROFILE_JUNGLE
var _profile_override: StringName = &""
## Ruutu, jolla profiili asetettiin käsin (sallii asetuksen uuden scenen _ready-vaiheessa).
var _override_frame: int = 0
var _tracked_scene_id: int = -1
var _jumping: bool = false
var _wind_target_db: float = SILENT_DB


func _ready() -> void:
	_rng.randomize()
	_build_streams()
	_build_players()
	EventBus.bullet_snap.connect(_on_bullet_snap)
	EventBus.squad_callout.connect(_on_squad_callout)
	EventBus.shot_fired.connect(_on_shot_fired)
	EventBus.suppression_changed.connect(_on_suppression_changed)
	EventBus.actor_died.connect(_on_actor_died)
	EventBus.jump_started.connect(_on_jump_started)
	EventBus.chute_opened.connect(_on_chute_opened)
	EventBus.landed.connect(_on_landed)
	EventBus.title_card.connect(_on_title_card)
	EventBus.nickname_assigned.connect(_on_nickname_assigned)
	_profile = _detect_profile()
	set_ambience_enabled(ambience_enabled)


func _exit_tree() -> void:
	# Pysäytetään silmukat, jotta toistot eivät jää roikkumaan sulkiessa.
	for child: Node in get_children():
		if child is AudioStreamPlayer:
			(child as AudioStreamPlayer).stop()
			(child as AudioStreamPlayer).stream = null
		elif child is AudioStreamPlayer3D:
			(child as AudioStreamPlayer3D).stop()
			(child as AudioStreamPlayer3D).stream = null


func _process(delta: float) -> void:
	_track_scene()
	_update_wildlife(delta)
	_update_lowpass(delta)
	_update_aircraft(delta)
	_update_wind(delta)


# --- Julkinen rajapinta -------------------------------------------------------

## Kytkee ambienssin päälle tai pois (esim. valikossa pois). Profiili säilyy.
func set_ambience_enabled(enabled: bool) -> void:
	ambience_enabled = enabled
	_apply_profile()


## Asettaa ambienssiprofiilin: &"jungle", &"fort_benning" tai &"aircraft".
## Tyhjä StringName palauttaa automaattisen valinnan (scenen tiedostonimestä).
## Palauttaa false tuntemattomalla nimellä. Asetus on voimassa nykyisen scenen ajan,
## ja sen voi tehdä myös uuden scenen _ready()-vaiheessa.
func set_ambience_profile(profile: StringName) -> bool:
	if profile == &"":
		_profile_override = &""
		_switch_profile(_detect_profile())
		return true
	if not PROFILES.has(profile):
		push_warning("AudioDirector: tuntematon ambienssiprofiili '%s'" % profile)
		return false
	_profile_override = profile
	_override_frame = Engine.get_process_frames()
	_switch_profile(profile)
	return true


## Nykyinen ambienssiprofiili.
func get_ambience_profile() -> StringName:
	return _profile


## Onko profiili asetettu käsin eikä päätelty scenen tiedostonimestä.
func is_ambience_profile_overridden() -> bool:
	return _profile_override != &""


## Nykyisen profiilin silmukkasoittimien nimet (testejä ja debug-näkymää varten).
func get_ambience_layer_names() -> PackedStringArray:
	var names: PackedStringArray = PackedStringArray()
	for player: AudioStreamPlayer in _layers_for(_profile):
		names.append(String(player.name))
	return names


## Kaikkien profiilien silmukoista ne, jotka soivat juuri nyt.
func get_playing_ambience_layer_names() -> PackedStringArray:
	var names: PackedStringArray = PackedStringArray()
	for profile: StringName in PROFILES:
		for player: AudioStreamPlayer in _layers_for(profile):
			if player.playing:
				names.append(String(player.name))
	return names


## Onko vapaapudotuksen tuuli käynnissä (jump_started → chute_opened).
func is_freefall_wind_active() -> bool:
	return _jumping


## Päättelee profiilin scenen tiedostopolusta. Puhdas funktio, testattavissa.
static func profile_for_scene_path(path: String) -> StringName:
	var file: String = path.get_file().get_basename().to_lower()
	if file.contains("benning") or file.contains("prologue"):
		return PROFILE_FORT_BENNING
	if file.contains("c130") or file.contains("aircraft") or file.contains("drop"):
		return PROFILE_AIRCRAFT
	return PROFILE_JUNGLE


## Hiljentää eläimet kuin laukaus olisi juuri ammuttu. Testejä ja skriptattuja hetkiä varten.
func scare_wildlife() -> void:
	_quiet_left = WILDLIFE_QUIET_SECONDS


## Ovatko eläimet tällä hetkellä hiljaa laukausten vuoksi.
func is_wildlife_quiet() -> bool:
	return _quiet_left > 0.0


## Valikon napsautusääni UI-väylällä.
func play_ui_click() -> void:
	if _ui_player != null:
		_ui_player.pitch_scale = _rng.randf_range(0.95, 1.05)
		_ui_player.play()


## Toistaa laukausäänen annetussa maailman pisteessä.
func play_shot_at(origin: Vector3) -> void:
	if _shot_pool.is_empty():
		return
	var player: AudioStreamPlayer3D = _shot_pool[_shot_index]
	_shot_index = (_shot_index + 1) % _shot_pool.size()
	player.global_position = origin
	player.pitch_scale = _rng.randf_range(0.93, 1.07)
	player.play()


# --- Signaalit -----------------------------------------------------------------

func _on_shot_fired(_shooter: Node3D, origin: Vector3, _direction: Vector3) -> void:
	play_shot_at(origin)
	scare_wildlife()


func _on_bullet_snap(listener: Node3D, distance: float) -> void:
	if not _is_player(listener) or _snap_player == null:
		return
	# Lähempi ohilento on kovempi ja terävämpi.
	var closeness: float = clampf(1.0 - distance / 6.0, 0.15, 1.0)
	_snap_player.volume_db = linear_to_db(closeness)
	_snap_player.pitch_scale = _rng.randf_range(0.9, 1.15)
	_snap_player.play()


func _on_suppression_changed(actor: Node3D, amount: float) -> void:
	if _is_player(actor):
		_suppression_target = clampf(amount, 0.0, 1.0)


func _on_actor_died(actor: Node3D) -> void:
	if _is_player(actor):
		_suppression_target = 0.0


func _on_squad_callout(speaker: Node3D, line_id: StringName) -> void:
	# Tekstitys näytetään HUDissa; tässä toistetaan vain valinnainen ääni.
	var catalog: VoiceLineCatalog = VoiceLineCatalog.get_default()
	if catalog == null:
		return
	var line: VoiceLine = catalog.find(line_id)
	if line == null or line.stream == null:
		return
	if speaker != null and is_instance_valid(speaker) and speaker.is_inside_tree():
		_voice_player_3d.stream = line.stream
		_voice_player_3d.global_position = speaker.global_position
		_voice_player_3d.play()
	else:
		_voice_player.stream = line.stream
		_voice_player.play()


func _on_jump_started(jumper: Node3D) -> void:
	if not _is_player(jumper):
		return
	_jumping = true
	_wind_target_db = WIND_FREEFALL_DB
	if _wind_player != null:
		_wind_player.volume_db = -30.0
		if not _wind_player.playing:
			_wind_player.play()


func _on_chute_opened(jumper: Node3D) -> void:
	if not _is_player(jumper):
		return
	# Kupu auki: kohina vaihtuu hiljaiseksi tuuleksi, joka loppuu maassa.
	_jumping = false
	_wind_target_db = WIND_CANOPY_DB
	if _canopy_player != null:
		_canopy_player.pitch_scale = _rng.randf_range(0.95, 1.05)
		_canopy_player.play()


func _on_landed(jumper: Node3D, quality: StringName) -> void:
	if not _is_player(jumper):
		return
	_jumping = false
	_wind_target_db = SILENT_DB
	if _landing_player == null:
		return
	match quality:
		&"injured":
			_landing_player.stream = _landing_heavy_stream
			_landing_player.volume_db = 3.0
			_landing_player.pitch_scale = 0.85
		&"hard":
			_landing_player.stream = _landing_heavy_stream
			_landing_player.volume_db = -1.0
			_landing_player.pitch_scale = 1.0
		_:
			_landing_player.stream = _landing_soft_stream
			_landing_player.volume_db = -4.0
			_landing_player.pitch_scale = _rng.randf_range(0.95, 1.05)
	_landing_player.play()


func _on_title_card(title: String, _subtitle: String) -> void:
	if _typewriter_player != null and not title.is_empty():
		_typewriter_player.play()


func _on_nickname_assigned(nickname: String) -> void:
	if _stamp_player != null and not nickname.is_empty():
		_stamp_player.play()


# --- Sisäiset ------------------------------------------------------------------

func _is_player(node: Variant) -> bool:
	return is_instance_valid(node) and node is Node and (node as Node).is_in_group(&"player")


func _bus_or_master(bus: StringName) -> StringName:
	return bus if AudioServer.get_bus_index(bus) >= 0 else &"Master"


func _current_scene_id() -> int:
	if not is_inside_tree():
		return 0
	var scene: Node = get_tree().current_scene
	return scene.get_instance_id() if scene != null else 0


func _detect_profile() -> StringName:
	if not is_inside_tree():
		return PROFILE_JUNGLE
	var scene: Node = get_tree().current_scene
	return profile_for_scene_path(scene.scene_file_path if scene != null else "")


## Huomaa scenen vaihdon: nollaa hypyn tilan ja valitsee profiilin uudelleen.
func _track_scene() -> void:
	var scene_id: int = _current_scene_id()
	if scene_id == _tracked_scene_id:
		return
	var first: bool = _tracked_scene_id == -1
	_tracked_scene_id = scene_id
	_jumping = false
	_wind_target_db = SILENT_DB
	engine_presence = 1.0
	door_factor = 0.0
	# Edellisen scenen käsiasetus raukeaa; uuden scenen _ready()-asetus (tällä tai
	# edellisellä ruudulla) jää voimaan.
	if not first and Engine.get_process_frames() - _override_frame > 1:
		_profile_override = &""
	_switch_profile(_profile_override if _profile_override != &"" else _detect_profile())


func _switch_profile(profile: StringName) -> void:
	_profile = profile
	_apply_profile()


func _layers_for(profile: StringName) -> Array[AudioStreamPlayer]:
	var candidates: Array[AudioStreamPlayer] = []
	match profile:
		PROFILE_FORT_BENNING:
			candidates = [_benning_insect_player, _cadence_player]
		PROFILE_AIRCRAFT:
			candidates = [_engine_cabin_player, _engine_door_player]
		_:
			candidates = [_rustle_player, _insect_player]
	var result: Array[AudioStreamPlayer] = []
	for player: AudioStreamPlayer in candidates:
		if player != null:
			result.append(player)
	return result


## Käynnistää nykyisen profiilin silmukat ja pysäyttää muut.
func _apply_profile() -> void:
	var wanted: Array[AudioStreamPlayer] = []
	if ambience_enabled:
		wanted = _layers_for(_profile)
	for profile: StringName in PROFILES:
		for player: AudioStreamPlayer in _layers_for(profile):
			if wanted.has(player):
				if player.stream == null:
					player.stream = _build_loop_for(player)
				if not player.playing:
					player.play()
			elif player.playing:
				player.stop()


## Profiilien silmukat syntetisoidaan vasta tarvittaessa, jotta käynnistys pysyy nopeana.
func _build_loop_for(player: AudioStreamPlayer) -> AudioStreamWAV:
	if player == _benning_insect_player:
		return _make_benning_insect_loop()
	if player == _cadence_player:
		return _make_cadence_loop()
	if player == _engine_cabin_player:
		return _make_engine_loop(false)
	if player == _engine_door_player:
		return _make_engine_loop(true)
	return null


func _update_wildlife(delta: float) -> void:
	_quiet_left = maxf(_quiet_left - delta, 0.0)
	var target: float = 0.0 if _quiet_left > 0.0 else 1.0
	var rate: float = WILDLIFE_FADE_OUT_PER_SECOND if target < wildlife_level else WILDLIFE_FADE_IN_PER_SECOND
	wildlife_level = move_toward(wildlife_level, target, rate * delta)
	var level_db: float = linear_to_db(maxf(wildlife_level, 0.001))
	if _insect_player != null:
		_insect_player.volume_db = -14.0 + level_db
	if _benning_insect_player != null:
		_benning_insect_player.volume_db = -16.0 + level_db
	if not ambience_enabled or _profile != PROFILE_JUNGLE:
		return
	_bird_cooldown -= delta
	if _bird_cooldown <= 0.0:
		_bird_cooldown = _rng.randf_range(2.5, 7.0)
		if wildlife_level > 0.6:
			_play_bird()


func _play_bird() -> void:
	if _bird_streams.is_empty():
		return
	var stream: AudioStreamWAV = _bird_streams[_rng.randi() % _bird_streams.size()]
	var camera: Camera3D = get_viewport().get_camera_3d()
	if camera != null and camera.is_inside_tree():
		var angle: float = _rng.randf_range(0.0, TAU)
		var radius: float = _rng.randf_range(12.0, 40.0)
		var offset: Vector3 = Vector3(cos(angle) * radius, _rng.randf_range(4.0, 15.0), sin(angle) * radius)
		_bird_player_3d.stream = stream
		_bird_player_3d.global_position = camera.global_position + offset
		_bird_player_3d.pitch_scale = _rng.randf_range(0.9, 1.1)
		_bird_player_3d.volume_db = linear_to_db(wildlife_level) - 4.0
		_bird_player_3d.play()
	else:
		_bird_player.stream = stream
		_bird_player.volume_db = linear_to_db(wildlife_level) - 12.0
		_bird_player.play()


func _update_lowpass(delta: float) -> void:
	_suppression_smoothed = move_toward(_suppression_smoothed, _suppression_target, 2.5 * delta)
	var bus: int = AudioServer.get_bus_index(BUS_SFX)
	if bus < 0 or AudioServer.get_bus_effect_count(bus) == 0:
		return
	var filter: AudioEffectLowPassFilter = AudioServer.get_bus_effect(bus, 0) as AudioEffectLowPassFilter
	if filter == null:
		return
	# Eksponentiaalinen interpolointi kuulostaa luonnollisemmalta kuin lineaarinen.
	var t: float = pow(_suppression_smoothed, 0.8)
	filter.cutoff_hz = LOWPASS_OPEN_HZ * pow(LOWPASS_SUPPRESSED_HZ / LOWPASS_OPEN_HZ, t)


## Moottorin taso: avoimen oven lähellä kovempi ja kirkkaampi, hypyn jälkeen kone etääntyy.
func _update_aircraft(delta: float) -> void:
	if _profile != PROFILE_AIRCRAFT or _engine_cabin_player == null or _engine_door_player == null:
		return
	if _jumping or _wind_player.playing:
		engine_presence = move_toward(engine_presence, 0.0, ENGINE_DEPART_PER_SECOND * delta)
	var target_door: float = 0.0
	var camera: Camera3D = get_viewport().get_camera_3d()
	if camera != null and camera.is_inside_tree():
		var nearest: float = INF
		for door: Node in get_tree().get_nodes_in_group(&"jump_door"):
			if door is Node3D and (door as Node3D).is_inside_tree():
				nearest = minf(nearest, camera.global_position.distance_to((door as Node3D).global_position))
		if nearest < INF:
			target_door = clampf(1.0 - nearest / DOOR_RANGE, 0.0, 1.0)
	door_factor = move_toward(door_factor, target_door, 2.0 * delta)
	_engine_cabin_player.volume_db = -6.0 + linear_to_db(engine_presence * (1.0 - 0.3 * door_factor) + 0.0005)
	_engine_door_player.volume_db = -3.0 + linear_to_db(engine_presence * door_factor + 0.0005)


func _update_wind(delta: float) -> void:
	if _wind_player == null or not _wind_player.playing:
		return
	_wind_player.volume_db = move_toward(_wind_player.volume_db, _wind_target_db, 40.0 * delta)
	if _wind_target_db <= SILENT_DB + 1.0 and _wind_player.volume_db <= -60.0:
		_wind_player.stop()


func _build_players() -> void:
	for i: int in SHOT_POOL_SIZE:
		var shot: AudioStreamPlayer3D = AudioStreamPlayer3D.new()
		shot.name = "Shot%d" % i
		shot.stream = _shot_stream
		shot.bus = _bus_or_master(BUS_SFX)
		shot.unit_size = 12.0
		shot.max_distance = SHOT_MAX_DISTANCE
		shot.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		shot.volume_db = 2.0
		add_child(shot)
		_shot_pool.append(shot)

	_snap_player = _make_player("Snap", _snap_stream, BUS_SFX, 0.0)
	_ui_player = _make_player("UIClick", _click_stream, BUS_UI, 0.0)
	_voice_player = _make_player("Voice", null, BUS_VOICE, 0.0)
	_bird_player = _make_player("Bird", null, BUS_AMBIENCE, -12.0)
	_rustle_player = _make_player("Rustle", _make_rustle_loop(), BUS_AMBIENCE, -20.0)
	_insect_player = _make_player("Insects", _make_insect_loop(), BUS_AMBIENCE, -14.0)
	# Muiden profiilien silmukat: streamit syntetisoidaan, kun profiili otetaan käyttöön.
	_benning_insect_player = _make_player("BenningInsects", null, BUS_AMBIENCE, -16.0)
	_cadence_player = _make_player("BenningCadence", null, BUS_AMBIENCE, -22.0)
	_engine_cabin_player = _make_player("EngineCabin", null, BUS_AMBIENCE, -6.0)
	_engine_door_player = _make_player("EngineDoor", null, BUS_AMBIENCE, SILENT_DB)
	# Hypyn kertaäänet.
	_wind_player = _make_player("Wind", _make_wind_loop(), BUS_SFX, SILENT_DB)
	_canopy_player = _make_player("Canopy", _make_canopy_snap(), BUS_SFX, 0.0)
	_landing_player = _make_player("Landing", _landing_soft_stream, BUS_SFX, -4.0)
	_typewriter_player = _make_player("Typewriter", _make_typewriter_burst(), BUS_UI, -2.0)
	_stamp_player = _make_player("Stamp", _make_stamp(), BUS_UI, 0.0)

	_voice_player_3d = AudioStreamPlayer3D.new()
	_voice_player_3d.name = "Voice3D"
	_voice_player_3d.bus = _bus_or_master(BUS_VOICE)
	_voice_player_3d.unit_size = 8.0
	add_child(_voice_player_3d)

	_bird_player_3d = AudioStreamPlayer3D.new()
	_bird_player_3d.name = "Bird3D"
	_bird_player_3d.bus = _bus_or_master(BUS_AMBIENCE)
	_bird_player_3d.unit_size = 15.0
	add_child(_bird_player_3d)


func _make_player(player_name: String, stream: AudioStream, bus: StringName, volume: float) -> AudioStreamPlayer:
	var player: AudioStreamPlayer = AudioStreamPlayer.new()
	player.name = player_name
	player.stream = stream
	player.bus = _bus_or_master(bus)
	player.volume_db = volume
	add_child(player)
	return player


# --- Paikkamerkkiäänien synteesi ------------------------------------------------

func _build_streams() -> void:
	_shot_stream = _make_gunshot()
	_snap_stream = _make_snap()
	_click_stream = _make_click()
	for seed_value: int in [11, 23, 37, 58]:
		_bird_streams.append(_make_bird_call(seed_value))
	_landing_soft_stream = _make_landing(false)
	_landing_heavy_stream = _make_landing(true)


## Muuntaa näytteet (-1..1) 16-bittiseksi mono-WAViksi.
static func _to_wav(samples: PackedFloat32Array, loop: bool) -> AudioStreamWAV:
	var bytes: PackedByteArray = PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i: int in samples.size():
		bytes.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32767.0))
	var wav: AudioStreamWAV = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = MIX_RATE
	wav.stereo = false
	wav.data = bytes
	if loop:
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = samples.size()
	return wav


## Pehmeä leikkuri, joka estää säröisen ylityksen.
static func _soft_clip(value: float) -> float:
	return value / (1.0 + absf(value))


## Silmukan saumaton liitos: loppuosa ristihäivytetään alkuun.
static func _crossfade_loop(raw: PackedFloat32Array, length: int) -> PackedFloat32Array:
	var fade: int = raw.size() - length
	var out: PackedFloat32Array = raw.slice(0, length)
	for i: int in fade:
		var a: float = float(i) / float(fade)
		out[i] = raw[i] * a + raw[length + i] * (1.0 - a)
	return out


## Kaksinapaisen resonaattorin kertoimet [a1, a2, gain] taajuudelle ja kaistanleveydelle (Hz).
static func _resonator(freq: float, bandwidth: float) -> PackedFloat32Array:
	var r: float = exp(-PI * bandwidth / MIX_RATE)
	return PackedFloat32Array([2.0 * r * cos(TAU * freq / MIX_RATE), -r * r, 1.0 - r])


## M60-laukaus: terävä paukahdus, matala tömähdys ja viidakon kaiku.
func _make_gunshot() -> AudioStreamWAV:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 60
	var count: int = int(0.9 * MIX_RATE)
	var samples: PackedFloat32Array = PackedFloat32Array()
	samples.resize(count)
	var low: float = 0.0
	for i: int in count:
		var t: float = float(i) / MIX_RATE
		var noise: float = rng.randf_range(-1.0, 1.0)
		low += (noise - low) * 0.3
		var crack: float = noise * exp(-t * 90.0)
		var body: float = low * exp(-t * 10.0) * 1.4
		var thump: float = sin(TAU * 68.0 * t) * exp(-t * 16.0)
		var echo: float = 0.0
		if t > 0.22:
			echo = low * exp(-(t - 0.22) * 5.0) * 0.35
		samples[i] = _soft_clip((crack * 0.9 + body + thump + echo) * 1.6) * 0.95
	return _to_wav(samples, false)


## Yliääniluodin ohilento: kova napsahdus ja lyhyt viuhahdus.
func _make_snap() -> AudioStreamWAV:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 7
	var count: int = int(0.14 * MIX_RATE)
	var samples: PackedFloat32Array = PackedFloat32Array()
	samples.resize(count)
	var previous: float = 0.0
	var phase: float = 0.0
	for i: int in count:
		var t: float = float(i) / MIX_RATE
		var noise: float = rng.randf_range(-1.0, 1.0)
		var high: float = noise - previous  # derivaatta = ylipäästö
		previous = noise
		var freq: float = lerpf(3200.0, 1100.0, t / 0.14)
		phase += TAU * freq / MIX_RATE
		var crack: float = high * exp(-t * 140.0)
		var whiz: float = sin(phase) * exp(-t * 35.0) * 0.25
		samples[i] = _soft_clip((crack + whiz) * 1.8)
	return _to_wav(samples, false)


## Lyhyt mekaaninen naksahdus valikkoon (kuin kytkin).
func _make_click() -> AudioStreamWAV:
	var count: int = int(0.05 * MIX_RATE)
	var samples: PackedFloat32Array = PackedFloat32Array()
	samples.resize(count)
	for i: int in count:
		var t: float = float(i) / MIX_RATE
		samples[i] = (sin(TAU * 1800.0 * t) * 0.5 + sin(TAU * 420.0 * t) * 0.5) * exp(-t * 120.0) * 0.6
	return _to_wav(samples, false)


## Viidakkolinnun huuto: 2–5 nousevaa tai laskevaa viserrystä.
func _make_bird_call(seed_value: int) -> AudioStreamWAV:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	var samples: PackedFloat32Array = PackedFloat32Array()
	var chirps: int = rng.randi_range(2, 5)
	var base: float = rng.randf_range(1800.0, 4200.0)
	var phase: float = 0.0
	for c: int in chirps:
		var length: int = int(rng.randf_range(0.06, 0.16) * MIX_RATE)
		var f0: float = base * rng.randf_range(0.8, 1.2)
		var f1: float = f0 * rng.randf_range(0.6, 1.6)
		for i: int in length:
			var x: float = float(i) / float(length)
			var vibrato: float = sin(TAU * 28.0 * x) * 120.0
			phase += TAU * (lerpf(f0, f1, x) + vibrato) / MIX_RATE
			samples.append(sin(phase) * sin(PI * x) * 0.5)
		var gap: int = int(rng.randf_range(0.04, 0.12) * MIX_RATE)
		for i: int in gap:
			samples.append(0.0)
	return _to_wav(samples, false)


## Lehtien kahina ja tuuli: alipäästetty kohina, hidas aaltoilu.
func _make_rustle_loop() -> AudioStreamWAV:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 3
	var length: int = 4 * MIX_RATE
	var fade: int = MIX_RATE / 4
	var raw: PackedFloat32Array = PackedFloat32Array()
	raw.resize(length + fade)
	var low: float = 0.0
	for i: int in raw.size():
		var t: float = float(i) / MIX_RATE
		low += (rng.randf_range(-1.0, 1.0) - low) * 0.05
		raw[i] = low * (0.7 + 0.3 * sin(TAU * 0.25 * t)) * 2.5
	return _to_wav(_crossfade_loop(raw, length), true)


## Sirkat ja hyönteiset: kaistanpäästetty kohina, nopea sirityssyke.
func _make_insect_loop() -> AudioStreamWAV:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 5
	var length: int = 4 * MIX_RATE
	var fade: int = MIX_RATE / 4
	var raw: PackedFloat32Array = PackedFloat32Array()
	raw.resize(length + fade)
	var low_a: float = 0.0
	var low_b: float = 0.0
	for i: int in raw.size():
		var t: float = float(i) / MIX_RATE
		var noise: float = rng.randf_range(-1.0, 1.0)
		low_a += (noise - low_a) * 0.75
		low_b += (noise - low_b) * 0.35
		var band: float = low_a - low_b
		var pulse: float = pow(maxf(sin(TAU * 40.0 * t), 0.0), 2.0)
		var swell: float = 0.6 + 0.4 * sin(TAU * 0.25 * t)
		raw[i] = band * pulse * swell * 1.6
	return _to_wav(_crossfade_loop(raw, length), true)


## Georgian kesä: kaskaiden aaltoileva surina ja sirkkojen kolmoissiritykset (8 s silmukka).
func _make_benning_insect_loop() -> AudioStreamWAV:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 1966
	var length: int = 8 * MIX_RATE
	var fade: int = MIX_RATE / 2
	var raw: PackedFloat32Array = PackedFloat32Array()
	raw.resize(length + fade)
	var previous: float = 0.0
	var high_lp: float = 0.0
	for i: int in raw.size():
		var t: float = float(i) / MIX_RATE
		var noise: float = rng.randf_range(-1.0, 1.0)
		var high: float = noise - previous
		previous = noise
		high_lp += (high - high_lp) * 0.6
		# Kaksi kaskasta: nopea surinasyke ja hidas paisunta eri tahdissa.
		var buzz_a: float = 0.55 + 0.45 * sin(TAU * 118.0 * t)
		var buzz_b: float = 0.55 + 0.45 * sin(TAU * 131.0 * t)
		var swell_a: float = pow(maxf(sin(TAU * t / 8.0), 0.0), 1.5)
		var swell_b: float = pow(maxf(sin(TAU * (t / 4.0 + 0.3)), 0.0), 2.0) * 0.6
		var cicada: float = high_lp * (buzz_a * swell_a + buzz_b * swell_b) * 0.9
		# Sirkka: kolme lyhyttä siritystä kahdesti sekunnissa.
		var beat: float = fmod(t * 2.0, 1.0)
		var cricket_env: float = 0.0
		if beat < 0.18:
			cricket_env = pow(maxf(sin(PI * fmod(beat, 0.06) / 0.06), 0.0), 2.0)
		var cricket: float = sin(TAU * 4400.0 * t) * cricket_env * 0.18
		raw[i] = _soft_clip((cicada + cricket) * 1.3)
	return _to_wav(_crossfade_loop(raw, length), true)


## Kaukainen marssitahdin mumina: esilaulaja ja ryhmän vastaus vokaaleina ilman sanoja,
## askelten tömähdykset ja vahva alipäästö etäisyyden vuoksi (8 s silmukka).
func _make_cadence_loop() -> AudioStreamWAV:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 503
	var length: int = 8 * MIX_RATE
	var fade: int = MIX_RATE / 2
	var total: int = length + fade
	var raw: PackedFloat32Array = PackedFloat32Array()
	raw.resize(total)
	# Vokaalien formantit (Hz): "aa", "oo", "ei", "uu".
	var vowels: Array[Vector2] = [Vector2(720.0, 1150.0), Vector2(480.0, 820.0), Vector2(520.0, 1800.0), Vector2(350.0, 700.0)]
	var filters_a: Array[PackedFloat32Array] = []
	var filters_b: Array[PackedFloat32Array] = []
	for vowel_formants: Vector2 in vowels:
		filters_a.append(_resonator(vowel_formants.x, 90.0))
		filters_b.append(_resonator(vowel_formants.y, 120.0))
	var call_pitches: PackedFloat32Array = PackedFloat32Array([128.0, 128.0, 144.0, 120.0])
	var chorus_pitch: PackedFloat32Array = PackedFloat32Array([104.0, 117.0, 126.0, 98.0, 139.0])
	var phases: PackedFloat32Array = PackedFloat32Array()
	phases.resize(chorus_pitch.size() + 1)
	var y1a: float = 0.0
	var y2a: float = 0.0
	var y1b: float = 0.0
	var y2b: float = 0.0
	var lp: float = 0.0
	var step_noise: float = 0.0
	for i: int in total:
		var t: float = fmod(float(i) / MIX_RATE, 8.0)
		var beat_f: float = t * 2.0  # kaksi iskua sekunnissa
		var beat: int = int(beat_f) % 16
		var in_beat: float = beat_f - floorf(beat_f)
		var is_call: bool = beat < 4 or (beat >= 8 and beat < 12)
		var vowel_index: int = beat % vowels.size()
		var env: float = sin(PI * clampf(in_beat / 0.7, 0.0, 1.0)) if in_beat < 0.7 else 0.0
		var source: float = 0.0
		if is_call:
			phases[0] = fmod(phases[0] + call_pitches[beat % 4] / MIX_RATE, 1.0)
			source = (2.0 * phases[0] - 1.0) * 0.6
		else:
			for v: int in chorus_pitch.size():
				var jitter: float = 1.0 + 0.01 * sin(TAU * (0.7 + v * 0.3) * t)
				phases[v + 1] = fmod(phases[v + 1] + chorus_pitch[v] * jitter / MIX_RATE, 1.0)
				source += (2.0 * phases[v + 1] - 1.0) * 0.28
		source *= env
		var fa: PackedFloat32Array = filters_a[vowel_index]
		var fb: PackedFloat32Array = filters_b[vowel_index]
		var ya: float = source * fa[2] + fa[0] * y1a + fa[1] * y2a
		y2a = y1a
		y1a = ya
		var yb: float = source * fb[2] + fb[0] * y1b + fb[1] * y2b
		y2b = y1b
		y1b = yb
		var voice: float = ya * 1.6 + yb * 0.9
		# Askeleet joka iskulla: matala tömähdys ja sorahdus.
		step_noise += (rng.randf_range(-1.0, 1.0) - step_noise) * 0.1
		var step: float = (sin(TAU * 70.0 * in_beat * 0.5) * 0.6 + step_noise * 1.5) * exp(-in_beat * 30.0)
		lp += (voice + step * 0.5 - lp) * 0.12
		raw[i] = lp
	# Kaiku parakkien seinistä.
	var delay: int = int(0.31 * MIX_RATE)
	for i: int in range(total - 1, delay - 1, -1):
		raw[i] += raw[i - delay] * 0.3
	for i: int in total:
		raw[i] = _soft_clip(raw[i] * 2.2) * 0.8
	return _to_wav(_crossfade_loop(raw, length), true)


## C-130:n neljä Allison T56 -potkuriturbiinia: potkurin lapataajuus noin 68 Hz ja
## sen kerrannaiset, moottorien välinen huojunta, turbiinin vinkuna ja runkojylinä.
## door = true: avoimen oven ääni, jossa ilmavirran kohina ja kirkkaammat yläsävelet.
func _make_engine_loop(door: bool) -> AudioStreamWAV:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 130 if door else 131
	var length: int = 4 * MIX_RATE
	var fade: int = MIX_RATE / 4
	var raw: PackedFloat32Array = PackedFloat32Array()
	raw.resize(length + fade)
	var low: float = 0.0
	var mid: float = 0.0
	var mid_low: float = 0.0
	for i: int in raw.size():
		var t: float = float(i) / MIX_RATE
		var noise: float = rng.randf_range(-1.0, 1.0)
		low += (noise - low) * 0.015
		mid += (noise - mid) * 0.35
		mid_low += (noise - mid_low) * 0.04
		# Taajuudet valittu niin, että 4 s sisältää kokonaisen määrän jaksoja.
		var prop: float = sin(TAU * 68.0 * t) * 0.5 + sin(TAU * 68.5 * t) * 0.45
		prop += sin(TAU * 136.0 * t) * 0.28 + sin(TAU * 137.0 * t) * 0.22
		prop += sin(TAU * 204.0 * t) * 0.12
		var whine: float = sin(TAU * 1150.0 * t) * 0.02
		var air: float = (mid - mid_low) * (0.8 + 0.2 * sin(TAU * 0.5 * t))
		var value: float = 0.0
		if door:
			prop += sin(TAU * 272.0 * t) * 0.12 + sin(TAU * 340.0 * t) * 0.08 + sin(TAU * 408.0 * t) * 0.05
			value = prop * 0.35 + low * 2.5 + air * 1.1 + whine * 2.5
		else:
			# Rungon läpi: yläpäät vaimenevat, jylinä korostuu.
			value = prop * 0.42 + low * 3.5 + air * 0.18 + whine
		raw[i] = _soft_clip(value * 1.3) * 0.85
	return _to_wav(_crossfade_loop(raw, length), true)


## Ilmavirran kohina vapaapudotuksessa: kaistanpäästetty kohina, puuskat ja
## varustenauhojen lepatus.
func _make_wind_loop() -> AudioStreamWAV:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 222
	var length: int = 4 * MIX_RATE
	var fade: int = MIX_RATE / 4
	var raw: PackedFloat32Array = PackedFloat32Array()
	raw.resize(length + fade)
	var a: float = 0.0
	var b: float = 0.0
	var rumble: float = 0.0
	for i: int in raw.size():
		var t: float = float(i) / MIX_RATE
		var noise: float = rng.randf_range(-1.0, 1.0)
		var gust: float = 0.7 + 0.2 * sin(TAU * 0.5 * t) + 0.1 * sin(TAU * 1.25 * t + 1.3)
		a += (noise - a) * (0.25 + 0.15 * gust)
		b += (noise - b) * 0.03
		rumble += (noise - rumble) * 0.008
		var flap: float = 0.85 + 0.15 * sin(TAU * 13.0 * t)
		raw[i] = _soft_clip(((a - b) * 1.6 * flap + rumble * 6.0) * gust * 1.4) * 0.9
	return _to_wav(_crossfade_loop(raw, length), true)


## Kuvun avautuminen: nouseva suhahdus, terävä kankaan läimähdys, nykäys ja lepatus.
func _make_canopy_snap() -> AudioStreamWAV:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 1967
	var count: int = int(1.3 * MIX_RATE)
	var samples: PackedFloat32Array = PackedFloat32Array()
	samples.resize(count)
	var lp: float = 0.0
	var previous: float = 0.0
	const SNAP_AT: float = 0.45
	for i: int in count:
		var t: float = float(i) / MIX_RATE
		var noise: float = rng.randf_range(-1.0, 1.0)
		var value: float = 0.0
		if t < SNAP_AT:
			# Kupu vetäytyy pussista: kohina kirkastuu ja voimistuu.
			var x: float = t / SNAP_AT
			lp += (noise - lp) * lerpf(0.04, 0.4, x)
			value = lp * x * x * 1.2
		else:
			var s: float = t - SNAP_AT
			var high: float = noise - previous
			var crack: float = high * exp(-s * 70.0) * 1.4
			var jolt: float = sin(TAU * 85.0 * s) * exp(-s * 14.0) * 0.9
			lp += (noise - lp) * 0.2
			var flutter: float = lp * (0.5 + 0.5 * sin(TAU * 17.0 * s)) * exp(-s * 3.5) * 0.7
			value = crack + jolt + flutter
		previous = noise
		samples[i] = _soft_clip(value * 1.5)
	return _to_wav(samples, false)


## Laskeutumisen tömähdys. heavy = kova tai loukkaantunut: kovempi isku, toinen
## tömähdys (kehon kieriminen) ja varusteiden kolina.
func _make_landing(heavy: bool) -> AudioStreamWAV:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 34 if heavy else 35
	var count: int = int((0.9 if heavy else 0.5) * MIX_RATE)
	var samples: PackedFloat32Array = PackedFloat32Array()
	samples.resize(count)
	var lp: float = 0.0
	var previous: float = 0.0
	for i: int in count:
		var t: float = float(i) / MIX_RATE
		var noise: float = rng.randf_range(-1.0, 1.0)
		lp += (noise - lp) * 0.08
		var thump: float = sin(TAU * (48.0 if heavy else 62.0) * t) * exp(-t * (11.0 if heavy else 16.0))
		var dirt: float = lp * exp(-t * 22.0) * 1.5
		var value: float = thump + dirt
		if heavy:
			var r: float = t - 0.17
			if r > 0.0:
				value += sin(TAU * 55.0 * r) * exp(-r * 13.0) * 0.7 + lp * exp(-r * 18.0)
			# Varusteiden kolina: sykkivä ylipäästetty kohina.
			var high: float = noise - previous
			var rattle_env: float = maxf(sin(TAU * 21.0 * t), 0.0) * exp(-t * 6.0)
			value += high * rattle_env * 0.25
		previous = noise
		samples[i] = _soft_clip(value * (1.8 if heavy else 1.3))
	return _to_wav(samples, false)


## Otsikkokortin kirjoituskone: noin 14 näppäinlyöntiä ja lopuksi rivikellon kilahdus.
func _make_typewriter_burst() -> AudioStreamWAV:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 1966
	var count: int = int(1.9 * MIX_RATE)
	var samples: PackedFloat32Array = PackedFloat32Array()
	samples.resize(count)
	var strike_times: PackedFloat32Array = PackedFloat32Array()
	var at: float = 0.05
	while at < 1.25:
		strike_times.append(at)
		at += rng.randf_range(0.055, 0.12)
	var previous: float = 0.0
	for i: int in count:
		var t: float = float(i) / MIX_RATE
		var noise: float = rng.randf_range(-1.0, 1.0)
		var high: float = noise - previous
		previous = noise
		var value: float = 0.0
		for strike: float in strike_times:
			var s: float = t - strike
			if s >= 0.0 and s < 0.06:
				value += high * exp(-s * 280.0) * 0.9 + sin(TAU * 190.0 * s) * exp(-s * 70.0) * 0.5
		var bell_t: float = t - 1.4
		if bell_t >= 0.0:
			var bell: float = sin(TAU * 2093.0 * bell_t) * 0.5 + sin(TAU * 4186.0 * bell_t) * 0.2 + sin(TAU * 5300.0 * bell_t) * 0.1
			value += bell * exp(-bell_t * 6.0) * 0.35
		samples[i] = _soft_clip(value * 1.2)
	return _to_wav(samples, false)


## Lempinimikortin leimasin: kumileimasimen tömähdys paperiin.
func _make_stamp() -> AudioStreamWAV:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 173
	var count: int = int(0.35 * MIX_RATE)
	var samples: PackedFloat32Array = PackedFloat32Array()
	samples.resize(count)
	var lp: float = 0.0
	for i: int in count:
		var t: float = float(i) / MIX_RATE
		var noise: float = rng.randf_range(-1.0, 1.0)
		lp += (noise - lp) * 0.3
		var thump: float = sin(TAU * 95.0 * t) * exp(-t * 28.0)
		var slap: float = lp * exp(-t * 60.0) * 0.9
		var click: float = sin(TAU * 1400.0 * t) * exp(-t * 200.0) * 0.3
		samples[i] = _soft_clip((thump + slap + click) * 1.6)
	return _to_wav(samples, false)
