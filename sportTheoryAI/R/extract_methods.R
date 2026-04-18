#' Assess construct validity alignment from a single article's methods section
#'
#' Sends the methods section text, together with the theories and tested
#' predictions from Pass 1, to the LLM and returns a structured assessment
#' of whether the operational measures correspond to the theoretical constructs.
#'
#' This is Pass 4 of the extraction pipeline. It addresses the construct
#' validity problem (Borsboom et al., 2004): a study that cites a causal
#' theory but measures different constructs than the theory specifies is not
#' a genuine test of that theory.
#'
#' @param text Character scalar. The methods section text.
#' @param theories Character vector. Theory names from Pass 1.
#' @param tested_predictions Character vector. Tested predictions from Pass 1.
#' @param model Character scalar. Ollama model name (default from config).
#' @param log_file Character scalar or NULL. Path to `.jsonl` log file.
#'
#' @return A named list with elements:
#'   - `construct_validity_alignment`: "aligned" | "partial" | "misaligned" | "unclear" | "not_applicable"
#'   - `alignment_rationale`: character
#'   - `mechanism_operationalisation`: "mechanism_measured" | "endpoints_only" | "not_applicable"
#'   - `mechanism_operationalisation_detail`: character or NA
#'   - `population_boundary_fit`: "within" | "outside" | "unclear"
#'   - `population_boundary_rationale`: character
#'   - `methods_extraction_error`: logical
#'   - `raw_response`: raw model response
#'
#' @export
extract_methods_validity <- function(text,
                                     theories           = character(0),
                                     tested_predictions = character(0),
                                     mechanism_context  = NULL,
                                     model              = NULL,
                                     log_file           = NULL) {

  cfg           <- .get_config()
  backend       <- getOption("sportTheoryAI.backend", default = "ollama")

  template_name <- if (identical(backend, "claude") &&
                       !is.null(cfg$claude$prompts$methods_extraction)) {
    cfg$claude$prompts$methods_extraction
  } else if (identical(backend, "kimi") &&
             !is.null(cfg$kimi$prompts$methods_extraction)) {
    cfg$kimi$prompts$methods_extraction
  } else if (identical(backend, "deepseek") &&
             !is.null(cfg$deepseek$prompts$methods_extraction)) {
    cfg$deepseek$prompts$methods_extraction
  } else {
    cfg$claude$prompts$methods_extraction
  }

  template_path <- .resolve_template_path(template_name)
  template <- paste(readLines(template_path, encoding = "UTF-8"), collapse = "\n")

  theory_list <- if (length(theories) > 0 && any(nzchar(theories))) {
    paste(paste0("- ", theories[nzchar(theories)]), collapse = "\n")
  } else {
    "None identified"
  }

  predictions_list <- if (length(tested_predictions) > 0 && any(nzchar(tested_predictions))) {
    paste(paste0("- ", tested_predictions[nzchar(tested_predictions)]), collapse = "\n")
  } else {
    "None identified"
  }

  # v5 templates support mechanism context from Pass 2
  mech_ctx <- mechanism_context %||% "Not available"

  prompt <- template |>
    stringr::str_replace("\\{\\{THEORY_LIST\\}\\}",        theory_list) |>
    stringr::str_replace("\\{\\{TESTED_PREDICTIONS\\}\\}", predictions_list) |>
    stringr::str_replace("\\{\\{MECHANISM_CONTEXT\\}\\}",  mech_ctx) |>
    stringr::str_replace("\\{\\{METHODS_TEXT\\}\\}",       text)

  raw_text <- call_model(prompt, model = model, log_file = log_file)
  parsed   <- .safe_parse_json(raw_text)

  if (is.null(parsed)) {
    result <- list(
      construct_validity_alignment       = NA_character_,
      alignment_rationale                = NA_character_,
      mechanism_operationalisation       = NA_character_,
      mechanism_operationalisation_detail = NA_character_,
      population_boundary_fit            = NA_character_,
      population_boundary_rationale      = NA_character_,
      methods_extraction_error           = TRUE
    )
  } else {
    result <- list(
      construct_validity_alignment        = parsed$construct_validity_alignment        %||% NA_character_,
      alignment_rationale                 = parsed$alignment_rationale                 %||% NA_character_,
      mechanism_operationalisation        = parsed$mechanism_operationalisation        %||% NA_character_,
      mechanism_operationalisation_detail = parsed$mechanism_operationalisation_detail %||% NA_character_,
      population_boundary_fit             = parsed$population_boundary_fit             %||% NA_character_,
      population_boundary_rationale       = parsed$population_boundary_rationale       %||% NA_character_,
      methods_extraction_error            = FALSE
    )
  }

  result$raw_response <- raw_text
  result
}


