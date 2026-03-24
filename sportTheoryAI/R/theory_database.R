#' Update the theory database with newly extracted theories
#'
#' Reads the canonical theory database CSV, adds any newly extracted theory
#' names not already present, and writes the file back. New entries are added
#' as stubs with empty definition fields — these should be completed manually
#' or via [enrich_theory_database()].
#'
#' @param flat Data frame from [flatten_results()] or [normalise_flat()].
#'   Must contain a `name` column.
#' @param db_path Path to the theory database CSV.
#'
#' @return Invisibly returns the updated database tibble.
#'
#' @export
update_theory_database <- function(flat,
                                   db_path = here::here("theory_database.csv")) {

  if (!file.exists(db_path)) {
    cli::cli_abort("Theory database not found at {.path {db_path}}.")
  }

  db <- readr::read_csv(db_path, show_col_types = FALSE)

  # Schema migration: add v4 columns if missing
  for (col in c("theory_type", "testability_ceiling", "home_domain", "cross_domain_application")) {
    if (!col %in% names(db)) db[[col]] <- NA_character_
  }

  # Count how many times each theory appears in this extraction run
  theory_counts <- flat |>
    dplyr::filter(!is.na(name), nzchar(name)) |>
    dplyr::count(name, name = "run_count")

  # Update times_extracted for existing theories
  db <- db |>
    dplyr::left_join(theory_counts, by = c("canonical_name" = "name")) |>
    dplyr::mutate(
      times_extracted = times_extracted + dplyr::coalesce(run_count, 0L),
      last_updated    = ifelse(!is.na(run_count), as.character(Sys.Date()), as.character(last_updated))
    ) |>
    dplyr::select(-run_count)

  # Identify theories not yet in the database
  new_names <- setdiff(
    theory_counts$name,
    db$canonical_name
  )

  if (length(new_names) > 0) {
    cli::cli_inform(c(
      "i" = "{length(new_names)} new theor{?y/ies} added to database as stubs:",
      ">" = paste(new_names, collapse = ", "),
      "!" = "Fill in definition, boundaries, and example fields manually."
    ))

    # Pull theory_type from flat if available (v4 schema)
    type_lookup <- if ("theory_framework_type" %in% names(flat)) {
      flat |>
        dplyr::filter(!is.na(name), nzchar(name), !is.na(theory_framework_type)) |>
        dplyr::distinct(name, theory_framework_type) |>
        dplyr::rename(theory_type = theory_framework_type)
    } else {
      dplyr::tibble(name = character(0), theory_type = character(0))
    }

    new_rows <- dplyr::tibble(
      canonical_name           = new_names,
      aliases                  = NA_character_,
      domain                   = NA_character_,
      key_authors              = NA_character_,
      year_proposed            = NA_integer_,
      definition               = "STUB — requires manual completion",
      boundaries               = "STUB — requires manual completion",
      example_use              = "STUB — requires manual completion",
      times_extracted          = purrr::map_int(new_names, function(nm) {
        theory_counts$run_count[theory_counts$name == nm]
      }),
      last_updated             = as.character(Sys.Date()),
      theory_type              = purrr::map_chr(new_names, function(nm) {
        idx <- match(nm, type_lookup$name)
        if (!is.na(idx)) type_lookup$theory_type[idx] else NA_character_
      }),
      testability_ceiling      = NA_character_,
      home_domain              = NA_character_,
      cross_domain_application = NA_character_
    )

    db <- dplyr::bind_rows(db, new_rows) |>
      dplyr::arrange(canonical_name)
  } else {
    cli::cli_inform(c("v" = "No new theories found — all already in database."))
  }

  readr::write_csv(db, db_path)
  cli::cli_inform(c("v" = "Theory database updated: {.path {db_path}}"))
  invisible(db)
}


#' Summarise the theory database
#'
#' Returns a formatted summary of the current database for inclusion in
#' reports or manual review.
#'
#' @param db_path Path to the theory database CSV.
#'
#' @return A tibble summary of the database.
#'
#' @export
summarise_theory_database <- function(db_path = here::here("theory_database.csv")) {
  db <- readr::read_csv(db_path, show_col_types = FALSE)
  cli::cli_inform(c(
    "i" = "Theory database contains {nrow(db)} entries.",
    "i" = "Stubs requiring completion: {sum(db$definition == 'STUB — requires manual completion', na.rm = TRUE)}"
  ))
  invisible(db)
}
