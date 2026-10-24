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
