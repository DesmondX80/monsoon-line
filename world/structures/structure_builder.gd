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


## Lisää kuperan prisman: [param profile] on kupera monikulmio (z, y) -tasossa, joka pursotetaan
## x-akselin suuntaan leveydelle [param width] keskikohdasta [param x_center]. Ramppeihin,
## kiilamuureihin ja porraslaattoihin: pelaajalla ei ole hyppyä eikä porrasnousua, joten
## kiivettävät pinnat tehdään enintään 45° kaltevina tasoina.
static func prism(body: StaticBody3D, profile: PackedVector2Array, x_center: float, width: float,
		mat: Material, collide: bool = true) -> MeshInstance3D:
	var hx: float = width * 0.5
	var n: int = profile.size()
	var centroid := Vector3.ZERO
	var left := PackedVector3Array()
	var right := PackedVector3Array()
	for p: Vector2 in profile:
		left.append(Vector3(x_center - hx, p.y, p.x))
		right.append(Vector3(x_center + hx, p.y, p.x))
		centroid += Vector3(x_center, p.y, p.x)
	centroid /= float(n)
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	# Päätykannet viuhkana (kupera monikulmio).
	for i: int in range(1, n - 1):
		_tri(verts, normals, left[0], left[i], left[i + 1], centroid)
		_tri(verts, normals, right[0], right[i], right[i + 1], centroid)
	# Sivutahkot.
	for i: int in n:
		var j: int = (i + 1) % n
		_tri(verts, normals, left[i], left[j], right[j], centroid)
		_tri(verts, normals, left[i], right[j], right[i], centroid)
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.set_meta(GENERATED_META, true)
	body.add_child(mi)
	if collide:
		var shape := ConvexPolygonShape3D.new()
		var points := PackedVector3Array(left)
		points.append_array(right)
		shape.points = points
		var cs := CollisionShape3D.new()
		cs.shape = shape
		cs.set_meta(GENERATED_META, true)
		body.add_child(cs)
	return mi


## Kolmio ulospäin osoittavalla normaalilla. Godotissa etupuoli on myötäpäivään katsottuna,
## joten järjestys käännetään tarvittaessa.
static func _tri(verts: PackedVector3Array, normals: PackedVector3Array, a: Vector3, b: Vector3,
		c: Vector3, centroid: Vector3) -> void:
	var n: Vector3 = (b - a).cross(c - a)
	if n.length_squared() < 0.0000001:
		return
	var center: Vector3 = (a + b + c) / 3.0
	var outward: Vector3 = n.normalized()
	if outward.dot(center - centroid) < 0.0:
		outward = -outward
	# Myötäpäiväinen järjestys ulkoa katsottuna: ristitulo osoittaa sisäänpäin.
	if n.dot(outward) > 0.0:
		verts.append_array([a, c, b])
	else:
		verts.append_array([a, b, c])
	normals.append_array([outward, outward, outward])
