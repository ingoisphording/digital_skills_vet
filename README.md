# Text-as-data: Ausbildungsordnungen

Dieses Repository veröffentlicht eine browserbasierte Übung für einen
Bachelor-Kurs in Computational Social Science.

Die Startseite ist `index.html`. Zum Lesen der Übung sind weder eine
R-Installation noch ein API-Schlüssel erforderlich.

## Öffentliche Inhalte

- `index.html`: Studierendenfassung der Übung;
- `downloads/`: Codebuch, Arbeitsvorlagen, Prompt und kommentiertes NLP-Skript;
- `source/`: Quarto-Quelldatei, öffentliche Datengrundlagen und ausgewählte
  kommentierte Skripte.

Dozierendenreferenzen, Musterlösungen und interne Qualitätsberichte sind nicht
Bestandteil dieses Veröffentlichungsordners.

Die Studierendenfassung der Quarto-Datei ist mit den öffentlichen Daten
renderbar. Modell- und Auswertungsskripte, die Referenzlabels benötigen,
werden zur methodischen Prüfung gezeigt, können ohne die bewusst
ausgeschlossene Dozierendendatei aber nicht vollständig erneut ausgeführt
werden.

## Lokale Vorschau

`index.html` kann direkt in einem Browser geöffnet werden. Für eine Vorschau
über einen lokalen Webserver kann im Ordner beispielsweise ausgeführt werden:

```powershell
python -m http.server 8000
```

Die Seite ist danach unter `http://localhost:8000/` erreichbar.
