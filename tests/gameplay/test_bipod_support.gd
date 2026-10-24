extends GutTest
## M1-03: kaksijalan tuki. Säännöt sekä tuen tunnistus oikealla fysiikkamaailmalla.

var data: WeaponData


func before_each() -> void:
	data = load("res://weapons/resources/m60.tres") as WeaponData


func _make_gun() -> MachineGun:
	var gun := MachineGun.new()
	gun.data = data
	add_child_autofree(gun)
	return gun


## Laatikko world-kerrokseen: keskipiste ja koko.
func _make_wall(center: Vector3, size: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	add_child_autofree(body)
	body.global_position = center
	return body


func test_prone_always_allows_bipod() -> void:
	assert_true(BipodSupport.can_deploy(true, true, false))


func test_crouch_without_rest_denies_bipod() -> void:
	assert_false(BipodSupport.can_deploy(true, false, false))


func test_crouch_with_rest_allows_bipod() -> void:
	assert_true(BipodSupport.can_deploy(true, false, true))


func test_weapon_without_bipod_never_deploys() -> void:
	assert_false(BipodSupport.can_deploy(false, true, true))


func test_rest_height_validation() -> void:
	assert_true(BipodSupport.is_rest_height_valid(1.0, 1.1))
	assert_false(BipodSupport.is_rest_height_valid(0.3, 1.1), "liian matala")
	assert_false(BipodSupport.is_rest_height_valid(1.4, 1.1), "piipun yläpuolella")


func test_machine_gun_deploy_rules() -> void:
	var gun := _make_gun()
	assert_false(gun.deploy_bipod(false, false))
	assert_true(gun.deploy_bipod(false, true))
	gun.retract_bipod()
	assert_false(gun.bipod_deployed)
	assert_true(gun.deploy_bipod(true, false))


func test_bipod_reduces_spread_by_data() -> void:
	var gun := _make_gun()
	var hip := gun.current_spread_deg()
	gun.deploy_bipod(true, false)
	assert_almost_eq(gun.current_spread_deg(), hip * data.supported_spread_multiplier, 0.0001)


func test_find_rest_detects_chest_high_wall() -> void:
	# Maavalli, jonka yläreuna on 1,0 m; piippu 1,1 m korkeudella, valli 0,5 m edessä.
	_make_wall(Vector3(0, 0.5, -0.8), Vector3(2, 1.0, 0.4))
	await wait_physics_frames(2)
	var space := get_tree().root.get_world_3d().direct_space_state
	var empty: Array[RID] = []
	assert_true(BipodSupport.find_rest(space, Vector3(0, 1.1, 0), Vector3.FORWARD, empty))


func test_find_rest_rejects_low_obstacle() -> void:
	_make_wall(Vector3(0, 0.15, -0.8), Vector3(2, 0.3, 0.4))
	await wait_physics_frames(2)
	var space := get_tree().root.get_world_3d().direct_space_state
	var empty: Array[RID] = []
	assert_false(BipodSupport.find_rest(space, Vector3(0, 1.1, 0), Vector3.FORWARD, empty))


func test_find_rest_rejects_open_ground() -> void:
	await wait_physics_frames(1)
	var space := get_tree().root.get_world_3d().direct_space_state
	var empty: Array[RID] = []
	assert_false(BipodSupport.find_rest(space, Vector3(0, 1.1, 0), Vector3.FORWARD, empty))
