@tool
class_name VegetationMeshes
extends RefCounted
## Proseduraaliset paikkamerkkiverkot ja -materiaalit kasvillisuudelle.
## Kaikki verkot ovat kevyitä (muutama kymmenen kolmiota), jotta MultiMesh-erät pysyvät halpoina.


## Rakentaa ruohotupon: [param blade_count] kapeaa, kartioituvaa korsikolmiota satunnaisella kallistuksella.
## Normaalit osoittavat ylöspäin, jolloin kaksipuoliset korret valaistuvat tasaisesti.
static func blade_cluster(blade_count: int, height: float, width: float, lean: float, spread: float, mesh_seed: int) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = mesh_seed
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	for i: int in blade_count:
		var angle: float = rng.randf() * TAU
		var base := Vector3(cos(angle), 0.0, sin(angle)) * rng.randf() * spread
		var side := Vector3(-sin(angle), 0.0, cos(angle)) * width * rng.randf_range(0.7, 1.3) * 0.5
		var tip_height: float = height * rng.randf_range(0.65, 1.0)
		var tip := base + Vector3(cos(angle), 0.0, sin(angle)) * lean * tip_height * rng.randf_range(0.3, 1.0)
		tip.y = tip_height
		vertices.append_array([base - side, base + side, tip])
		normals.append_array([Vector3.UP, Vector3.UP, Vector3.UP])
		# Tyvi tummempi, kärki vaaleampi: halpa "ambient occlusion".
		colors.append_array([Color(0.45, 0.45, 0.45), Color(0.45, 0.45, 0.45), Color(1, 1, 1)])
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


## Matala pallo pensaalle (säde 1, korkeus 1.4 ennen skaalausta).
static func bush() -> Mesh:
	var mesh := SphereMesh.new()
	mesh.radius = 1.0
	mesh.height = 1.4
	mesh.radial_segments = 8
	mesh.rings = 4
	return mesh


## Puunrunko: kapeneva sylinteri, tyvi origossa. Korkeus 1, säde 1 – skaalataan instanssikohtaisesti.
static func trunk() -> Mesh:
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.7
	mesh.bottom_radius = 1.0
	mesh.height = 1.0
	mesh.radial_segments = 7
	mesh.rings = 1
	mesh.cap_top = false
	mesh.cap_bottom = false
	# Siirretään tyvi origoon, jotta instanssin skaalaus y-suunnassa kasvattaa runkoa ylöspäin.
	var arrays: Array = mesh.get_mesh_arrays()
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	for i: int in verts.size():
		verts[i].y += 0.5
	arrays[Mesh.ARRAY_VERTEX] = verts
	var out := ArrayMesh.new()
	out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return out


## Latvusmöhkäle: litistetty pallo.
static func canopy() -> Mesh:
	var mesh := SphereMesh.new()
	mesh.radius = 1.0
	mesh.height = 1.0
	mesh.radial_segments = 10
	mesh.rings = 5
	return mesh


## Kasvillisuusmateriaali, joka käyttää MultiMeshin instanssiväriä värivaihteluun.
static func material(base: Color, double_sided: bool) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = base
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.95
	mat.metallic_specular = 0.2
	if double_sided:
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return mat
