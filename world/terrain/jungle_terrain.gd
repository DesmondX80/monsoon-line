@tool
class_name JungleTerrain
extends StaticBody3D
## Proseduraalinen viidakkomaasto (kerros 1, world).
##
## Korkeus = loiva kohina, joka tasoitetaan [member flatten_zones]-alueilla, miinus kaivetut muodot:
## juoksuhauta ([member trench_path]) ja kuopat ([member pits], esim. bunkkerien lattiat).
## [method height_at] on puhdas funktio, joten kasvillisuus ja muut järjestelmät voivat kysyä
## maanpinnan korkeuden ilman, että maasto on vielä generoitu.
##
## Törmäys on HeightMapShape3D, verkko samasta ruudukosta. Ruudukon tiheys [member resolution].

## Maaston koko metreinä (x, z), keskitettynä origoon.
@export var size: Vector2 = Vector2(160.0, 160.0)
## Näytteitä metrillä. 2 = 0,5 m:n ruudukko (riittää 1–2 m leveään juoksuhautaan).
@export_range(1, 4) var resolution: int = 2
@export var noise_seed: int = 1967
## Kohinan amplitudi metreinä (huippu–pohja noin kaksinkertainen).
@export var noise_amplitude: float = 0.35
@export var noise_frequency: float = 0.025
## Tasoitettavat alueet: (x, z, säde). Reunalla 4 m:n pehmennys.
@export var flatten_zones: PackedVector3Array = PackedVector3Array()

@export_group("Excavations")
## Juoksuhaudan keskilinja (x, z).
@export var trench_path: PackedVector2Array = PackedVector2Array()
@export var trench_width: float = 1.8
@export var trench_depth: float = 1.0
## Ramppien pituus haudan kummassakin päässä (syvyys nousee nollaan).
@export var trench_ramp_length: float = 3.0
## Suorakulmaiset kuopat: (keski_x, keski_z, puoli_x, puoli_z). Syvyys [member pit_depth].
@export var pits: PackedVector4Array = PackedVector4Array()
@export var pit_depth: float = 1.0

@export_group("Look")
@export var ground_color: Color = Color(0.27, 0.22, 0.15)
@export var moss_color: Color = Color(0.20, 0.25, 0.12)
@export var mud_color: Color = Color(0.22, 0.16, 0.10)

var _noise: FastNoiseLite
var _trench_length: float = 0.0


func _ready() -> void:
	generate()


## Rakentaa törmäysmuodon ja verkon uudelleen.
func generate() -> void:
	for child: Node in get_children():
		if child.has_meta(&"terrain_generated"):
			remove_child(child)
			child.queue_free()
	_prepare()
	var step: float = 1.0 / float(resolution)
	var nx: int = int(size.x * resolution) + 1
	var nz: int = int(size.y * resolution) + 1
	var heights := PackedFloat32Array()
	heights.resize(nx * nz)
	for iz: int in nz:
		var z: float = -size.y * 0.5 + iz * step
		for ix: int in nx:
			heights[iz * nx + ix] = height_at(-size.x * 0.5 + ix * step, z)

	# Törmäys: HeightMapShape3D:n näytteet ovat 1 m välein, joten skaalataan tasaisesti 1/resolution
	# ja kerrotaan korkeudet vastaavasti.
	var shape := HeightMapShape3D.new()
	shape.map_width = nx
	shape.map_depth = nz
	var scaled := heights.duplicate()
	for i: int in scaled.size():
		scaled[i] *= float(resolution)
	shape.map_data = scaled
	var cs := CollisionShape3D.new()
	cs.name = "Collision"
	cs.set_meta(&"terrain_generated", true)
	cs.shape = shape
	cs.scale = Vector3.ONE * step
	add_child(cs)

	var mi := MeshInstance3D.new()
	mi.name = "Mesh"
	mi.set_meta(&"terrain_generated", true)
	mi.mesh = _build_mesh(heights, nx, nz, step)
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 1.0
	mat.metallic_specular = 0.1
	mi.material_override = mat
	add_child(mi)


