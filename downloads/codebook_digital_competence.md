# Codebuch: Digitale Kompetenz

## Ziel

Für jedes Lernziel wird die binäre Variable `digital` kodiert:

- `1`: digitale Kompetenz;
- `0`: keine digitale Kompetenz.

Kodiert wird ein Kontextpaket aus `learning_goal_text`, `unit_name`,
`section` und `occupation`. Das Lernziel bleibt die Analyseeinheit; die
Berufsbildposition und der Beruf dienen dazu, mehrdeutige Begriffe wie
„System“, „Modul“, „Störung“ oder „Daten“ fachlich einzuordnen.

## Arbeitsdefinition

Eine Kompetenzzeile wird als digital klassifiziert, wenn ihre Erfüllung
ausdrücklich die Nutzung, Konfiguration, Entwicklung, Steuerung oder Analyse
digitaler Systeme, Software, Daten oder automatisierter digitaler Prozesse
erfordert.

Nicht ausreichend ist die bloße Nutzung eines technischen Geräts, sofern kein
digitaler Bezug erkennbar ist.

## Entscheidungsregeln

1. **Explizites digitales Objekt:** Der Text nennt beispielsweise
   IT-Systeme, Software, Betriebssysteme, Programme, Datenbanken, digitale
   Netze, digitale Medien oder digitale Schnittstellen.
2. **Explizite digitale Handlung:** Das Lernziel verlangt beispielsweise
   Programmieren, Konfigurieren, Installieren, Testen, Analysieren oder
   Steuern eines solchen digitalen Objekts.
3. **Erforderlichkeit:** Der digitale Bezug muss zur Erfüllung des
   kontextualisierten Lernziels notwendig sein. Eine nur denkbare digitale
   Umsetzung reicht nicht.
4. **Kontrollierte Kontextnutzung:** Berufsbildposition, Abschnitt und Beruf
   dürfen den Gegenstand einer verkürzt formulierten Tätigkeit präzisieren.
   „Störungsmeldungen bearbeiten“ wird beispielsweise digital, wenn die
   Berufsbildposition ausdrücklich „Betreiben von IT-Systemen“ lautet.
5. **Keine pauschale Berufsinferenz:** Nicht jedes Lernziel eines IT- oder
   Technikberufs ist digital. Allgemeine Sozial-, Organisations-,
   Arbeitsschutz- oder Umweltkompetenzen bleiben `0`, wenn auch der fachliche
   Kontext keine digitale Teilkompetenz für ihre Erfüllung verlangt.
6. **Gemischte Lernziele:** Enthält eine Zeile mindestens eine ausdrücklich
   erforderliche digitale Teilkompetenz, wird die gesamte Zeile mit `1`
   kodiert. Die gemischte Form wird in der Begründung notiert.
7. **Daten im Kontext:** „Daten erfassen“ oder „Kundendaten verarbeiten“
   werden mit `1` kodiert, wenn Berufsbildposition oder Abschnitt die
   Tätigkeit eindeutig in einen digitalen Informations-, IT- oder
   Datensicherheitsprozess einordnen. Ohne solchen Kontext bleibt das Wort
   „Daten“ allein unzureichend.
8. **Technische Anlagen:** Bedienen, Überwachen oder Prüfen einer Anlage wird
   als digital kodiert, wenn der unmittelbare Kontext Programmierung,
   Hard-/Software, Automatisierungs- oder digitale Steuerungssysteme zum
   Gegenstand macht. Ein technischer Beruf oder ein Sensor allein genügt
   weiterhin nicht.

## Ankerbeispiele aus dem Lehrvortrag

| Lernziel | Label | Begründung |
|---|---:|---|
| Teilaufgaben von IT-Systemen automatisieren | 1 | IT-System und Automatisierung sind ausdrücklich genannt. |
| Bedarfe von Kunden und Kundinnen feststellen sowie Zielgruppen unterscheiden | 0 | Kein digitaler Gegenstand und keine digitale Handlung werden genannt. |
| CNC-Anlagen programmieren | 1 | Programmieren ist eine ausdrücklich digitale Handlung. |

Die Ankerbeispiele erläutern Regeln. Sie sind keine ausgefüllte
Referenzkodierung für die 60-Zeilen-Stichprobe.

## Typische Grenzfälle

| Formulierung | Kontext | Label |
|---|---|---:|
| Daten erfassen und auswerten | Berufsbildposition nennt digitales Informations- oder Datensystem | 1 |
| Daten erfassen und auswerten | kein digitaler Kontext | 0 |
| Anlagen überwachen | Berufsbildposition nennt Automatisierungs- oder digitale Steuerungssysteme | 1 |
| Anlagen überwachen | nur allgemeine technische Anlage | 0 |
| Kundinnen und Kunden beraten | Beratung bezieht sich auf IT-Systeme oder digitale Produkte | 1 |
| Kundinnen und Kunden beraten | allgemeine Dienstleistungsberatung | 0 |
| Kassenabrechnung durchführen | digitales Kassensystem ist im Kontext festgelegt | 1 |
| Kassenabrechnung durchführen | kein digitaler Kontext | 0 |

Diese Festlegungen sind theoretische Entscheidungen, keine technischen
Notwendigkeiten.

## Konfidenz

- `1.00`: Regel eindeutig anwendbar;
- `0.75`: überwiegend eindeutig, geringe Restunsicherheit;
- `0.50`: echter Grenzfall;
- `0.25`: Entscheidung nur vorläufig möglich.

Die Konfidenz verändert das binäre Label nicht. Ein niedriger Wert erfordert
eine konkrete Begründung.
