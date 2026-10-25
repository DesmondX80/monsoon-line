class_name AmbushEnemy
extends Node3D
## Väijytyksen yksinkertainen, osuttava vihollisplaceholder (M3).
##
## Vihollisella on AmbushHitbox, kapselimainen visuaaliedustaja ja suora liike
## pelaajaa kohti. Hitbox on ballistiikan vaatimalla hitbox-layerillä (5), jotta
## Bullet osuu siihen ja kutsuu receive_hit-metodia.

signal enemy_died(enemy: AmbushEnemy)

const HITBOX_NAME := &"Hitbox"
const VISUAL_NAME := &"Visual"
## Sama layer kuin Ballistics.BULLET_COLLISION_MASKin hitbox-bitti.
const HITBOX_COLLISION_LAYER := 1 << 4

@export var max_health: float = 3.0
@export var move_speed: float = 2.5
@export var fire_interval: float = 2.5
@export var fire_range: float = 25.0
@export var stop_distance: float = 8.0
@export var hitbox_radius: float = 0.55
@export var fire_line: StringName = &"enemy_fire"

var health: float = 0.0
var alive: bool = true

var _fire_timer: float = 0.0
var _hitbox: AmbushHitbox
var _visual: MeshInstance3D


func _ready() -> void:
	health = max_health
	_fire_timer = fire_interval
	_build_visual()
	_build_hitbox()
	EventBus.actor_hit.connect(_on_actor_hit)


func _physics_process(delta: float) -> void:
	if not alive:
		return
	_move_toward_player(delta)
	_try_fire(delta)


## Liikkuu pelaajaa kohti, kunnes on stop_distance-etäisyydellä.
func _move_toward_player(delta: float) -> void:
	var player := get_tree().get_first_node_in_group(&"player") as Node3D
	if player == null:
		return
	var to_player: Vector3 = player.global_position - global_position
	to_player.y = 0.0
	var distance: float = to_player.length()
	if distance <= stop_distance:
		return
	var direction: Vector3 = to_player.normalized()
	global_position += direction * move_speed * delta
	look_at(Vector3(player.global_position.x, global_position.y, player.global_position.z), Vector3.UP)


## Lähettää ampumisrepliikin, jos pelaaja on kantamalla.
func _try_fire(delta: float) -> void:
	_fire_timer -= delta
	if _fire_timer > 0.0:
		return
	_fire_timer = fire_interval
	var player := get_tree().get_first_node_in_group(&"player") as Node3D
	if player == null:
		return
	if global_position.distance_to(player.global_position) <= fire_range:
		EventBus.squad_callout.emit(self, fire_line)


## Vähentää vihollisen terveyttä ja lähettää kuolin-signaalin, jos se kuolee.
func take_hit(damage: float) -> void:
	if not alive:
		return
	health -= damage
	if health <= 0.0:
		alive = false
		EventBus.actor_died.emit(self)
		enemy_died.emit(self)
		queue_free()


func _on_actor_hit(target: Node3D, damage: float, _body_part: StringName) -> void:
	if target == self or target == _hitbox:
		take_hit(damage)


## Rakentaa yksinkertaisen kapselivisuaalin, jotta vihollisen näkee pelissä.
func _build_visual() -> void:
	_visual = MeshInstance3D.new()
	_visual.name = VISUAL_NAME
	var mesh := CapsuleMesh.new()
	mesh.radius = hitbox_radius
	mesh.height = 1.7
	_visual.mesh = mesh
	_visual.position = Vector3(0.0, 0.85, 0.0)
	add_child(_visual)


## Rakentaa ballistiikan vaatiman Hitbox-osuma-alueen layerille 5.
func _build_hitbox() -> void:
	_hitbox = AmbushHitbox.new()
	_hitbox.name = HITBOX_NAME
	_hitbox.enemy = self
	_hitbox.collision_layer = HITBOX_COLLISION_LAYER
	_hitbox.collision_mask = 0
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = hitbox_radius
	shape.shape = sphere
	shape.position = Vector3(0.0, 0.85, 0.0)
	_hitbox.add_child(shape)
	add_child(_hitbox)
