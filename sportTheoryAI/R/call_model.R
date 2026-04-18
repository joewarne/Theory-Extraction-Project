#' Route a prompt to the configured LLM backend and return the raw response
#'
#' Dispatches to the Claude or Kimi API based on the
#' `sportTheoryAI.backend` option. Set the backend with:
#'   `options(sportTheoryAI.backend = "kimi")` or `"claude"`
#'
#' @param prompt Character scalar. The fully assembled prompt (use
#'   [build_prompt()] to generate this).
#' @param model Character scalar. Model name override (optional).
#' @param log_file Character scalar or NULL. Path to a `.jsonl` log file.
#'   `NULL` disables logging regardless of the config setting.
#'
#' @return A character scalar containing the raw model response text.
#'
#' @seealso [build_prompt()], [extract_theory()]
#'
#' @examples
#' \dontrun{
#' options(sportTheoryAI.backend = "kimi")
#' prompt <- build_prompt("Athletes used Self-Determination Theory to frame...")
#' raw    <- call_model(prompt)
#' cat(raw)
#' }
#'
#' @export
call_model <- function(prompt,
                       model    = NULL,
                       log_file = NULL) {

  if (!is.character(prompt) || length(prompt) != 1L || !nzchar(prompt)) {
    cli::cli_abort("{.arg prompt} must be a non-empty character scalar.")
  }

  backend <- getOption("sportTheoryAI.backend", default = "kimi")

  if (identical(backend, "claude")) {
    claude_model  <- model %||% "claude-sonnet-4-6"
    claude_cfg    <- tryCatch(.get_config()$claude, error = function(e) NULL)
    max_tokens    <- claude_cfg$max_tokens %||% 4096L
    return(call_claude_api(prompt, model = claude_model,
                           max_tokens = max_tokens, log_file = log_file))
  }

  if (identical(backend, "kimi")) {
    kimi_cfg    <- tryCatch(.get_config()$kimi, error = function(e) NULL)
    kimi_model  <- model %||% kimi_cfg$model %||% "moonshot-v1-32k"
    max_tokens  <- kimi_cfg$max_tokens %||% 4096L
    return(call_kimi_api(prompt, model = kimi_model,
                         max_tokens = max_tokens, log_file = log_file))
  }

  if (identical(backend, "deepseek")) {
    ds_cfg     <- tryCatch(.get_config()$deepseek, error = function(e) NULL)
    ds_model   <- model %||% ds_cfg$model %||% "deepseek-chat"
    max_tokens <- ds_cfg$max_tokens %||% 4096L
    return(call_deepseek_api(prompt, model = ds_model,
                             max_tokens = max_tokens, log_file = log_file))
  }

  cli::cli_abort(c(
    "Unknown backend: {.val {backend}}",
    "i" = "Set {.code options(sportTheoryAI.backend = 'kimi')} or {.code 'claude'}"
  ))
}
