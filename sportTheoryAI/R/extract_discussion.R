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
#'   - `claims_beyond_hypothesis`: logical
#'   - `beyond_hypothesis_detail`: character or NA
#'   - `discussion_quality`: "strong" | "adequate" | "weak"
#'   - `extraction_error`: logical
#'   - `raw_response`: raw model response
#'
#' @export
extract_discussion <- function(text,
                               theories = character(0),
                               model    = NULL,
                               log_file = NULL) {

  cfg           <- .get_config()
  template_name <- cfg$prompts$discussion_analysis
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

  prompt <- template |>
    stringr::str_replace("\\{\\{THEORY_LIST\\}\\}",    theory_list) |>
    stringr::str_replace("\\{\\{DISCUSSION_TEXT\\}\\}", text)

  raw_text <- call_model(prompt, model = model, log_file = log_file)
  parsed   <- .safe_parse_json(raw_text)

  if (is.null(parsed)) {
    result <- list(
      theory_reengagement              = NA_character_,
      reengagement_evidence            = NA_character_,
      theories_mentioned_in_discussion = character(0),
      claims_beyond_hypothesis         = NA,
      beyond_hypothesis_detail         = NA_character_,
      discussion_quality               = NA_character_,
      extraction_error                 = TRUE
    )
  } else {
    result <- list(
      theory_reengagement              = parsed$theory_reengagement              %||% NA_character_,
      reengagement_evidence            = parsed$reengagement_evidence            %||% NA_character_,
      theories_mentioned_in_discussion = unlist(parsed$theories_mentioned_in_discussion) %||% character(0),
      claims_beyond_hypothesis         = parsed$claims_beyond_hypothesis         %||% NA,
      beyond_hypothesis_detail         = parsed$beyond_hypothesis_detail         %||% NA_character_,
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
#'   - `disc_overclaim`: logical
#'   - `disc_overclaim_detail`: character
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

    if (is.na(text) || !nzchar(stringr::str_trim(as.character(text)))) {
      cli::cli_warn("Row {row_id}: empty discussion text — skipping.")
      return(list(theory_reengagement = NA_character_, reengagement_evidence = NA_character_,
                  claims_beyond_hypothesis = NA, beyond_hypothesis_detail = NA_character_,
                  discussion_quality = NA_character_, extraction_error = TRUE))
    }

    tryCatch(
      extract_discussion(text, theories = theories, model = model, log_file = log_file),
      error = function(e) {
        cli::cli_warn("Row {row_id} discussion extraction failed: {conditionMessage(e)}")
        list(theory_reengagement = NA_character_, reengagement_evidence = NA_character_,
             claims_beyond_hypothesis = NA, beyond_hypothesis_detail = NA_character_,
             discussion_quality = NA_character_, extraction_error = TRUE)
      }
    )
  })

  df$disc_reengagement    <- purrr::map_chr(results, ~ .x$theory_reengagement      %||% NA_character_)
  df$disc_evidence        <- purrr::map_chr(results, ~ .x$reengagement_evidence     %||% NA_character_)
  df$disc_overclaim       <- purrr::map_lgl(results, ~ isTRUE(.x$claims_beyond_hypothesis))
  df$disc_overclaim_detail <- purrr::map_chr(results, ~ .x$beyond_hypothesis_detail %||% NA_character_)
  df$disc_quality         <- purrr::map_chr(results, ~ .x$discussion_quality        %||% NA_character_)
  df$disc_error           <- purrr::map_lgl(results, ~ isTRUE(.x$extraction_error))

  cli::cli_inform(c("v" = "Discussion extraction complete. {sum(!df$disc_error)}/{n} rows succeeded."))
  df
}
