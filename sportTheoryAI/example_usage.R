# =============================================================================
# sportTheoryAI — Example Usage Script
# =============================================================================
# Prerequisites:
#   1. Set your DeepSeek API key:
#        Sys.setenv(DEEPSEEK_API_KEY = "your-key-here")
#      Or add to your .Renviron file:
#        DEEPSEEK_API_KEY=your-key-here
#   2. Source the package (development mode):
#        source("sportTheoryAI/R/utils.R")
#        source("sportTheoryAI/R/call_deepseek_api.R")
#        ... (see 01_setup.R for full source list)
#      Or install the package:
#        devtools::install("sportTheoryAI")
# =============================================================================

library(dplyr)
library(readr)

# Set DeepSeek as the active backend
options(sportTheoryAI.backend = "deepseek")

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

# Were any entries flagged for human review?
purrr::map_lgl(result$explicit_theories, ~ isTRUE(.x$requires_review))


# ── 2. Inspect the assembled prompt (without running the model) ──────────────

prompt <- build_prompt(intro_text)
cat(prompt)


# ── 3. Batch extraction from a data frame ────────────────────────────────────

articles <- tibble::tibble(
  article_id   = c("A1", "A2"),
  introduction = c(
    intro_text,
    "Progressive overload and periodisation principles were applied across a
     16-week training block. We hypothesised that the periodised group would
     show greater gains in VO2max than the non-periodised control group."
  )
)

results_df <- batch_extract(
  df          = articles,
  text_column = "introduction",
  id_column   = "article_id",
  log_file    = "extraction_log.jsonl"
)

glimpse(results_df)


# ── 4. Flatten to a tidy long-format table ───────────────────────────────────

flat <- flatten_results(results_df, id_column = "article_id")
flat

# Theories flagged for human review
flat |> filter(requires_review == TRUE)

# Most common explicit theories
flat |>
  filter(detection_type == "explicit") |>
  count(name, sort = TRUE)


# ── 5. Export results ────────────────────────────────────────────────────────

write_csv(flat, "theory_extraction_results.csv")
saveRDS(results_df, "theory_extraction_full.Rds")
