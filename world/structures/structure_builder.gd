@tool
class_name StructureBuilder
extends RefCounted
## Apufunktiot proseduraalisille paikkamerkkirakenteille (bunkkerit, tuliasemat).
## Jokainen palikka saa sekä verkon että törmäysmuodon samaan StaticBody3D-vanhempaan.

const GENERATED_META: StringName = &"structure_generated"


## Poistaa aiemmin generoidut lapset (työkalutilan uudelleengenerointia varten).
static func clear(parent: Node) -> void:
	for child: Node in parent.get_children():
		if child.has_meta(GENERATED_META):
			parent.remove_child(child)
			child.queue_free()


## Lisää laatikon [param body]-solmuun. [param basis] valinnainen kierto.
static func box(body: StaticBody3D, box_size: Vector3, position: Vector3, mat: Material,
		basis: Basis = Basis.IDENTITY, collide: bool = true) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = box_size
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.transform = Transform3D(basis, position)
	mi.set_meta(GENERATED_META, true)
	body.add_child(mi)
	if collide:
		var shape := BoxShape3D.new()
		shape.size = box_size
		var cs := CollisionShape3D.new()
		cs.shape = shape
		cs.transform = mi.transform
		cs.set_meta(GENERATED_META, true)
		body.add_child(cs)
	return mi


## Lisää vaakasuoran tukin (sylinteri x-akselin suuntaan ennen kiertoa).
static func add_log(body: StaticBody3D, length: float, radius: float, position: Vector3, yaw: float,
		mat: Material, collide: bool = true) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius * 1.08
	mesh.height = length
	mesh.radial_segments = 10
	mesh.rings = 1
	var basis := Basis(Vector3.UP, yaw) * Basis(Vector3.FORWARD, PI * 0.5)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.transform = Transform3D(basis, position)
	mi.set_meta(GENERATED_META, true)
	body.add_child(mi)
	if collide:
		var shape := CylinderShape3D.new()
		shape.radius = radius
		shape.height = length
		var cs := CollisionShape3D.new()
		cs.shape = shape
		cs.transform = mi.transform
		cs.set_meta(GENERATED_META, true)
		body.add_child(cs)
	return mi


static func material(color: Color, roughness: float = 0.95) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = roughness
	mat.metallic_specular = 0.15
	return mat
