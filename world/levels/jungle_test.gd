extends Node3D
## Viidakkotestitaso (M1-11). Sotavyöhyke C, Tay Ninhin maakunta, helmikuu 1967.
##
## Asettelu (−Z = pohjoinen):
## - Etelässä pudotusalue (LZ) elefanttiheinineen, pelaajan aloituspaikka.
## - Keskellä tiheä viidakko, kolme konekivääriasemaa ja aukea "tappoalue" bunkkerien edessä.
## - Pohjoisessa Viet Congin bunkkerikompleksi: neljä bunkkeria, juoksuhauta ja tunnelin suu.
## - Idässä ja lännessä polut, joita vihollinen voi käyttää koukkaukseen; poluilla punji-ansat.
##
## Navigaatioverkko leivotaan ajon aikana, koska maasto ja kasvillisuus generoidaan proseduraalisesti.

signal navigation_ready

const AMBUSH_DIRECTOR := preload("res://missions/ambush/ambush_director.gd")

@onready var navigation_region: NavigationRegion3D = $NavigationRegion3D

var ambush_director: AmbushDirector


func _ready() -> void:
	navigation_region.bake_finished.connect(_on_bake_finished, CONNECT_ONE_SHOT)
	# Leivotaan vasta, kun kaikki generoidut törmäysmuodot ovat puussa.
	_bake_navigation.call_deferred()


## Kasvillisuuden MultiMesh-instanssien määrät kaikista levittäjistä, tyypin nimen mukaan.
func vegetation_report() -> Dictionary:
	var report: Dictionary = {}
	for node: Node in find_children("*", "VegetationScatter", true, false):
		var scatter: VegetationScatter = node as VegetationScatter
		for kind: int in scatter.instance_counts.keys():
			var key: String = "%s/%s" % [scatter.name, VegetationScatter.Kind.keys()[kind]]
			report[key] = scatter.instance_counts[kind]
	return report


func _bake_navigation() -> void:
	navigation_region.bake_navigation_mesh(true)


func _on_bake_finished() -> void:
	navigation_ready.emit()
	_start_ambush()


## Käynnistää M3-väijytystehtävän, kun navigointiverkko on valmis.
func _start_ambush() -> void:
	if ambush_director != null:
		return
	ambush_director = AMBUSH_DIRECTOR.new() as AmbushDirector
	add_child(ambush_director)
	ambush_director.start()
