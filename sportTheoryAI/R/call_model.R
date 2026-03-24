#' Send a prompt to a locally hosted Ollama model and return the raw response
#'
#' Posts to the Ollama `/api/generate` endpoint with parameters fixed for
#' deterministic, reproducible output (`temperature = 0`, `top_p = 1`,
#' `top_k = 1`, `seed = 42`). These values are read from `inst/config.yml`
#' and must not be changed between runs to preserve reproducibility.
#'
#' @param prompt Character scalar. The fully assembled prompt (use
#'   [build_prompt()] to generate this).
#' @param model Character scalar. Ollama model name. Defaults to the value in
#'   `inst/config.yml` (e.g. `"llama3"` or `"mistral"`).
#' @param base_url Character scalar. Ollama server base URL. Defaults to
#'   `"http://localhost:11434"`.
#' @param log_file Character scalar or NULL. Path to a `.jsonl` log file.
#'   `NULL` disables logging regardless of the config setting.
#'
#' @return A character scalar containing the raw model response text.
#'
#' @seealso [build_prompt()], [extract_theory()]
#'
#' @examples
#' \dontrun{
#' prompt <- build_prompt("Athletes used Self-Determination Theory to frame...")
#' raw    <- call_model(prompt)
#' cat(raw)
#' }
#'
#' @export
call_model <- function(prompt,
                       model    = NULL,
                       base_url = NULL,
                       log_file = NULL) {

  if (!is.character(prompt) || length(prompt) != 1L || !nzchar(prompt)) {
    cli::cli_abort("{.arg prompt} must be a non-empty character scalar.")
  }

  cfg <- .get_config()

  model    <- model    %||% cfg$model$name
  base_url <- base_url %||% cfg$ollama$base_url
  endpoint <- paste0(base_url, cfg$ollama$endpoint)
  timeout  <- cfg$ollama$timeout_seconds %||% 120

  body <- list(
    model  = model,
    prompt = prompt,
    stream = FALSE,
    options = list(
      temperature = cfg$model$temperature,
      top_p       = cfg$model$top_p,
      top_k       = cfg$model$top_k,
      seed        = cfg$model$seed,
      num_predict = cfg$model$num_predict,
      num_ctx     = cfg$model$num_ctx %||% 8192
    )
  )

  cli::cli_progress_step("Querying {.val {model}} via Ollama...")

  response <- tryCatch(
    httr::POST(
      url     = endpoint,
      body    = jsonlite::toJSON(body, auto_unbox = TRUE),
      encode  = "raw",
      httr::content_type_json(),
      httr::timeout(timeout)
    ),
    error = function(e) {
      cli::cli_abort(c(
        "Failed to reach Ollama at {.url {endpoint}}.",
        "i" = "Is Ollama running? Try: {.code ollama serve}",
        "x" = conditionMessage(e)
      ))
    }
  )

  if (httr::http_error(response)) {
    status <- httr::status_code(response)
    body_txt <- httr::content(response, as = "text", encoding = "UTF-8")
    cli::cli_abort(c(
      "Ollama returned HTTP {status}.",
      "x" = body_txt
    ))
  }

  parsed_response <- httr::content(response, as = "parsed", encoding = "UTF-8")
  raw_text        <- parsed_response$response

  if (is.null(raw_text) || !nzchar(raw_text)) {
    cli::cli_abort("Ollama returned an empty response body.")
  }

  # Optional logging
  do_log <- isTRUE(cfg$logging$enabled) && !is.null(log_file)
  if (do_log) {
    log_entry <- list(
      model          = model,
      prompt_length  = nchar(prompt),
      response_length = nchar(raw_text),
      template       = attr(prompt, "template_name") %||% NA_character_
    )
    if (isTRUE(cfg$logging$log_prompts)) {
      log_entry$prompt <- prompt
    }
    .write_log(log_entry, log_file)
  }

  raw_text
}
