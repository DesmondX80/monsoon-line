extends Node
## Pelin äänijohtaja: viidakon ambienssi, laukaukset 3D-äänenä, ohilentojen snap,
## tukahdutuksen alipäästö SFX-väylällä ja sotilaiden repliikit.
##
## Kaikki M1-vaiheen äänet ovat paikkamerkkejä, jotka syntetisoidaan koodissa
## (AudioStreamWAV), joten ääntä kuuluu ilman yhtään äänitiedostoa.
## Eläimet (hyönteiset ja linnut) hiljenevät laukausten jälkeen noin 20 sekunniksi.

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

## Onko ambienssi päällä. Päävalikko kytkee sen pois.
var ambience_enabled: bool = true
## Eläinäänten nykyinen taso 0–1 (0 = hiljaa laukausten takia).
var wildlife_level: float = 1.0

var _quiet_left: float = 0.0
var _suppression_target: float = 0.0
var _suppression_smoothed: float = 0.0
var _bird_cooldown: float = 2.0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

var _shot_stream: AudioStreamWAV
var _snap_stream: AudioStreamWAV
var _click_stream: AudioStreamWAV
var _bird_streams: Array[AudioStreamWAV] = []

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


func _ready() -> void:
	_rng.randomize()
	_build_streams()
	_build_players()
	EventBus.bullet_snap.connect(_on_bullet_snap)
	EventBus.squad_callout.connect(_on_squad_callout)
	EventBus.shot_fired.connect(_on_shot_fired)
	EventBus.suppression_changed.connect(_on_suppression_changed)
	EventBus.actor_died.connect(_on_actor_died)
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
	_update_wildlife(delta)
	_update_lowpass(delta)


# --- Julkinen rajapinta -------------------------------------------------------

## Kytkee viidakon ambienssin päälle tai pois (esim. valikossa pois).
func set_ambience_enabled(enabled: bool) -> void:
	ambience_enabled = enabled
	for player: AudioStreamPlayer in [_rustle_player, _insect_player]:
		if player == null:
			continue
		if enabled and not player.playing:
			player.play()
		elif not enabled:
			player.stop()


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


# --- Sisäiset ------------------------------------------------------------------

func _is_player(node: Variant) -> bool:
	return is_instance_valid(node) and node is Node and (node as Node).is_in_group(&"player")


func _bus_or_master(bus: StringName) -> StringName:
	return bus if AudioServer.get_bus_index(bus) >= 0 else &"Master"


func _update_wildlife(delta: float) -> void:
	_quiet_left = maxf(_quiet_left - delta, 0.0)
	var target: float = 0.0 if _quiet_left > 0.0 else 1.0
	var rate: float = WILDLIFE_FADE_OUT_PER_SECOND if target < wildlife_level else WILDLIFE_FADE_IN_PER_SECOND
	wildlife_level = move_toward(wildlife_level, target, rate * delta)
	if _insect_player != null:
		_insect_player.volume_db = -14.0 + linear_to_db(maxf(wildlife_level, 0.001))
	if not ambience_enabled:
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
