# =============================================================================
# 02_pipeline_deepseek.R  —  Theory Extraction Pipeline (DeepSeek API backend)
#
# Four-pass LLM extraction pipeline using DeepSeek V4 Pro (deepseek-v4-pro):
#   Pass 1 — Theory classification  (introduction)
#   Pass 2 — Hypothesis-theory linkage  (introduction)
#   Pass 3 — Discussion re-engagement  (discussion/conclusion)
#   Pass 4 — Construct validity  (methods section)
#
# PREREQUISITES:
#   1. Run 01_setup.R at least once.
#   2. Set your DeepSeek API key:
#        Sys.setenv(DEEPSEEK_API_KEY = "sk-...")
#   3. GROBID XML files must already exist (run Steps 1–3 of any prior pipeline).
#
# OUTPUT:  deepseek_results/
#          theory_extraction_deepseek.Rds   / theory_extraction_deepseek.csv
#          hypothesis_extraction_deepseek.Rds / hypothesis_extraction_deepseek.csv
#          discussion_extraction_deepseek.Rds / discussion_extraction_deepseek.csv
#          methods_extraction_deepseek.Rds   / methods_extraction_deepseek.csv
# =============================================================================

# ── API key check ─────────────────────────────────────────────────────────────

if (!nzchar(Sys.getenv("DEEPSEEK_API_KEY"))) {
  stop(
    "DEEPSEEK_API_KEY is not set.\n",
    "Run: Sys.setenv(DEEPSEEK_API_KEY = 'sk-...')\n",
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

# ── Route all LLM calls through the DeepSeek API ─────────────────────────────

options(sportTheoryAI.backend = "deepseek")
DS_MODEL <- "deepseek-v4-pro"

# ── Configuration ─────────────────────────────────────────────────────────────

PDF_DIR    <- here("Study_papers")
GROBID_URL <- "https://thesanogoeffect-grobid-papercheck.hf.space"
xml_dir    <- here("files", "xml_files_theory")    # shared GROBID output
rds_path   <- here("theory_pipeline_articles.Rds") # shared GROBID parse cache

OUT_DIR    <- here("deepseek_results")
dir.create(OUT_DIR, showWarnings = FALSE, recursive = TRUE)

out_rds   <- file.path(OUT_DIR, "theory_extraction_deepseek.Rds")
out_csv   <- file.path(OUT_DIR, "theory_extraction_deepseek.csv")
hyp_rds   <- file.path(OUT_DIR, "hypothesis_extraction_deepseek.Rds")
hyp_csv   <- file.path(OUT_DIR, "hypothesis_extraction_deepseek.csv")
disc_rds  <- file.path(OUT_DIR, "discussion_extraction_deepseek.Rds")
disc_csv  <- file.path(OUT_DIR, "discussion_extraction_deepseek.csv")
meth_rds  <- file.path(OUT_DIR, "methods_extraction_deepseek.Rds")
meth_csv  <- file.path(OUT_DIR, "methods_extraction_deepseek.csv")
log_file  <- file.path(OUT_DIR, "theory_extraction_deepseek.jsonl")

# ── Load sportTheoryAI functions ──────────────────────────────────────────────

source(here("sportTheoryAI", "R", "utils.R"))
source(here("sportTheoryAI", "R", "build_prompt.R"))
source(here("sportTheoryAI", "R", "call_deepseek_api.R"))
source(here("sportTheoryAI", "R", "call_model.R"))
source(here("sportTheoryAI", "R", "extract_theory.R"))
source(here("sportTheoryAI", "R", "extract_hypotheses.R"))
source(here("sportTheoryAI", "R", "extract_discussion.R"))
source(here("sportTheoryAI", "R", "extract_methods.R"))
source(here("sportTheoryAI", "R", "normalise_theories.R"))
source(here("sportTheoryAI", "R", "theory_database.R"))

# ── Step 1–2: Load pre-parsed articles (skip GROBID — use shared cache) ──────

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

message(sprintf("\n── Step 4 [DeepSeek]: Theory extraction on %d articles ──", nrow(introductions)))

if (file.exists(out_rds)) {
  message("Loading cached theory results. Delete deepseek_results/", basename(out_rds), " to rerun.")
  results_df <- readRDS(out_rds)
} else {
  results_df <- batch_extract(
    df          = rename(introductions, introduction = text),
    text_column = "introduction",
    id_column   = "article_id",
    model       = DS_MODEL,
    log_file    = log_file
  )

  for (attempt in 1:2) {
    failed_ids <- results_df$article_id[results_df$theory_error == TRUE]
    if (length(failed_ids) == 0) break
    message(sprintf("Retry %d: %d failed articles...", attempt, length(failed_ids)))
    retry_df <- filter(rename(introductions, introduction = text), article_id %in% failed_ids)
    retry_results <- batch_extract(retry_df, "introduction", "article_id",
                                   model = DS_MODEL, log_file = log_file)
    results_df[results_df$article_id %in% failed_ids, ] <- retry_results
  }

  flat <- flatten_results(results_df, id_column = "article_id") |> normalise_flat()
  saveRDS(results_df, out_rds)
  write_csv(flat, out_csv)
  message(sprintf("Theory results saved (%d theories across %d articles)", nrow(flat), nrow(results_df)))
}

flat <- read_csv(out_csv, show_col_types = FALSE)

if (nrow(flat) > 0) {
  update_theory_database(flat, db_path = file.path(OUT_DIR, "theory_database_deepseek.csv"))
}

if (nrow(flat) == 0) {
  message("No theories extracted — skipping Steps 5–7. Check warnings() for API errors.")
  stop("Step 4 produced 0 theories. Fix API errors before proceeding.", call. = FALSE)
}

# ── Step 5: Hypothesis extraction ─────────────────────────────────────────────

message(sprintf("\n── Step 5 [DeepSeek]: Hypothesis extraction on %d articles ──", nrow(introductions)))

if (file.exists(hyp_rds)) {
  message("Loading cached hypothesis results. Delete deepseek_results/", basename(hyp_rds), " to rerun.")
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
    model         = DS_MODEL,
    log_file      = log_file
  )

  for (attempt in 1:2) {
    failed_ids <- hyp_df$article_id[hyp_df$hyp_error == TRUE]
    if (length(failed_ids) == 0) break
    message(sprintf("Retry %d: %d failed...", attempt, length(failed_ids)))
    retry_df <- filter(hyp_df, article_id %in% failed_ids) |>
      select(all_of(names(intro_with_theories)))
    retry_res <- batch_extract_hypotheses(retry_df, "introduction", "theory_names",
                                          "article_id", model = DS_MODEL, log_file = log_file)
    hyp_df[hyp_df$article_id %in% failed_ids, ] <- retry_res
  }

  hyp_flat <- flatten_hypotheses(hyp_df, id_column = "article_id")
  saveRDS(hyp_df, hyp_rds)
  write_csv(hyp_flat, hyp_csv)
  message(sprintf("Hypothesis results saved (%d hypotheses)", nrow(hyp_flat)))
}

# ── Step 6: Discussion analysis ───────────────────────────────────────────────

if (!is.null(discussions)) {
  message(sprintf("\n── Step 6 [DeepSeek]: Discussion analysis on %d articles ──", nrow(discussions)))

  if (file.exists(disc_rds)) {
    message("Loading cached discussion results. Delete deepseek_results/", basename(disc_rds), " to rerun.")
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
      model         = DS_MODEL,
      log_file      = log_file
    )

    for (attempt in 1:2) {
      failed_ids <- disc_df$article_id[disc_df$disc_error == TRUE]
      if (length(failed_ids) == 0) break
      retry_df <- filter(disc_df, article_id %in% failed_ids) |>
        select(all_of(names(disc_with_theories)))
      retry_res <- batch_extract_discussion(retry_df, "discussion", "theory_names",
                                            "article_id", model = DS_MODEL, log_file = log_file)
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
  message(sprintf("\n── Step 7 [DeepSeek]: Construct validity analysis on %d articles ──",
                  nrow(methods_sections)))

  if (file.exists(meth_rds)) {
    message("Loading cached methods results. Delete deepseek_results/", basename(meth_rds), " to rerun.")
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
      model         = DS_MODEL,
      log_file      = log_file
    )

    for (attempt in 1:2) {
      failed_ids <- meth_df$article_id[meth_df$meth_error == TRUE]
      if (length(failed_ids) == 0) break
      retry_df <- filter(meth_df, article_id %in% failed_ids) |>
        select(all_of(names(meth_with_theories)))
      retry_res <- batch_extract_methods(retry_df, "methods_text", "theory_names",
                                         "article_id", model = DS_MODEL, log_file = log_file)
      meth_df[meth_df$article_id %in% failed_ids, ] <- retry_res
    }

    saveRDS(meth_df, meth_rds)
    write_csv(select(meth_df, article_id, starts_with("meth_")), meth_csv)
    message(sprintf("Methods results saved (%d articles)", nrow(meth_df)))
  }
}

# ── Final summary ─────────────────────────────────────────────────────────────

hyp_flat  <- if (file.exists(hyp_csv))  read_csv(hyp_csv,  show_col_types = FALSE) else tibble()
disc_data <- if (file.exists(disc_rds)) readRDS(disc_rds)                          else tibble()
meth_data <- if (file.exists(meth_rds)) readRDS(meth_rds)                          else tibble()

cat("\n=== DeepSeek Pipeline Complete ===\n")
cat(sprintf("Articles processed          : %d\n", nrow(results_df)))
cat(sprintf("Theory errors               : %d\n", sum(results_df$theory_error, na.rm = TRUE)))
cat(sprintf("Theories found (total)      : %d\n", nrow(flat)))
cat(sprintf("  Causal theories           : %d\n", sum(flat$theory_framework_type == "causal",      na.rm = TRUE)))
cat(sprintf("  Taxonomic theories        : %d\n", sum(flat$theory_framework_type == "taxonomic",   na.rm = TRUE)))
cat(sprintf("  Mathematical theories     : %d\n", sum(flat$theory_framework_type == "mathematical",na.rm = TRUE)))
cat(sprintf("  Paradigm frameworks       : %d\n", sum(flat$theory_framework_type == "paradigm",    na.rm = TRUE)))
cat(sprintf("Hypotheses found            : %d\n", nrow(hyp_flat)))
if (nrow(disc_data) > 0) {
  cat(sprintf("Discussion analyses         : %d\n", nrow(disc_data)))
  cat(sprintf("  Full re-engagement        : %d\n", sum(disc_data$disc_reengagement == "full",    na.rm = TRUE)))
  cat(sprintf("  Partial re-engagement     : %d\n", sum(disc_data$disc_reengagement == "partial", na.rm = TRUE)))
  cat(sprintf("  Absent re-engagement      : %d\n", sum(disc_data$disc_reengagement == "absent",  na.rm = TRUE)))
  cat(sprintf("  Theory revision signal    : %d\n", sum(disc_data$disc_revision_signal != "none" & !is.na(disc_data$disc_revision_signal))))
}
if (nrow(meth_data) > 0) {
  cat(sprintf("Construct validity analyses : %d\n", nrow(meth_data)))
  cat(sprintf("  Aligned                   : %d\n", sum(meth_data$meth_cv_alignment == "aligned",    na.rm = TRUE)))
  cat(sprintf("  Partial alignment         : %d\n", sum(meth_data$meth_cv_alignment == "partial",    na.rm = TRUE)))
  cat(sprintf("  Misaligned                : %d\n", sum(meth_data$meth_cv_alignment == "misaligned", na.rm = TRUE)))
}
cat("\nResults saved to: ", OUT_DIR, "\n")
cat("Run quarto::quarto_render('04_report.qmd',\n")
cat("  execute_params = list(results_dir = 'deepseek_results'))\n")
cat("to generate the report.\n")