#' Batch assess construct validity across a data frame
#'
#' Applies [extract_methods_validity()] to every row of `df`, reading methods
#' text from `text_column`. Returns `df` with construct validity columns appended.
#'
#' @param df Data frame containing methods section text and theory names.
#' @param text_column Column name containing methods section text.
#' @param theory_column Optional list-column of extracted theories.
#' @param id_column Optional column name to use as row identifier.
#' @param model Character scalar. Ollama model name.
#' @param log_file Path to `.jsonl` log file.
#' @param .progress Logical. Print progress messages.
#'
#' @return `df` with columns added:
#'   - `meth_cv_alignment`: "aligned" | "partial" | "misaligned" | "unclear" | "not_applicable"
#'   - `meth_cv_rationale`: character
#'   - `meth_mechanism_operationalised`: "mechanism_measured" | "endpoints_only" | "not_applicable"
#'   - `meth_mechanism_detail`: character
#'   - `meth_population_fit`: "within" | "outside" | "unclear"
#'   - `meth_population_rationale`: character
#'   - `meth_error`: logical
#'
#' @export
batch_extract_methods <- function(df,
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

    tested_preds <- if ("theory_explicit" %in% names(df)) {
      exp <- df$theory_explicit[[idx]]
      if (is.list(exp) && length(exp) > 0) {
        preds <- purrr::map_chr(exp, ~ .x$tested_prediction %||% "")
        preds[nzchar(preds)]
      } else character(0)
    } else character(0)

    if (is.na(text) || !nzchar(stringr::str_trim(as.character(text)))) {
      cli::cli_warn("Row {row_id}: empty methods text — skipping.")
      return(list(
        construct_validity_alignment = NA_character_, alignment_rationale = NA_character_,
        mechanism_operationalisation = NA_character_, mechanism_operationalisation_detail = NA_character_,
        population_boundary_fit = NA_character_, population_boundary_rationale = NA_character_,
        methods_extraction_error = TRUE
      ))
    }

    tryCatch(
      extract_methods_validity(text, theories = theories, tested_predictions = tested_preds,
                                model = model, log_file = log_file),
      error = function(e) {
        cli::cli_warn("Row {row_id} methods extraction failed: {conditionMessage(e)}")
        list(
          construct_validity_alignment = NA_character_, alignment_rationale = NA_character_,
          mechanism_operationalisation = NA_character_, mechanism_operationalisation_detail = NA_character_,
          population_boundary_fit = NA_character_, population_boundary_rationale = NA_character_,
          methods_extraction_error = TRUE
        )
      }
    )
  })

  df$meth_cv_alignment            <- purrr::map_chr(results, ~ .x$construct_validity_alignment        %||% NA_character_)
  df$meth_cv_rationale            <- purrr::map_chr(results, ~ .x$alignment_rationale                 %||% NA_character_)
  df$meth_mechanism_operationalised <- purrr::map_chr(results, ~ .x$mechanism_operationalisation      %||% NA_character_)
  df$meth_mechanism_detail        <- purrr::map_chr(results, ~ .x$mechanism_operationalisation_detail %||% NA_character_)
  df$meth_population_fit          <- purrr::map_chr(results, ~ .x$population_boundary_fit             %||% NA_character_)
  df$meth_population_rationale    <- purrr::map_chr(results, ~ .x$population_boundary_rationale       %||% NA_character_)
  df$meth_error                   <- purrr::map_lgl(results, ~ isTRUE(.x$methods_extraction_error))
  df$meth_raw_response            <- purrr::map_chr(results, ~ .x$raw_response                        %||% NA_character_)

  cli::cli_inform(c("v" = "Methods validity extraction complete. {sum(!df$meth_error)}/{n} rows succeeded."))
  df
}
