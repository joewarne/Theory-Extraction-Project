#' Extract hypotheses and assess theory-hypothesis linkage for a single article
#'
#' Sends the introduction text and previously extracted theory list to the LLM
#' and returns a structured assessment of how well stated hypotheses are
#' grounded in the identified theories.
#'
#' @param text Character scalar. The introduction text.
#' @param theories Character vector. Theory names already extracted (from
#'   [extract_theory()] or [batch_extract_v2()]). Used to guide the model.
#' @param model Character scalar. Ollama model name (default from config).
#' @param log_file Character scalar or NULL. Path to `.jsonl` log file.
#'
#' @return A named list with elements:
#'   - `hypotheses`: list of hypothesis objects
#'   - `no_hypothesis_present`: logical
#'   - `hypothesis_theory_alignment`: "strong" | "partial" | "absent"
#'   - `extraction_error`: logical
#'   - `raw_response`: raw model response
#'
#' @export
extract_hypotheses <- function(text,
                               theories          = character(0),
                               tested_predictions = character(0),
                               model             = NULL,
                               log_file          = NULL) {

  cfg           <- .get_config()
  template_name <- cfg$prompts$hypothesis_extraction
  template_path <- system.file(
    file.path("prompt_templates", template_name),
    package = "sportTheoryAI"
  )
  if (!nzchar(template_path) || !file.exists(template_path)) {
    template_path <- here::here("sportTheoryAI", "inst", "prompt_templates", template_name)
  }

  template <- paste(readLines(template_path, encoding = "UTF-8"), collapse = "\n")

  theory_list <- if (length(theories) > 0) {
    paste(paste0("- ", theories), collapse = "\n")
  } else {
    "None identified"
  }

  predictions_list <- if (length(tested_predictions) > 0 && any(nzchar(tested_predictions))) {
    paste(paste0("- ", tested_predictions[nzchar(tested_predictions)]), collapse = "\n")
  } else {
    "None identified"
  }

  prompt <- template |>
    stringr::str_replace("\\{\\{THEORY_LIST\\}\\}",         theory_list) |>
    stringr::str_replace("\\{\\{TESTED_PREDICTIONS\\}\\}",  predictions_list) |>
    stringr::str_replace("\\{\\{INTRODUCTION_TEXT\\}\\}",   text)

  raw_text <- call_model(prompt, model = model, log_file = log_file)
  parsed   <- .safe_parse_json(raw_text)

  if (is.null(parsed)) {
    result <- list(
      hypotheses                = list(),
      no_hypothesis_present     = NA,
      hypothesis_theory_alignment = NA_character_,
      extraction_error          = TRUE
    )
  } else {
    result <- list(
      hypotheses                  = parsed$hypotheses                  %||% list(),
      no_hypothesis_present       = parsed$no_hypothesis_present       %||% NA,
      hypothesis_theory_alignment = parsed$hypothesis_theory_alignment %||% NA_character_,
      extraction_error            = FALSE
    )
  }

  result$raw_response <- raw_text
  result
}


