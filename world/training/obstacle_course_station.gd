class_name ObstacleCourseStation
extends TrainingStation
## Esterata (station_id "obstacle_course"). Lapsisolmuina CourseTrigger-alueet:
##
## - START: lähtöviiva, ajanotto alkaa (ilman lähtöviivaa ajanotto alkaa begin()-kutsusta).
## - CHECKPOINT (index 0..n-1): esteiden päälle/perään sijoitetut välietapit, hyväksytään vain
##   järjestyksessä. Jokaisesta hyväksytystä lähtee training_event "checkpoint".
## - ELEVATED: ohut alue puomin (tai muun korokkeen) pinnalla jalkojen korkeudella; merkitsee
##   pelaajan olevan esteen päällä. Alue on kapeampi kuin este, joten maassa vieressä seisova
##   pelaaja ei osu siihen.
## - FALL: alue korokkeen vieressä maan tasalla. Jos pelaaja on korokkeella tai poistui sieltä alle
##   [member fall_grace] sekuntia sitten ja päätyy tähän, kirjataan kaatuminen
##   (training_event "fell") ja pelaaja palautetaan reset_point-merkkiin.
## - WIRE: piikkilankaryömintä. Jos pelaaja on alueella muussa kuin makuuasennossa, kirjataan
##   kosketus (training_event "wire_touched"). Yksi kosketus per nousu: uusi kirjaus vasta, kun
##   pelaaja on käynyt makuulla tai poistunut alueelta.
## - FINISH: maali. Hyväksytään, kun kaikki välietapit on ohitettu. Lähettää completed-tuloksen
##   {time_s: float, falls: int, wire_touches: int}.
##
## Logiikka on erotettu triggereistä (handle_*-metodit), jotta sitä voi testata ilman fysiikkaa.

## PlayerController.Stance.PRONE. Luetaan arvona, ettei world riipu player-koodista.
const STANCE_PRONE: int = 2

## Kuinka kauan korokkeelta poistumisen jälkeen putoaminen FALL-alueelle lasketaan kaatumiseksi.
@export var fall_grace: float = 1.2

var time_s: float = 0.0
var falls: int = 0
var wire_touches: int = 0
var next_checkpoint: int = 0
var timing: bool = false
var on_elevated: bool = false

var _checkpoint_count: int = 0
var _wire_triggers: Array[CourseTrigger] = []
var _wire_flagged: bool = false
var _fall_cooldown: float = 0.0
var _since_elevated: float = INF


func _ready() -> void:
	if station_id == &"":
		station_id = &"obstacle_course"
	super._ready()
	_checkpoint_count = 0
	for node: Node in find_children("*", "Area3D", true, false):
		var trigger := node as CourseTrigger
		if trigger == null:
			continue
		trigger.player_entered.connect(_on_trigger_entered)
		trigger.player_exited.connect(_on_trigger_exited)
		match trigger.kind:
			CourseTrigger.Kind.CHECKPOINT:
				_checkpoint_count = maxi(_checkpoint_count, trigger.index + 1)
			CourseTrigger.Kind.WIRE:
				_wire_triggers.append(trigger)


func _physics_process(delta: float) -> void:
	if not active:
		return
	advance_time(delta)
	var inside: Node3D = null
	for trigger: CourseTrigger in _wire_triggers:
		if trigger.player_inside != null and is_instance_valid(trigger.player_inside):
			inside = trigger.player_inside
			break
	update_wire(inside != null, _read_stance(inside))


## Välietappien määrä (testit voivat asettaa, jos triggereitä ei ole).
func set_checkpoint_count(count: int) -> void:
	_checkpoint_count = count


func checkpoint_count() -> int:
	return _checkpoint_count


func advance_time(delta: float) -> void:
	_fall_cooldown = maxf(_fall_cooldown - delta, 0.0)
	_since_elevated += delta
	if timing:
		time_s += delta


func handle_start() -> void:
	if not active or timing:
		return
	timing = true
	time_s = 0.0


## Palauttaa true, jos välietappi hyväksyttiin (oikea järjestys).
func handle_checkpoint(index: int) -> bool:
	if not active or index != next_checkpoint:
		return false
	# Ajanotto käynnistyy viimeistään ensimmäisestä välietapista (lähtöviiva ohitettu sivusta).
	timing = true
	next_checkpoint += 1
	on_elevated = false
	_since_elevated = INF
	emit_event(&"checkpoint")
	return true


func handle_elevated() -> void:
	if active:
		on_elevated = true


## Pelaaja poistui korokkeen pinnalta (putosi tai käveli rampin alas).
func handle_elevated_exit() -> void:
	if on_elevated:
		on_elevated = false
		_since_elevated = 0.0


## Palauttaa true, jos kaatuminen kirjattiin.
func handle_fall() -> bool:
	if not active or _fall_cooldown > 0.0:
		return false
	if not on_elevated and _since_elevated > fall_grace:
		return false
	on_elevated = false
	_since_elevated = INF
	_fall_cooldown = 1.0
	falls += 1
	emit_event(&"fell")
	return true


## Kutsutaan joka fysiikka-askeleella: onko pelaaja piikkilanka-alueella ja missä asennossa.
## Palauttaa true, jos uusi kosketus kirjattiin.
func update_wire(inside: bool, stance: int) -> bool:
	if not active:
		return false
	if not inside or stance == STANCE_PRONE:
		_wire_flagged = false
		return false
	if _wire_flagged:
		return false
	_wire_flagged = true
	wire_touches += 1
	emit_event(&"wire_touched")
	return true


## Palauttaa true, jos rata suoritettiin (kaikki välietapit ohitettu).
func handle_finish() -> bool:
	if not active or next_checkpoint < _checkpoint_count:
		return false
	complete(build_result())
	return true


func build_result() -> Dictionary:
	return {
		"time_s": snappedf(time_s, 0.01),
		"falls": falls,
		"wire_touches": wire_touches,
	}


func _reset_state() -> void:
	time_s = 0.0
	falls = 0
	wire_touches = 0
	next_checkpoint = 0
	on_elevated = false
	_wire_flagged = false
	_fall_cooldown = 0.0
	_since_elevated = INF
	# Ilman lähtöviivaa ajanotto alkaa heti.
	timing = not _has_trigger(CourseTrigger.Kind.START)


func _has_trigger(kind: CourseTrigger.Kind) -> bool:
	for node: Node in find_children("*", "Area3D", true, false):
		if node is CourseTrigger and (node as CourseTrigger).kind == kind:
			return true
	return false


func _on_trigger_entered(trigger: CourseTrigger, player: Node3D) -> void:
	match trigger.kind:
		CourseTrigger.Kind.START:
			handle_start()
		CourseTrigger.Kind.CHECKPOINT:
			handle_checkpoint(trigger.index)
		CourseTrigger.Kind.ELEVATED:
			handle_elevated()
		CourseTrigger.Kind.FALL:
			if handle_fall() and trigger.reset_point != null:
				TrainingStation.move_player_to.call_deferred(player, trigger.reset_point)
		CourseTrigger.Kind.FINISH:
			handle_finish()


func _on_trigger_exited(trigger: CourseTrigger, _player: Node3D) -> void:
	if trigger.kind == CourseTrigger.Kind.ELEVATED:
		handle_elevated_exit()


static func _read_stance(player: Node3D) -> int:
	if player == null or not is_instance_valid(player):
		return 0
	var value: Variant = player.get(&"stance")
	return int(value) if value is int else 0
