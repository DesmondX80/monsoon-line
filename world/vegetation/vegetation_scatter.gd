@tool
class_name VegetationScatter
extends Node3D
## Uudelleenkäytettävä kasvillisuuden levittäjä (M1-10).
##
## Täyttää [member size]-kokoisen alueen (keskitetty solmun origoon) MultiMeshInstance3D-erillä:
## puunrungot, latvusto, pensaat ja ruoho. Alue jaetaan [member chunk_size]-kokoisiin lohkoihin,
## jotta näkymättömät lohkot karsitaan (frustum culling) ja visibility_range-LOD toimii lohkokohtaisesti.
##
## Deterministinen: sama [member scatter_seed] ja samat asetukset tuottavat aina saman metsän,
## koska jokainen lohko ja kasvityyppi saa oman, siemenestä johdetun satunnaislukugeneraattorin.
##
## Törmäykset:
## - rungot: StaticBody3D kerroksella 1 (world) – estävät liikkeen, luodit ja näkölinjan.
## - pensaat ja (valinnaisesti) korkea ruoho: StaticBody3D kerroksella 6 (vegetation) – estävät
##   AI:n näkösäteet, mutta eivät liikettä, koska pelaajan maski ei sisällä kerrosta 6.

enum Kind { TRUNK, CANOPY, BUSH, GRASS }

const LAYER_WORLD: int = 1
const LAYER_VEGETATION: int = 1 << 5

## Alueen koko metreinä (x, z), keskitettynä solmun origoon.
@export var size: Vector2 = Vector2(150.0, 150.0):
	set(value):
		size = value
		_queue_regenerate()
## Valinnainen maasto: instanssit asetetaan sen pinnalle eikä kaivantoihin (haudat, bunkkerikuopat).
@export var terrain: JungleTerrain:
	set(value):
		terrain = value
		_queue_regenerate()
## Siemen. Sama siemen tuottaa saman metsän.
@export var scatter_seed: int = 1967:
	set(value):
		scatter_seed = value
		_queue_regenerate()
## Lohkon sivun pituus metreinä. Pienempi = tarkempi LOD, enemmän draw calleja.
@export var chunk_size: float = 25.0:
	set(value):
		chunk_size = maxf(value, 5.0)
		_queue_regenerate()
## Aukiot, joilta kaikki kasvillisuus puuttuu: (x, z, säde) paikallisissa koordinaateissa.
@export var clearings: PackedVector3Array = PackedVector3Array():
	set(value):
		clearings = value
		_queue_regenerate()
## Aukiot, joilta vain aluskasvillisuus (pensaat ja ruoho) puuttuu – esim. bunkkerit latvuston alla.
@export var undergrowth_clearings: PackedVector3Array = PackedVector3Array():
	set(value):
		undergrowth_clearings = value
		_queue_regenerate()
## Jos > 0, kasvillisuus rajataan tämän säteen sisälle alueen keskipisteestä (esim. pyöreä heinäaukea).
@export var inclusion_radius: float = 0.0:
	set(value):
		inclusion_radius = value
		_queue_regenerate()
## Aukion reunan pehmennys metreinä: tiheys kasvaa lineaarisesti säteestä säde + feather.
@export var clearing_feather: float = 3.0

@export_group("Trees")
## Puita 100 m²:llä.
@export var tree_density: float = 1.6
@export var trunk_height_range: Vector2 = Vector2(12.0, 24.0)
@export var trunk_radius_range: Vector2 = Vector2(0.18, 0.55)
## Rungon LOD-etäisyys (0 = ei rajaa).
@export var trunk_visibility_end: float = 130.0
@export var trunk_color: Color = Color(0.32, 0.27, 0.21)
@export var canopy_color: Color = Color(0.13, 0.24, 0.10)

@export_group("Bushes")
## Pensaita 100 m²:llä.
@export var bush_density: float = 12.0
@export var bush_visibility_end: float = 70.0
@export var bush_color: Color = Color(0.20, 0.33, 0.13)
## Lisätäänkö pensaille näköä estävä törmäys kerrokselle 6.
@export var bush_blocks_sight: bool = true

@export_group("Grass")
## Ruohotuppoja neliömetrillä.
@export var grass_density: float = 0.25
@export var grass_height: float = 0.5
@export var grass_blades: int = 8
@export var grass_width: float = 0.06
@export var grass_visibility_end: float = 40.0
@export var grass_color: Color = Color(0.36, 0.45, 0.18)
## Korkea elefanttiheinä: lisää karkeat näköesteet (kerros 6) ruohoa sisältäviin soluihin.
@export var grass_blocks_sight: bool = false
## Näköesteen solukoko metreinä.
@export var grass_sight_cell: float = 4.0

