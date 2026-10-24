extends Node3D
## Hiekkalaatikon asema-stub: begin() käynnistää ajastimen, joka lähettää training_event- ja
## training_station_completed-signaalit kuten oikea asema (world/training/training_station.gd).

@export var station_id: StringName = &""
@export var duration: float = 3.0
@export var result: Dictionary = {}
@export var events: Array[StringName] = []

var _running: bool = false
var _time: float = 0.0
var _event_index: int = 0


func _ready() -> void:
	add_to_group(&"training_station")


func begin() -> void:
	_running = true
	_time = 0.0
	_event_index = 0
	EventBus.training_station_started.emit(station_id)


func _process(delta: float) -> void:
	if not _running:
		return
	_time += delta
	var next_at: float = duration * float(_event_index + 1) / float(events.size() + 1)
	if _event_index < events.size() and _time >= next_at:
		EventBus.training_event.emit(station_id, events[_event_index])
		_event_index += 1
	if _time >= duration:
		_running = false
		EventBus.training_station_completed.emit(station_id, result)