#' Batch extract hypotheses across a data frame
#'
#' @param df Data frame containing introduction text and extracted theory names.
#' @param text_column Column name containing introduction text.
#' @param theory_column Column name containing theory names as a list-column
#'   (e.g., output of [batch_extract_v2()]). Optional — pass NULL to skip.
#' @param id_column Optional column name to use as row identifier in logs.
#' @param model Character scalar. Ollama model name.
#' @param log_file Path to `.jsonl` log file.
#' @param .progress Logical. Print progress messages.
#'
#' @return `df` with columns added:
#'   - `hyp_hypotheses`: list-column
#'   - `hyp_no_hypothesis`: logical
#'   - `hyp_alignment`: character ("strong" | "partial" | "absent")
#'   - `hyp_error`: logical
#'
#' @export
batch_extract_hypotheses <- function(df,
                                     text_column,
                                     theory_column = NULL,
                                     id_column     = NULL,
                                     model         = NULL,
                                     log_file      = NULL,
                                     .progress     = TRUE) {

  texts <- df[[text_column]]
  n     <- nrow(df)

  results <- purrr::imap(texts, function(text, idx) {
    row_id <- if (!is.null(id_column) && id_column %in% names(df)) {
      as.character(df[[id_column]][idx])
    } else as.character(idx)

    if (.progress) message(sprintf("[%d/%d] %s", idx, n, row_id))

    theories <- if (!is.null(theory_column) && theory_column %in% names(df)) {
      th <- df[[theory_column]][[idx]]
      if (is.list(th)) purrr::map_chr(th, ~ .x$name %||% "") else as.character(th)
    } else character(0)

    theories <- theories[nzchar(theories)]

    # Extract tested_predictions from theory_explicit list-column (v3 schema)
    tested_preds <- if ("theory_explicit" %in% names(df)) {
      exp <- df$theory_explicit[[idx]]
      if (is.list(exp) && length(exp) > 0) {
        preds <- purrr::map_chr(exp, ~ .x$tested_prediction %||% "")
        preds[nzchar(preds)]
      } else character(0)
    } else character(0)

    if (is.na(text) || !nzchar(stringr::str_trim(as.character(text)))) {
      return(list(hypotheses = list(), no_hypothesis_present = NA,
                  hypothesis_theory_alignment = NA_character_, extraction_error = TRUE))
    }

    tryCatch(
      extract_hypotheses(text, theories = theories, tested_predictions = tested_preds,
                         model = model, log_file = log_file),
      error = function(e) {
        cli::cli_warn("Row {row_id} hypothesis extraction failed: {conditionMessage(e)}")
        list(hypotheses = list(), no_hypothesis_present = NA,
             hypothesis_theory_alignment = NA_character_, extraction_error = TRUE)
      }
    )
  })

  df$hyp_hypotheses    <- purrr::map(results, "hypotheses")
  df$hyp_no_hypothesis <- purrr::map_lgl(results, ~ isTRUE(.x$no_hypothesis_present))
  df$hyp_alignment     <- purrr::map_chr(results, ~ .x$hypothesis_theory_alignment %||% NA_character_)
  df$hyp_error         <- purrr::map_lgl(results, ~ isTRUE(.x$extraction_error))
  df$hyp_raw_response  <- purrr::map_chr(results, ~ .x$raw_response %||% NA_character_)

  cli::cli_inform(c("v" = "Hypothesis extraction complete. {sum(!df$hyp_error)}/{n} rows succeeded."))
  df
}


#' Flatten hypothesis results to a tidy long-format table
#'
#' @param df Data frame output from [batch_extract_hypotheses()].
#' @param id_column Column name to carry through as identifier.
#'
#' @return A tibble with one row per hypothesis.
#'
#' @export
flatten_hypotheses <- function(df, id_column = NULL) {
  purrr::imap_dfr(seq_len(nrow(df)), function(i, ...) {
    id_val <- if (!is.null(id_column) && id_column %in% names(df)) {
      df[[id_column]][i]
    } else i

    hyps <- df$hyp_hypotheses[[i]]
    if (length(hyps) == 0) return(NULL)

    purrr::map_dfr(hyps, function(h) {
      tibble::tibble(
        article_id             = as.character(id_val),
        hypothesis_text        = h$hypothesis_text        %||% NA_character_,
        linked_theory          = h$linked_theory          %||% NA_character_,
        linkage_strength       = h$linkage_strength       %||% NA_character_,
        inference_type         = h$inference_type         %||% NA_character_,
        mechanism_specified    = h$mechanism_specified    %||% NA,
        mechanism_description  = h$mechanism_description %||% NA_character_,
        linkage_explanation    = h$linkage_explanation    %||% NA_character_
      )
    })
  })
}
