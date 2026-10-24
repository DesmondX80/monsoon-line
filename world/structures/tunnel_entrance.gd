@tool
class_name TunnelEntrance
extends StaticBody3D
## Tunnelin suu: kapea pystykuilu, jonka suulla on puukehys ja sivuun siirretty naamioitu luukku.
## Maaston pitää olla kaivettu kohdalta (JungleTerrain.pits). Ryhmä "tunnel_entrance" AI:ta varten.
## Pelaaja ei mahdu tunneliin (0,7 m aukko); se on toistaiseksi vihollisen ilmestymis- ja katoamispaikka.

@export var opening: float = 0.7
@export var shaft_depth: float = 1.0

const WOOD_COLOR: Color = Color(0.28, 0.21, 0.14)
const LID_COLOR: Color = Color(0.26, 0.24, 0.14)


func _ready() -> void:
	collision_layer = 1
	collision_mask = 0
	add_to_group(&"tunnel_entrance")
	build()


func build() -> void:
	StructureBuilder.clear(self)
	var wood := StructureBuilder.material(WOOD_COLOR)
	var dark := StructureBuilder.material(Color(0.02, 0.02, 0.015), 1.0)
	var h: float = opening * 0.5 + 0.06
	# Kehys maanpinnan tasolla
	for side: float in [-1.0, 1.0]:
		StructureBuilder.box(self, Vector3(opening + 0.24, 0.08, 0.12), Vector3(0.0, 0.0, side * h), wood)
		StructureBuilder.box(self, Vector3(0.12, 0.08, opening), Vector3(side * h, 0.0, 0.0), wood)
	# Kuilun pohja: musta "syvyys" ilman törmäystä.
	StructureBuilder.box(self, Vector3(opening, 0.02, opening), Vector3(0.0, -shaft_depth + 0.02, 0.0), dark,
			Basis.IDENTITY, false)
	# Naamioitu luukku sivussa (lehtiä punotun kannen päällä).
	StructureBuilder.box(self, Vector3(opening + 0.1, 0.06, opening + 0.1), Vector3(opening + 0.4, 0.03, 0.2),
			StructureBuilder.material(LID_COLOR), Basis(Vector3.UP, 0.3), false)
