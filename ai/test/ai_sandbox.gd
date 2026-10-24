extends Node3D
## AI-hiekkalaatikko: leipoo navigaatioverkon käynnistyksessä ja raportoi vihollisten tilan.
## Ajo headless-tilassa: godot --headless res://ai/test/ai_sandbox.tscn --quit-after 300

@export var nav_region: NavigationRegion3D
@export var report_interval: float = 2.0

var _start_positions: Dictionary = {}  ## EnemyController -> Vector3
var _last_states: Dictionary = {}  ## EnemyController -> StringName
var _timer: float = 0.0


func _ready() -> void:
	if nav_region:
		nav_region.bake_navigation_mesh(false)
	# Pelaaja-ryhmä lisätään puolustavasti, jos pelaajakohtaus ei sitä vielä tee.
	var player := get_node_or_null("Player") as Node3D
	if player and not player.is_in_group(&"player"):
		player.add_to_group(&"player")
	for enemy in _enemies():
		_start_positions[enemy] = enemy.global_position


func _physics_process(delta: float) -> void:
	for enemy in _enemies():
		var state: StringName = enemy.state_machine.current.name if enemy.state_machine.current else &""
		if _last_states.get(enemy, &"") != state:
			print("[ai_sandbox] %s -> %s" % [enemy.name, state])
			_last_states[enemy] = state
	_timer += delta
	if _timer < report_interval:
		return
	_timer = 0.0
	for enemy in _enemies():
		var start: Vector3 = _start_positions.get(enemy, enemy.global_position)
		print("[ai_sandbox] %s siirtynyt %.1f m, havainto %.2f" % [
			enemy.name, start.distance_to(enemy.global_position), enemy.perception.awareness])


func _enemies() -> Array[EnemyController]:
	var result: Array[EnemyController] = []
	for node: Node in get_tree().get_nodes_in_group(&"enemy"):
		if node is EnemyController:
			result.append(node as EnemyController)
	return result
