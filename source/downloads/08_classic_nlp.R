# Phase 4: Didaktisch transparente TF-IDF-Klassifikation.
# Das Modell nutzt ausschließlich die geprüfte 60-Zeilen-Referenzstichprobe.
#
# Datenfluss:
# Text -> Tokens -> TF-IDF-Matrix -> regularisierte logistische Regression
#      -> Wahrscheinlichkeit -> Label bei einer Schwelle von 0,5
#
# Die Funktionen sind bewusst mit Basis-R umgesetzt. So bleiben die einzelnen
# Rechenschritte sichtbar, auch wenn produktive NLP-Projekte dafür meist
# spezialisierte Modellpakete verwenden.

options(encoding = "UTF-8")

required <- c("readr", "dplyr", "stringr")
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

# Im internen Projekt wird die vollständige Dozierendendatei verwendet. Das
# öffentliche Selbstlernprojekt enthält stattdessen nur die für die
# Modellschätzung erforderlichen Analysevariablen.
reference_path <- if (
  file.exists("data/manual/instructor/instructor_reference_template.csv")
) {
  "data/manual/instructor/instructor_reference_template.csv"
} else {
  "data/model/modeling_data.csv"
}

# Jede Zeile ist ein Beobachtungsfall; reference_label ist die Zielvariable.
reference <- readr::read_csv(
  reference_path,
  show_col_types = FALSE,
  locale = readr::locale(encoding = "UTF-8")
) |>
  dplyr::filter(!is.na(reference_label)) |>
  dplyr::mutate(
    # Das Modell erhält denselben dokumentierten Kontext wie die Handkodierung.
    reference_label = as.integer(reference_label),
    model_text = paste(occupation, unit_name, learning_goal_text, sep = " | ")
  )

curriculum <- readr::read_csv(
  "data/derived/curriculum_units.csv",
  show_col_types = FALSE,
  locale = readr::locale(encoding = "UTF-8")
) |>
  dplyr::mutate(
    model_text = paste(occupation, unit_name, learning_goal_text, sep = " | ")
  )

if (nrow(reference) != 60L ||
    any(!reference$reference_label %in% c(0L, 1L)) ||
    anyDuplicated(reference$unit_id)) {
  stop("Die Referenzkodierung ist unvollständig oder formal ungültig.")
}

# Kleine, fest eingebaute Liste häufiger deutscher Funktionswörter.
german_stopwords <- c(
  "aber", "alle", "allem", "allen", "aller", "alles", "als", "also", "am",
  "an", "ander", "andere", "anderem", "anderen", "anderer", "anderes",
  "auch", "auf", "aus", "bei", "beim", "bin", "bis", "bist", "da", "damit",
  "dann", "das", "dass", "dazu", "dem", "den", "denn", "der", "des", "die",
  "dies", "diese", "diesem", "diesen", "dieser", "dieses", "doch", "durch",
  "ein", "eine", "einem", "einen", "einer", "eines", "er", "es", "etwas",
  "für", "gegen", "hat", "haben", "hier", "ich", "im", "in", "ins", "ist",
  "ja", "jede", "jedem", "jeden", "jeder", "jedes", "kann", "kein", "keine",
  "mit", "nach", "nicht", "noch", "nur", "ob", "oder", "ohne", "sein",
  "seine", "sich", "sie", "sind", "so", "sowie", "über", "um", "und",
  "unter", "vom", "von", "vor", "war", "was", "wenn", "werden", "wie",
  "wieder", "wir", "wird", "wo", "zu", "zum", "zur"
)

# Zerlegt einen Text in kleingeschriebene Wörter mit mindestens drei
# Buchstaben und entfernt häufige Funktionswörter.
tokenize <- function(text) {
  tokens <- stringr::str_extract_all(
    stringr::str_to_lower(text, locale = "de"),
    "\\p{L}{3,}"
  )[[1]]
  tokens[!tokens %in% german_stopwords]
}