## Viimeisimmän generoinnin instanssimäärät tyypeittäin.
var instance_counts: Dictionary = {}

var _regenerate_queued: bool = false


func _ready() -> void:
	regenerate()


## Poistaa vanhat erät ja rakentaa kasvillisuuden uudelleen.
func regenerate() -> void:
	_regenerate_queued = false
	for child: Node in get_children():
		if child.has_meta(&"vegetation_generated"):
			remove_child(child)
			child.queue_free()
	instance_counts = { Kind.TRUNK: 0, Kind.CANOPY: 0, Kind.BUSH: 0, Kind.GRASS: 0 }

	var grass_mesh: ArrayMesh = VegetationMeshes.blade_cluster(grass_blades, grass_height, grass_width,
			0.35, maxf(grass_height * 0.25, 0.1), scatter_seed)
	var meshes: Dictionary = {
		Kind.TRUNK: VegetationMeshes.trunk(),
		Kind.CANOPY: VegetationMeshes.canopy(),
		Kind.BUSH: VegetationMeshes.bush(),
		Kind.GRASS: grass_mesh,
	}
	var materials: Dictionary = {
		Kind.TRUNK: VegetationMeshes.material(trunk_color, false),
		Kind.CANOPY: VegetationMeshes.material(canopy_color, false),
		Kind.BUSH: VegetationMeshes.material(bush_color, false),
		Kind.GRASS: VegetationMeshes.material(grass_color, true),
	}

	var trunk_body := _make_body(&"TrunkColliders", LAYER_WORLD)
	var sight_body := _make_body(&"SightBlockers", LAYER_VEGETATION)
	var trunk_shapes: Dictionary = {}

	var chunks_x: int = ceili(size.x / chunk_size)
	var chunks_z: int = ceili(size.y / chunk_size)
	for cz: int in chunks_z:
		for cx: int in chunks_x:
			var origin := _chunk_origin(cx, cz)
			var trunks := chunk_transforms(Kind.TRUNK, cx, cz)
			var canopies := chunk_transforms(Kind.CANOPY, cx, cz)
			var bushes := chunk_transforms(Kind.BUSH, cx, cz)
			var grass := chunk_transforms(Kind.GRASS, cx, cz)
			_add_batch(Kind.TRUNK, cx, cz, origin, trunks, meshes, materials, trunk_visibility_end, true)
			_add_batch(Kind.CANOPY, cx, cz, origin, canopies, meshes, materials, 0.0, true)
			_add_batch(Kind.BUSH, cx, cz, origin, bushes, meshes, materials, bush_visibility_end, false)
			_add_batch(Kind.GRASS, cx, cz, origin, grass, meshes, materials, grass_visibility_end, false)
			for t: Transform3D in trunks:
				_add_trunk_shape(trunk_body, trunk_shapes, t)
			if bush_blocks_sight:
				for t: Transform3D in bushes:
					_add_bush_shape(sight_body, t)
			if grass_blocks_sight and not grass.is_empty():
				_add_grass_blockers(sight_body, grass)


