# Phase 1: Buchstabierte Kompetenz-Unterpunkte aus lokalen HTML-Snapshots
# technisch erschließen. In der Vier-Schritt-Logik des Lehrvortrags gehört
# dies zur Digitalisierung; die inhaltliche Text-as-data-Extraktion der
# Zielvariable digital = 0/1 erfolgt erst in späteren Phasen.
# Live-Webseiten werden in diesem Skript nicht abgerufen.
#
# Eingaben:  lokale HTML-Snapshots und ihre Quellenmetadaten
# Ausgaben:  eine Zeile je buchstabiertem Lernziel sowie Diagnostikfälle
# Hinweis:   Der DOM-Parser ist der technisch anspruchsvollste Teil der Übung.
#            Die Hilfsfunktionen zerlegen ihn in kleine, prüfbare Schritte.

options(encoding = "UTF-8")

# Fehlende Pakete werden früh gemeldet, statt erst mitten in der Extraktion.
required <- c("readr", "dplyr", "purrr", "stringr", "rvest", "xml2")
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

dir.create("data/derived", recursive = TRUE, showWarnings = FALSE)
dir.create("output/tables", recursive = TRUE, showWarnings = FALSE)

sources <- readr::read_csv(
  "config/source_urls.csv",
  show_col_types = FALSE,
  locale = readr::locale(encoding = "UTF-8")
)
manifest <- readr::read_csv(
  "raw/html/snapshot_manifest.csv",
  show_col_types = FALSE,
  locale = readr::locale(encoding = "UTF-8")
)

# left_join() ergänzt jede konfigurierte Quelle um Snapshot, Datum und Hash.
# occupation_id ist dabei der gemeinsame Schlüssel beider Tabellen.
source_info <- sources |>
  dplyr::left_join(
    manifest |>
      dplyr::select(
        occupation_id, snapshot_file, retrieval_date, sha256
      ),
    by = "occupation_id"
  )

# Vereinheitlicht nur Leerraum; inhaltliche Wörter werden nicht verändert.
clean_text <- function(x) {
  x |>
    stringr::str_replace_all("\u00a0", " ") |>
    stringr::str_squish()
}

# Liest beispielsweise "Abschnitt B" aus einer Tabellenüberschrift.
section_code_from_caption <- function(caption) {
  code <- stringr::str_match(caption, "Abschnitt\\s+([A-Z])")[, 2]
  dplyr::if_else(is.na(code), "MAIN", code)
}

# Ordnet Tabellen gemeinsamen Inhalten, Fachrichtungen oder
# Wahlqualifikationen zu. Eine list erlaubt zwei Rückgabewerte: type und name.
track_from_caption <- function(caption) {
  if (stringr::str_detect(
    caption,
    stringr::regex("in der Fachrichtung", ignore_case = TRUE)
  )) {
    name <- stringr::str_match(
      caption,
      stringr::regex("in der Fachrichtung\\s+(.+)$", ignore_case = TRUE)
    )[, 2]
    return(list(type = "fachrichtung", name = clean_text(name)))
  }
  if (stringr::str_detect(
    caption,
    stringr::regex("in den Wahlqualifikation", ignore_case = TRUE)
  )) {
    return(list(type = "wahlqualifikation", name = NA_character_))
  }
  list(type = "gemeinsam", name = "gemeinsame Inhalte")
}

# Erzeugt aus Text eine stabile ID-Komponente ohne Leer- oder Sonderzeichen.
safe_id <- function(x) {
  x |>
    stringr::str_to_lower() |>
    stringr::str_replace_all("ä", "ae") |>
    stringr::str_replace_all("ö", "oe") |>
    stringr::str_replace_all("ü", "ue") |>
    stringr::str_replace_all("ß", "ss") |>
    stringr::str_replace_all("[^a-z0-9]+", "_") |>
    stringr::str_replace_all("^_|_$", "")
}

