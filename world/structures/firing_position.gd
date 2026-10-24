@tool
class_name FiringPosition
extends StaticBody3D
## Konekivääriasema (kerros 1, world): kaatunut puu tai maavalli, jonka yläreuna on 0,6–0,9 m
## maanpinnasta, jotta M60:n kaksijalan tukisäde osuu siihen.
##
## Suojan etupuoli on paikallinen −Z (ampumasuunta). Ampuja asettuu origon taakse (+Z).
## Solmu lisää itsensä ryhmään "firing_position"; [member gunner_marker] kertoo ampujan paikan.

enum Kind { FALLEN_LOG, EARTH_BERM }

@export var kind: Kind = Kind.FALLEN_LOG:
	set(value):
		kind = value
		if is_inside_tree():
			build()
## Suojan yläreunan korkeus maanpinnasta (0,6–0,9 m).
@export_range(0.6, 0.9, 0.01) var cover_height: float = 0.75:
	set(value):
		cover_height = value
		if is_inside_tree():
			build()
@export var length: float = 4.0

const WOOD_COLOR: Color = Color(0.33, 0.26, 0.19)
const EARTH_COLOR: Color = Color(0.31, 0.24, 0.15)

## Ampujan paikka (paikallinen), suojan takana.
var gunner_marker: Vector3 = Vector3(0.0, 0.0, 0.9)


func _ready() -> void:
	collision_layer = 1
	collision_mask = 0
	add_to_group(&"firing_position")
	build()


func build() -> void:
	StructureBuilder.clear(self)
	match kind:
		Kind.FALLEN_LOG:
			_build_log()
		Kind.EARTH_BERM:
			_build_berm()


## Ampujan sijainti maailmankoordinaateissa.
func gunner_position() -> Vector3:
	return global_transform * gunner_marker


func _build_log() -> void:
	var wood := StructureBuilder.material(WOOD_COLOR)
	var radius: float = cover_height * 0.5
	# Runko on hieman upoksissa maahan, jotta se ei vieri silmissä; yläreuna = cover_height.
	StructureBuilder.add_log(self, length, radius, Vector3(0.0, cover_height - radius, 0.0), 0.0, wood)
	# Juurakko ja katkenneet oksat: visuaalisia, juurakolla törmäys.
	StructureBuilder.box(self, Vector3(0.5, cover_height * 1.6, cover_height * 1.6),
			Vector3(length * 0.5 + 0.2, cover_height * 0.7, 0.0), wood, Basis(Vector3.RIGHT, 0.4))
	StructureBuilder.add_log(self, 1.2, 0.06, Vector3(-length * 0.3, cover_height * 0.9, -0.4), 0.9, wood, false)
	StructureBuilder.add_log(self, 0.9, 0.05, Vector3(length * 0.15, cover_height * 0.95, -0.35), -0.7, wood, false)


func _build_berm() -> void:
	var earth := StructureBuilder.material(EARTH_COLOR, 1.0)
	# Tasainen harja tuelle ja porrastettu etuluiska.
	StructureBuilder.box(self, Vector3(length, cover_height, 0.9), Vector3(0.0, cover_height * 0.5, 0.0), earth)
	StructureBuilder.box(self, Vector3(length + 0.4, cover_height * 0.6, 0.8),
			Vector3(0.0, cover_height * 0.3, -0.75), earth)
	StructureBuilder.box(self, Vector3(length + 0.8, cover_height * 0.25, 0.7),
			Vector3(0.0, cover_height * 0.125, -1.4), earth)
	# Sivuvallit suojaavat sivustoja.
	for side: float in [-1.0, 1.0]:
		StructureBuilder.box(self, Vector3(0.8, cover_height * 0.8, 1.6),
				Vector3(side * (length * 0.5 + 0.3), cover_height * 0.4, 0.6), earth,
				Basis(Vector3.UP, side * 0.35))
