extends Node3D
## C-130-hypyn hiekkalaatikko: oikea DropDirector, stub-laskuvarjo ja automaattinen hyppy.
## Ajo headless-tilassa: godot --headless --path . res://ai/test/drop_sandbox.tscn --quit-after 1500

@export var director: DropDirector
@export var player: Node3D

var _land_timer: float = -1.0


func _ready() -> void:
	Engine.time_scale = 4.0
	director.phase_changed.connect(_on_phase_changed)
	director.scene_change_requested.connect(_on_scene_change)
	EventBus.jumpmaster_command.connect(_on_command)
	EventBus.squad_callout.connect(_on_callout)
	EventBus.jump_started.connect(_on_jump_started)


func _physics_process(delta: float) -> void:
	if director.phase == DropDirector.Phase.READY_TO_JUMP:
		director.request_jump()
	if _land_timer >= 0.0:
		_land_timer -= delta
		if _land_timer < 0.0:
			EventBus.landed.emit(player, &"good")


func _on_phase_changed(phase: DropDirector.Phase) -> void:
	print("[drop_sandbox] vaihe -> %s" % DropDirector.Phase.keys()[phase])


func _on_command(command: StringName) -> void:
	print("[drop_sandbox] komento %s" % command)


func _on_callout(_speaker: Node3D, line_id: StringName) -> void:
	print("[drop_sandbox] repliikki %s" % line_id)


func _on_jump_started(jumper: Node3D) -> void:
	print("[drop_sandbox] hyppy %s, pelaaja ovella %s" % [jumper.name, player.global_position])
	if jumper == player:
		_land_timer = 3.0


func _on_scene_change(path: String) -> void:
	print("[drop_sandbox] scene-vaihto: %s" % path)
