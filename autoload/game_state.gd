extends Node
## Kampanjan pysyvä tila: pelaajan sotilasarvo, lempinimi ja ryhmän kokoonpano.

enum Rank { PRIVATE, PRIVATE_FIRST_CLASS, SPECIALIST_4, SERGEANT, STAFF_SERGEANT }
enum Role { MACHINE_GUNNER, SQUAD_LEADER }

var player_rank: Rank = Rank.PRIVATE
var player_role: Role = Role.MACHINE_GUNNER
## Kersantti Tibbsin harjoitusleirillä antama lempinimi. Seuraa pelaajaa koko kampanjan.
var player_nickname: String = ""
var current_mission: StringName = &"prologue_fort_benning"
## Ryhmäläisten tunnisteet, jotka ovat yhä elossa. Kuolemat ovat pysyviä.
var squad_alive: Array[StringName] = []


func promote() -> void:
	if player_rank < Rank.STAFF_SERGEANT:
		player_rank = (player_rank + 1) as Rank


func to_dict() -> Dictionary:
	return {
		"rank": player_rank,
		"role": player_role,
		"nickname": player_nickname,
		"mission": current_mission,
		"squad_alive": squad_alive,
	}


func from_dict(data: Dictionary) -> void:
	player_rank = data.get("rank", Rank.PRIVATE)
	player_role = data.get("role", Role.MACHINE_GUNNER)
	player_nickname = data.get("nickname", "")
	current_mission = data.get("mission", &"prologue_fort_benning")
	squad_alive.assign(data.get("squad_alive", []))
