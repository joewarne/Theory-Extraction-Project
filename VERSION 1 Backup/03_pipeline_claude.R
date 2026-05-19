# =============================================================================
# 03_pipeline_claude.R  —  Theory Extraction Pipeline (Claude API backend)
#
# Four-pass LLM extraction pipeline using Anthropic Claude API.
#
# PREREQUISITES:
#   1. Run 01_setup.R at least once.
#   2. Set your Anthropic API key:
#        Sys.setenv(ANTHROPIC_API_KEY = "sk-ant-...")
#   3. GROBID XML files must already exist (shared with 02_pipeline_deepseek.R).
#
# OUTPUT:  claude_results/
#          theory_extraction_claude.Rds   / theory_extraction_claude.csv
#          hypothesis_extraction_claude.Rds / hypothesis_extraction_claude.csv
#          discussion_extraction_claude.Rds / discussion_extraction_claude.csv
#          methods_extraction_claude.Rds   / methods_extraction_claude.csv
#
# RENDERING the comparison report:
#   quarto::quarto_render("04_report.qmd",
#     execute_params = list(results_dir = "claude_results"))
# =============================================================================

# ── API key check ─────────────────────────────────────────────────────────────

if (!nzchar(Sys.getenv("ANTHROPIC_API_KEY"))) {
  stop(
    "ANTHROPIC_API_KEY is not set.\n",
    "Run: Sys.setenv(ANTHROPIC_API_KEY = 'sk-ant-...')\n",
    "or add it to your .Renviron file."
  )
}

# ── Package check ─────────────────────────────────────────────────────────────

required_packages <- c("metacheck", "dplyr", "purrr", "stringr",
                       "tibble", "readr", "here", "yaml", "httr", "jsonlite", "cli",
                       "lubridate")

missing <- required_packages[!required_packages %in% rownames(installed.packages())]
if (length(missing) > 0) {
  stop("Required packages not installed:\n  ", paste(missing, collapse = ", "),
       "\nRun 01_setup.R first.")
}

library(metacheck)
library(dplyr)
library(purrr)
library(stringr)
library(tibble)
library(readr)
library(here)

# ── Route all LLM calls through the Claude API ────────────────────────────────

options(sportTheoryAI.backend = "claude")
CLAUDE_MODEL <- "claude-sonnet-4-6"

# ── Configuration ─────────────────────────────────────────────────────────────

PDF_DIR    <- here("Study_papers")
GROBID_URL <- "https://thesanogoeffect-grobid-papercheck.hf.space"
xml_dir    <- here("files", "xml_files_theory")    # shared GROBID output
rds_path   <- here("theory_pipeline_articles.Rds") # shared GROBID parse cache

OUT_DIR    <- here("claude_results")
dir.create(OUT_DIR, showWarnings = FALSE, recursive = TRUE)

out_rds   <- file.path(OUT_DIR, "theory_extraction_claude.Rds")
out_csv   <- file.path(OUT_DIR, "theory_extraction_claude.csv")
hyp_rds   <- file.path(OUT_DIR, "hypothesis_extraction_claude.Rds")
hyp_csv   <- file.path(OUT_DIR, "hypothesis_extraction_claude.csv")
disc_rds  <- file.path(OUT_DIR, "discussion_extraction_claude.Rds")
disc_csv  <- file.path(OUT_DIR, "discussion_extraction_claude.csv")
meth_rds  <- file.path(OUT_DIR, "methods_extraction_claude.Rds")
meth_csv  <- file.path(OUT_DIR, "methods_extraction_claude.csv")
log_file  <- file.path(OUT_DIR, "theory_extraction_claude.jsonl")

# ── Load sportTheoryAI functions ──────────────────────────────────────────────

source(here("sportTheoryAI", "R", "utils.R"))
source(here("sportTheoryAI", "R", "build_prompt.R"))
source(here("sportTheoryAI", "R", "call_claude_api.R"))  # load before call_model
source(here("sportTheoryAI", "R", "call_model.R"))
source(here("sportTheoryAI", "R", "extract_theory.R"))
source(here("sportTheoryAI", "R", "extract_hypotheses.R"))
source(here("sportTheoryAI", "R", "extract_discussion.R"))
source(here("sportTheoryAI", "R", "extract_methods.R"))
source(here("sportTheoryAI", "R", "normalise_theories.R"))
source(here("sportTheoryAI", "R", "theory_database.R"))

# ── Step 1–2: Load pre-parsed articles (skip GROBID — use shared cache) ───────

