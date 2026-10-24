class_name DrillSergeantState
extends State
## Kersantti Tibbsin tilojen yhteinen kanta. Viittaus hahmoon haetaan scenen omistajasta.

var sergeant: DrillSergeant


func _ready() -> void:
	sergeant = owner as DrillSergeant
