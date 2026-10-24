# Monsoon Line

Taktinen yksinpelattava ensimmäisen persoonan räiskintä. Pelaaja on 173. ilmarynnäkköprikaatin
laskuvarjojääkäri ja M60-konekiväärimies Operaatio Junction Cityssä, Vietnamissa helmi–toukokuussa 1967.

- **Moottori:** Godot 4.x, GDScript (staattiset tyypit)
- **Alusta:** PC (Windows, Linux)
- **Suunnitteludokumentti:** [docs/GDD.md](docs/GDD.md) (täysi versio Claude Docsissa)

## Ajaminen

1. Asenna Godot 4.4 tai uudempi.
2. Avaa `project.godot`.
3. Aja (F5). Aloitusscene on ampumarata `world/levels/test_range.tscn`.

| Toiminto | Näppäin |
| --- | --- |
| Liiku | WASD, Shift juoksu |
| Kyykky / makuu | C / Z |
| Ammu / tähtää | Hiiren vasen / oikea |
| Kaksijalka (makuulla) | V |
| Lataa nauha | R |
| Vaihda piippu | B |

## Rakenne

```
autoload/     EventBus, GameState, AudioDirector, SaveManager
core/         komponentit (terveys, tukahdutus, hitbox) ja tilakone
player/       pelaajan ohjain ja scene
weapons/      WeaponData-resurssit (.tres), konekivääri, ballistiikka
ai/           vihollisen ja oman ryhmän tekoäly
world/        tasot, kasvillisuus, ansat, sää
ui/  audio/  missions/  tests/
```

## Kehitys agenttitiimillä

Projekti tehdään Claude Code -agenttitiimillä. Roolit ja säännöt: [CLAUDE.md](CLAUDE.md) ja `.claude/agents/`.