## Palauttaa yhden lohkon instanssien muunnokset (solmun paikallisissa koordinaateissa).
## Puhdas funktio: sama siemen, lohko ja tyyppi → sama tulos.
func chunk_transforms(kind: Kind, cx: int, cz: int) -> Array[Transform3D]:
	var result: Array[Transform3D] = []
	if kind == Kind.CANOPY:
		# Latvusto johdetaan rungoista, jotta latvat ovat aina runkojen päällä.
		var rng_c := _rng(Kind.CANOPY, cx, cz)
		for trunk_t: Transform3D in chunk_transforms(Kind.TRUNK, cx, cz):
			var height: float = trunk_t.basis.y.length()
			var radius: float = trunk_t.basis.x.length()
			var blobs: int = 1 + int(radius > 0.3) + rng_c.randi_range(0, 1)
			for i: int in blobs:
				var spread: float = 1.5 + radius * 4.0
				var offset := Vector3(rng_c.randf_range(-spread, spread), 0.0, rng_c.randf_range(-spread, spread))
				var top := trunk_t.origin + Vector3(0.0, height * rng_c.randf_range(0.82, 1.0), 0.0) + offset
				var width: float = rng_c.randf_range(3.0, 4.5) + radius * 6.0
				var b := Basis(Vector3.UP, rng_c.randf() * TAU).scaled(Vector3(width, rng_c.randf_range(1.6, 3.0), width * rng_c.randf_range(0.7, 1.0)))
				result.append(Transform3D(b, top))
		return result

	var rng := _rng(kind, cx, cz)
	var origin := _chunk_origin(cx, cz)
	var half := Vector2(size.x, size.y) * 0.5
	var area: float = chunk_size * chunk_size
	var expected: float
	match kind:
		Kind.TRUNK: expected = tree_density * area / 100.0
		Kind.BUSH: expected = bush_density * area / 100.0
		_: expected = grass_density * area
	var count: int = int(expected)
	if rng.randf() < expected - float(count):
		count += 1
	for i: int in count:
		var local := Vector3(rng.randf_range(-0.5, 0.5) * chunk_size, 0.0, rng.randf_range(-0.5, 0.5) * chunk_size) + origin
		var keep_roll: float = rng.randf()
		var yaw: float = rng.randf() * TAU
		var s1: float = rng.randf()
		var s2: float = rng.randf()
		if absf(local.x) > half.x or absf(local.z) > half.y:
			continue
		if keep_roll > _density_factor(local, kind):
			continue
		var ground: float = 0.0
		if terrain != null:
			var tp: Vector3 = _to_terrain(local)
			if terrain.is_excavated(tp.x, tp.z, 0.6 if kind == Kind.GRASS else 1.2):
				continue
			ground = terrain.height_at(tp.x, tp.z)
		var b: Basis
		match kind:
			Kind.TRUNK:
				var r: float = lerpf(trunk_radius_range.x, trunk_radius_range.y, s1 * s1)
				var h: float = lerpf(trunk_height_range.x, trunk_height_range.y, s2) * (0.6 + r)
				b = Basis(Vector3.UP, yaw).scaled(Vector3(r, h, r))
				local.y = ground - 0.3
			Kind.BUSH:
				var w: float = lerpf(0.6, 1.6, s1)
				var hb: float = lerpf(0.6, 1.1, s2)
				b = Basis(Vector3.UP, yaw).scaled(Vector3(w, hb, w * lerpf(0.7, 1.0, s2)))
				local.y = ground + 0.35 * hb
			_:
				var g: float = lerpf(0.75, 1.25, s1)
				b = Basis(Vector3.UP, yaw).scaled(Vector3(g, lerpf(0.8, 1.2, s2), g))
				local.y = ground - 0.05
		result.append(Transform3D(b, local))
	return result


## Laskee kaikkien tyyppien instanssimäärät generoimatta solmuja (raportointiin ja testeihin).
func count_instances() -> Dictionary:
	var counts: Dictionary = { Kind.TRUNK: 0, Kind.CANOPY: 0, Kind.BUSH: 0, Kind.GRASS: 0 }
	for cz: int in ceili(size.y / chunk_size):
		for cx: int in ceili(size.x / chunk_size):
			for kind: Kind in counts.keys():
				counts[kind] += chunk_transforms(kind, cx, cz).size()
	return counts


## Muuntaa tämän solmun paikallisen pisteen maaston paikallisiin koordinaatteihin.
func _to_terrain(local: Vector3) -> Vector3:
	if is_inside_tree() and terrain.is_inside_tree():
		return terrain.global_transform.affine_inverse() * (global_transform * local)
	return local


func _chunk_origin(cx: int, cz: int) -> Vector3:
	return Vector3(-size.x * 0.5 + (cx + 0.5) * chunk_size, 0.0, -size.y * 0.5 + (cz + 0.5) * chunk_size)


