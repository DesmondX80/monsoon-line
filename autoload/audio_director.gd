extends Node
## Viidakon ambienssi, sotilaiden repliikit ja tukahdutusäänet.
## TODO(audio-agentti): ambienssi joka hiljenee, kun joku liikkuu lähellä.

func _ready() -> void:
	EventBus.bullet_snap.connect(_on_bullet_snap)
	EventBus.squad_callout.connect(_on_squad_callout)


func _on_bullet_snap(_listener: Node3D, _distance: float) -> void:
	pass


func _on_squad_callout(_speaker: Node3D, _line_id: StringName) -> void:
	pass
