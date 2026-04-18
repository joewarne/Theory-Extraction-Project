#' @keywords internal
#' Load and cache package configuration from inst/config.yml
#'
#' @return A named list of configuration values.
.get_config <- function() {
  # 1. Installed package
  config_path <- system.file("config.yml", package = "sportTheoryAI")

  # 2. Source directory (when sourced directly without installing)
  if (!nzchar(config_path) || !file.exists(config_path)) {
    config_path <- here::here("sportTheoryAI", "inst", "config.yml")
  }

  if (!file.exists(config_path)) {
    cli::cli_abort(
      "config.yml not found at {.path {config_path}}. Check sportTheoryAI/inst/config.yml exists."
    )
  }
  yaml::read_yaml(config_path)
}


#' @keywords internal
#' Safely parse a JSON string, returning NULL and a warning on failure.
#'
#' @param raw_string Character. Raw JSON string from model response.
#' @return Parsed list or NULL.
.safe_parse_json <- function(raw_string) {
  # Strip markdown code fences
  cleaned <- stringr::str_replace_all(
    raw_string,
    pattern = "(?s)```(?:json)?\\s*|\\s*```",
    replacement = ""
  )
  # Extract the JSON object — take everything from first { to last }
  json_match <- stringr::str_extract(cleaned, "(?s)\\{.*\\}")
  cleaned <- if (!is.na(json_match)) json_match else cleaned
  cleaned <- stringr::str_trim(cleaned)

  tryCatch(
    jsonlite::fromJSON(cleaned, simplifyVector = FALSE),
    error = function(e) {
      cli::cli_warn(c(
        "!" = "Failed to parse model response as JSON.",
        "i" = "Raw response: {.val {substr(cleaned, 1, 200)}}"
      ))
      NULL
    }
  )
}


#' @keywords internal
#' Validate that a parsed theory object conforms to the expected schema.
#'
#' Supports both v1 schema (explicit_theories/implicit_theories) and
#' v2+/v4 schema (theories[] array with type field).
#'
#' @param parsed List. Parsed JSON from model.
#' @return Invisibly TRUE if valid; emits warnings for schema violations.
.validate_schema <- function(parsed) {
  # v2/v3/v4/v5 schema uses 'theories' array

  if (!is.null(parsed$theories)) {
    required_keys <- c("theories", "no_theory_present")
  } else {
    # v1 schema uses separate explicit/implicit lists
    required_keys <- c("explicit_theories", "implicit_theories", "no_theory_present")
  }

  missing_keys <- setdiff(required_keys, names(parsed))

  if (length(missing_keys) > 0) {
    cli::cli_warn(c(
      "!" = "Model response missing required JSON keys: {.val {missing_keys}}",
      "i" = "Response will be returned as-is."
    ))
  }
  invisible(TRUE)
}


#' @keywords internal
#' Write a single log entry (JSON Lines format) to the log file.
#'
#' @param entry Named list to serialise as one JSON line.
#' @param log_file Path to the .jsonl log file.
.write_log <- function(entry, log_file) {
  entry$timestamp <- format(Sys.time(), "%Y-%m-%dT%H:%M:%S%z")
  line <- jsonlite::toJSON(entry, auto_unbox = TRUE, null = "null")
  cat(line, "\n", file = log_file, append = TRUE)
}


#' @keywords internal
#' Return the empty/null result structure used when extraction fails.
.null_result <- function() {
  list(
    explicit_theories  = list(),
    implicit_theories  = list(),
    no_theory_present  = NA,
    extraction_error   = TRUE
  )
}
