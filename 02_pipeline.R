# =============================================================================
# 02_pipeline.R  —  Theory Extraction Pipeline
#
# Converts a folder of PDFs → XML → extracts introductions + discussions →
# runs LLM extraction (theories, hypotheses, discussion analysis) → saves
# results ready for 03_report.qmd
#
# USAGE:
#   1. Set PDF_DIR below to point at your folder of papers
#   2. Set OUT_DIR for where results should be saved (defaults to project root)
#   3. Run the whole script, or step-by-step
#
# PREREQUISITES: Run 01_setup.R at least once first.
# =============================================================================

# ── Package check ─────────────────────────────────────────────────────────────

required_packages <- c("metacheck", "dplyr", "purrr", "stringr",
                       "tibble", "readr", "here", "yaml", "httr", "jsonlite", "cli")

missing <- required_packages[!required_packages %in% rownames(installed.packages())]
if (length(missing) > 0) {
  stop(
    "Required packages not installed:\n  ", paste(missing, collapse = ", "),
    "\nRun 01_setup.R first."
  )
}

library(metacheck)
library(dplyr)
library(purrr)
library(stringr)
library(tibble)
library(readr)
library(here)

# ── Configuration ─────────────────────────────────────────────────────────────

PDF_DIR    <- here("Study_papers")
OUT_DIR    <- here()
GROBID_URL <- "https://thesanogoeffect-grobid-papercheck.hf.space"

xml_dir       <- file.path(OUT_DIR, "files", "xml_files_theory")
rds_path      <- file.path(OUT_DIR, "theory_pipeline_articles.Rds")
out_rds       <- file.path(OUT_DIR, "theory_extraction_full.Rds")
out_csv       <- file.path(OUT_DIR, "theory_extraction_results.csv")
hyp_rds       <- file.path(OUT_DIR, "hypothesis_extraction_full.Rds")
hyp_csv       <- file.path(OUT_DIR, "hypothesis_extraction_results.csv")
disc_rds      <- file.path(OUT_DIR, "discussion_extraction_full.Rds")
disc_csv      <- file.path(OUT_DIR, "discussion_extraction_results.csv")
log_file      <- file.path(OUT_DIR, "theory_extraction_log.jsonl")

# ── Load sportTheoryAI functions ──────────────────────────────────────────────

source(here("sportTheoryAI", "R", "utils.R"))
source(here("sportTheoryAI", "R", "build_prompt.R"))
source(here("sportTheoryAI", "R", "call_model.R"))
source(here("sportTheoryAI", "R", "extract_theory.R"))
source(here("sportTheoryAI", "R", "extract_hypotheses.R"))
source(here("sportTheoryAI", "R", "extract_discussion.R"))
source(here("sportTheoryAI", "R", "normalise_theories.R"))

# ── Step 1: Convert PDFs to XML via GROBID ───────────────────────────────────

dir.create(xml_dir, showWarnings = FALSE, recursive = TRUE)

pdf_files    <- list.files(PDF_DIR, pattern = "\\.pdf$", full.names = TRUE)
message(sprintf("Found %d PDFs in %s", length(pdf_files), basename(PDF_DIR)))

existing_ids <- str_remove(list.files(xml_dir, pattern = "\\.xml$"), "\\.xml$")
pdf_ids      <- str_remove(basename(pdf_files), "\\.pdf$")
to_convert   <- pdf_files[!pdf_ids %in% existing_ids]

if (length(to_convert) == 0) {
  message("All PDFs already converted — skipping GROBID step.")
} else {
  message(sprintf("Converting %d PDFs to XML via GROBID...", length(to_convert)))
  pdf2grobid(to_convert, save_path = xml_dir, grobid_url = GROBID_URL)
  message("Conversion complete.")
}

# ── Step 2: Parse XML files ───────────────────────────────────────────────────

xml_files <- list.files(xml_dir, pattern = "\\.xml$", full.names = TRUE)
message(sprintf("%d XML files found.", length(xml_files)))

if (file.exists(rds_path)) {
  message("Loading cached articles RDS: ", basename(rds_path))
  articles <- readRDS(rds_path)
} else {
  message("Parsing XML files...")
  articles <- read(xml_files)
  saveRDS(articles, rds_path)
  message("Saved: ", basename(rds_path))
}

