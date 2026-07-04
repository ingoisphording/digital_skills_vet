# Einmalige Einrichtung für die lokal ausführbare Quarto-Übung.
#
# Öffnen Sie diese Datei in RStudio und führen Sie den gesamten Inhalt aus.
# Es werden nur Pakete installiert, die auf Ihrem Rechner noch fehlen.

required_packages <- c("readr", "dplyr", "knitr", "stringr")
missing_packages <- setdiff(
  required_packages,
  rownames(installed.packages())
)

if (length(missing_packages) > 0) {
  install.packages(missing_packages)
} else {
  message("Alle benötigten R-Pakete sind bereits installiert.")
}
