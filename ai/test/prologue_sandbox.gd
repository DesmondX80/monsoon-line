extends Node3D
## Prologin hiekkalaatikko: Tibbs kävelee navigaatioverkolla asemalta toiselle oikean
## PrologueDirectorin ohjaamana; asemat ovat stubeja. Ajo headless-tilassa:
## godot --headless --path . res://ai/test/prologue_sandbox.tscn --quit-after 1500

@export var nav_region: NavigationRegion3D
@export var director: PrologueDirector

var _timer: float = 0.0


func _ready() -> void:
	Engine.time_scale = 4.0
	if nav_region:
		nav_region.bake_navigation_mesh(false)
	director.stage_changed.connect(_on_stage_changed)
	director.scene_change_requested.connect(_on_scene_change)
	EventBus.squad_callout.connect(_on_callout)
	EventBus.nickname_assigned.connect(_on_nickname)


func _on_stage_changed(stage: PrologueDirector.Stage) -> void:
	print("[prologue_sandbox] vaihe -> %s" % PrologueDirector.Stage.keys()[stage])


func _on_scene_change(path: String) -> void:
	print("[prologue_sandbox] scene-vaihto: %s, lempinimi %s" % [path, GameState.player_nickname])


func _on_callout(_speaker: Node3D, line_id: StringName) -> void:
	print("[prologue_sandbox] repliikki %s" % line_id)


func _on_nickname(nick: String) -> void:
	print("[prologue_sandbox] lempinimi %s" % nick)


func _physics_process(delta: float) -> void:
	_timer += delta
	if _timer < 1.0 or not is_instance_valid(director.tibbs):
		return
	_timer = 0.0
	var tibbs: DrillSergeant = director.tibbs as DrillSergeant
	if tibbs.is_walking():
		print("[prologue_sandbox] Tibbs kävelee %s" % tibbs.global_position.snapped(Vector3.ONE * 0.1))