# ── Step 3: Extract text sections ────────────────────────────────────────────

.extract_section <- function(articles, section_name) {
  hits <- search_text(articles, pattern = ".+", section = section_name, return = "sentence")
  if (is.null(hits) || nrow(hits) == 0) return(NULL)

  id_col   <- intersect(c("id", "file", "file_name", "article_id", "doc_id"), names(hits))[1]
  text_col <- intersect(c("text", "sentence", "content", "value"),            names(hits))[1]

  if (is.na(id_col) || is.na(text_col)) {
    stop("Cannot detect columns from search_text(). Columns: ", paste(names(hits), collapse = ", "))
  }

  hits |>
    rename(article_id = all_of(id_col), sentence = all_of(text_col)) |>
    group_by(article_id) |>
    summarise(text = paste(sentence, collapse = " "), n_sentences = n(), .groups = "drop") |>
    mutate(
      article_id   = str_remove(basename(as.character(article_id)), "\\.xml$"),
      text_length  = nchar(text)
    )
}

message("Extracting introduction sections...")
introductions <- .extract_section(articles, "intro")

if (is.null(introductions)) {
  stop(
    "No introduction text found.\n",
    "Check section names: unique(search_text(articles, '.+', NULL, 'sentence')$section)"
  )
}

message("Extracting discussion sections...")
discussions <- .extract_section(articles, "discussion")

if (is.null(discussions)) {
  message("Warning: No discussion sections found — discussion analysis will be skipped.")
}

# Report intro quality
n_total <- length(xml_files)
short   <- filter(introductions, text_length < 200)
message(sprintf("Introductions: %d / %d articles", nrow(introductions), n_total))
if (nrow(short) > 0) {
  warning(sprintf("%d articles have very short introductions (< 200 chars): %s",
    nrow(short), paste(short$article_id, collapse = ", ")))
}

# ── Step 4: Theory extraction (v2) ───────────────────────────────────────────
# Uses the updated prompt with operational/contextual classification.

message(sprintf("\n── Step 4: Theory extraction on %d articles ──", nrow(introductions)))

if (file.exists(out_rds)) {
  message("Loading cached theory results. Delete ", basename(out_rds), " to rerun.")
  results_df <- readRDS(out_rds)
} else {
  results_df <- batch_extract(
    df          = rename(introductions, introduction = text),
    text_column = "introduction",
    id_column   = "article_id",
    log_file    = log_file
  )

  # Retry failures (up to 2 attempts)
  for (attempt in 1:2) {
    failed_ids <- results_df$article_id[results_df$theory_error == TRUE]
    if (length(failed_ids) == 0) break
    message(sprintf("Retry %d: %d failed articles...", attempt, length(failed_ids)))
    retry_df <- filter(rename(introductions, introduction = text), article_id %in% failed_ids)
    retry_results <- batch_extract(retry_df, "introduction", "article_id", log_file = log_file)
    results_df[results_df$article_id %in% failed_ids, ] <- retry_results
  }

  # Flatten and normalise theory names
  flat <- flatten_results(results_df, id_column = "article_id") |> normalise_flat()
  saveRDS(results_df, out_rds)
  write_csv(flat, out_csv)
  message(sprintf("Theory results saved (%d theories across %d articles)", nrow(flat), nrow(results_df)))
}

flat <- read_csv(out_csv, show_col_types = FALSE)

# ── Step 5: Hypothesis extraction ────────────────────────────────────────────

message(sprintf("\n── Step 5: Hypothesis extraction on %d articles ──", nrow(introductions)))

