# Phase 1: deterministische Zufallsstichprobe und einfache Strukturprüfungen.
#
# Das Skript prüft zuerst harte Strukturregeln und erzeugt danach Dateien für
# eine manuelle Sichtprüfung. stop() beendet den Lauf sofort, wenn eine
# Voraussetzung verletzt ist.

options(encoding = "UTF-8")

required <- c("readr", "dplyr", "purrr", "rvest", "xml2")
missing <- required[!vapply(required, requireNamespace, logical(1), quietly = TRUE)]
if (length(missing) > 0) {
  stop("Fehlende R-Pakete: ", paste(missing, collapse = ", "))
}

args <- commandArgs(trailingOnly = FALSE)
file_arg <- sub("^--file=", "", grep("^--file=", args, value = TRUE))
project_root <- if (length(file_arg) == 1) {
  normalizePath(file.path(dirname(file_arg), ".."), winslash = "/")
} else {
  normalizePath(".", winslash = "/")
}
setwd(project_root)

units <- readr::read_csv(
  "data/derived/curriculum_units.csv",
  show_col_types = FALSE,
  locale = readr::locale(encoding = "UTF-8")
)
manifest <- readr::read_csv(
  "raw/html/snapshot_manifest.csv",
  show_col_types = FALSE,
  locale = readr::locale(encoding = "UTF-8")
)

# Ein Vektor mit Pflichtspalten macht die erwartete Datenstruktur explizit.
required_columns <- c(
  "unit_id", "occupation_id", "occupation", "order_year", "source_file",
  "source_url", "source_page", "section", "unit_name",
  "learning_goal_text", "extraction_note"
)
missing_columns <- setdiff(required_columns, names(units))
if (length(missing_columns) > 0) {
  stop("Fehlende Variablen: ", paste(missing_columns, collapse = ", "))
}
# anyDuplicated() liefert 0, wenn kein Wert doppelt vorkommt.
if (anyDuplicated(units$unit_id)) {
  stop("unit_id ist nicht eindeutig.")
}
if (any(is.na(units$learning_goal_text) | units$learning_goal_text == "")) {
  stop("Leere Kompetenztexte gefunden.")
}
if (dplyr::n_distinct(units$occupation_id) != 5L) {
  stop("Der Datensatz enthält nicht genau fünf Berufe.")
}

# Unabhängiger Vollständigkeitstest: Jede in den Snapshots vorhandene
# dt/dd-Kompetenz muss genau eine Zeile im Datensatz ergeben.
source_item_counts <- manifest |>
  dplyr::transmute(
    occupation_id,
    source_dt_items = purrr::map_int(snapshot_file, function(path) {
      document <- xml2::read_html(path)
      length(rvest::html_elements(document, "table dt"))
    })
  ) |>
  dplyr::left_join(
    units |>
      dplyr::count(occupation_id, name = "extracted_units"),
    by = "occupation_id"
  ) |>
  dplyr::mutate(
    counts_match = source_dt_items == extracted_units
  )

if (!all(source_item_counts$counts_match)) {
  stop("Nicht alle HTML-dt-Elemente wurden genau einmal extrahiert.")
}

# Ein fester Seed macht eine Zufallsstichprobe reproduzierbar.
set.seed(20260702)
audit <- units |>
  # Zuerst nach Beruf gruppieren, dann innerhalb jeder Gruppe fünf Fälle ziehen.
  dplyr::group_by(occupation_id) |>
  dplyr::slice_sample(n = 5L) |>
  dplyr::ungroup() |>
  dplyr::arrange(occupation_id, unit_id) |>
  # Leere Auditfelder sind für die spätere manuelle Prüfung vorgesehen.
  dplyr::transmute(
    unit_id,
    occupation,
    section,
    track_type,
    track_name,
    position_number,
    unit_name,
    item_letter,
    competency_stem,
    original_item_text,
    learning_goal_text,
    source_url,
    source_file,
    source_table,
    source_row,
    extraction_note,
    audit_matches_source = NA,
    audit_note = NA_character_
  )

# Diese Aggregation beschreibt den Umfang nach Beruf und Inhaltstyp.
summary <- units |>
  dplyr::count(
    occupation_id, occupation, track_type,
    name = "n_competency_lines"
  ) |>
  dplyr::arrange(occupation_id, track_type)

readr::write_csv(
  audit,
  "data/derived/extraction_audit_sample.csv",
  na = ""
)
readr::write_csv(
  summary,
  "output/tables/extraction_summary.csv",
  na = ""
)
readr::write_csv(
  source_item_counts,
  "output/tables/source_item_count_check.csv",
  na = ""
)

message(
  "Prüfstichprobe mit ", nrow(audit),
  " Zeilen erzeugt (Seed 20260702)."
)
