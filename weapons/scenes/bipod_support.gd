class_name BipodSupport
extends RefCounted
## Kaksijalan tuen tunnistus. Makuulla kaksijalka lasketaan aina maahan; kyykyssä ja seisten
## tarvitaan piipun eteen rintakorkeudelle tukeva pinta (world-kerros), esim. maavalli tai kaatunut puu.

const WORLD_MASK := 1 << 0
## Kuinka kaukaa piipun edestä tukea etsitään (m, vaakasuunnassa).
const PROBE_DISTANCE := 0.9
## Kuinka paljon piipun alapuolelta eteenpäin suunnattu säde lähtee (m).
const PROBE_DROP := 0.12
## Tukipinnan yläreunan sallittu korkeus suhteessa piippuun: ei liian matalalla, ei piipun yläpuolella.
const MAX_REST_BELOW_MUZZLE := 0.45
const MAX_REST_ABOVE_MUZZLE := 0.05


## Sääntö: makuulla aina, muuten vain tuen kanssa. Ase ilman kaksijalkaa ei tue koskaan.
static func can_deploy(has_bipod: bool, prone: bool, has_rest: bool) -> bool:
	if not has_bipod:
		return false
	return prone or has_rest


## Onko tukipinnan yläreuna sopivalla korkeudella piippuun nähden.
static func is_rest_height_valid(rest_top_y: float, muzzle_y: float) -> bool:
	var diff := rest_top_y - muzzle_y
	return diff <= MAX_REST_ABOVE_MUZZLE and diff >= -MAX_REST_BELOW_MUZZLE


## Etsii tukevan pinnan piipun edestä. Ensin lyhyt säde eteenpäin hieman piipun alapuolelta;
## osuman kohdalta säde alaspäin etsii pinnan yläreunan, jonka on oltava sopivalla korkeudella.
static func find_rest(space: PhysicsDirectSpaceState3D, muzzle_position: Vector3, forward: Vector3, exclude: Array[RID]) -> bool:
	var flat := Vector3(forward.x, 0.0, forward.z)
	if flat.length_squared() < 0.0001:
		return false
	flat = flat.normalized()
	var start := muzzle_position - flat * 0.5 + Vector3.DOWN * PROBE_DROP
	var forward_query := PhysicsRayQueryParameters3D.create(start, start + flat * (PROBE_DISTANCE + 0.5), WORLD_MASK, exclude)
	var forward_hit := space.intersect_ray(forward_query)
	if forward_hit.is_empty():
		return false
	var hit_point: Vector3 = forward_hit.position
	var top_from := hit_point + flat * 0.08 + Vector3.UP * (MAX_REST_ABOVE_MUZZLE + PROBE_DROP + 0.1)
	var down_query := PhysicsRayQueryParameters3D.create(top_from, top_from + Vector3.DOWN * 1.0, WORLD_MASK, exclude)
	var down_hit := space.intersect_ray(down_query)
	if down_hit.is_empty():
		return false
	var top: Vector3 = down_hit.position
	return is_rest_height_valid(top.y, muzzle_position.y)
