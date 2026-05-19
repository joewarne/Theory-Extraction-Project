#' Analyse the discussion section for theory re-engagement
#'
#' Sends the discussion text and the list of theories from the introduction
#' to the LLM and returns a structured assessment of whether the authors
#' reconnect their results to the theoretical framework.
#'
#' @param text Character scalar. The discussion section text.
#' @param theories Character vector. Theory names from the introduction
#'   (output of [extract_theory()] or [batch_extract_v2()]).
#' @param model Character scalar. Ollama model name (default from config).
#' @param log_file Character scalar or NULL. Path to `.jsonl` log file.
#'
#' @return A named list with elements:
#'   - `theory_reengagement`: "full" | "partial" | "absent"
#'   - `reengagement_evidence`: character
#'   - `theories_mentioned_in_discussion`: character vector
#'   - `theory_revision_signal`: "none" | "refined" | "partially_disconfirming" | "new_prediction_generated"
#'   - `theory_revision_detail`: character or NA
#'   - `claims_beyond_hypothesis`: logical
#'   - `beyond_hypothesis_detail`: character or NA
#'   - `null_result_present`: logical
#'   - `null_result_handling`: "accepted_as_disconfirming" | "auxiliary_hypothesis" | "methodological_artefact" | "not_addressed" | "not_applicable"
#'   - `study_positioning`: "novel_prediction" | "replication" | "extension" | "boundary_test" | "unclear"
#'   - `discussion_quality`: "strong" | "adequate" | "weak"
#'   - `extraction_error`: logical
#'   - `raw_response`: raw model response
#'
#' @export
extract_discussion <- function(text,
                               theories           = character(0),
                               tested_predictions = character(0),
                               hypothesis_context = NULL,
                               model              = NULL,
                               log_file           = NULL) {

  cfg           <- .get_config()
  backend       <- getOption("sportTheoryAI.backend", default = "ollama")

  template_name <- if (identical(backend, "claude") &&
                       !is.null(cfg$claude$prompts$discussion_analysis)) {
    cfg$claude$prompts$discussion_analysis
  } else if (identical(backend, "kimi") &&
             !is.null(cfg$kimi$prompts$discussion_analysis)) {
    cfg$kimi$prompts$discussion_analysis
  } else if (identical(backend, "deepseek") &&
             !is.null(cfg$deepseek$prompts$discussion_analysis)) {
    cfg$deepseek$prompts$discussion_analysis
  } else {
    cfg$claude$prompts$discussion_analysis
  }

  template_path <- .resolve_template_path(template_name)
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

  # v5 templates support additional context from prior passes
  theory_details <- attr(theories, "details") %||% "Not available"
  hyp_ctx        <- hypothesis_context %||% "Not available"

  prompt <- template |>
    stringr::str_replace("\\{\\{THEORY_LIST\\}\\}",         theory_list) |>
    stringr::str_replace("\\{\\{THEORY_DETAILS\\}\\}",      theory_details) |>
    stringr::str_replace("\\{\\{HYPOTHESIS_CONTEXT\\}\\}",  hyp_ctx) |>
    stringr::str_replace("\\{\\{TESTED_PREDICTIONS\\}\\}",  predictions_list) |>
    stringr::str_replace("\\{\\{DISCUSSION_TEXT\\}\\}",     text)

  raw_text <- call_model(prompt, model = model, log_file = log_file)
  parsed   <- .safe_parse_json(raw_text)

  if (is.null(parsed)) {
    result <- list(
      theory_reengagement              = NA_character_,
      reengagement_evidence            = NA_character_,
      theories_mentioned_in_discussion = character(0),
      theory_revision_signal           = NA_character_,
      theory_revision_detail           = NA_character_,
      new_prediction_generated         = NA,
      new_prediction_detail            = NA_character_,
      claims_beyond_hypothesis         = NA,
      beyond_hypothesis_detail         = NA_character_,
      null_result_present              = NA,
      null_result_handling             = NA_character_,
      study_positioning                = NA_character_,
      discussion_quality               = NA_character_,
      extraction_error                 = TRUE
    )
  } else {
    result <- list(
      theory_reengagement              = parsed$theory_reengagement              %||% NA_character_,
      reengagement_evidence            = parsed$reengagement_evidence            %||% NA_character_,
      theories_mentioned_in_discussion = unlist(parsed$theories_mentioned_in_discussion) %||% character(0),
      theory_revision_signal           = parsed$theory_revision_signal           %||% NA_character_,
      theory_revision_detail           = parsed$theory_revision_detail           %||% NA_character_,
      new_prediction_generated         = parsed$new_prediction_generated         %||% NA,
      new_prediction_detail            = parsed$new_prediction_detail            %||% NA_character_,
      claims_beyond_hypothesis         = parsed$claims_beyond_hypothesis         %||% NA,
      beyond_hypothesis_detail         = parsed$beyond_hypothesis_detail         %||% NA_character_,
      null_result_present              = parsed$null_result_present              %||% NA,
      null_result_handling             = parsed$null_result_handling             %||% NA_character_,
      study_positioning                = parsed$study_positioning                %||% NA_character_,
      discussion_quality               = parsed$discussion_quality               %||% NA_character_,
      extraction_error                 = FALSE
    )
  }

  result$raw_response <- raw_text
  result
}


