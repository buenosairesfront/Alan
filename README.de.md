[English](README.md) · [Español](README.es.md) · [Français](README.fr.md) · **Deutsch** · [日本語](README.ja.md) · [中文](README.zh.md) · [हिन्दी](README.hi.md)

# alan

Ein Körper aus Daten, der wie ein Drone klingt. Ein Script für
[monome norns](https://monome.org/docs/norns/): Auf dem Display steht eine
menschliche 3D-Figur aus Punkten, einem Drahtgitter und fallenden Ziffern.
Jeder Körperteil ist eine Stimme. Bewegst du ihn, ändert sich der Klang.

![alan](docs/sheet.png)

- **6 Drone-Stimmen**, die nie verstummen: Rumpf, Kopf, zwei Arme und zwei Beine
- **20 Gelenke**, mit den Encodern bewegt, ein Körperteil nach dem anderen
- **Eigenbewegung**: Der Körper bewegt sich von selbst, wie eine Welle, die
  durch die Gelenke läuft
- **freie Kamera**: Zoom, Umlaufbahn und Höhe; man kann mitten durch die
  Figur fliegen
- **Atem und Herzschlag**: Die Brust hebt sich, und das Herz schlägt bei
  Anstrengung schneller
- **Auflösen**: Körper und Klang zerfallen in Partikel und Grains
- **8 Posen-Plätze** (7 Werksposen) zum Speichern und Laden
- 6 Skalen und einstellbarer Grundton, damit alles gestimmt bleibt

## Voraussetzungen

- norns (jede: shield, Standard oder fates)
- kein MIDI-Keyboard und kein Controller nötig: gespielt wird mit Encodern
  und Tasten

## Installation

In maiden:

```
;install https://github.com/buenosairesfront/alan
```

Danach **norns neu starten** (SYSTEM > RESTART), damit die neue Engine
`Turing` kompiliert wird, und **alan** über SELECT laden.

## Intro

![Intro](docs/1_title.png)

Beim Öffnen läuft das U-MA-Intro, danach eine Nahaufnahme von Alans Kopf mit
seinem Namen. Die Kamera fährt zurück, bis der ganze Körper zu sehen ist.
Jede Taste und jeder Encoder springt weiter.

## Bedienung

### Den Körper bewegen

![Körperteil wählen](docs/3_select.png)

| Bedienelement | Funktion |
|---|---|
| E1 | Körperteil wählen (eine kleine Karte oben links zeigt welchen) |
| E2 / E3 | den gewählten Teil bewegen (jeder Teil hat zwei Bewegungen) |
| K3 halten | auflösen: Der Körper zerfällt in Partikel; loslassen, und er kommt zurück |
| K2 halten + E2 | Tempo der Eigenbewegung |
| K2 halten + E3 | Stärke der Eigenbewegung |

Die Teile der Reihe nach: Kopf (drehen / nicken), linke Schulter, linker
Ellbogen, linke Hüfte, linkes Knie und Sprunggelenk, rechtes Knie und
Sprunggelenk, rechte Hüfte, rechter Ellbogen, rechte Schulter und Taille
(beugen / verdrehen).

Bei aktiver Eigenbewegung bleibt der Teil, den du anfasst, ein paar Sekunden
in deiner Hand und reiht sich dann wieder in die Welle ein.

### Kamera

![Kamera](docs/5_camera.png)

**K2** antippen, um den Kameramodus zu öffnen oder zu verlassen (die Ecken
des Displays werden markiert).

| Bedienelement | Funktion |
|---|---|
| E1 | Zoom: Aus der Nähe zielt die Kamera auf den Kopf; weiter gedreht fliegt sie durch die Figur und schaut von der anderen Seite |
| E2 | Umlaufbahn um den Körper |
| E3 | Höhe (ganz herum) |

Wird 8 Sekunden lang nichts berührt, kreist die Kamera von selbst (in PARAMS
abschaltbar).

### Posen und Stimmung (K1 halten)

![eine Pose](docs/4_pose.png)

| Bedienelement | Funktion |
|---|---|
| K1 + E1 | Pose wählen (1 bis 8): Der Körper geht beim Drehen durch jede einzelne |
| K1 + K2 | aktuelle Pose auf diesem Platz speichern |
| K1 + K3 | Pose dieses Platzes laden |
| K1 + E2 | Atem |
| K1 + E3 | Grundton |

Gespeicherte Posen liegen in `data/alan/poses.tab` und ersetzen die Werkspose
auf diesem Platz.

## Wie es klingt

![der Körper in Bewegung](docs/2_body.png)

Jeder Körperteil steuert eine Stimme. Die Töne liegen immer in der gewählten
Skala.

| Stimme | Klang | was ihn verändert |
|---|---|---|
| Rumpf | tiefer Sub, Herzschlag und Luft | Beugen macht ihn dunkler; Verdrehen öffnet einen Sägezahn-Chor |
| Kopf | ein Chor, der Vokale singt | nach oben schauen hebt den Ton; den Kopf drehen wechselt den Vokal (a e i o u) |
| Arme | resonierende Sehne (Rauschen, durch Resonatoren gestrichen) | die Höhe der Hand ist der Ton, die Reichweite öffnet das Filter, ein gebeugter Ellbogen macht den Klang unharmonisch |
| Beine | tiefer Knochen und Holz | die Höhe des Fußes ist der Ton, die Hüfte öffnen öffnet das Filter, ein gebeugtes Knie knistert |

- Je weiter ein Teil von seiner Ruhestellung entfernt ist, desto lauter seine
  Stimme.
- Schnelle Bewegung macht lauter und heller und wirft Partikel auf das Display.
- Panorama und Hall kommen von der Kamera: Was links im Bild ist, klingt
  links, und was weit weg ist, klingt fern.
- Der Herzschlag beschleunigt mit der Anstrengung der Pose und mit Bewegung.

![Auflösen](docs/6_dissolve.png)

## Parameter

In PARAMS > alan:

| Parameter | Funktion |
|---|---|
| tonica | Grundton, von E1 bis E3 |
| escala | Skala: dorisch, äolisch, phrygisch, lydisch, pentatonisch oder Quinten |
| respiracion | wie stark der Körper (und der Klang) atmet |
| movimiento solo | Stärke der Eigenbewegung |
| movimiento velocidad | von einem Zyklus alle 50 s bis zu einem alle 2,4 s |
| desintegracion base | lässt den Körper immer leicht aufgelöst |
| auto orbita | die Kamera kreist nach 8 s ohne Eingabe von selbst |
| espacio (reverb) | Größe des Halls |
| volumen | Gesamtlautstärke |
| cuerpo | alle 20 Gelenke einzeln (praktisch für MIDI-Mapping) |

Die Parameternamen sind auf dem Gerät spanisch. Die Einstellungen werden beim
Verlassen des Scripts gespeichert.

## Dateien

- `alan.lua`: das Script
- `lib/Engine_Turing.sc`: die Klang-Engine in SuperCollider
- `lib/alan_title.bin`: der Titel des Intros
- `lib/uma_splash*.lua`, `lib/uma_particles.wav`: das U-MA-Intro

<!-- u-ma:more -->
**Mehr von U-MA:** alle Instrumente und Werkzeuge an einem Ort → [U-MA-Übersicht](https://github.com/buenosairesfront/U-ma/blob/main/README.de.md)
<!-- /u-ma:more -->

## Credits

Erstellt von [Buenos Aires Front](https://github.com/buenosairesfront) / U-MA.
MIT-Lizenz.