# Lernt Vokabular und IDF-Gewichte ausschließlich aus Trainingsdokumenten.
# Das verhindert, dass Informationen aus der Testmenge in das Modell gelangen.
fit_vectorizer <- function(text, min_document_frequency = 2L) {
  tokens <- lapply(text, tokenize)
  # Dokumenthäufigkeit: In wie vielen verschiedenen Texten kommt ein Wort vor?
  document_frequency <- sort(
    table(unlist(lapply(tokens, unique), use.names = FALSE)),
    decreasing = TRUE
  )
  document_frequency <- document_frequency[
    document_frequency >= min_document_frequency
  ]
  vocabulary <- names(document_frequency)
  if (length(vocabulary) == 0) {
    stop("Nach der Mindesthäufigkeit sind keine Textmerkmale übrig.")
  }
  # Seltene Wörter erhalten ein höheres inverse-document-frequency-Gewicht.
  idf <- log((1 + length(text)) / (1 + as.numeric(document_frequency))) + 1
  names(idf) <- vocabulary
  list(vocabulary = vocabulary, idf = idf)
}

# Wandelt Texte in eine numerische Matrix um:
# Zeilen = Kompetenztexte, Spalten = Wörter, Zellen = TF-IDF-Werte.
transform_tfidf <- function(text, vectorizer) {
  vocabulary <- vectorizer$vocabulary
  matrix <- matrix(
    0,
    nrow = length(text),
    ncol = length(vocabulary),
    dimnames = list(NULL, vocabulary)
  )
  for (i in seq_along(text)) {
    # match() ordnet Tokens den Spalten des Trainingsvokabulars zu.
    matched <- match(tokenize(text[[i]]), vocabulary, nomatch = 0L)
    counts <- tabulate(matched[matched > 0L], nbins = length(vocabulary))
    if (sum(counts) > 0) {
      matrix[i, ] <- counts / sum(counts)
    }
  }
  sweep(matrix, 2, vectorizer$idf[vocabulary], `*`)
}

# Numerisch stabile Hilfsfunktion für die logistische Verlustfunktion.
softplus <- function(x) {
  ifelse(x > 0, x + log1p(exp(-x)), log1p(exp(x)))
}

# Schätzt eine logistische Regression. Ridge bestraft sehr große
# Koeffizienten und stabilisiert das Modell bei wenigen Fällen und vielen Wörtern.
fit_ridge_logistic <- function(x, y, lambda = 1) {
  initial_intercept <- stats::qlogis((sum(y) + 0.5) / (length(y) + 1))
  initial <- c(initial_intercept, rep(0, ncol(x)))

  # objective() ist die zu minimierende Summe aus Fehlanpassung und Ridge-Strafe.
  objective <- function(parameters) {
    intercept <- parameters[[1]]
    coefficients <- parameters[-1]
    eta <- as.vector(intercept + x %*% coefficients)
    sum(softplus(eta) - y * eta) +
      lambda * sum(coefficients^2) / 2
  }

  # Der Gradient beschreibt die Steigung der Zielfunktion für optim().
  gradient <- function(parameters) {
    intercept <- parameters[[1]]
    coefficients <- parameters[-1]
    error <- stats::plogis(as.vector(intercept + x %*% coefficients)) - y
    c(sum(error), as.vector(crossprod(x, error)) + lambda * coefficients)
  }

  # optim() sucht iterativ nach den Parametern mit kleinstem Verlust.
  result <- stats::optim(
    initial,
    objective,
    gradient,
    method = "BFGS",
    control = list(maxit = 1000, reltol = 1e-10)
  )
  if (result$convergence != 0) {
    stop("Die logistische Regression ist nicht konvergiert.")
  }
  list(
    intercept = result$par[[1]],
    coefficients = result$par[-1],
    lambda = lambda,
    convergence = result$convergence
  )
}

# plogis() überführt lineare Modellwerte in Wahrscheinlichkeiten von 0 bis 1.
predict_probability <- function(model, x) {
  stats::plogis(as.vector(model$intercept + x %*% model$coefficients))
}

# Kapselt die vollständige Trainieren-und-Vorhersagen-Pipeline.
fit_and_predict <- function(training, test, lambda = 1) {
  vectorizer <- fit_vectorizer(training$model_text)
  x_train <- transform_tfidf(training$model_text, vectorizer)
  x_test <- transform_tfidf(test$model_text, vectorizer)
  model <- fit_ridge_logistic(
    x_train,
    training$reference_label,
    lambda = lambda
  )
  model$feature <- colnames(x_train)
  probability <- predict_probability(model, x_test)
  list(
    probability = probability,
    prediction = as.integer(probability >= 0.5),
    model = model,
    vectorizer = vectorizer
  )
}

