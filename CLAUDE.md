# CLAUDE.md – Monsoon Line

Ohjeet kaikille tässä repossa työskenteleville agenteille.

## Projekti

Taktinen FPS Godot 4:llä. Pelaaja on M60-konekiväärimies, 173. ilmarynnäkköprikaati,
Operaatio Junction City 1967. Lue `docs/GDD.md` ennen kuin aloitat uuden järjestelmän.

## Säännöt

- **GDScript, staattiset tyypit aina.** Ei tyypittömiä muuttujia tai funktioita.
- **Järjestelmät puhuvat `EventBus`-signaaleilla**, eivät suorilla viittauksilla toisiinsa.
- **Datavetoisuus:** aseet `WeaponData`-resursseina (`weapons/resources/*.tres`), tehtävät `MissionData`-resursseina.
- **Komponentit** (`core/components/`) toimivat sekä pelaajalle että AI:lle.
- **Pysy omalla alueellasi** (ks. roolit alla). Muutokset toisen alueelle vain sopimalla tiiminvetäjän kanssa.
- **Testit:** jokaiselle logiikkaluokalle GUT-testi `tests/`-kansioon.
- **Historiallinen tarkkuus:** aseet, varusteet ja tapahtumat vuoden 1967 mukaan. Ei pelillistettyjä sotarikoksia.
- **Kieli:** koodi ja tunnisteet englanniksi, kommentit ja docstringit suomeksi.
- Tehtävät tulevat Planesta hyväksymiskriteereineen. Viittaa tehtävään commit-viestissä.

## Roolit ja vastuualueet

| Agentti | Kansiot |
| --- | --- |
| designer | `docs/`, `missions/` (data) |
| gameplay | `player/`, `weapons/`, `core/` |
| ai | `ai/` |
| world | `world/` |
| ui-audio | `ui/`, `audio/`, `autoload/audio_director.gd` |
| tester | `tests/`, `.github/` |

Tiiminvetäjä (ihminen) priorisoi, hyväksyy ja pelitestaa.

## Ensimmäinen tavoite: vertical slice

Yksi 10 minuutin partio viidakossa: konekiväärimies ja avustaja torjuvat väijytyksen ryhmän kanssa.
Kaikki muu odottaa, kunnes se tuntuu hyvältä.
