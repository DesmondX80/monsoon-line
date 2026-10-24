extends Node3D
## Testien vale-hyppyvalo.

var green: bool = false


func _ready() -> void:
	add_to_group(&"jump_light")


func set_green() -> void:
	green = true


func set_red() -> void:
	green = false
