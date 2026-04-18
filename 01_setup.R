# =============================================================================
# 01_setup.R  —  One-time setup for the Theory Extraction Project
#
# Run this script ONCE before using any pipeline for the first time.
# It installs all required R packages and verifies your API key is set.
#
# Pipelines available:
#   04_pipeline_claude.R   — Anthropic Claude (requires ANTHROPIC_API_KEY)
#   05_pipeline_deepseek.R — DeepSeek V3      (requires DEEPSEEK_API_KEY)
# =============================================================================

# ── 1. Install required R packages ───────────────────────────────────────────

required_packages <- c(
  # Core pipeline
  "httr", "jsonlite", "yaml", "here",
  # Data wrangling
  "dplyr", "purrr", "stringr", "tibble", "readr", "tidyr",
  # PDF parsing
  "metacheck",
  # Reporting
  "knitr", "kableExtra", "quarto",
  # Dev tools
  "devtools", "cli"
)

missing <- required_packages[!required_packages %in% rownames(installed.packages())]

if (length(missing) > 0) {
  message("The following packages are not installed and are required:")
  message("  ", paste(missing, collapse = ", "))
  message("")
  answer <- readline("Install them now? [y/n]: ")
  if (tolower(trimws(answer)) == "y") {
    install.packages(missing)
    message("Installation complete.")
  } else {
    stop(
      "Setup cannot continue without these packages.\n",
      "Run install.packages(c(", paste0('"', missing, '"', collapse = ", "), ")) to install manually."
    )
  }
} else {
  message("All required packages already installed.")
}

# ── 2. Load sportTheoryAI functions ──────────────────────────────────────────

message("\nLoading sportTheoryAI functions...")

source(here::here("sportTheoryAI", "R", "utils.R"))
source(here::here("sportTheoryAI", "R", "build_prompt.R"))
source(here::here("sportTheoryAI", "R", "call_deepseek_api.R"))
source(here::here("sportTheoryAI", "R", "call_claude_api.R"))
source(here::here("sportTheoryAI", "R", "call_model.R"))
source(here::here("sportTheoryAI", "R", "extract_theory.R"))

message("Functions loaded: build_prompt, call_model, extract_theory, batch_extract, flatten_results")

# ── 3. Verify API key ─────────────────────────────────────────────────────────

message("\nChecking API keys...")

deepseek_ok  <- nzchar(Sys.getenv("DEEPSEEK_API_KEY"))
anthropic_ok <- nzchar(Sys.getenv("ANTHROPIC_API_KEY"))

if (deepseek_ok) {
  message("  DEEPSEEK_API_KEY  : set")
} else {
  message("  DEEPSEEK_API_KEY  : NOT SET — run: Sys.setenv(DEEPSEEK_API_KEY = 'sk-...')")
}

if (anthropic_ok) {
  message("  ANTHROPIC_API_KEY : set")
} else {
  message("  ANTHROPIC_API_KEY : NOT SET — run: Sys.setenv(ANTHROPIC_API_KEY = 'sk-ant-...')")
}

if (!deepseek_ok && !anthropic_ok) {
  stop("At least one API key must be set before running a pipeline.")
}

# ── 4. Quick smoke test ───────────────────────────────────────────────────────

if (deepseek_ok) {
  message("\nRunning DeepSeek smoke test...")
  options(sportTheoryAI.backend = "deepseek")
} else {
  message("\nRunning Claude smoke test...")
  options(sportTheoryAI.backend = "claude")
}

test_result <- extract_theory(
  "This study applies Self-Determination Theory (Deci & Ryan, 1985) to examine
   intrinsic motivation in youth athletes."
)

if (isTRUE(test_result$extraction_error)) {
  warning("Smoke test failed — model returned an unparseable response. Check your API key.")
} else {
  n_exp <- length(test_result$explicit_theories)
  message(sprintf("Smoke test passed. Explicit theories found: %d", n_exp))
}

message("\nSetup complete.")
message("Run 05_pipeline_deepseek.R (DeepSeek) or 04_pipeline_claude.R (Claude) to extract theories.")
