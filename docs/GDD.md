# Monsoon Line – pelisuunnitteludokumentti (tiivistelmä)

Täysi, ajantasainen versio on Claude Docsissa. Tämä tiivistelmä on agenttien pikalukuun.

## Ydin

- Taktinen yksinpeli-FPS, 15–30 minuutin tehtävät, PEGI 18.
- Pelaaja: M60-konekiväärimies, 173. ilmarynnäkköprikaati (2/503). Rooli voi vaihtua ylennysten myötä ryhmänjohtajaksi.
- Yksi hahmo koko pelin, ei näkökulman vaihtoja.
- Realistinen ballistiikka ja haavoittuminen, veri näkyy. Huumori syntyy sotilaiden kommenteista.

## Kampanja

1. **Prologi:** laskuvarjokoulu Fort Benningissä 1966. Kersantti Roscoe Tibbs, äänekäs "Black Hat", keksii jokaiselle lempinimen; pelaajan lempinimi seuraa koko pelin. Toimii opetusosiona.
2. **Hyppy 22.2.1967:** pataljoonan taisteluhyppy C-130:sta Katumin pohjoispuolelle. Ei vihollisen tulta; jännite tuntemattomasta ja kuormasta.
3. **Hevosenkenkä:** Sotavyöhyke C:n saartaminen, bunkkerit ja tunnelit.
4. **Vastaisku:** Viet Congin yöhyökkäykset tukikohtiin.
5. **Loppu:** vihollinen vetäytyy Kambodžaan, operaatio jättää sodan ratkaisematta.

## Mekaniikat

- M60: kaksijalka (makuulla/tuettuna), nauha 100 ptr, piipun kuumeneminen ja vaihto, jumitus kuumana.
- Tukahdutus molempiin suuntiin, osakohtainen terveys ja verenvuoto.
- AI-ryhmänjohtaja käskee; pelaaja käskee avustajaa (lataa, seuraa, peitä).
- Minimaalinen HUD: ei ammuslaskuria, paperikartta.

## Viholliset

Viet Congin 9. divisioona (bunkkerit, väijytykset, tunnelit), NVA-jalkaväki, tarkka-ampujat, ansat.

## Tekninen

Godot 4, GDScript, komponentit + EventBus, WeaponData-resurssit, GUT-testit, GitHub Actions.
