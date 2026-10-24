extends Node3D
## Testien valeasema: training_station-ryhmässä, station_id ja begin() kuten sopimuksessa.

@export var station_id: StringName = &""

var begin_calls: int = 0


func _ready() -> void:
	add_to_group(&"training_station")


func begin() -> void:
	begin_calls += 1
	EventBus.training_station_started.emit(station_id)
