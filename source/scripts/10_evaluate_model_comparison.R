# Phase 5: Ausgefüllte Gruppenabgaben mit Referenz und klassischem ML vergleichen.
#
# Das Skript erzeugt erst dann Resultate, wenn reale CSV-Abgaben im
# submissions-Ordner liegen. Es erfindet oder ergänzt keine Modellantworten.

options(encoding = "UTF-8")

required <- c("readr", "dplyr")
missing <- required[!vapply(required, requireNamespace, logical(1), quietly = TRUE)]
if (length(missing) > 0) {
  stop("Fehlende R-Pakete: ", paste(missing, collapse = ", "))
}

args <- commandArgs(trailingOnly = FALSE)
file_arg <- sub("^--file=", "", grep("^--file=", args, value = TRUE))
project_root <- if (file.exists("data/manual/instructor/model_comparison_reference.csv")) {
  normalizePath(".", winslash = "/")
} else if (length(file_arg) == 1) {
  normalizePath(file.path(dirname(file_arg), ".."), winslash = "/")
} else {
  normalizePath(".", winslash = "/")
}
setwd(project_root)

submission_dir <- "data/manual/student/model_comparison_submissions"
# list.files() findet alle eingereichten CSV-Dateien, unabhängig vom Dateinamen.
files <- list.files(submission_dir, pattern = "\\.csv$", full.names = TRUE)
if (length(files) == 0) {
  message("Noch keine ausgefüllten Modellvergleichsdateien vorhanden.")
  quit(save = "no", status = 0)
}

reference <- readr::read_csv(
  "data/manual/instructor/model_comparison_reference.csv",
  show_col_types = FALSE,
  locale = readr::locale(encoding = "UTF-8")
)

# Liest genau eine Gruppenabgabe und prüft ihre Struktur, bevor Daten mehrerer
# Gruppen verbunden werden.
read_submission <- function(path) {
  data <- readr::read_csv(
    path,
    show_col_types = FALSE,
    locale = readr::locale(encoding = "UTF-8")
  )
  required_columns <- c(
    "group_id", "model_service", "model_name_displayed", "access_date",
    "prompt_changed", "unit_id", "llm_label", "llm_confidence",
    "llm_rationale"
  )
  # Jede Bedingung schützt vor einem anderen häufigen Eingabefehler:
  # fehlende Spalten, falsche Fallzahl, ungültige Labels oder gemischte Modelle.
  if (!all(required_columns %in% names(data)) ||
      nrow(data) != 5L ||
      anyDuplicated(data$unit_id) ||
      !setequal(data$unit_id, reference$unit_id) ||
      any(!data$llm_label %in% c(0, 1)) ||
      any(data$llm_confidence < 0 | data$llm_confidence > 1) ||
      dplyr::n_distinct(data$group_id) != 1L ||
      dplyr::n_distinct(data$model_service) != 1L ||
      dplyr::n_distinct(data$model_name_displayed) != 1L) {
    stop("Ungültige Gruppenabgabe: ", path)
  }
  dplyr::mutate(data, submission_file = basename(path))
}

# lapply() wendet die geprüfte Lesefunktion auf jede Datei an; bind_rows()
# setzt die fünfzeiligen Gruppenabgaben untereinander.
submissions <- dplyr::bind_rows(lapply(files, read_submission))
# Der Join ergänzt zu jedem studentischen Modelllabel die Referenz und das
# klassische ML-Ergebnis desselben Falls.
scored <- submissions |>
  dplyr::left_join(
    reference |>
      dplyr::select(
        unit_id,
        reference_label,
        ml_probability,
        ml_label
      ),
    by = "unit_id"
  ) |>
  dplyr::mutate(
    llm_correct = llm_label == reference_label,
    llm_error = dplyr::case_when(
      reference_label == 0L & llm_label == 1L ~ "False Positive",
      reference_label == 1L & llm_label == 0L ~ "False Negative",
      TRUE ~ "korrekt"
    )
  )

# Eine Ergebniszeile je Gruppe und verwendetem Chatmodell.
llm_metrics <- scored |>
  dplyr::group_by(
    group_id,
    model_service,
    model_name_displayed,
    access_date,
    prompt_changed
  ) |>
  dplyr::summarise(
    method = paste(model_service, model_name_displayed, sep = ": "),
    n = dplyr::n(),
    correct = sum(llm_correct),
    accuracy = mean(llm_correct),
    false_positive = sum(llm_error == "False Positive"),
    false_negative = sum(llm_error == "False Negative"),
    .groups = "drop"
  )

# Das klassische ML wird auf denselben fünf Fällen als zusätzliche Methode
# zusammengefasst, damit der Vergleich dieselbe Grundgesamtheit verwendet.
ml_metrics <- reference |>
  dplyr::summarise(
    group_id = "–",
    model_service = "Klassisches ML",
    model_name_displayed = "TF-IDF + logistische Regression",
    access_date = as.Date(NA),
    prompt_changed = FALSE,
    method = "Klassisches ML: TF-IDF + logistische Regression",
    n = dplyr::n(),
    correct = sum(ml_label == reference_label),
    accuracy = mean(ml_label == reference_label),
    false_positive = sum(reference_label == 0L & ml_label == 1L),
    false_negative = sum(reference_label == 1L & ml_label == 0L)
  )

# Beide Methodentypen erhalten dieselbe Spaltenstruktur.
metrics <- dplyr::bind_rows(ml_metrics, llm_metrics)

readr::write_csv(
  metrics,
  "output/tables/classroom_model_comparison_metrics.csv",
  na = ""
)
readr::write_csv(
  scored,
  "output/tables/classroom_model_comparison_scored.csv",
  na = ""
)

message(
  "Modellvergleich ausgewertet: ",
  dplyr::n_distinct(scored$group_id), " Gruppenabgaben."
)
