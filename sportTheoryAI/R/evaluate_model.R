#' Compare model-extracted theories against human-coded ground truth
#'
#' Computes precision, recall, F1 score, and a confusion matrix by matching
#' theory names between model output and human annotations. Matching is
#' case-insensitive and strips common stop-words so minor label differences
#' (e.g. "SDT" vs "Self-Determination Theory") do not cause false negatives
#' when using fuzzy matching.
#'
#' @param human_df A data frame with human-coded labels. Must contain:
#'   - An ID column (specified by `id_column`)
#'   - A theory-name column (specified by `human_name_column`)
#'   - Optionally a `theory_type` column (`"explicit"` / `"implicit"`)
#' @param model_df A data frame output from [flatten_results()].
#' @param id_column Character scalar. Name of the shared ID column.
#' @param human_name_column Character scalar. Name of the theory-name column in
#'   `human_df`.
#' @param fuzzy Logical. Use fuzzy (token-overlap) matching in addition to
#'   exact case-insensitive matching (default `TRUE`).
#' @param fuzzy_threshold Numeric 0–1. Minimum Jaccard token overlap to count
#'   as a match when `fuzzy = TRUE` (default `0.5`).
#'
#' @return A named list:
#'   - `metrics`: tibble with `precision`, `recall`, `f1`
#'   - `confusion`: tibble counts of TP, FP, FN per article
#'   - `matched_pairs`: tibble of human–model matched name pairs
#'   - `unmatched_human`: theory names in human coding not found in model
#'   - `unmatched_model`: theory names in model not found in human coding
#'
#' @examples
#' \dontrun{
#' human <- tibble::tibble(
#'   article_id = c("A1", "A1", "A2"),
#'   theory_name = c("Self-Determination Theory", "Achievement Goal Theory",
#'                   "Inverted-U Hypothesis")
#' )
#' eval <- evaluate_extraction(human, model_results,
#'                             id_column = "article_id",
#'                             human_name_column = "theory_name")
#' eval$metrics
#' }
#'
#' @export
evaluate_extraction <- function(human_df,
                                model_df,
                                id_column          = "article_id",
                                human_name_column  = "theory_name",
                                fuzzy              = TRUE,
                                fuzzy_threshold    = 0.5) {

  .check_col <- function(df, col, df_name) {
    if (!col %in% names(df)) {
      cli::cli_abort("Column {.val {col}} not found in {.arg {df_name}}.")
    }
  }

  .check_col(human_df, id_column,         "human_df")
  .check_col(human_df, human_name_column, "human_df")
  .check_col(model_df, id_column,         "model_df")
  .check_col(model_df, "name",            "model_df")

  human_clean <- human_df |>
    dplyr::select(article_id = dplyr::all_of(id_column),
                  human_name = dplyr::all_of(human_name_column)) |>
    dplyr::mutate(article_id = as.character(article_id),
                  human_name_lc = .normalise_name(human_name))

  model_clean <- model_df |>
    dplyr::select(article_id = dplyr::all_of(id_column),
                  model_name = name) |>
    dplyr::filter(!is.na(model_name)) |>
    dplyr::mutate(article_id = as.character(article_id),
                  model_name_lc = .normalise_name(model_name))

  all_ids <- union(human_clean$article_id, model_clean$article_id)

  per_article <- purrr::map_dfr(all_ids, function(aid) {
    h <- human_clean |> dplyr::filter(article_id == aid)
    m <- model_clean |> dplyr::filter(article_id == aid)

    match_matrix <- .build_match_matrix(h$human_name_lc, m$model_name_lc,
                                        fuzzy, fuzzy_threshold)

    tp <- sum(match_matrix)
    fp <- nrow(m) - sum(colSums(match_matrix) > 0)
    fn <- nrow(h) - sum(rowSums(match_matrix) > 0)

    tibble::tibble(article_id = aid, tp = tp, fp = fp, fn = fn)
  })

  total_tp <- sum(per_article$tp)
  total_fp <- sum(per_article$fp)
  total_fn <- sum(per_article$fn)

  precision <- if ((total_tp + total_fp) > 0) total_tp / (total_tp + total_fp) else NA_real_
  recall    <- if ((total_tp + total_fn) > 0) total_tp / (total_tp + total_fn) else NA_real_
  f1        <- if (!is.na(precision) && !is.na(recall) && (precision + recall) > 0) {
    2 * precision * recall / (precision + recall)
  } else NA_real_

  metrics <- tibble::tibble(
    precision = round(precision, 4),
    recall    = round(recall,    4),
    f1        = round(f1,        4),
    tp_total  = total_tp,
    fp_total  = total_fp,
    fn_total  = total_fn
  )

  # Identify unmatched names globally
  all_human <- unique(human_clean$human_name)
  all_model <- unique(model_clean$model_name)

  all_human_lc <- .normalise_name(all_human)
  all_model_lc <- .normalise_name(all_model)

  global_matrix  <- .build_match_matrix(all_human_lc, all_model_lc, fuzzy, fuzzy_threshold)
  matched_human  <- all_human[rowSums(global_matrix) > 0]
  matched_model  <- all_model[colSums(global_matrix) > 0]

  # Build matched pairs table
  matched_pairs <- purrr::map_dfr(
    which(global_matrix, arr.ind = TRUE) |> as.data.frame(),
    function(rc) {
      tibble::tibble(human_name = all_human[rc$row], model_name = all_model[rc$col])
    }
  )

  list(
    metrics         = metrics,
    confusion       = per_article,
    matched_pairs   = matched_pairs,
    unmatched_human = setdiff(all_human, matched_human),
    unmatched_model = setdiff(all_model, matched_model)
  )
}