# Berechnet die Konfusionsmatrix und daraus Accuracy, Precision, Recall und F1.
# Nenner von 0 werden als NA statt als irreführende Zahl behandelt.
classification_metrics <- function(truth, prediction, evaluation) {
  tp <- sum(truth == 1L & prediction == 1L)
  tn <- sum(truth == 0L & prediction == 0L)
  fp <- sum(truth == 0L & prediction == 1L)
  fn <- sum(truth == 1L & prediction == 0L)
  precision <- if ((tp + fp) == 0) NA_real_ else tp / (tp + fp)
  recall <- if ((tp + fn) == 0) NA_real_ else tp / (tp + fn)
  f1 <- if (is.na(precision) || is.na(recall) || (precision + recall) == 0) {
    NA_real_
  } else {
    2 * precision * recall / (precision + recall)
  }
  data.frame(
    evaluation = evaluation,
    n = length(truth),
    accuracy = (tp + tn) / length(truth),
    precision = precision,
    recall = recall,
    f1 = f1,
    true_positive = tp,
    true_negative = tn,
    false_positive = fp,
    false_negative = fn
  )
}

# Markiert jede einzelne Vorhersage als korrekt, False Positive oder
# False Negative. Das ermöglicht die anschließende inhaltliche Fehleranalyse.
add_error_type <- function(data) {
  dplyr::mutate(
    data,
    error_type = dplyr::case_when(
      reference_label == 0L & model_label == 1L ~ "False Positive",
      reference_label == 1L & model_label == 0L ~ "False Negative",
      TRUE ~ "korrekt"
    )
  )
}

# Zehn vorab zurückgehaltene Testfälle: je Beruf ein positives und ein
# negatives Beispiel. Dies macht Fehler beider Klassen sichtbar, bildet aber
# nicht deren Häufigkeit im Korpus ab.
set.seed(20260703)
test_ids <- reference |>
  dplyr::group_by(occupation) |>
  dplyr::group_modify(function(.x, .y) {
    dplyr::bind_rows(
      dplyr::slice_sample(dplyr::filter(.x, reference_label == 1L), n = 1L),
      dplyr::slice_sample(dplyr::filter(.x, reference_label == 0L), n = 1L)
    )
  }) |>
  dplyr::ungroup() |>
  dplyr::pull(unit_id)

training <- dplyr::filter(reference, !unit_id %in% test_ids)
test <- dplyr::filter(reference, unit_id %in% test_ids)

holdout_fit <- fit_and_predict(training, test)
# transmute() baut eine kompakte Ergebnistabelle aus Testdaten und Vorhersagen.
holdout_predictions <- test |>
  dplyr::transmute(
    unit_id,
    occupation,
    unit_name,
    learning_goal_text,
    reference_label,
    model_probability = holdout_fit$probability,
    model_label = holdout_fit$prediction
  ) |>
  add_error_type()

# Jeder Beruf wird einmal vollständig zurückgehalten. So kann das Modell den
# Testberuf und seine Labels während des jeweiligen Trainings nicht sehen.
# lapply() wiederholt denselben Ablauf für jeden der fünf Testberufe.
logo_predictions <- lapply(unique(reference$occupation), function(test_occupation) {
  logo_training <- dplyr::filter(reference, occupation != test_occupation)
  logo_test <- dplyr::filter(reference, occupation == test_occupation)
  logo_fit <- fit_and_predict(logo_training, logo_test)
  logo_test |>
    dplyr::transmute(
      unit_id,
      occupation,
      unit_name,
      learning_goal_text,
      reference_label,
      model_probability = logo_fit$probability,
      model_label = logo_fit$prediction
    ) |>
    add_error_type()
}) |>
  dplyr::bind_rows()

# Nach der getrennten Evaluation wird das Modell auf allen 60
# Referenzkodierungen trainiert und auf den vollständigen Korpus angewandt.
# Diese Vorhersagen dienen der deskriptiven Auswertung, nicht der Gütemessung.
full_fit <- fit_and_predict(reference, curriculum)

all_predictions <- curriculum |>
  dplyr::transmute(
    unit_id,
    occupation_id,
    occupation,
    section,
    track_type,
    track_name,
    unit_name,
    learning_goal_text,
    model_probability = full_fit$probability,
    model_label = full_fit$prediction
  )

