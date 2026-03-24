#' Extract theoretical frameworks from a single introduction text
#'
#' Combines [build_prompt()] and [call_model()] into a single call. Returns a
#' validated, parsed list matching the output schema. On JSON parse failure the
#' raw response is preserved in the `raw_response` attribute so nothing is lost.
#'
#' @param text Character scalar. The article introduction text.
#' @param model Character scalar. Ollama model name (default from config).
#' @param log_file Character scalar or NULL. Path to `.jsonl` log file.
#' @param .verbose Logical. If `TRUE` (default), prints progress to console.
#'
#' @return A named list with elements:
#'   - `explicit_theories`: list of named-theory objects
#'   - `implicit_theories`: list of inferred-theory objects
#'   - `no_theory_present`: logical
#'   - `extraction_error`: logical (TRUE only when JSON parsing failed)
#'   - `raw_response`: the raw character string from the model (always stored)
#'
#' @examples
#' \dontrun{
#' intro <- "This study examines burnout in youth athletes through the lens of
#'   Self-Determination Theory (Deci & Ryan, 1985), which posits that
#'   satisfaction of basic psychological needs predicts motivation quality."
#'
#' result <- extract_theory(intro)
#' str(result)
#' }
#'
#' @export
extract_theory <- function(text,
                           model    = NULL,
                           log_file = NULL,
                           .verbose = TRUE) {

  prompt   <- build_prompt(text)
  raw_text <- call_model(prompt, model = model, log_file = log_file)

  parsed <- .safe_parse_json(raw_text)

  if (is.null(parsed)) {
    result <- .null_result()
  } else {
    # Handle v1 schema (explicit_theories / implicit_theories)
    # and v2/v3 schema (theories[] with type field)
    if (!is.null(parsed$theories)) {
      all_theories      <- parsed$theories
      explicit_theories <- Filter(function(t) identical(t$type, "explicit"), all_theories)
      implicit_theories <- Filter(function(t) identical(t$type, "implicit"), all_theories)
      # Normalise implicit entries to unified field names for flatten_results()
      implicit_theories <- lapply(implicit_theories, function(t) {
        list(inferred_name               = t$name,
             justification               = t$tested_prediction              %||% NA_character_,
             confidence                  = t$confidence,
             role                        = t$role                           %||% NA_character_,
             theory_type                 = t$theory_type                    %||% NA_character_,
             prediction_strength         = t$prediction_strength            %||% NA_character_,
             boundary_conditions_met     = t$boundary_conditions_met        %||% NA_character_,
             rival_theories_acknowledged = t$rival_theories_acknowledged    %||% FALSE)
      })
      # Carry v3/v4 fields through for explicit theories too
      explicit_theories <- lapply(explicit_theories, function(t) {
        t$prediction_strength           <- t$prediction_strength            %||% NA_character_
        t$theory_type                   <- t$theory_type                    %||% NA_character_
        t$boundary_conditions_met       <- t$boundary_conditions_met        %||% NA_character_
        t$rival_theories_acknowledged   <- t$rival_theories_acknowledged    %||% FALSE
        t
      })
    } else {
      explicit_theories <- parsed$explicit_theories %||% list()
      implicit_theories <- parsed$implicit_theories %||% list()
    }

    result <- list(
      explicit_theories          = explicit_theories,
      implicit_theories          = implicit_theories,
      no_theory_present          = parsed$no_theory_present          %||% NA,
      intended_as_atheoretical   = parsed$intended_as_atheoretical   %||% NA,
      multi_theory_coherence     = parsed$multi_theory_coherence     %||% NA_character_,
      theoretical_basis_quality  = parsed$theoretical_basis_quality  %||% NA_character_,
      extraction_error           = FALSE
    )
  }

  result$raw_response <- raw_text
  result
}


