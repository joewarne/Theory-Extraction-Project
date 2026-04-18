#' Send a prompt to the Anthropic Claude API and return the raw response
#'
#' Used as an alternative backend to Ollama when
#' `options(sportTheoryAI.backend = "claude")` is set. Requires the
#' `ANTHROPIC_API_KEY` environment variable to be set.
#'
#' Supports system/user prompt separation for Claude-optimised templates
#' (v5 series) which use a `---SYSTEM/USER---` delimiter. When a system
#' prompt is provided, it is sent via the API's `system` parameter, which
#' improves instruction adherence and enables prompt caching.
#'
#' @param prompt  Character scalar. The user message content (article text +
#'   context). If no `system_prompt` is provided and the prompt contains the
#'   `---SYSTEM/USER---` delimiter, it will be automatically split.
#' @param system_prompt Character scalar or NULL. The system-level instructions
#'   (persona, definitions, schema). NULL means auto-detect from delimiter.
#' @param model   Character scalar. Claude model ID.
#'   Defaults to `"claude-sonnet-4-6"`.
#' @param max_tokens Integer. Maximum tokens in the response. Defaults to 4096.
#' @param log_file Character scalar or NULL. Path to a `.jsonl` log file.
#'
#' @return A character scalar containing the raw model response text.
#' @keywords internal
call_claude_api <- function(prompt,
                            system_prompt = NULL,
                            model      = "claude-sonnet-4-6",
                            max_tokens = 4096L,
                            log_file   = NULL) {

  api_key <- Sys.getenv("ANTHROPIC_API_KEY")
  if (!nzchar(api_key)) {
    stop(
      "ANTHROPIC_API_KEY environment variable is not set.\n",
      "Set it with: Sys.setenv(ANTHROPIC_API_KEY = '<your-key>')"
    )
  }

  # Auto-split system/user if delimiter present and no explicit system_prompt

  if (is.null(system_prompt) && grepl("---SYSTEM/USER---", prompt, fixed = TRUE)) {
    parts         <- strsplit(prompt, "---SYSTEM/USER---", fixed = TRUE)[[1]]
    system_prompt <- trimws(parts[1])
    prompt        <- trimws(parts[2])
  }

  body <- list(
    model       = model,
    max_tokens  = as.integer(max_tokens),
    temperature = 0
  )

  # System prompt separation (Claude-specific optimisation)
  if (!is.null(system_prompt) && nzchar(system_prompt)) {
    body$system <- system_prompt
  }

  body$messages <- list(
    list(role = "user", content = prompt)
  )

  message("  [Claude API] Querying ", model, "...")

  # Retry with exponential backoff for rate limits (HTTP 429) and server errors
  max_retries <- 3L
  raw_text    <- NULL
  parsed      <- NULL


  for (attempt in seq_len(max_retries)) {
    response <- tryCatch(
      httr::POST(
        url    = "https://api.anthropic.com/v1/messages",
        httr::add_headers(
          "x-api-key"         = api_key,
          "anthropic-version" = "2023-06-01",
          "content-type"      = "application/json"
        ),
        body   = jsonlite::toJSON(body, auto_unbox = TRUE),
        encode = "raw",
        httr::timeout(180)
      ),
      error = function(e) {
        if (attempt < max_retries) {
          wait <- 2^attempt
          message("  [Claude API] Connection error (attempt ", attempt, "/",
                  max_retries, "). Retrying in ", wait, "s...")
          Sys.sleep(wait)
          return(NULL)
        }
        stop("Failed to reach Anthropic API after ", max_retries,
             " attempts: ", conditionMessage(e))
      }
    )

    if (is.null(response)) next

    status <- httr::status_code(response)

    # Rate limit — wait and retry
    if (status == 429L && attempt < max_retries) {
      retry_after <- as.numeric(httr::headers(response)$`retry-after`) %||% (2^attempt)
      message("  [Claude API] Rate limited (attempt ", attempt, "/",
              max_retries, "). Waiting ", round(retry_after), "s...")
      Sys.sleep(retry_after)
      next
    }

    # Server error — retry
    if (status >= 500L && attempt < max_retries) {
      wait <- 2^attempt
      message("  [Claude API] Server error ", status, " (attempt ", attempt,
              "/", max_retries, "). Retrying in ", wait, "s...")
      Sys.sleep(wait)
      next
    }

    # Any other error — fail immediately
    if (httr::http_error(response)) {
      body_txt <- httr::content(response, as = "text", encoding = "UTF-8")
      stop("Anthropic API returned HTTP ", status, ": ", body_txt)
    }

    # Success
    parsed   <- httr::content(response, as = "parsed", encoding = "UTF-8")
    raw_text <- parsed$content[[1]]$text
    break
  }

  if (is.null(raw_text) || !nzchar(raw_text)) {
    stop("Anthropic API returned an empty response body.")
  }

  # Optional logging (same schema as Ollama logger, plus Claude-specific fields)
  if (!is.null(log_file)) {
    log_entry <- list(
      model           = parsed$model %||% model,
      backend         = "claude",
      prompt_length   = nchar(prompt),
      system_length   = if (!is.null(system_prompt)) nchar(system_prompt) else 0L,
      response_length = nchar(raw_text),
      template        = attr(prompt, "template_name") %||% NA_character_,
      input_tokens    = parsed$usage$input_tokens        %||% NA_integer_,
      output_tokens   = parsed$usage$output_tokens       %||% NA_integer_,
      cache_read      = parsed$usage$cache_read_input_tokens %||% 0L,
      stop_reason     = parsed$stop_reason               %||% NA_character_
    )
    .write_log(log_entry, log_file)
  }

  raw_text
}