## Maanpinnan korkeus pisteessä (x, z) solmun paikallisissa koordinaateissa.
func height_at(x: float, z: float) -> float:
	if _noise == null:
		_prepare()
	var p := Vector2(x, z)
	var h: float = _noise.get_noise_2d(x, z) * noise_amplitude
	# Tasoitus
	for f: Vector3 in flatten_zones:
		var d: float = p.distance_to(Vector2(f.x, f.y))
		if d < f.z + 4.0:
			h *= clampf((d - f.z) / 4.0, 0.0, 1.0)
	var cut: float = 0.0
	# Kuopat
	for r: Vector4 in pits:
		if absf(x - r.x) <= r.z and absf(z - r.y) <= r.w:
			cut = maxf(cut, pit_depth)
	# Juoksuhauta
	if trench_path.size() >= 2:
		var info: Vector2 = _trench_distance(p)
		if info.x <= trench_width * 0.5:
			var s: float = info.y
			var ramp: float = 1.0
			if trench_ramp_length > 0.0:
				ramp = clampf(minf(s, _trench_length - s) / trench_ramp_length, 0.0, 1.0)
			cut = maxf(cut, trench_depth * ramp)
	if cut > 0.0:
		# Kaivannon pohja on tasainen, kohina ei vaikuta.
		return -cut
	return h


## Onko piste kaivannossa (haudassa tai kuopassa)? Kasvillisuus käyttää tätä välttääkseen kaivantoja.
func is_excavated(x: float, z: float, margin: float = 0.0) -> bool:
	if _noise == null:
		_prepare()
	for r: Vector4 in pits:
		if absf(x - r.x) <= r.z + margin and absf(z - r.y) <= r.w + margin:
			return true
	if trench_path.size() >= 2:
		return _trench_distance(Vector2(x, z)).x <= trench_width * 0.5 + margin
	return false


func _prepare() -> void:
	_noise = FastNoiseLite.new()
	_noise.seed = noise_seed
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_noise.frequency = noise_frequency
	_noise.fractal_octaves = 3
	_trench_length = 0.0
	for i: int in range(1, trench_path.size()):
		_trench_length += trench_path[i - 1].distance_to(trench_path[i])


## Palauttaa (etäisyys keskilinjaan, kaarenpituus lähimpään pisteeseen).
func _trench_distance(p: Vector2) -> Vector2:
	var best: float = INF
	var best_s: float = 0.0
	var acc: float = 0.0
	for i: int in range(1, trench_path.size()):
		var a: Vector2 = trench_path[i - 1]
		var b: Vector2 = trench_path[i]
		var ab: Vector2 = b - a
		var len_sq: float = ab.length_squared()
		var t: float = clampf((p - a).dot(ab) / len_sq, 0.0, 1.0) if len_sq > 0.0 else 0.0
		var d: float = p.distance_to(a + ab * t)
		if d < best:
			best = d
			best_s = acc + sqrt(len_sq) * t
		acc += sqrt(len_sq)
	return Vector2(best, best_s)


func _build_mesh(heights: PackedFloat32Array, nx: int, nz: int, step: float) -> ArrayMesh:
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	verts.resize(nx * nz)
	normals.resize(nx * nz)
	colors.resize(nx * nz)
	for iz: int in nz:
		for ix: int in nx:
			var i: int = iz * nx + ix
			var h: float = heights[i]
			verts[i] = Vector3(-size.x * 0.5 + ix * step, h, -size.y * 0.5 + iz * step)
			var hl: float = heights[iz * nx + maxi(ix - 1, 0)]
			var hr: float = heights[iz * nx + mini(ix + 1, nx - 1)]
			var hd: float = heights[maxi(iz - 1, 0) * nx + ix]
			var hu: float = heights[mini(iz + 1, nz - 1) * nx + ix]
			normals[i] = Vector3(hl - hr, 2.0 * step, hd - hu).normalized()
			var moss: float = clampf(_noise.get_noise_2d(verts[i].x * 4.0, verts[i].z * 4.0) * 0.5 + 0.5, 0.0, 1.0)
			var c: Color = ground_color.lerp(moss_color, moss * 0.7)
			if h < -0.05:
				c = mud_color.lerp(c, 0.2)
			colors[i] = c
	indices.resize((nx - 1) * (nz - 1) * 6)
	var k: int = 0
	for iz: int in nz - 1:
		for ix: int in nx - 1:
			var a: int = iz * nx + ix
			var b: int = a + 1
			var c2: int = a + nx
			var d: int = c2 + 1
			indices[k] = a
			indices[k + 1] = b
			indices[k + 2] = c2
			indices[k + 3] = b
			indices[k + 4] = d
			indices[k + 5] = c2
			k += 6
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh
