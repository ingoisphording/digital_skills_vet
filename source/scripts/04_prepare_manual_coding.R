# Phase 3: Zufallsstichprobe und leere Kodiermasken vorbereiten.
# Bestehende manuell ausgefüllte Vorlagen werden niemals überschrieben.
#
# Eingabe:  vollständiger Datensatz der Kompetenzzeilen
# Ausgaben: 60 Fälle sowie getrennte Vorlagen für Studierende und Dozierende

options(encoding = "UTF-8")

required <- c("readr", "dplyr")
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

dir.create("data/manual/student", recursive = TRUE, showWarnings = FALSE)
dir.create("data/manual/instructor", recursive = TRUE, showWarnings = FALSE)
dir.create("data/derived", recursive = TRUE, showWarnings = FALSE)

curriculum <- readr::read_csv(
  "data/derived/curriculum_units.csv",
  show_col_types = FALSE,
  locale = readr::locale(encoding = "UTF-8")
)

# Der Seed hält die Auswahl über wiederholte Durchläufe konstant.
set.seed(20260703)

coding_sample <- curriculum |>
  # Zwölf Fälle innerhalb jedes der fünf Berufe ergeben insgesamt 60 Fälle.
  dplyr::group_by(occupation_id) |>
  dplyr::slice_sample(n = 12L) |>
  dplyr::ungroup() |>
  dplyr::arrange(occupation_id, unit_id) |>
  dplyr::select(
    unit_id,
    occupation_id,
    occupation,
    order_year,
    section,
    track_type,
    track_name,
    position_number,
    unit_name,
    item_letter,
    learning_goal_text,
    source_url,
    source_table,
    source_row
  )

if (nrow(coding_sample) != 60L ||
    dplyr::n_distinct(coding_sample$occupation_id) != 5L ||
    anyDuplicated(coding_sample$unit_id)) {
  stop("Die Kodierstichprobe erfüllt die vorgesehenen Strukturregeln nicht.")
}

readr::write_csv(
  coding_sample,
  "data/derived/manual_coding_sample.csv",
  na = ""
)

# NA bedeutet "noch nicht ausgefüllt". Die Typen integer, double und character
# verhindern später uneindeutige Eingaben.
student_template <- coding_sample |>
  dplyr::transmute(
    coder_id = NA_character_,
    unit_id,
    occupation,
    section,
    track_type,
    track_name,
    unit_name,
    learning_goal_text,
    student_label = NA_integer_,
    student_confidence = NA_real_,
    student_rationale = NA_character_
  )

# Die Referenz wird getrennt gehalten, damit sie studentische Entscheidungen
# nicht vorab beeinflusst.
reference_template <- coding_sample |>
  dplyr::transmute(
    unit_id,
    occupation,
    section,
    track_type,
    track_name,
    unit_name,
    learning_goal_text,
    reference_label = NA_integer_,
    reference_confidence = NA_real_,
    reference_rationale = NA_character_,
    reference_coder = NA_character_,
    reference_date = as.Date(NA)
  )

# Schreibt eine neue Vorlage oder gleicht nur ihre Struktur ab. Bereits
# eingetragene manuelle Werte werden anhand der unveränderten unit_id erhalten.
write_template_once <- function(data, path) {
  if (file.exists(path)) {
    existing <- readr::read_csv(
      path,
      show_col_types = FALSE,
      locale = readr::locale(encoding = "UTF-8")
    )
    if (!identical(existing$unit_id, data$unit_id)) {
      stop(
        "Bestehende Vorlage hat andere unit_id und wurde nicht verändert: ",
        path
      )
    }
    # setdiff() findet Spalten, die in der gewünschten Struktur noch fehlen.
    missing_columns <- setdiff(names(data), names(existing))
    for (column in missing_columns) {
      existing[[column]] <- data[[column]]
    }
    existing <- existing[, names(data)]
    readr::write_csv(existing, path, na = "")
    message("Vorhandene manuelle Felder erhalten: ", path)
  } else {
    readr::write_csv(data, path, na = "")
    message("Vorlage erzeugt: ", path)
  }
}

write_template_once(
  student_template,
  "data/manual/student/student_coding_template.csv"
)
write_template_once(
  reference_template,
  "data/manual/instructor/instructor_reference_template.csv"
)

summary <- coding_sample |>
  dplyr::count(
    occupation_id, occupation, track_type,
    name = "n_coding_units"
  ) |>
  dplyr::arrange(occupation_id, track_type)

readr::write_csv(
  summary,
  "output/tables/manual_coding_sample_summary.csv",
  na = ""
)

message("Kodierstichprobe: 60 Zeilen, davon 12 je Beruf.")
