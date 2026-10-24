class_name PlayerLookup
extends RefCounted
## Apufunktiot pelaajan ja sen solmujen löytämiseen turvallisesti.
## Pelaajan koodi muuttuu rinnakkain, joten kaikki haut sietävät puuttuvat solmut.

const PLAYER_GROUP: StringName = &"player"
const HEALTH_PATH: NodePath = ^"HealthComponent"
const SUPPRESSION_PATH: NodePath = ^"SuppressionComponent"
const WEAPON_PATH: NodePath = ^"Head/MachineGun"


## Etsii pelaajan ryhmästä "player". Varalla nykyisen scenen "Player"-niminen solmu.
static func find_player(tree: SceneTree) -> Node:
	if tree == null:
		return null
	var player: Node = tree.get_first_node_in_group(PLAYER_GROUP)
	if player != null:
		return player
	var scene: Node = tree.current_scene
	if scene != null:
		return scene.find_child("Player", true, false)
	return null


## Parametrit ovat Variant-tyyppisiä, koska tyypitetty Node-parametri ei hyväksy
## vapautettua oliota (pelaaja voi kuolla ja poistua kesken ruudun).

static func get_health(player: Variant) -> Node:
	return (player as Node).get_node_or_null(HEALTH_PATH) if is_valid(player) else null


static func get_suppression(player: Variant) -> Node:
	return (player as Node).get_node_or_null(SUPPRESSION_PATH) if is_valid(player) else null


static func get_weapon(player: Variant) -> Node:
	return (player as Node).get_node_or_null(WEAPON_PATH) if is_valid(player) else null


## Onko arvo elossa oleva, puussa oleva solmu.
static func is_valid(node: Variant) -> bool:
	return is_instance_valid(node) and node is Node and (node as Node).is_inside_tree()


## Onko solmu pelaaja itse (signaalien suodatukseen).
static func is_player(node: Variant, player: Variant) -> bool:
	if not is_instance_valid(node) or not node is Node:
		return false
	if (node as Node).is_in_group(PLAYER_GROUP):
		return true
	return is_valid(player) and node == player


## Kuuluuko solmu (esim. ase) pelaajalle.
static func belongs_to_player(node: Variant, player: Variant) -> bool:
	if not is_instance_valid(node) or not node is Node or not is_valid(player):
		return false
	return node == player or (player as Node).is_ancestor_of(node as Node)


## Lukee ominaisuuden, jos se on olemassa, muuten palauttaa oletuksen.
static func read(node: Variant, property: StringName, fallback: Variant) -> Variant:
	if not is_instance_valid(node) or not node is Object:
		return fallback
	var obj: Object = node
	if property in obj:
		return obj.get(property)
	return fallback
