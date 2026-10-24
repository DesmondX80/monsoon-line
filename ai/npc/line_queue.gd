class_name LineQueue
extends RefCounted
## Repliikkijono: lähettää EventBus.squad_callout-repliikit niin, etteivät ne mene päällekkäin.
## Kahden repliikin väli on vähintään min_gap sekuntia. Sama repliikki ei ole jonossa kahdesti.
## Ohjaaja kutsuu tick(delta) joka ruudulla; testit voivat kutsua sitä käsin.

signal line_emitted(speaker: Node3D, line_id: StringName)

## Pienin väli kahden repliikin alkujen välillä (s).
var min_gap: float = 3.0
## Jonon enimmäispituus. Ylimääräiset (vanhimmat) repliikit pudotetaan.
var max_length: int = 6
## Lähetetäänkö repliikit EventBusiin (testeissä voidaan kuunnella pelkkää line_emitted-signaalia).
var emit_to_event_bus: bool = true

## Alkiot muodossa { "speaker": Node3D tai null, "line_id": StringName }.
var _queue: Array[Dictionary] = []
var _cooldown: float = 0.0


func _init(gap: float = 3.0) -> void:
	min_gap = gap


## Lisää repliikin jonoon. Jos jono on tyhjä ja väli on kulunut, repliikki lähtee heti.
func push(speaker: Node3D, line_id: StringName) -> void:
	for item: Dictionary in _queue:
		if item["line_id"] == line_id:
			return
	_queue.append({"speaker": speaker, "line_id": line_id})
	while _queue.size() > max_length:
		_queue.pop_front()
	if _cooldown <= 0.0:
		_emit_next()


func tick(delta: float) -> void:
	_cooldown = maxf(_cooldown - delta, 0.0)
	if _cooldown <= 0.0 and not _queue.is_empty():
		_emit_next()


## Onko jono tyhjä ja edellinen repliikki ehditty kuulla.
func is_idle() -> bool:
	return _queue.is_empty() and _cooldown <= 0.0


func is_empty() -> bool:
	return _queue.is_empty()


func clear() -> void:
	_queue.clear()


func _emit_next() -> void:
	var item: Dictionary = _queue.pop_front()
	_cooldown = min_gap
	var speaker: Node3D = null
	var raw: Variant = item["speaker"]
	if is_instance_valid(raw) and raw is Node3D:
		speaker = raw as Node3D
	var line_id: StringName = item["line_id"]
	if emit_to_event_bus:
		EventBus.squad_callout.emit(speaker, line_id)
	line_emitted.emit(speaker, line_id)
