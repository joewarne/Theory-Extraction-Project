#' Build an extraction prompt from an introduction text
#'
#' Loads the versioned prompt template from `inst/prompt_templates/` and
#' substitutes the `{{INTRODUCTION_TEXT}}` placeholder with the supplied text.
#' The template version is recorded so outputs remain reproducible even if the
#' template is updated in a future package version.
#'
#' When the Claude backend is active and v5 templates are configured, this
#' function selects the Claude-optimised template automatically. The v5
#' templates contain a `---SYSTEM/USER---` delimiter which is handled
#' transparently by [call_claude_api()].
#'
#' @param text Character scalar. The introduction text to analyse.
#' @param template_name Character scalar. File name of the template inside
#'   `inst/prompt_templates/`. Defaults to the value in `inst/config.yml`,
#'   with automatic Claude template selection when the Claude backend is active.
#'
#' @return A character scalar containing the fully assembled prompt, with an
#'   attribute `"template_name"` recording which template was used.
#'
#' @examples
#' text <- "Athletes must regulate arousal to perform optimally, consistent
#'   with the Inverted-U hypothesis proposed by Yerkes and Dodson (1908)."
#' prompt <- build_prompt(text)
#' cat(prompt)
#'
#' @export
build_prompt <- function(text, template_name = NULL) {
  if (!is.character(text) || length(text) != 1L) {
    cli::cli_abort("{.arg text} must be a single character string.")
  }
  if (!nzchar(stringr::str_trim(text))) {
    cli::cli_abort("{.arg text} is empty or contains only whitespace.")
  }

  cfg <- .get_config()

  if (is.null(template_name)) {
    # Auto-select v5 template if Claude or Kimi backend is active
    backend <- getOption("sportTheoryAI.backend", default = "ollama")
    if (identical(backend, "claude") && !is.null(cfg$claude$prompts$theory_extraction)) {
      template_name <- cfg$claude$prompts$theory_extraction
    } else if (identical(backend, "kimi") && !is.null(cfg$kimi$prompts$theory_extraction)) {
      template_name <- cfg$kimi$prompts$theory_extraction
    } else if (identical(backend, "deepseek") && !is.null(cfg$deepseek$prompts$theory_extraction)) {
      template_name <- cfg$deepseek$prompts$theory_extraction
    } else {
      template_name <- cfg$claude$prompts$theory_extraction
    }
  }

  template_path <- .resolve_template_path(template_name)
  template <- paste(readLines(template_path, encoding = "UTF-8"), collapse = "\n")
  prompt   <- stringr::str_replace(template, "\\{\\{INTRODUCTION_TEXT\\}\\}", text)

  attr(prompt, "template_name") <- template_name
  prompt
}


#' Resolve the file path for a prompt template
#'
#' Checks the installed package location first, then falls back to the
#' development source directory.
#'
#' @param template_name Character scalar. Template filename.
#' @return Absolute path to the template file.
#' @keywords internal
.resolve_template_path <- function(template_name) {
  template_path <- system.file(
    file.path("prompt_templates", template_name),
    package = "sportTheoryAI"
  )

  # fallback for development mode (sourced directly, not installed)
  if (!nzchar(template_path) || !file.exists(template_path)) {
    template_path <- here::here("sportTheoryAI", "inst", "prompt_templates", template_name)
  }

  if (!file.exists(template_path)) {
    cli::cli_abort(c(
      "Prompt template {.val {template_name}} not found.",
      "i" = "Check {.path inst/prompt_templates/} inside the package."
    ))
  }

  template_path
}