all_predictions_summary <- all_predictions |>
  dplyr::group_by(occupation) |>
  dplyr::summarise(
    competency_rows = dplyr::n(),
    predicted_digital = sum(model_label),
    predicted_digital_share = mean(model_label),
    .groups = "drop"
  ) |>
  dplyr::arrange(occupation)

# bind_rows() stellt beide Evaluationsdesigns in einer gemeinsamen Tabelle dar.
metrics <- dplyr::bind_rows(
  classification_metrics(
    holdout_predictions$reference_label,
    holdout_predictions$model_label,
    "stratifizierte Testmenge"
  ),
  classification_metrics(
    logo_predictions$reference_label,
    logo_predictions$model_label,
    "Leave-one-occupation-out"
  )
)

confusion <- dplyr::bind_rows(
  holdout_predictions |>
    dplyr::count(reference_label, model_label, name = "n") |>
    dplyr::mutate(evaluation = "stratifizierte Testmenge"),
  logo_predictions |>
    dplyr::count(reference_label, model_label, name = "n") |>
    dplyr::mutate(evaluation = "Leave-one-occupation-out")
) |>
  dplyr::select(evaluation, reference_label, model_label, n)

# Vorzeichen und Betrag der Koeffizienten zeigen, welche Wörter die
# Klassifikation in welche Richtung treiben.
feature_coefficients <- data.frame(
  feature = holdout_fit$model$feature,
  coefficient = holdout_fit$model$coefficients
) |>
  dplyr::mutate(
    direction = ifelse(
      coefficient >= 0,
      "spricht eher für digital",
      "spricht eher gegen digital"
    )
  ) |>
  dplyr::arrange(dplyr::desc(abs(coefficient)))

# Für die Fehlerdatei werden nur falsch klassifizierte Fälle aufbewahrt.
error_analysis <- dplyr::bind_rows(
  dplyr::mutate(holdout_predictions, evaluation = "stratifizierte Testmenge"),
  dplyr::mutate(logo_predictions, evaluation = "Leave-one-occupation-out")
) |>
  dplyr::filter(error_type != "korrekt") |>
  dplyr::select(
    evaluation,
    unit_id,
    occupation,
    learning_goal_text,
    reference_label,
    model_probability,
    model_label,
    error_type
  )

# Abgeleitete Vorhersagen und Auswertungstabellen bleiben getrennt von
# Rohdaten und manuellen Labels.
readr::write_csv(
  holdout_predictions,
  "data/derived/classic_nlp_holdout_predictions.csv",
  na = ""
)
readr::write_csv(
  logo_predictions,
  "data/derived/classic_nlp_logo_predictions.csv",
  na = ""
)
readr::write_csv(
  all_predictions,
  "data/derived/classic_nlp_all_predictions.csv",
  na = ""
)
readr::write_csv(
  metrics,
  "output/tables/classic_nlp_metrics.csv",
  na = ""
)
readr::write_csv(
  confusion,
  "output/tables/classic_nlp_confusion_matrix.csv",
  na = ""
)
readr::write_csv(
  feature_coefficients,
  "output/tables/classic_nlp_feature_coefficients.csv",
  na = ""
)
readr::write_csv(
  error_analysis,
  "output/tables/classic_nlp_error_analysis.csv",
  na = ""
)
readr::write_csv(
  all_predictions_summary,
  "output/tables/classic_nlp_all_predictions_summary.csv",
  na = ""
)
readr::write_csv(
  data.frame(
    training_rows = nrow(training),
    test_rows = nrow(test),
    test_positive = sum(test$reference_label == 1L),
    test_negative = sum(test$reference_label == 0L),
    vocabulary_size = length(holdout_fit$vectorizer$vocabulary),
    minimum_document_frequency = 2L,
    ridge_lambda = holdout_fit$model$lambda,
    classification_threshold = 0.5
  ),
  "output/tables/classic_nlp_run_summary.csv",
  na = ""
)

message(
  "Klassisches ML abgeschlossen: ", nrow(training), " Trainingsfälle, ",
  nrow(test), " Testfälle, ",
  length(holdout_fit$vectorizer$vocabulary), " TF-IDF-Merkmale und ",
  nrow(all_predictions), " Korpusvorhersagen."
)
