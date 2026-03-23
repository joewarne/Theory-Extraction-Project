# =============================================================================
# sportTheoryAI — Example Usage Script
# =============================================================================
# Prerequisites:
#   1. Install Ollama:  https://ollama.com/download
#   2. Start Ollama:    ollama serve          (in a terminal)
#   3. Pull a model:    ollama pull llama3    (once; ~4 GB)
#   4. Install package (from this directory):
#        devtools::install("sportTheoryAI")
# =============================================================================

library(sportTheoryAI)
library(dplyr)
library(readr)

# ── 1. Single article extraction ─────────────────────────────────────────────

intro_text <- "Self-Determination Theory (SDT; Deci & Ryan, 1985) has been
widely applied to understand athlete motivation. SDT posits that satisfaction
of three basic psychological needs—autonomy, competence, and relatedness—
predicts the quality of motivation and, ultimately, well-being and performance
outcomes. The present study applies an SDT framework to examine coach-athlete
relationships in elite swimming, hypothesising that autonomy-supportive
coaching behaviours will predict higher levels of intrinsic motivation and
lower burnout."

result <- extract_theory(intro_text)
str(result)

# Explicit theories detected
result$explicit_theories

# Implicit theories (if any)
result$implicit_theories

# Was any theory present?
result$no_theory_present


# ── 2. Inspect the assembled prompt (without running the model) ──────────────

prompt <- build_prompt(intro_text)
cat(prompt)


# ── 3. Batch extraction from a data frame ────────────────────────────────────

# Load example data included with the package
examples_path <- system.file("extdata", "example_introductions.csv",
                             package = "sportTheoryAI")
articles <- read_csv(examples_path, show_col_types = FALSE)

# Run batch extraction (requires Ollama running)
results_df <- batch_extract(
  df          = articles,
  text_column = "introduction",
  id_column   = "article_id",
  log_file    = "extraction_log.jsonl"   # saved to working directory
)

# Inspect the raw results
glimpse(results_df)


# ── 4. Flatten to a tidy long-format table ───────────────────────────────────

flat <- flatten_results(results_df, id_column = "article_id")
flat

# Count theory types detected
flat |>
  count(theory_type, sort = TRUE)

# Most common explicit theories in the corpus
flat |>
  filter(theory_type == "explicit") |>
  count(name, sort = TRUE)


# ── 5. Evaluate against human-coded ground truth ────────────────────────────

human_codes_path <- system.file("extdata", "example_human_codes.csv",
                                package = "sportTheoryAI")
human_codes <- read_csv(human_codes_path, show_col_types = FALSE) |>
  filter(!is.na(theory_name), theory_name != "")

eval_result <- evaluate_extraction(
  human_df          = human_codes,
  model_df          = flat,
  id_column         = "article_id",
  human_name_column = "theory_name",
  fuzzy             = TRUE,
  fuzzy_threshold   = 0.5
)

# Print formatted summary
print_evaluation(eval_result)

# Inspect per-article confusion
eval_result$confusion

# Matched name pairs (human label ↔ model label)
eval_result$matched_pairs


# ── 6. Export results ────────────────────────────────────────────────────────

# Save tidy extraction results as CSV
write_csv(flat, "theory_extraction_results.csv")

# Save full list (including raw model responses) as RDS
saveRDS(results_df, "theory_extraction_full.Rds")

# Save evaluation metrics
write_csv(eval_result$metrics, "evaluation_metrics.csv")
