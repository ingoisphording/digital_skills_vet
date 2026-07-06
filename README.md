# Text-as-data: Ausbildungsordnungen

Dieses Repository veröffentlicht eine browserbasierte Übung für einen
Bachelor-Kurs in Computational Social Science.

Die Startseite ist `index.html`. Zum Lesen und Bearbeiten der Standardaufgaben
sind weder eine R-Installation noch ein API-Schlüssel erforderlich. Wer den
Analyseweg technisch nachvollziehen möchte, kann zusätzlich das vollständige
öffentliche R/Quarto-Projekt im Ordner `source/` ausführen.

## Öffentliche Inhalte

- `index.html`: Studierendenfassung der Übung;
- `downloads/`: Codebuch, Arbeitsvorlagen, Prompt und kommentiertes NLP-Skript;
- `source/`: ausführbares Quarto-Projekt mit öffentlichen Datengrundlagen,
  gezielten Selbstlernauflösungen und kommentierten Skripten.

Die Selbstlernfassung enthält Lösungen für die zehn Handkodierungsfälle und
die fünf Fälle des Modellvergleichs. Die Seite dokumentiert außerdem die
dozierendenseitige Evaluation auf 90 blind handkodierten Testfällen und stellt
deren aggregierte Kennzahlen bereit. Personenbezogene Dozierendenangaben,
API-Ausgaben, interne Vorlagen und Einzelfalllabels der blinden Evaluation
sind nicht Bestandteil des Repositorys.

## R-Code lokal ausführen

1. Das Repository klonen oder über **Code → Download ZIP** herunterladen.
2. [R über CRAN](https://cran.r-project.org/) und die
   [Open-Source-Version von RStudio Desktop](https://posit.co/download/rstudio-desktop/)
   installieren. Quarto ist in aktuellen RStudio-Versionen enthalten; bei
   Bedarf steht eine separate
   [Quarto-Installationsanleitung](https://quarto.org/docs/get-started/) bereit.
3. In RStudio `source/digital_skills_vet.Rproj` öffnen. Dadurch verwendet R
   automatisch das richtige Arbeitsverzeichnis.
4. `source/setup.R` öffnen und einmal vollständig ausführen.
5. `source/digital_skills_vet.qmd` öffnen.
6. Einzelne Codeblöcke über den grünen Ausführungspfeil starten oder das
   gesamte Dokument mit **Render** erzeugen.

Die Extraktion, Tabellen und studentischen Aufgaben lassen sich im
öffentlichen Projekt nachvollziehen. Die vollständige dozierendenseitige
Modellpipeline wird wegen der nicht veröffentlichten API-Ausgaben und
Blindkodierungen nicht als unmittelbar reproduzierbarer Studierendenschritt
ausgegeben.

## Lokale Vorschau

`index.html` kann direkt in einem Browser geöffnet werden. Für eine Vorschau
über einen lokalen Webserver kann im Ordner beispielsweise ausgeführt werden:

```powershell
python -m http.server 8000
```

Die Seite ist danach unter `http://localhost:8000/` erreichbar.