#' Batch analyse discussion sections across a data frame
#'
#' @param df Data frame containing discussion text and theory names.
#' @param text_column Column name containing discussion section text.
#' @param theory_column Optional list-column of extracted theories to pass
#'   as context. If NULL, the model receives no theory list.
#' @param id_column Optional column name to use as row identifier in logs.
#' @param model Character scalar. Ollama model name.
#' @param log_file Path to `.jsonl` log file.
#' @param .progress Logical. Print progress messages.
#'
#' @return `df` with columns added:
#'   - `disc_reengagement`: "full" | "partial" | "absent"
#'   - `disc_evidence`: character
#'   - `disc_revision_signal`: "none" | "refined" | "partially_disconfirming" | "new_prediction_generated"
#'   - `disc_revision_detail`: character
#'   - `disc_overclaim`: logical
#'   - `disc_overclaim_detail`: character
#'   - `disc_null_present`: logical
#'   - `disc_null_handling`: character
#'   - `disc_positioning`: character
#'   - `disc_quality`: "strong" | "adequate" | "weak"
#'   - `disc_error`: logical
#'
#' @export
batch_extract_discussion <- function(df,
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

    .disc_null <- list(
      theory_reengagement      = NA_character_, reengagement_evidence    = NA_character_,
      theory_revision_signal   = NA_character_, theory_revision_detail   = NA_character_,
      new_prediction_generated = NA,            new_prediction_detail    = NA_character_,
      claims_beyond_hypothesis = NA,            beyond_hypothesis_detail = NA_character_,
      null_result_present      = NA,            null_result_handling     = NA_character_,
      study_positioning        = NA_character_, discussion_quality       = NA_character_,
      extraction_error         = TRUE
    )

    if (is.na(text) || !nzchar(stringr::str_trim(as.character(text)))) {
      cli::cli_warn("Row {row_id}: empty discussion text — skipping.")
      return(.disc_null)
    }

    tryCatch(
      extract_discussion(text, theories = theories, tested_predictions = tested_preds,
                         model = model, log_file = log_file),
      error = function(e) {
        cli::cli_warn("Row {row_id} discussion extraction failed: {conditionMessage(e)}")
        .disc_null
      }
    )
  })

  df$disc_reengagement       <- purrr::map_chr(results, ~ .x$theory_reengagement        %||% NA_character_)
  df$disc_evidence           <- purrr::map_chr(results, ~ .x$reengagement_evidence       %||% NA_character_)
  df$disc_revision_signal    <- purrr::map_chr(results, ~ .x$theory_revision_signal     %||% NA_character_)
  df$disc_revision_detail    <- purrr::map_chr(results, ~ .x$theory_revision_detail     %||% NA_character_)
  df$disc_new_prediction     <- purrr::map_lgl(results, ~ isTRUE(.x$new_prediction_generated))
  df$disc_new_prediction_detail <- purrr::map_chr(results, ~ .x$new_prediction_detail   %||% NA_character_)
  df$disc_overclaim          <- purrr::map_lgl(results, ~ isTRUE(.x$claims_beyond_hypothesis))
  df$disc_overclaim_detail   <- purrr::map_chr(results, ~ .x$beyond_hypothesis_detail   %||% NA_character_)
  df$disc_null_present       <- purrr::map_lgl(results, ~ isTRUE(.x$null_result_present))
  df$disc_null_handling      <- purrr::map_chr(results, ~ .x$null_result_handling        %||% NA_character_)
  df$disc_positioning        <- purrr::map_chr(results, ~ .x$study_positioning           %||% NA_character_)
  df$disc_quality            <- purrr::map_chr(results, ~ .x$discussion_quality          %||% NA_character_)
  df$disc_error              <- purrr::map_lgl(results, ~ isTRUE(.x$extraction_error))
  df$disc_raw_response       <- purrr::map_chr(results, ~ .x$raw_response                %||% NA_character_)

  cli::cli_inform(c("v" = "Discussion extraction complete. {sum(!df$disc_error)}/{n} rows succeeded."))
  df
}
