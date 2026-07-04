# Phase 1: Amtliche HTML-Anlagen unverändert lokal sichern.
#
# Eingabe:  config/source_urls.csv
# Ausgaben: raw/html/*.html, data/extracted/full_text/*.txt und ein Manifest
# Eine Funktion erledigt den Ablauf für einen Beruf; Map() wendet sie später
# auf alle Berufe an.

options(encoding = "UTF-8")

# requireNamespace() prüft Pakete, ohne sie an den globalen Suchpfad zu hängen.
required <- c("readr", "dplyr", "httr2", "digest", "rvest", "xml2")
missing <- required[!vapply(required, requireNamespace, logical(1), quietly = TRUE)]
if (length(missing) > 0) {
  stop("Fehlende R-Pakete: ", paste(missing, collapse = ", "))
}

# Der folgende Block setzt unabhängig vom Startort den Projektordner als
# Arbeitsverzeichnis. Relative Pfade beziehen sich danach immer auf Uebung/.
args <- commandArgs(trailingOnly = FALSE)
file_arg <- sub("^--file=", "", grep("^--file=", args, value = TRUE))
project_root <- if (length(file_arg) == 1) {
  normalizePath(file.path(dirname(file_arg), ".."), winslash = "/")
} else {
  normalizePath(".", winslash = "/")
}
setwd(project_root)

dir.create("raw/html", recursive = TRUE, showWarnings = FALSE)
dir.create("data/extracted/full_text", recursive = TRUE, showWarnings = FALSE)

sources <- readr::read_csv(
  "config/source_urls.csv",
  show_col_types = FALSE,
  locale = readr::locale(encoding = "UTF-8")
)

# Lädt genau eine Quelle oder verwendet einen vorhandenen Snapshot.
# Rückgabewert ist eine einzeilige Tabelle mit Herkunfts- und Prüfinformationen.
download_one <- function(occupation_id, extraction_url, access_date) {
  snapshot_name <- paste0(occupation_id, "__", access_date, ".html")
  snapshot_path <- file.path("raw/html", snapshot_name)
  text_path <- file.path(
    "data/extracted/full_text",
    sub("\\.html$", ".txt", snapshot_name)
  )

  if (file.exists(snapshot_path)) {
    # Bereits vorhandene Rohdaten werden nicht erneut heruntergeladen.
    status <- 200L
    content_type <- "text/html (cached)"
    retrieval_status <- "cached"
    retrieved_at <- file.info(snapshot_path)$mtime
  } else {
    # request() baut die Anfrage schrittweise auf; req_perform() sendet sie.
    response <- httr2::request(extraction_url) |>
      httr2::req_user_agent("digital-skills-vet teaching exercise") |>
      httr2::req_timeout(30) |>
      httr2::req_perform()

    status <- httr2::resp_status(response)
    if (status != 200L) {
      stop("HTTP-Status ", status, " für ", extraction_url)
    }

    content_type <- httr2::resp_header(response, "content-type")
    writeBin(httr2::resp_body_raw(response), snapshot_path)
    retrieval_status <- "downloaded"
    retrieved_at <- Sys.time()
  }

  # Die Klartextdatei dient nur der Sichtprüfung. Der Parser liest den
  # unveränderten HTML-Snapshot.
  # Die amtlichen Seiten deklarieren derzeit ISO-8859-1. Ohne erzwungene
  # Kodierung übernimmt libxml2 die Deklaration aus dem HTML-Header.
  document <- xml2::read_html(snapshot_path)
  full_text <- rvest::html_element(document, "body") |>
    rvest::html_text2()
  writeLines(enc2utf8(full_text), text_path, useBytes = TRUE)

  # Der Hash macht spätere Änderungen am gespeicherten Snapshot erkennbar.
  data.frame(
    occupation_id = occupation_id,
    source_url = extraction_url,
    retrieval_date = as.character(access_date),
    retrieved_at_utc = format(retrieved_at, tz = "UTC", usetz = TRUE),
    retrieval_status = retrieval_status,
    http_status = status,
    content_type = content_type,
    snapshot_file = gsub("\\\\", "/", snapshot_path),
    snapshot_bytes = file.info(snapshot_path)$size,
    sha256 = digest::digest(snapshot_path, algo = "sha256", file = TRUE),
    stringsAsFactors = FALSE
  )
}

# Map() ruft download_one() elementweise mit den drei gleich langen Spalten auf.
# bind_rows() setzt die fünf einzeiligen Ergebnisse untereinander.
manifest <- Map(
  download_one,
  sources$occupation_id,
  sources$extraction_url,
  sources$access_date
) |>
  dplyr::bind_rows()

readr::write_csv(manifest, "raw/html/snapshot_manifest.csv", na = "")

message(
  "HTML-Snapshots: ",
  sum(manifest$retrieval_status == "downloaded"), " neu, ",
  sum(manifest$retrieval_status == "cached"), " aus Cache."
)