if (file.exists(hyp_rds)) {
  message("Loading cached hypothesis results. Delete ", basename(hyp_rds), " to rerun.")
  hyp_df <- readRDS(hyp_rds)
} else {
  # Build theory name list-column from flat results for context
  theory_names_by_article <- flat |>
    group_by(article_id) |>
    summarise(theory_names = list(unique(name[!is.na(name)])), .groups = "drop")

  intro_with_theories <- rename(introductions, introduction = text) |>
    left_join(theory_names_by_article, by = "article_id") |>
    mutate(theory_names = map(theory_names, ~ .x %||% character(0)))

  hyp_df <- batch_extract_hypotheses(
    df            = intro_with_theories,
    text_column   = "introduction",
    theory_column = "theory_names",
    id_column     = "article_id",
    log_file      = log_file
  )

  # Retry failures
  for (attempt in 1:2) {
    failed_ids <- hyp_df$article_id[hyp_df$hyp_error == TRUE]
    if (length(failed_ids) == 0) break
    message(sprintf("Retry %d: %d failed...", attempt, length(failed_ids)))
    retry_df <- filter(hyp_df, article_id %in% failed_ids) |>
      select(all_of(names(intro_with_theories)))
    retry_res <- batch_extract_hypotheses(retry_df, "introduction", "theory_names",
                                          "article_id", log_file = log_file)
    hyp_df[hyp_df$article_id %in% failed_ids, ] <- retry_res
  }

  hyp_flat <- flatten_hypotheses(hyp_df, id_column = "article_id")
  saveRDS(hyp_df, hyp_rds)
  write_csv(hyp_flat, hyp_csv)
  message(sprintf("Hypothesis results saved (%d hypotheses)", nrow(hyp_flat)))
}

# ── Step 6: Discussion analysis ───────────────────────────────────────────────

if (!is.null(discussions)) {
  message(sprintf("\n── Step 6: Discussion analysis on %d articles ──", nrow(discussions)))

  if (file.exists(disc_rds)) {
    message("Loading cached discussion results. Delete ", basename(disc_rds), " to rerun.")
    disc_df <- readRDS(disc_rds)
  } else {
    theory_names_by_article <- flat |>
      group_by(article_id) |>
      summarise(theory_names = list(unique(name[!is.na(name)])), .groups = "drop")

    disc_with_theories <- rename(discussions, discussion = text) |>
      left_join(theory_names_by_article, by = "article_id") |>
      mutate(theory_names = map(theory_names, ~ .x %||% character(0)))

    disc_df <- batch_extract_discussion(
      df            = disc_with_theories,
      text_column   = "discussion",
      theory_column = "theory_names",
      id_column     = "article_id",
      log_file      = log_file
    )

    # Retry failures
    for (attempt in 1:2) {
      failed_ids <- disc_df$article_id[disc_df$disc_error == TRUE]
      if (length(failed_ids) == 0) break
      message(sprintf("Retry %d: %d failed...", attempt, length(failed_ids)))
      retry_df <- filter(disc_df, article_id %in% failed_ids) |>
        select(all_of(names(disc_with_theories)))
      retry_res <- batch_extract_discussion(retry_df, "discussion", "theory_names",
                                            "article_id", log_file = log_file)
      disc_df[disc_df$article_id %in% failed_ids, ] <- retry_res
    }

    disc_summary <- disc_df |>
      select(article_id, disc_reengagement, disc_overclaim, disc_quality, disc_error)
    saveRDS(disc_df, disc_rds)
    write_csv(disc_summary, disc_csv)
    message(sprintf("Discussion results saved (%d articles)", nrow(disc_df)))
  }
} else {
  message("Skipping Step 6 — no discussion sections found.")
}

# ── Final summary ─────────────────────────────────────────────────────────────

hyp_flat  <- if (file.exists(hyp_csv))  read_csv(hyp_csv,  show_col_types = FALSE) else tibble()
disc_data <- if (file.exists(disc_rds)) readRDS(disc_rds) else tibble()

cat("\n=== Pipeline Complete ===\n")
cat(sprintf("Articles processed       : %d\n", nrow(results_df)))
cat(sprintf("Theory errors            : %d\n", sum(results_df$theory_error, na.rm = TRUE)))
cat(sprintf("Theories found (total)   : %d\n", nrow(flat)))
cat(sprintf("Hypotheses found         : %d\n", nrow(hyp_flat)))
if (nrow(disc_data) > 0) {
  cat(sprintf("Discussion analyses      : %d\n", nrow(disc_data)))
  cat(sprintf("  Full re-engagement     : %d\n", sum(disc_data$disc_reengagement == "full",   na.rm = TRUE)))
  cat(sprintf("  Partial re-engagement  : %d\n", sum(disc_data$disc_reengagement == "partial", na.rm = TRUE)))
  cat(sprintf("  Absent re-engagement   : %d\n", sum(disc_data$disc_reengagement == "absent",  na.rm = TRUE)))
}
cat("\nRun quarto::quarto_render('03_report.qmd') to generate the report.\n")
