class_name StateMachine
extends Node
## Yksinkertainen tilakone. Lapsisolmut ovat State-solmuja.

@export var initial_state: State

var current: State


func _ready() -> void:
	for child in get_children():
		if child is State:
			child.machine = self
	if initial_state:
		transition_to(initial_state.name)


func _physics_process(delta: float) -> void:
	if current:
		current.physics_update(delta)


func transition_to(state_name: StringName) -> void:
	var next := get_node_or_null(NodePath(state_name)) as State
	if next == null:
		push_warning("Tuntematon tila: %s" % state_name)
		return
	if current:
		current.exit()
	current = next
	current.enter()
