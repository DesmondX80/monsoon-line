extends Node
## Globaali signaaliväylä. Järjestelmät eivät viittaa toisiinsa suoraan,
## vaan lähettävät ja kuuntelevat näitä signaaleja.

signal shot_fired(shooter: Node3D, origin: Vector3, direction: Vector3)
signal bullet_snap(listener: Node3D, distance: float)
signal actor_hit(target: Node3D, damage: float, body_part: StringName)
signal actor_died(actor: Node3D)
signal suppression_changed(actor: Node3D, amount: float)
signal barrel_overheated(weapon: Node)
signal belt_empty(weapon: Node)
signal squad_callout(speaker: Node3D, line_id: StringName)
signal mission_objective_updated(objective_id: StringName, state: StringName)

# --- Prologi ja hyppy (M2) ---
## Harjoitusrata aloitettiin. station_id: obstacle_course, mg_range, jump_tower.
signal training_station_started(station_id: StringName)
## Harjoitusrata suoritettu. result-sanakirjan avaimet radoittain: ks. docs/backlog/milestone-2-prologue.json.
signal training_station_completed(station_id: StringName, result: Dictionary)
## Harjoitustapahtuma radalla, esim. &"fell", &"wire_touched", &"target_hit", &"target_missed".
signal training_event(station_id: StringName, event_id: StringName)
## Ohjeteksti ruudulle (tehtävä/ohje). Tyhjä teksti piilottaa.
signal objective_prompt(text_fi: String, text_en: String)
## Otsikkokortti, esim. "Fort Benning, Georgia – 1966".
signal title_card(title: String, subtitle: String)
## Kersantti Tibbs antoi pelaajalle lempinimen.
signal nickname_assigned(nickname: String)
## Hyppymestarin komento C-130:ssa (stand_up, hook_up, check_equipment, stand_in_door, go).
signal jumpmaster_command(command: StringName)
signal jump_started(jumper: Node3D)
signal chute_opened(jumper: Node3D)
## Laskeutuminen: quality = &"good", &"hard" tai &"injured".
signal landed(jumper: Node3D, quality: StringName)

# --- Kampanja ja väijytys (M3) ---
## Tehtävän päävaihe vaihtui. stage: patrol, contact, firefight, regroup, extraction, complete.
signal mission_stage_changed(stage: StringName)
## Väijytys alkoi: viholliset ovat ottaneet yhteyden ryhmään.
signal ambush_started()
## Kaikki väijytyksen viholliset on torjuttu tai ne ovat vetäytyneet.
signal ambush_cleared()
## Ryhmä on aloittanut perääntymisen kohtaamisalueelta.
signal extraction_started()
## Tehtävä päättyi. result sisältää ainakin avaimen "success".
signal mission_completed(result: Dictionary)