# Verarbeitet eine einzelne HTML-Tabelle.
# Jede reguläre Rückgabezeile entspricht später einem Lernziel; problematische
# Tabellenzeilen werden stattdessen mit diagnostic_type zurückgegeben.
extract_table <- function(
  table,
  table_index,
  source_row,
  caption_override = NA_character_
) {
  caption_node <- rvest::html_element(table, "caption")
  caption <- if (!is.na(caption_override)) {
    caption_override
  } else if (inherits(caption_node, "xml_missing")) {
    "Anlage 1: Ausbildungsrahmenplan"
  } else {
    clean_text(rvest::html_text2(caption_node))
  }
  section_code <- section_code_from_caption(caption)
  track <- track_from_caption(caption)

  # CSS-Selektor "tbody > tr" meint direkte Tabellenzeilen im Tabellenkörper.
  rows <- rvest::html_elements(table, "tbody > tr")
  last_position_number <- ""
  last_unit_name <- ""

  # imap_dfr() durchläuft alle Zeilen, kennt zusätzlich ihren Index und setzt
  # die resultierenden kleinen Tabellen anschließend untereinander.
  purrr::imap_dfr(rows, function(row, row_index) {
    cells <- rvest::html_elements(row, xpath = "./td")

    # In den amtlichen HTML-Seiten stehen Buchstaben in <dt> und Texte in <dd>.
    cells_with_items <- vapply(cells, function(cell) {
      length(rvest::html_elements(cell, "dt")) > 0
    }, logical(1))

    if (!any(cells_with_items)) {
      return(tibble::tibble(
        diagnostic_type = "row_without_lettered_items",
        occupation_id = source_row$occupation_id,
        source_table = table_index,
        source_row = row_index,
        section = caption
      ))
    }

    competence_index <- which(cells_with_items)[[1]]
    competence_cell <- cells[[competence_index]]
    metadata_cells <- if (competence_index > 1) {
      cells[seq_len(competence_index - 1)]
    } else {
      cells[0]
    }
    metadata_text <- if (length(metadata_cells) > 0) {
      clean_text(rvest::html_text2(metadata_cells))
    } else {
      character()
    }

    position_number_raw <- ""
    unit_name_raw <- ""
    if (length(metadata_text) >= 2) {
      position_number_raw <- metadata_text[[1]]
      unit_name_raw <- metadata_text[[2]]
    } else if (length(metadata_text) == 1) {
      if (stringr::str_detect(metadata_text, "^\\d+(?:\\.\\d+)?$")) {
        position_number_raw <- metadata_text
      } else {
        unit_name_raw <- metadata_text
      }
    }
    metadata_carried <- !nzchar(position_number_raw) || !nzchar(unit_name_raw)

    # Bei HTML-rowspan erscheinen Positionsdaten nur in der ersten Zeile.
    # <<- aktualisiert hier bewusst die zuletzt bekannten Werte der äußeren
    # Funktion, damit Folgezeilen dieselbe Berufsbildposition erhalten.
    if (nzchar(position_number_raw)) {
      last_position_number <<- position_number_raw
    }
    if (nzchar(unit_name_raw)) {
      last_unit_name <<- unit_name_raw
    }
    position_number <- last_position_number
    unit_name <- last_unit_name

    if (!nzchar(position_number) || !nzchar(unit_name)) {
      return(tibble::tibble(
        diagnostic_type = "row_without_position_metadata",
        occupation_id = source_row$occupation_id,
        source_table = table_index,
        source_row = row_index,
        section = caption
      ))
    }

    # Labels und Texte werden getrennt gelesen und anschließend positionsweise
    # zusammengeführt. Unterschiedliche Anzahlen wären ein Parsingfehler.
    labels <- competence_cell |>
      rvest::html_elements("dt") |>
      rvest::html_text2() |>
      clean_text()
    items <- competence_cell |>
      rvest::html_elements("dd") |>
      rvest::html_text2() |>
      clean_text()

    # Text vor der Definitionsliste ist bei Formulierungen wie
    # "... beitragen, insbesondere" ein grammatischer Bestandteil aller
    # folgenden Unterpunkte.
    stem_nodes <- rvest::html_elements(
      competence_cell,
      xpath = "./*[not(self::dl)] | ./text()[normalize-space()]"
    )
    stem <- if (length(stem_nodes) == 0) {
      ""
    } else {
      clean_text(paste(rvest::html_text2(stem_nodes), collapse = " "))
    }

    if (length(labels) != length(items) || length(items) == 0) {
      return(tibble::tibble(
        diagnostic_type = ifelse(
          length(items) == 0,
          "row_without_lettered_items",
          "label_item_count_mismatch"
        ),
        occupation_id = source_row$occupation_id,
        source_table = table_index,
        source_row = row_index,
        section = caption,
        position_number = position_number,
        unit_name = unit_name,
        label_count = length(labels),
        item_count = length(items)
      ))
    }

    item_letters <- stringr::str_remove(labels, "\\)$")
    learning_goal <- if (nzchar(stem)) {
      paste(stem, items)
    } else {
      items
    }

    track_name <- if (track$type == "wahlqualifikation") {
      rep(unit_name, length(items))
    } else {
      rep(track$name, length(items))
    }
    note_parts <- c(
      "HTML-dl/dt/dd; whitespace normalized",
      if (nzchar(stem)) "introductory stem prepended",
      if (metadata_carried) {
        "rowspan metadata carried from preceding HTML row"
      }
    )

    # tibble() erzeugt die standardisierte Tabellenstruktur des Datensatzes.
    tibble::tibble(
      diagnostic_type = NA_character_,
      occupation_id = source_row$occupation_id,
      occupation = source_row$occupation,
      order_year = source_row$order_year,
      source_file = source_row$snapshot_file,
      source_url = source_row$extraction_url,
      retrieval_date = source_row$retrieval_date,
      source_sha256 = source_row$sha256,
      source_page = NA_integer_,
      section = caption,
      section_code = section_code,
      track_type = track$type,
      track_name = track_name,
      source_table = table_index,
      source_row = row_index,
      position_number = position_number,
      unit_name = unit_name,
      item_letter = item_letters,
      competency_stem = dplyr::na_if(stem, ""),
      original_item_text = items,
      learning_goal_text = learning_goal,
      extraction_note = paste(note_parts, collapse = "; ")
    )
  })
}

