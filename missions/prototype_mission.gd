class_name PrototypeMission
extends Node
## M1-prototyypin tehtävä (M1-19): kokoaa tasolle viholliset ja HUDin ja seuraa tavoitetta.
## Tavoite: tuhoa bunkkerikompleksin Viet Cong -puolustajat. Pelaajan kuollessa taso alkaa alusta.

const ENEMY_SCENE: PackedScene = preload("res://ai/enemy/enemy.tscn")
const HUD_SCENE: PackedScene = preload("res://ui/hud.tscn")
const MAIN_MENU := "res://ui/main_menu.tscn"
const RESTART_DELAY := 5.0
const RETURN_TO_MENU_DELAY := 8.0

## Kuinka monta vihollista tasolle syntyy (enintään spawn-merkkien määrä).
@export var enemy_count: int = 8

var _enemies_alive: int = 0
var _finished: bool = false
var _hud: Hud


func _ready() -> void:
	_hud = HUD_SCENE.instantiate() as Hud
	add_child(_hud)
	EventBus.actor_died.connect(_on_actor_died)
	var level := get_parent()
	if level.has_signal(&"navigation_ready"):
		level.connect(&"navigation_ready", _spawn_enemies, CONNECT_ONE_SHOT)
	else:
		_spawn_enemies.call_deferred()
	_show_briefing.call_deferred()


func _show_briefing() -> void:
	if _hud:
		_hud.show_subtitle("Ryhmänjohtaja", "Bunkkerit pohjoisessa. Asetu konekiväärillä tuliasemaan ja pidä ne maassa.")


func _spawn_enemies() -> void:
	var markers := get_tree().get_nodes_in_group(&"enemy_spawn")
	var level := get_parent()
	for i in mini(enemy_count, markers.size()):
		var marker := markers[i] as Node3D
		var enemy := ENEMY_SCENE.instantiate() as Node3D
		level.add_child(enemy)
		enemy.global_transform = marker.global_transform
		_enemies_alive += 1
	EventBus.mission_objective_updated.emit(&"clear_bunkers", &"active")


func _on_actor_died(actor: Node3D) -> void:
	if _finished or actor == null:
		return
	if actor.is_in_group(&"player"):
		_finish(false)
	elif actor.is_in_group(&"enemy"):
		_enemies_alive -= 1
		if _enemies_alive <= 0:
			_finish(true)


func _finish(success: bool) -> void:
	_finished = true
	EventBus.mission_objective_updated.emit(&"clear_bunkers", &"completed" if success else &"failed")
	if success:
		if _hud:
			_hud.show_subtitle("Ryhmänjohtaja", "Bunkkerit tyhjät. Hyvää työtä, konekivääri. Tehtävä suoritettu.")
		await get_tree().create_timer(RETURN_TO_MENU_DELAY).timeout
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		get_tree().change_scene_to_file(MAIN_MENU)
	else:
		if _hud:
			_hud.show_subtitle("", "Kaaduit. Tehtävä alkaa alusta.")
		await get_tree().create_timer(RESTART_DELAY).timeout
		get_tree().reload_current_scene()