#' Summarise evaluation metrics with a formatted report
#'
#' @param eval_result Output from [evaluate_extraction()].
#' @return Invisibly returns `eval_result`. Prints a formatted summary.
#' @export
print_evaluation <- function(eval_result) {
  m <- eval_result$metrics
  cli::cli_h1("Theory Extraction Evaluation")
  cli::cli_inform(c(
    "Precision : {round(m$precision * 100, 1)}%",
    "Recall    : {round(m$recall    * 100, 1)}%",
    "F1        : {round(m$f1        * 100, 1)}%",
    "",
    "True Positives  : {m$tp_total}",
    "False Positives : {m$fp_total}",
    "False Negatives : {m$fn_total}"
  ))

  if (length(eval_result$unmatched_human) > 0) {
    cli::cli_inform(c(
      "!",
      "Theories in human coding NOT found by model:",
      purrr::map_chr(eval_result$unmatched_human, ~ paste0("  - ", .x))
    ))
  }

  if (length(eval_result$unmatched_model) > 0) {
    cli::cli_inform(c(
      "!",
      "Theories found by model NOT in human coding:",
      purrr::map_chr(eval_result$unmatched_model, ~ paste0("  - ", .x))
    ))
  }

  invisible(eval_result)
}


# ── Internal helpers ──────────────────────────────────────────────────────────

#' @keywords internal
.normalise_name <- function(x) {
  x |>
    stringr::str_to_lower() |>
    stringr::str_replace_all("[^a-z0-9 ]", " ") |>
    stringr::str_squish()
}

#' @keywords internal
.jaccard <- function(a, b) {
  tok_a <- unlist(stringr::str_split(a, " "))
  tok_b <- unlist(stringr::str_split(b, " "))
  intersection <- length(intersect(tok_a, tok_b))
  union_size   <- length(union(tok_a, tok_b))
  if (union_size == 0) return(0)
  intersection / union_size
}

#' @keywords internal
#' Build a logical match matrix (rows = human, cols = model)
.build_match_matrix <- function(human_lc, model_lc, fuzzy, threshold) {
  nh <- length(human_lc)
  nm <- length(model_lc)
  if (nh == 0 || nm == 0) return(matrix(FALSE, nrow = nh, ncol = nm))

  mat <- matrix(FALSE, nrow = nh, ncol = nm)
  for (i in seq_len(nh)) {
    for (j in seq_len(nm)) {
      exact_match <- identical(human_lc[i], model_lc[j])
      fuzzy_match <- fuzzy && .jaccard(human_lc[i], model_lc[j]) >= threshold
      mat[i, j]   <- exact_match || fuzzy_match
    }
  }
  mat
}