if (!dir.exists(xml_dir) || length(list.files(xml_dir, "\\.xml$")) == 0) {
  stop(
    "No XML files found in ", xml_dir, "\n",
    "Convert PDFs via GROBID first (see project README)."
  )
}

xml_files <- list.files(xml_dir, pattern = "\\.xml$", full.names = TRUE)
message(sprintf("%d XML files found.", length(xml_files)))

if (file.exists(rds_path)) {
  message("Loading shared GROBID article cache: ", basename(rds_path))
  articles <- readRDS(rds_path)
} else {
  message("Parsing XML files...")
  articles <- read(xml_files)
  saveRDS(articles, rds_path)
}

# ── Step 3: Extract text sections ─────────────────────────────────────────────

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
      article_id  = str_remove(basename(as.character(article_id)), "\\.xml$"),
      text_length = nchar(text)
    )
}

message("Extracting introduction sections...")
introductions <- .extract_section(articles, "intro")

message("Extracting methods sections...")
methods_sections <- .extract_section(articles, "methods")
if (is.null(methods_sections) || nrow(methods_sections) == 0)
  methods_sections <- .extract_section(articles, "method")

message("Extracting discussion sections...")
discussions <- .extract_section(articles, "discussion")
if (is.null(discussions) || nrow(discussions) == 0)
  discussions <- .extract_section(articles, "conclusion")

disc_extra <- .extract_section(articles, "conclusion")
if (!is.null(discussions) && !is.null(disc_extra)) {
  missing_ids <- disc_extra$article_id[!disc_extra$article_id %in% discussions$article_id]
  if (length(missing_ids) > 0)
    discussions <- bind_rows(discussions, filter(disc_extra, article_id %in% missing_ids))
}

if (is.null(introductions)) stop("No introduction text found.")

.extract_year_from_id <- function(id) {
  yr <- stringr::str_extract(id, "\\b(19|20)\\d{2}\\b")
  if (!is.na(yr)) as.integer(yr) else NA_integer_
}

introductions <- introductions |>
  mutate(pub_year = purrr::map_int(article_id, .extract_year_from_id))

message(sprintf("Introductions: %d / %d articles", nrow(introductions), length(xml_files)))

# ── Step 4: Theory extraction ─────────────────────────────────────────────────

message(sprintf("\n── Step 4 [Claude]: Theory extraction on %d articles ──", nrow(introductions)))

if (file.exists(out_rds)) {
  message("Loading cached theory results. Delete claude_results/", basename(out_rds), " to rerun.")
  results_df <- readRDS(out_rds)
} else {
  results_df <- batch_extract(
    df          = rename(introductions, introduction = text),
    text_column = "introduction",
    id_column   = "article_id",
    model       = CLAUDE_MODEL,
    log_file    = log_file
  )

  for (attempt in 1:2) {
    failed_ids <- results_df$article_id[results_df$theory_error == TRUE]
    if (length(failed_ids) == 0) break
    message(sprintf("Retry %d: %d failed articles...", attempt, length(failed_ids)))
    retry_df <- filter(rename(introductions, introduction = text), article_id %in% failed_ids)
    retry_results <- batch_extract(retry_df, "introduction", "article_id",
                                   model = CLAUDE_MODEL, log_file = log_file)
    results_df[results_df$article_id %in% failed_ids, ] <- retry_results
  }

  flat <- flatten_results(results_df, id_column = "article_id") |> normalise_flat()
  saveRDS(results_df, out_rds)
  write_csv(flat, out_csv)
  message(sprintf("Theory results saved (%d theories across %d articles)", nrow(flat), nrow(results_df)))
  update_theory_database(flat, db_path = file.path(OUT_DIR, "theory_database_claude.csv"))
}

flat <- read_csv(out_csv, show_col_types = FALSE)

# ── Step 5: Hypothesis extraction ─────────────────────────────────────────────

message(sprintf("\n── Step 5 [Claude]: Hypothesis extraction on %d articles ──", nrow(introductions)))

