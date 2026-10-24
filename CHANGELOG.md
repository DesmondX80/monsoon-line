# Muutosloki

## 0.1.0 – 2026-10-24 (M1 Prototyyppi)

Ensimmäinen pelattava prototyyppi. Windows-jakelu: `MonsoonLine.exe`.

### Pelattavaa
- Päävalikko ja viidakkotestitaso (Sotavyöhyke C, 1967): pudotusalue elefanttiheinineen, tiheä viidakko, kolme konekivääriasemaa, Viet Congin bunkkerikompleksi, juoksuhauta, tunnelin suu ja kaksi punji-ansaa.
- Tavoite: tuhoa kahdeksan bunkkerien puolustajaa. Pelaajan kaatuessa taso alkaa alusta.

### Gameplay
- M60: nauha, piipun kuumeneminen ja vaihto, jumitus, kaksijalka makuulla tai esteeseen tuettuna.
- Ammuksina lentävät luodit (lentoaika, pudotus) ja osumat ruumiinosiin.
- Ohilentotukahdutus molempiin suuntiin, rekyyli ja huojunta, kestävyys kantokuorman mukaan.

### Tekoäly
- Viet Cong -kiväärimies (Type 56): partioi, epäilee, taistelee, painuu maahan tukahdutettuna.
- Näkö- ja kuulohavainnointi, kasvillisuus heikentää näkyvyyttä.

### UI ja ääni
- Minimaalinen HUD: tukahdutus-, osuma-, verenvuoto- ja kuumuusefektit, vihjeet ja tekstitykset.
- Kehittäjän debug-näkymä (F3).
- Koodissa syntetisoidut paikkamerkkiäänet; viidakon eläimet hiljenevät laukausten jälkeen.
- 16 repliikkiä, joista 8 kersantti Roscoe Tibbsin prologirepliikkejä.

### Tekninen
- GUT 9.4.0, 122 testiä, CI ajaa testit jokaisesta pushista.
- Julkaisutyönkulku rakentaa Windows-.exe:n versiotageista.

### Tunnetut rajoitukset
- Kaikki grafiikka ja äänet ovat paikkamerkkejä.
- Ei läpäisyä eikä kimmokkeita; viholliset eivät vielä hakeudu suojaan.
- 60 fps -tavoitetta ei ole mitattu oikealla näytönohjaimella.
