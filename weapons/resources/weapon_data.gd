class_name WeaponData
extends Resource
## Datavetoinen asemäärittely. Uudet aseet lisätään .tres-tiedostoina, ei koodina.

@export var display_name: String = ""
@export_group("Tuli")
@export var rounds_per_minute: float = 600.0
@export var magazine_size: int = 20
@export var reload_time: float = 2.5
@export var damage: float = 40.0
@export_group("Ballistiikka")
@export var muzzle_velocity: float = 850.0  ## m/s
@export var bullet_mass_g: float = 9.5
## Kuinka paljon kasvillisuutta tai seinää luoti läpäisee (cm vastaavaa puuta).
@export var penetration: float = 20.0
@export_group("Käsittely")
## Kameran nousu asteina per laukaus.
@export var recoil_vertical: float = 1.0
## Satunnaisen sivuheiton enimmäismäärä asteina per laukaus.
@export var recoil_horizontal: float = 0.4
## Kuinka nopeasti rekyyli palautuu (eksponentiaalinen kerroin, 1/s).
@export var recoil_recovery: float = 6.0
## Aika viimeisestä laukauksesta ennen kuin rekyyli alkaa palautua (s).
@export var recoil_recovery_delay: float = 0.15
## Huojunnan perusamplitudi asteina (levännyt, tukahduttamaton, tukematon ampuja).
@export var sway: float = 1.0
## Huojunnan perustaajuus hertseinä. Väsymys nopeuttaa sitä.
@export var sway_frequency: float = 0.5
## Kuinka paljon tyhjä kestävyys kasvattaa huojuntaa (0 = ei vaikutusta, 2 = kolminkertainen).
@export var stamina_sway_factor: float = 1.5
## Kuinka paljon täysi tukahdutus kasvattaa huojuntaa (3 = nelinkertainen).
@export var suppression_sway_factor: float = 3.0
@export var hip_spread_deg: float = 4.0
## Hajonnan kerroin kaksijalalta tai tuettuna.
@export var supported_spread_multiplier: float = 0.25
## Rekyylin kerroin kaksijalalta tai tuettuna.
@export var supported_recoil_multiplier: float = 0.3
## Huojunnan kerroin kaksijalalta tai tuettuna.
@export var supported_sway_multiplier: float = 0.15
@export_group("Konekivääri")
@export var uses_belt: bool = false
@export var has_bipod: bool = false
## Lämpöä per laukaus (0–1 asteikolla, 1 = ylikuumentunut).
@export var heat_per_shot: float = 0.0
@export var cooling_per_second: float = 0.0
@export var barrel_change_time: float = 0.0
@export var jam_chance_when_hot: float = 0.0