# Wählt aus einem Dokument die Ausbildungsrahmenplan-Tabellen aus und ruft
# extract_table() für jede davon auf.
extract_document <- function(source_row) {
  if (is.na(source_row$snapshot_file) ||
      !file.exists(source_row$snapshot_file)) {
    stop("Snapshot fehlt für ", source_row$occupation_id)
  }

  # Kodierung aus dem HTML-Header erkennen (derzeit ISO-8859-1).
  document <- xml2::read_html(source_row$snapshot_file)
  tables <- rvest::html_elements(document, "table")
  # vapply() liefert hier für jede Tabelle genau TRUE oder FALSE.
  is_curriculum_table <- vapply(tables, function(table) {
    header <- rvest::html_element(table, "thead")
    if (inherits(header, "xml_missing")) {
      return(FALSE)
    }
    stringr::str_detect(
      clean_text(rvest::html_text2(header)),
      "Ausbildungsberufsbild|Berufsbildposition|Wahlqualifikation"
    )
  }, logical(1))
  tables <- tables[is_curriculum_table]

  captions <- vapply(tables, function(table) {
    caption_node <- rvest::html_element(table, "caption")
    if (inherits(caption_node, "xml_missing")) {
      return(NA_character_)
    }
    clean_text(rvest::html_text2(caption_node))
  }, character(1))
  if (length(captions) > 1) {
    for (i in seq_along(captions)[-1]) {
      if (is.na(captions[[i]])) {
        captions[[i]] <- captions[[i - 1]]
      }
    }
  }

  # map2_dfr() läuft parallel über Tabellenindizes und Tabellenüberschriften.
  purrr::map2_dfr(
    seq_along(tables),
    captions,
    ~ extract_table(tables[[.x]], .x, source_row, .y)
  )
}

# Die fünf Dokumentergebnisse werden zu einer Tabelle zusammengesetzt.
all_extracted <- purrr::map_dfr(
  seq_len(nrow(source_info)),
  ~ extract_document(source_info[.x, , drop = FALSE])
)

# Diagnostik und reguläre Daten werden getrennt gespeichert. Dadurch gehen
# problematische Zeilen nicht stillschweigend verloren.
diagnostics <- all_extracted |>
  dplyr::filter(!is.na(diagnostic_type)) |>
  dplyr::select(dplyr::any_of(c(
    "occupation_id", "diagnostic_type", "section", "source_table",
    "source_row", "position_number", "unit_name", "label_count", "item_count"
  )))

units <- all_extracted |>
  dplyr::filter(is.na(diagnostic_type)) |>
  dplyr::select(-diagnostic_type) |>
  dplyr::mutate(
    position_id = safe_id(position_number),
    unit_id = paste(
      occupation_id,
      stringr::str_to_lower(section_code),
      position_id,
      safe_id(item_letter),
      sep = "_"
    ),
    .before = occupation_id
  ) |>
  dplyr::select(-position_id) |>
  dplyr::arrange(
    occupation_id, source_table, source_row, item_letter
  )

# unit_id ist der Primärschlüssel. Doppelte IDs würden spätere Joins verfälschen.
duplicate_ids <- units |>
  dplyr::count(unit_id, name = "n") |>
  dplyr::filter(n > 1)
if (nrow(duplicate_ids) > 0) {
  readr::write_csv(
    duplicate_ids,
    "output/tables/duplicate_unit_ids.csv",
    na = ""
  )
  stop(
    "Nicht eindeutige unit_id; siehe output/tables/duplicate_unit_ids.csv"
  )
}

readr::write_csv(
  units,
  "data/derived/curriculum_units.csv",
  na = ""
)
readr::write_csv(
  diagnostics,
  "output/tables/extraction_diagnostics.csv",
  na = ""
)

message(
  nrow(units), " Kompetenzzeilen extrahiert; ",
  nrow(diagnostics), " Tabellenzeilen als Diagnostik zurückgestellt."
)
