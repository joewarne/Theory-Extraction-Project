#' Send a prompt to the Moonshot Kimi API and return the raw response
#'
#' Used as an alternative backend to Ollama/Claude when
#' `options(sportTheoryAI.backend = "kimi")` is set. Requires the
#' `KIMI_API_KEY` environment variable to be set.
#'
#' The Kimi API is OpenAI-compatible. Supports system/user prompt separation
#' for v5 templates which use a `---SYSTEM/USER---` delimiter.
#'
#' @param prompt  Character scalar. The user message content (article text +
#'   context). If no `system_prompt` is provided and the prompt contains the
#'   `---SYSTEM/USER---` delimiter, it will be automatically split.
#' @param system_prompt Character scalar or NULL. The system-level instructions.
#'   NULL means auto-detect from delimiter.
#' @param model   Character scalar. Kimi model ID.
#'   Defaults to `"moonshot-v1-32k"`.
#' @param max_tokens Integer. Maximum tokens in the response. Defaults to 4096.
#' @param log_file Character scalar or NULL. Path to a `.jsonl` log file.
#'
#' @return A character scalar containing the raw model response text.
#' @keywords internal
call_kimi_api <- function(prompt,
                          system_prompt = NULL,
                          model      = "moonshot-v1-32k",
                          max_tokens = 4096L,
                          log_file   = NULL) {

  api_key <- Sys.getenv("KIMI_API_KEY")
  if (!nzchar(api_key)) {
    stop(
      "KIMI_API_KEY environment variable is not set.\n",
      "Set it with: Sys.setenv(KIMI_API_KEY = '<your-key>')"
    )
  }

  # Auto-split system/user if delimiter present and no explicit system_prompt
  if (is.null(system_prompt) && grepl("---SYSTEM/USER---", prompt, fixed = TRUE)) {
    parts         <- strsplit(prompt, "---SYSTEM/USER---", fixed = TRUE)[[1]]
    system_prompt <- trimws(parts[1])
    prompt        <- trimws(parts[2])
  }

  # Build messages array (OpenAI-compatible format)
  messages <- list()
  if (!is.null(system_prompt) && nzchar(system_prompt)) {
    messages[[length(messages) + 1]] <- list(role = "system", content = system_prompt)
  }
  messages[[length(messages) + 1]] <- list(role = "user", content = prompt)

  body <- list(
    model       = model,
    messages    = messages,
    max_tokens  = as.integer(max_tokens),
    temperature = 0
  )

  cfg <- tryCatch(.get_config()$kimi, error = function(e) NULL)
  timeout <- cfg$timeout_seconds %||% 180L

  message("  [Kimi API] Querying ", model, "...")

  # Retry with exponential backoff for rate limits and server errors
  max_retries <- 3L
  raw_text    <- NULL
  parsed      <- NULL

  for (attempt in seq_len(max_retries)) {
    response <- tryCatch(
      httr::POST(
        url    = "https://api.kimi.com/coding/v1/chat/completions",
        httr::add_headers(
          "Authorization" = paste("Bearer", api_key),
          "Content-Type"  = "application/json"
        ),
        body   = jsonlite::toJSON(body, auto_unbox = TRUE),
        encode = "raw",
        httr::timeout(timeout)
      ),
      error = function(e) {
        if (attempt < max_retries) {
          wait <- 2^attempt
          message("  [Kimi API] Connection error (attempt ", attempt, "/",
                  max_retries, "). Retrying in ", wait, "s...")
          Sys.sleep(wait)
          return(NULL)
        }
        stop("Failed to reach Kimi API after ", max_retries,
             " attempts: ", conditionMessage(e))
      }
    )

    if (is.null(response)) next

    status <- httr::status_code(response)

    # Rate limit — wait and retry
    if (status == 429L && attempt < max_retries) {
      retry_after <- as.numeric(httr::headers(response)$`retry-after`) %||% (2^attempt)
      message("  [Kimi API] Rate limited (attempt ", attempt, "/",
              max_retries, "). Waiting ", round(retry_after), "s...")
      Sys.sleep(retry_after)
      next
    }

    # Server error — retry
    if (status >= 500L && attempt < max_retries) {
      wait <- 2^attempt
      message("  [Kimi API] Server error ", status, " (attempt ", attempt,
              "/", max_retries, "). Retrying in ", wait, "s...")
      Sys.sleep(wait)
      next
    }

    # Any other error — fail immediately
    if (httr::http_error(response)) {
      body_txt <- httr::content(response, as = "text", encoding = "UTF-8")
      stop("Kimi API returned HTTP ", status, ": ", body_txt)
    }

    # Success — parse OpenAI-compatible response
    parsed   <- httr::content(response, as = "parsed", encoding = "UTF-8")
    raw_text <- parsed$choices[[1]]$message$content
    break
  }

  if (is.null(raw_text) || !nzchar(raw_text)) {
    stop("Kimi API returned an empty response body.")
  }

  # Optional logging (same schema as other backends)
  if (!is.null(log_file)) {
    log_entry <- list(
      model           = parsed$model %||% model,
      backend         = "kimi",
      prompt_length   = nchar(prompt),
      system_length   = if (!is.null(system_prompt)) nchar(system_prompt) else 0L,
      response_length = nchar(raw_text),
      template        = attr(prompt, "template_name") %||% NA_character_,
      input_tokens    = parsed$usage$prompt_tokens       %||% NA_integer_,
      output_tokens   = parsed$usage$completion_tokens   %||% NA_integer_,
      stop_reason     = parsed$choices[[1]]$finish_reason %||% NA_character_
    )
    .write_log(log_entry, log_file)
  }

  raw_text
}
