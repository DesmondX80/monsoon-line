class_name VoiceLine
extends Resource
## Yksittäinen repliikki: puhujan rooli, tekstitys suomeksi ja englanniksi sekä valinnainen ääni.
## Repliikit ovat dataa (.tres), eivät koodia. Teksti voi sisältää paikan {nickname},
## johon sijoitetaan pelaajan lempinimi (GameState.player_nickname).

## Yksilöivä tunniste, jolla EventBus.squad_callout viittaa repliikkiin.
@export var id: StringName = &""
## Puhujan rooli, esim. drill_sergeant, squad_leader, assistant_gunner, rifleman.
@export var speaker_role: StringName = &""
@export var speaker_name_fi: String = ""
@export var speaker_name_en: String = ""
@export_multiline var text_fi: String = ""
@export_multiline var text_en: String = ""
## Valinnainen äänitiedosto. Ilman sitä näytetään pelkkä tekstitys.
@export var stream: AudioStream


## Palauttaa tekstin pyydetyllä kielellä ja sijoittaa lempinimen paikalleen.
func get_text(language: StringName, nickname: String = "") -> String:
	var text: String = text_en if language == &"en" else text_fi
	if text.is_empty():
		text = text_fi if language == &"en" else text_en
	var who: String = nickname
	if who.is_empty():
		who = "trooper" if language == &"en" else "sotilas"
	return text.replace("{nickname}", who)


## Palauttaa puhujan nimen pyydetyllä kielellä.
func get_speaker_name(language: StringName) -> String:
	var speaker: String = speaker_name_en if language == &"en" else speaker_name_fi
	return speaker if not speaker.is_empty() else String(speaker_role)