#' Batch extract theoretical frameworks from a data frame
#'
#' Applies [extract_theory()] to every row of `df`, reading introduction text
#' from `text_column`. Returns `df` with three new columns appended:
#' `explicit_theories`, `implicit_theories`, and `no_theory_present`.
#' Failed rows are filled with `NA` without stopping the pipeline.
#'
#' @param df A data frame or tibble.
#' @param text_column Character scalar. Name of the column containing
#'   introduction text.
#' @param id_column Character scalar or NULL. Optional column to use as a row
#'   identifier in log messages (e.g. `"article_id"`).
#' @param model Character scalar. Ollama model name (default from config).
#' @param log_file Character scalar or NULL. Path to `.jsonl` log file.
#'   Recommended for batch runs.
#' @param .progress Logical. Show a progress bar (default `TRUE`).
#'
#' @return The original `df` with columns added:
#'   - `theory_explicit`: list-column, each element is the `explicit_theories`
#'     list from [extract_theory()]
#'   - `theory_implicit`: list-column, each element is the `implicit_theories`
#'     list
#'   - `theory_none`: logical, value of `no_theory_present`
#'   - `theory_error`: logical, `TRUE` if extraction failed for that row
#'
#' @examples
#' \dontrun{
#' articles_df <- tibble::tibble(
#'   article_id = c("A1", "A2"),
#'   introduction = c(
#'     "Self-Determination Theory underpinned our hypotheses...",
#'     "Participants completed a 5 km time trial."
#'   )
#' )
#' results <- batch_extract(articles_df, text_column = "introduction",
#'                          id_column = "article_id",
#'                          log_file = "extraction_log.jsonl")
#' }
#'
#' @export
batch_extract <- function(df,
                          text_column,
                          id_column   = NULL,
                          model       = NULL,
                          log_file    = NULL,
                          .progress   = TRUE) {

  if (!is.data.frame(df)) {
    cli::cli_abort("{.arg df} must be a data frame or tibble.")
  }
  if (!text_column %in% names(df)) {
    cli::cli_abort(
      "Column {.val {text_column}} not found in {.arg df}. \\
      Available columns: {.val {names(df)}}"
    )
  }

  texts <- df[[text_column]]
  n     <- nrow(df)

  cli::cli_inform(c(
    "i" = "Starting batch extraction for {n} articles.",
    "i" = "Model: {.val {model %||% .get_config()$model$name}}"
  ))

  results <- purrr::imap(
    texts,
    function(text, idx) {
      row_id <- if (!is.null(id_column) && id_column %in% names(df)) {
        as.character(df[[id_column]][idx])
      } else {
        as.character(idx)
      }

      if (.progress) {
        message(sprintf("[%d/%d] %s", idx, n, row_id))
      }

      if (is.na(text) || !nzchar(stringr::str_trim(as.character(text)))) {
        cli::cli_warn("Row {row_id}: empty text — skipping.")
        return(.null_result())
      }

      tryCatch(
        extract_theory(text, model = model, log_file = log_file, .verbose = FALSE),
        error = function(e) {
          cli::cli_warn("Row {row_id} failed: {conditionMessage(e)}")
          .null_result()
        }
      )
    }
  )

  df$theory_explicit            <- purrr::map(results, "explicit_theories")
  df$theory_implicit            <- purrr::map(results, "implicit_theories")
  df$theory_none                <- purrr::map_lgl(results, ~ isTRUE(.x$no_theory_present))
  df$theory_atheoretical        <- purrr::map_lgl(results, ~ isTRUE(.x$intended_as_atheoretical))
  df$multi_theory_coherence     <- purrr::map_chr(results, ~ .x$multi_theory_coherence    %||% NA_character_)
  df$theory_error               <- purrr::map_lgl(results, ~ isTRUE(.x$extraction_error))
  df$theory_raw_response        <- purrr::map_chr(results, ~ .x$raw_response              %||% NA_character_)
  df$theoretical_basis_quality  <- purrr::map_chr(results, ~ .x$theoretical_basis_quality %||% NA_character_)

  n_errors <- sum(df$theory_error, na.rm = TRUE)
  if (n_errors > 0) {
    cli::cli_warn("{n_errors} row(s) failed extraction. Check {.field theory_error} column.")
  }

  cli::cli_inform(c("v" = "Batch complete. {n - n_errors}/{n} rows extracted successfully."))

  df
}


#' Flatten batch results into a tidy long-format data frame
#'
#' Unnests the list-columns produced by [batch_extract()] into one row per
#' detected theory, making it straightforward to count, tabulate, and export.
#'
#' @param df Data frame output from [batch_extract()].
#' @param id_column Character scalar or NULL. Column(s) to carry through as
#'   identifiers (e.g. `"article_id"`).
#'
#' @return A tibble with one row per detected theory and columns:
#'   `article_id` (if supplied), `detection_type` ("explicit" | "implicit"),
#'   `name`, `theory_framework_type` ("causal" | "taxonomic" | "mathematical" | "paradigm"),
#'   `role` ("operational" | "contextual"), `tested_prediction`, `prediction_strength`,
#'   `boundary_conditions_met`, `rival_theories_acknowledged`, `justification` (implicit only),
#'   `confidence`.
#'
#' @export
flatten_results <- function(df, id_column = NULL) {

  rows <- purrr::imap_dfr(seq_len(nrow(df)), function(i, ...) {
    id_val <- if (!is.null(id_column) && id_column %in% names(df)) {
      df[[id_column]][i]
    } else {
      i
    }

    explicit <- df$theory_explicit[[i]]
    implicit <- df$theory_implicit[[i]]

    exp_rows <- if (length(explicit) > 0) {
      purrr::map_dfr(explicit, function(t) {
        tibble::tibble(
          article_id                  = as.character(id_val),
          detection_type              = "explicit",
          name                        = t$name                        %||% NA_character_,
          theory_framework_type       = t$theory_type                 %||% NA_character_,
          role                        = t$role                        %||% NA_character_,
          tested_prediction           = t$tested_prediction           %||% NA_character_,
          prediction_strength         = t$prediction_strength         %||% NA_character_,
          boundary_conditions_met     = t$boundary_conditions_met     %||% NA_character_,
          rival_theories_acknowledged = t$rival_theories_acknowledged %||% FALSE,
          justification               = NA_character_,
          confidence                  = t$confidence                  %||% NA_real_
        )
      })
    } else {
      NULL
    }

    imp_rows <- if (length(implicit) > 0) {
      purrr::map_dfr(implicit, function(t) {
        tibble::tibble(
          article_id                  = as.character(id_val),
          detection_type              = "implicit",
          name                        = t$inferred_name               %||% NA_character_,
          theory_framework_type       = t$theory_type                 %||% NA_character_,
          role                        = t$role                        %||% NA_character_,
          tested_prediction           = t$justification               %||% NA_character_,
          prediction_strength         = t$prediction_strength         %||% NA_character_,
          boundary_conditions_met     = t$boundary_conditions_met     %||% NA_character_,
          rival_theories_acknowledged = t$rival_theories_acknowledged %||% FALSE,
          justification               = t$justification               %||% NA_character_,
          confidence                  = t$confidence                  %||% NA_real_
        )
      })
    } else {
      NULL
    }

    dplyr::bind_rows(exp_rows, imp_rows)
  })

  rows
}
