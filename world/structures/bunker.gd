@tool
class_name Bunker
extends StaticBody3D
## Viet Congin hirsibunkkeri (kerros 1, world).
##
## Rakennetaan maahan kaivettuun kuoppaan: lattia on [member floor_depth] maanpinnan alapuolella.
## Seinät nousevat hieman maanpinnan yläpuolelle, ja niiden päällä on hirsikatto ja maakumpu.
## Etuseinässä (paikallinen +Z) on matala ampuma-aukko, takaseinässä (−Z) oviaukko juoksuhautaan.
## Origo on maanpinnan tasolla huoneen keskellä.
##
## Maaston kuoppa kaivetaan JungleTerrain.pits-listalla; ks. [method terrain_pit].

## Sisämitat (x, z) metreinä.
@export var interior: Vector2 = Vector2(2.8, 2.6)
@export var floor_depth: float = 1.0
## Seinän yläreuna maanpinnasta. Sisäkorkeus = floor_depth + wall_top.
@export var wall_top: float = 0.6
@export var wall_thickness: float = 0.3
## Ampuma-aukon alareuna ja korkeus maanpinnasta.
@export var slit_bottom: float = 0.15
@export var slit_height: float = 0.3
@export var slit_width: float = 1.8
@export var door_width: float = 0.9

const LOG_COLOR: Color = Color(0.30, 0.23, 0.16)
const EARTH_COLOR: Color = Color(0.29, 0.22, 0.14)


func _ready() -> void:
	collision_layer = 1
	collision_mask = 0
	build()


func build() -> void:
	StructureBuilder.clear(self)
	var wood := StructureBuilder.material(LOG_COLOR)
	var earth := StructureBuilder.material(EARTH_COLOR, 1.0)
	var hx: float = interior.x * 0.5 + wall_thickness * 0.5
	var hz: float = interior.y * 0.5 + wall_thickness * 0.5
	var outer_x: float = interior.x + wall_thickness * 2.0
	var bottom: float = -floor_depth
	var full_h: float = floor_depth + wall_top
	var mid_y: float = bottom + full_h * 0.5

	# Sivuseinät
	for side: float in [-1.0, 1.0]:
		StructureBuilder.box(self, Vector3(wall_thickness, full_h, interior.y + wall_thickness * 2.0),
				Vector3(side * hx, mid_y, 0.0), wood)

	# Etuseinä ampuma-aukolla: alaosa, yläosa ja aukon sivupalat.
	var below_h: float = slit_bottom - bottom
	StructureBuilder.box(self, Vector3(outer_x, below_h, wall_thickness),
			Vector3(0.0, bottom + below_h * 0.5, hz), wood)
	var slit_top: float = slit_bottom + slit_height
	var above_h: float = wall_top - slit_top
	if above_h > 0.01:
		StructureBuilder.box(self, Vector3(outer_x, above_h, wall_thickness),
				Vector3(0.0, slit_top + above_h * 0.5, hz), wood)
	var side_w: float = (outer_x - slit_width) * 0.5
	for side: float in [-1.0, 1.0]:
		StructureBuilder.box(self, Vector3(side_w, slit_height, wall_thickness),
				Vector3(side * (slit_width * 0.5 + side_w * 0.5), slit_bottom + slit_height * 0.5, hz), wood)

	# Takaseinä oviaukolla
	var rear_w: float = (outer_x - door_width) * 0.5
	for side: float in [-1.0, 1.0]:
		StructureBuilder.box(self, Vector3(rear_w, full_h, wall_thickness),
				Vector3(side * (door_width * 0.5 + rear_w * 0.5), mid_y, -hz), wood)

	# Hirsikatto ja maakumpu. Kumpu ulottuu ampuma-aukon yli suojaksi, mutta jättää aukon auki.
	var roof_size := Vector3(outer_x + 0.4, 0.25, interior.y + wall_thickness * 2.0 + 0.4)
	StructureBuilder.box(self, roof_size, Vector3(0.0, wall_top + 0.125, 0.0), wood)
	StructureBuilder.box(self, Vector3(roof_size.x + 0.6, 0.45, roof_size.z + 0.3),
			Vector3(0.0, wall_top + 0.25 + 0.225, -0.1), earth)
	StructureBuilder.box(self, Vector3(roof_size.x - 0.4, 0.3, roof_size.z - 0.6),
			Vector3(0.0, wall_top + 0.7 + 0.15, -0.1), earth)
	# Matala maavalli aukon edessä naamioi bunkkerin (ei peitä aukkoa).
	StructureBuilder.box(self, Vector3(outer_x + 0.8, slit_bottom, 0.8),
			Vector3(0.0, slit_bottom * 0.5, hz + wall_thickness * 0.5 + 0.4), earth)


## Kuoppa, joka maastoon pitää kaivaa tälle bunkkerille: (keski_x, keski_z, puoli_x, puoli_z)
## maailmankoordinaateissa olettaen, ettei bunkkeria ole kierretty. Kuoppa jatkuu taakse
## [param rear_extension] metriä juoksuhautaan asti.
static func terrain_pit(center: Vector3, interior_size: Vector2, thickness: float, rear_extension: float) -> Vector4:
	var half_x: float = interior_size.x * 0.5 + thickness * 0.5
	var front: float = interior_size.y * 0.5 + thickness
	var back: float = interior_size.y * 0.5 + rear_extension
	return Vector4(center.x, center.z + (front - back) * 0.5, half_x, (front + back) * 0.5)
