# Phase 5: Fünf gemeinsame Fälle für den Browser-Modellvergleich vorbereiten.
#
# Eingaben:  Referenzstichprobe und vorhandene ML-Vorhersagen
# Ausgaben: fünf Fälle ohne Lösung, kopierfertiger Prompt, studentische
#           Ergebnismaske und getrennte Dozierendenauflösung

options(encoding = "UTF-8")

required <- c("readr", "dplyr", "jsonlite")
missing <- required[!vapply(required, requireNamespace, logical(1), quietly = TRUE)]
if (length(missing) > 0) {
  stop("Fehlende R-Pakete: ", paste(missing, collapse = ", "))
}

args <- commandArgs(trailingOnly = FALSE)
file_arg <- sub("^--file=", "", grep("^--file=", args, value = TRUE))
project_root <- if (file.exists("data/derived/manual_coding_sample.csv")) {
  normalizePath(".", winslash = "/")
} else if (length(file_arg) == 1) {
  normalizePath(file.path(dirname(file_arg), ".."), winslash = "/")
} else {
  normalizePath(".", winslash = "/")
}
setwd(project_root)

dir.create("data/manual/student/model_comparison_submissions",
  recursive = TRUE, showWarnings = FALSE
)
dir.create("output/tables", recursive = TRUE, showWarnings = FALSE)

# Die feste Auswahl garantiert, dass alle Gruppen dieselben fünf Fälle sehen.
# Je Beruf ist genau ein klarer oder kontextabhängiger Fall vertreten.
selected_ids <- c(
  "bueromanagement_c_4_g",
  "elektroniker_b_6_l",
  "fachinformatiker_a_8_e",
  "friseur_c_4_b",
  "mechatroniker_main_17_k"
)

reference <- readr::read_csv(
  "data/manual/instructor/instructor_reference_template.csv",
  show_col_types = FALSE,
  locale = readr::locale(encoding = "UTF-8")
)
ml <- readr::read_csv(
  "data/derived/classic_nlp_logo_predictions.csv",
  show_col_types = FALSE,
  locale = readr::locale(encoding = "UTF-8")
)

# match() stellt die pädagogisch festgelegte Reihenfolge wieder her.
sample <- reference |>
  dplyr::filter(unit_id %in% selected_ids) |>
  dplyr::mutate(case_number = match(unit_id, selected_ids)) |>
  dplyr::arrange(case_number) |>
  dplyr::select(
    case_number,
    unit_id,
    occupation,
    section,
    unit_name,
    learning_goal_text
  )

if (nrow(sample) != 5L ||
    anyDuplicated(sample$unit_id) ||
    dplyr::n_distinct(sample$occupation) != 5L) {
  stop("Die Unterrichtsstichprobe muss genau einen Fall je Beruf enthalten.")
}

# Metadaten zum Chatmodell werden einmal pro Datei wiederholt. Das erleichtert
# später das Zusammenfügen mehrerer Gruppenabgaben.
student_template <- sample |>
  dplyr::transmute(
    group_id = NA_character_,
    model_service = NA_character_,
    model_name_displayed = NA_character_,
    access_date = as.Date(NA),
    prompt_changed = FALSE,
    case_number,
    unit_id,
    occupation,
    unit_name,
    learning_goal_text,
    llm_label = NA_integer_,
    llm_confidence = NA_real_,
    llm_rationale = NA_character_
  )

# Zwei left_join()-Schritte ergänzen die ausgeblendete Referenz und die bereits
# vorhandene ML-Prognose über den gemeinsamen Schlüssel unit_id.
instructor_comparison <- sample |>
  dplyr::left_join(
    reference |>
      dplyr::select(
        unit_id,
        reference_label,
        reference_confidence,
        reference_rationale
      ),
    by = "unit_id"
  ) |>
  dplyr::left_join(
    ml |>
      dplyr::select(
        unit_id,
        ml_probability = model_probability,
        ml_label = model_label
      ),
    by = "unit_id"
  )

if (any(is.na(instructor_comparison$reference_label)) ||
    any(is.na(instructor_comparison$ml_label))) {
  stop("Referenz- oder ML-Klassifikation fehlt für mindestens einen Fall.")
}

# Der Prompt enthält nur öffentliche Texte und keine Referenzlabels.
prompt_items <- sample |>
  dplyr::select(
    case_number,
    unit_id,
    occupation,
    unit_name,
    learning_goal_text
  )

# c() setzt einzelne Textzeilen zusammen; toJSON() überträgt die fünf Fälle
# strukturiert und ohne manuelles Kopieren in den Prompt.
prompt <- c(
  "Du klassifizierst fünf Kompetenzzeilen aus deutschen Ausbildungsordnungen.",
  "",
  "Arbeitsdefinition:",
  paste(
    "Eine Kompetenzzeile ist digital, wenn ihre Erfüllung ausdrücklich die",
    "Nutzung, Konfiguration, Entwicklung, Steuerung oder Analyse digitaler",
    "Systeme, Software, Daten oder automatisierter digitaler Prozesse erfordert."
  ),
  "",
  "Entscheidungsregeln:",
  paste(
    "- Interpretiere jedes Lernziel zusammen mit Ausbildungsberuf und",
    "Berufsbildposition."
  ),
  paste(
    "- Der Kontext darf mehrdeutige Wörter wie System, Modul, Störung oder",
    "Daten fachlich präzisieren."
  ),
  "- Der Beruf allein macht eine Tätigkeit nicht digital.",
  "- Eine nur denkbare digitale Umsetzung reicht nicht.",
  paste(
    "- Allgemeine Sozial-, Organisations-, Arbeitsschutz- und",
    "Umweltkompetenzen sind nicht digital, sofern der Kontext keine digitale",
    "Teilkompetenz erfordert."
  ),
  paste(
    "- Wenn mindestens eine ausdrücklich erforderliche digitale",
    "Teilkompetenz enthalten ist, klassifiziere die gesamte Zeile als digital."
  ),
  "- Beurteile alle fünf Fälle getrennt.",
  "",
  "Fälle:",
  jsonlite::toJSON(
    prompt_items,
    dataframe = "rows",
    auto_unbox = TRUE,
    pretty = TRUE
  ),
  "",
  "Gib ausschließlich eine Markdown-Tabelle mit diesen Spalten zurück:",
  "case_number | unit_id | digital | confidence | reason",
  "",
  "Dabei gilt:",
  "- digital ist 0 oder 1.",
  "- confidence liegt zwischen 0 und 1.",
  "- reason ist eine kurze Begründung auf Deutsch.",
  "- Übernimm case_number und unit_id unverändert.",
  "- Ergänze keine weiteren Spalten oder Erläuterungen."
)

# Studierenden- und Dozierendendateien werden strikt getrennt geschrieben.
readr::write_csv(
  sample,
  "data/derived/classroom_model_comparison_sample.csv",
  na = ""
)
readr::write_csv(
  student_template,
  "data/manual/student/model_comparison_results_template.csv",
  na = ""
)
readr::write_csv(
  instructor_comparison,
  "data/manual/instructor/model_comparison_reference.csv",
  na = ""
)
writeLines(
  prompt,
  "data/derived/classroom_model_comparison_prompt.txt",
  useBytes = TRUE
)

message(
  "Browser-Modellvergleich vorbereitet: fünf Fälle, je einer pro Beruf."
)