func _rng(kind: Kind, cx: int, cz: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	# Kokonaislukuhajautus: ei riipu ajonaikaisista osoittimista, joten tulos on toistettava.
	var h: int = scatter_seed * 73856093
	h = (h ^ (cx * 19349663)) * 1099511628211
	h = (h ^ (cz * 83492791)) * 1099511628211
	h = h ^ (int(kind) * 2654435761)
	rng.seed = h
	return rng


## Tiheyskerroin 0..1 aukioiden perusteella.
func _density_factor(p: Vector3, kind: Kind) -> float:
	var factor: float = _clearing_factor(p, clearings)
	if inclusion_radius > 0.0:
		var r: float = Vector2(p.x, p.z).length()
		if r > inclusion_radius + clearing_feather:
			return 0.0
		if r > inclusion_radius and clearing_feather > 0.0:
			factor = minf(factor, 1.0 - (r - inclusion_radius) / clearing_feather)
	if kind == Kind.BUSH or kind == Kind.GRASS:
		factor = minf(factor, _clearing_factor(p, undergrowth_clearings))
	return factor


func _clearing_factor(p: Vector3, list: PackedVector3Array) -> float:
	var factor: float = 1.0
	for c: Vector3 in list:
		# c = (x, z, säde)
		var d: float = Vector2(p.x - c.x, p.z - c.y).length()
		if d < c.z:
			return 0.0
		if clearing_feather > 0.0 and d < c.z + clearing_feather:
			factor = minf(factor, (d - c.z) / clearing_feather)
	return factor


func _add_batch(kind: Kind, cx: int, cz: int, origin: Vector3, transforms: Array[Transform3D],
		meshes: Dictionary, materials: Dictionary, visibility_end: float, shadows: bool) -> void:
	if transforms.is_empty():
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = meshes[kind]
	mm.instance_count = transforms.size()
	var rng := _rng(kind, cx + 1000, cz + 1000)
	for i: int in transforms.size():
		var t: Transform3D = transforms[i]
		t.origin -= origin
		mm.set_instance_transform(i, t)
		var tint: float = rng.randf_range(0.8, 1.15)
		mm.set_instance_color(i, Color(tint * rng.randf_range(0.92, 1.05), tint, tint * rng.randf_range(0.9, 1.05)))
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "%s_%d_%d" % [Kind.keys()[kind].capitalize(), cx, cz]
	mmi.set_meta(&"vegetation_generated", true)
	mmi.multimesh = mm
	mmi.material_override = materials[kind]
	mmi.position = origin
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if visibility_end > 0.0:
		mmi.visibility_range_end = visibility_end
		mmi.visibility_range_end_margin = 4.0
	add_child(mmi)
	instance_counts[kind] += transforms.size()


func _make_body(body_name: StringName, layer: int) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = body_name
	body.set_meta(&"vegetation_generated", true)
	body.collision_layer = layer
	body.collision_mask = 0
	add_child(body)
	return body


func _add_trunk_shape(body: StaticBody3D, cache: Dictionary, t: Transform3D) -> void:
	# Säteet pyöristetään 5 cm:n tarkkuuteen, jolloin muotoja voidaan jakaa.
	var radius: float = snappedf(t.basis.x.length(), 0.05)
	var height: float = minf(t.basis.y.length(), 6.0)
	var key: Vector2i = Vector2i(int(radius * 100.0), int(height))
	if not cache.has(key):
		var shape := CylinderShape3D.new()
		shape.radius = radius
		shape.height = float(key.y)
		cache[key] = shape
	var cs := CollisionShape3D.new()
	cs.shape = cache[key]
	cs.position = t.origin + Vector3(0.0, float(key.y) * 0.5, 0.0)
	body.add_child(cs)


func _add_bush_shape(body: StaticBody3D, t: Transform3D) -> void:
	var shape := BoxShape3D.new()
	var sx: float = t.basis.x.length()
	var sy: float = t.basis.y.length()
	var sz: float = t.basis.z.length()
	shape.size = Vector3(sx * 1.4, sy * 1.2, sz * 1.4)
	var cs := CollisionShape3D.new()
	cs.shape = shape
	cs.transform = Transform3D(t.basis.orthonormalized(), t.origin + Vector3(0.0, sy * 0.25, 0.0))
	body.add_child(cs)


## Elefanttiheinä: yksi laatikko jokaiseen soluun, jossa on ruohoa.
func _add_grass_blockers(body: StaticBody3D, grass: Array[Transform3D]) -> void:
	var cells: Dictionary = {}
	var heights: Dictionary = {}
	for t: Transform3D in grass:
		var key := Vector2i(floori(t.origin.x / grass_sight_cell), floori(t.origin.z / grass_sight_cell))
		cells[key] = int(cells.get(key, 0)) + 1
		heights[key] = float(heights.get(key, 0.0)) + t.origin.y
	var min_per_cell: int = maxi(1, int(grass_density * grass_sight_cell * grass_sight_cell * 0.35))
	var shape := BoxShape3D.new()
	shape.size = Vector3(grass_sight_cell, grass_height * 0.85, grass_sight_cell)
	for key: Vector2i in cells.keys():
		if int(cells[key]) < min_per_cell:
			continue
		var cs := CollisionShape3D.new()
		cs.shape = shape
		var ground: float = float(heights[key]) / float(cells[key])
		cs.position = Vector3((key.x + 0.5) * grass_sight_cell, ground + grass_height * 0.425, (key.y + 0.5) * grass_sight_cell)
		body.add_child(cs)


func _queue_regenerate() -> void:
	if not is_inside_tree() or _regenerate_queued:
		return
	_regenerate_queued = true
	regenerate.call_deferred()
