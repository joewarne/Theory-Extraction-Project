# =============================================================================
# 01_setup.R  —  One-time setup for the Theory Extraction Project
#
# Run this script ONCE before using 02_pipeline.R for the first time.
# It installs all required R packages and verifies Ollama is reachable.
#
# Prerequisites (do these manually before running this script):
#   1. Install Ollama from https://ollama.com/download
#   2. In a terminal run:  ollama serve
#   3. In a second terminal run: ollama pull llama3
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

# ── 2. Verify Ollama is running ───────────────────────────────────────────────

message("\nChecking Ollama connection...")

ollama_ok <- tryCatch({
  resp <- httr::GET("http://localhost:11434", httr::timeout(5))
  httr::status_code(resp) == 200
}, error = function(e) FALSE)

if (!ollama_ok) {
  stop(
    "Cannot reach Ollama at http://localhost:11434.\n",
    "Open a terminal and run:  ollama serve\n",
    "Then re-run this script."
  )
}

message("Ollama is running.")

# ── 3. Verify the model is available ─────────────────────────────────────────

message("Checking available models...")

models_resp <- httr::GET("http://localhost:11434/api/tags")
models      <- jsonlite::fromJSON(
  httr::content(models_resp, as = "text", encoding = "UTF-8")
)$models$name

if (length(models) == 0) {
  stop(
    "No models found in Ollama.\n",
    "In a terminal run:  ollama pull llama3"
  )
}

message("Models available: ", paste(models, collapse = ", "))

# Check that the configured model is present
config_path <- here::here("sportTheoryAI", "inst", "config.yml")
cfg         <- yaml::read_yaml(config_path)
target      <- cfg$model$name

if (!any(grepl(target, models, fixed = TRUE))) {
  warning(
    sprintf("Model '%s' not found in Ollama.\n", target),
    sprintf("Run in a terminal:  ollama pull %s\n", target),
    sprintf("Or edit sportTheoryAI/inst/config.yml and change model.name to one of: %s",
            paste(models, collapse = ", "))
  )
} else {
  message(sprintf("Model '%s' is ready.", target))
}

# ── 4. Source sportTheoryAI functions ─────────────────────────────────────────
# The package is loaded by sourcing its R files directly (avoids install issues).

message("\nLoading sportTheoryAI functions...")

source(here::here("sportTheoryAI", "R", "utils.R"))
source(here::here("sportTheoryAI", "R", "build_prompt.R"))
source(here::here("sportTheoryAI", "R", "call_model.R"))
source(here::here("sportTheoryAI", "R", "extract_theory.R"))

message("Functions loaded: build_prompt, call_model, extract_theory, batch_extract, flatten_results")

# ── 5. Quick smoke test ───────────────────────────────────────────────────────

message("\nRunning smoke test on one sentence...")

test_result <- extract_theory(
  "This study applies Self-Determination Theory (Deci & Ryan, 1985) to examine
   intrinsic motivation in youth athletes."
)

if (isTRUE(test_result$extraction_error)) {
  warning("Smoke test failed — model returned an unparseable response. Check Ollama.")
} else {
  n_exp <- length(test_result$explicit_theories)
  message(sprintf("Smoke test passed. Explicit theories found: %d", n_exp))
}

message("\nSetup complete. You can now run 02_pipeline.R")