if (file.exists(hyp_rds)) {
  message("Loading cached hypothesis results. Delete claude_results/", basename(hyp_rds), " to rerun.")
  hyp_df <- readRDS(hyp_rds)
} else {
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
    model         = CLAUDE_MODEL,
    log_file      = log_file
  )

  for (attempt in 1:2) {
    failed_ids <- hyp_df$article_id[hyp_df$hyp_error == TRUE]
    if (length(failed_ids) == 0) break
    message(sprintf("Retry %d: %d failed...", attempt, length(failed_ids)))
    retry_df <- filter(hyp_df, article_id %in% failed_ids) |>
      select(all_of(names(intro_with_theories)))
    retry_res <- batch_extract_hypotheses(retry_df, "introduction", "theory_names",
                                          "article_id", model = CLAUDE_MODEL, log_file = log_file)
    hyp_df[hyp_df$article_id %in% failed_ids, ] <- retry_res
  }

  hyp_flat <- flatten_hypotheses(hyp_df, id_column = "article_id")
  saveRDS(hyp_df, hyp_rds)
  write_csv(hyp_flat, hyp_csv)
  message(sprintf("Hypothesis results saved (%d hypotheses)", nrow(hyp_flat)))
}

# ── Step 6: Discussion analysis ───────────────────────────────────────────────

if (!is.null(discussions)) {
  message(sprintf("\n── Step 6 [Claude]: Discussion analysis on %d articles ──", nrow(discussions)))

  if (file.exists(disc_rds)) {
    message("Loading cached discussion results. Delete claude_results/", basename(disc_rds), " to rerun.")
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
      model         = CLAUDE_MODEL,
      log_file      = log_file
    )

    for (attempt in 1:2) {
      failed_ids <- disc_df$article_id[disc_df$disc_error == TRUE]
      if (length(failed_ids) == 0) break
      retry_df <- filter(disc_df, article_id %in% failed_ids) |>
        select(all_of(names(disc_with_theories)))
      retry_res <- batch_extract_discussion(retry_df, "discussion", "theory_names",
                                            "article_id", model = CLAUDE_MODEL, log_file = log_file)
      disc_df[disc_df$article_id %in% failed_ids, ] <- retry_res
    }

    disc_summary <- disc_df |>
      select(article_id, disc_reengagement, disc_overclaim, disc_quality, disc_error)
    saveRDS(disc_df, disc_rds)
    write_csv(disc_summary, disc_csv)
    message(sprintf("Discussion results saved (%d articles)", nrow(disc_df)))
  }
}

# ── Step 7: Construct validity analysis ───────────────────────────────────────

if (!is.null(methods_sections) && nrow(methods_sections) > 0) {
  message(sprintf("\n── Step 7 [Claude]: Construct validity analysis on %d articles ──",
                  nrow(methods_sections)))

  if (file.exists(meth_rds)) {
    message("Loading cached methods results. Delete claude_results/", basename(meth_rds), " to rerun.")
    meth_df <- readRDS(meth_rds)
  } else {
    theory_names_by_article <- flat |>
      group_by(article_id) |>
      summarise(theory_names = list(unique(name[!is.na(name)])), .groups = "drop")

    meth_with_theories <- rename(methods_sections, methods_text = text) |>
      left_join(theory_names_by_article, by = "article_id") |>
      mutate(theory_names = map(theory_names, ~ .x %||% character(0)))

    if (exists("results_df") && "theory_explicit" %in% names(results_df)) {
      meth_with_theories <- meth_with_theories |>
        left_join(select(results_df, article_id, theory_explicit), by = "article_id")
    }

    meth_df <- batch_extract_methods(
      df            = meth_with_theories,
      text_column   = "methods_text",
      theory_column = "theory_names",
      id_column     = "article_id",
      model         = CLAUDE_MODEL,
      log_file      = log_file
    )

    for (attempt in 1:2) {
      failed_ids <- meth_df$article_id[meth_df$meth_error == TRUE]
      if (length(failed_ids) == 0) break
      retry_df <- filter(meth_df, article_id %in% failed_ids) |>
        select(all_of(names(meth_with_theories)))
      retry_res <- batch_extract_methods(retry_df, "methods_text", "theory_names",
                                         "article_id", model = CLAUDE_MODEL, log_file = log_file)
      meth_df[meth_df$article_id %in% failed_ids, ] <- retry_res
    }

    saveRDS(meth_df, meth_rds)
    write_csv(select(meth_df, article_id, starts_with("meth_")), meth_csv)
    message(sprintf("Methods results saved (%d articles)", nrow(meth_df)))
  }
}

message("\n── Claude pipeline complete ──────────────────────────────────────────────────")
message("Results saved to: ", OUT_DIR)
message("\nTo render the Claude report:")
message('  quarto::quarto_render("04_report.qmd",')
message('    execute_params = list(results_dir = "claude_results"))')
message("\nTo render a comparison report:")
message('  quarto::quarto_render("05_report_compare.qmd")')
