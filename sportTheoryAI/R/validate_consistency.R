#' Validate cross-pass consistency for a single article
#'
#' Checks that the outputs of Passes 1–4 are logically consistent with
#' each other. Returns a character vector of warning messages (empty if
#' no inconsistencies detected). This function does not modify results —
#' it only flags issues for human review.
#'
#' @param theory_result  List. Output from [extract_theory()] (Pass 1).
#' @param hyp_result     List. Output from [extract_hypotheses()] (Pass 2).
#' @param disc_result    List. Output from [extract_discussion()] (Pass 3).
#' @param meth_result    List. Output from [extract_methods_validity()] (Pass 4).
#' @param article_id     Character scalar. Article identifier for messages.
#'
#' @return Character vector of warning messages. Empty vector if consistent.
#'
#' @export
validate_cross_pass_consistency <- function(theory_result,
                                            hyp_result   = NULL,
                                            disc_result  = NULL,
                                            meth_result  = NULL,
                                            article_id   = "unknown") {
  warnings <- character(0)

  # --- Pass 1 → Pass 2 consistency ---
  if (!is.null(hyp_result)) {
    no_theory <- isTRUE(theory_result$no_theory_present)

    for (h in hyp_result$hypotheses %||% list()) {
      # 1. If no theory present, hypothesis inference_type should be "none" or "abductive"
      if (no_theory && !is.null(h$inference_type)) {
        if (!h$inference_type %in% c("none", "abductive")) {
          warnings <- c(warnings, paste0(
            article_id, ": No theory in Pass 1, but hypothesis has inference_type = '",
            h$inference_type, "' (expected 'none' or 'abductive')"
          ))
        }
      }

      # 2. Taxonomic/paradigm theories cannot have derived inferences
      if (!no_theory && identical(h$inference_type, "derived")) {
        all_theories <- c(theory_result$explicit_theories, theory_result$implicit_theories)
        theory_types <- vapply(all_theories, function(t) t$theory_type %||% "unknown", character(1))
        if (all(theory_types %in% c("taxonomic", "paradigm"))) {
          warnings <- c(warnings, paste0(
            article_id, ": All theories are taxonomic/paradigm, but hypothesis has ",
            "inference_type = 'derived' (only causal/mathematical theories support derivation)"
          ))
        }
      }
    }
  }

  # --- Pass 1 → Pass 3 consistency ---
  if (!is.null(disc_result)) {
    no_theory <- isTRUE(theory_result$no_theory_present)

    # 3. If no theory, re-engagement should be "absent"
    if (no_theory && !is.null(disc_result$theory_reengagement)) {
      if (!identical(disc_result$theory_reengagement, "absent")) {
        warnings <- c(warnings, paste0(
          article_id, ": No theory in Pass 1, but disc_reengagement = '",
          disc_result$theory_reengagement, "' (expected 'absent')"
        ))
      }
    }

    # 4. If theory role is only contextual, full re-engagement is unusual
    if (!no_theory && identical(disc_result$theory_reengagement, "full")) {
      all_theories <- c(theory_result$explicit_theories, theory_result$implicit_theories)
      roles <- vapply(all_theories, function(t) t$role %||% "unknown", character(1))
      if (all(roles == "contextual")) {
        warnings <- c(warnings, paste0(
          article_id, ": All theories are contextual, but disc_reengagement = 'full' ",
          "(full re-engagement typically requires an operational theory)"
        ))
      }
    }
  }

  # --- Pass 2 → Pass 4 consistency ---
  if (!is.null(hyp_result) && !is.null(meth_result)) {
    # 5. If mechanism_specified = FALSE in Pass 2, mechanism_operationalisation
    #    should be "endpoints_only" or "not_applicable"
    any_mechanism <- any(vapply(
      hyp_result$hypotheses %||% list(),
      function(h) isTRUE(h$mechanism_specified),
      logical(1)
    ))

    if (!any_mechanism && identical(meth_result$mechanism_operationalisation, "mechanism_measured")) {
      warnings <- c(warnings, paste0(
        article_id, ": No mechanism specified in Pass 2, but Pass 4 says ",
        "mechanism_operationalisation = 'mechanism_measured'"
      ))
    }
  }

  # --- Pass 1 → Pass 4 consistency ---
  if (!is.null(meth_result)) {
    no_theory <- isTRUE(theory_result$no_theory_present)

    # 6. If no theory, construct validity should be not_applicable
    if (no_theory && !is.null(meth_result$construct_validity_alignment)) {
      if (!identical(meth_result$construct_validity_alignment, "not_applicable")) {
        warnings <- c(warnings, paste0(
          article_id, ": No theory in Pass 1, but construct_validity_alignment = '",
          meth_result$construct_validity_alignment, "' (expected 'not_applicable')"
        ))
      }
    }
  }

  warnings
}


#' Batch validate cross-pass consistency across a data frame
#'
#' Runs [validate_cross_pass_consistency()] for every article in the pipeline
#' output and returns a summary data frame of inconsistencies.
#'
#' @param df Data frame with columns from all 4 passes (output of full pipeline).
#' @param id_column Character scalar. Column name for article identifiers.
#'
#' @return A tibble with columns: `article_id`, `warning`.
#'   Empty tibble if no inconsistencies found.
#'
#' @export
batch_validate_consistency <- function(df, id_column = "article_id") {
  all_warnings <- purrr::imap_dfr(seq_len(nrow(df)), function(i, ...) {
    aid <- if (id_column %in% names(df)) df[[id_column]][i] else as.character(i)

    # Reconstruct per-article result structures from the flat data frame
    theory_result <- list(
      explicit_theories         = df$theory_explicit[[i]] %||% list(),
      implicit_theories         = df$theory_implicit[[i]] %||% list(),
      no_theory_present         = df$theory_none[i] %||% NA
    )

    hyp_result <- if ("hyp_hypotheses" %in% names(df)) {
      list(hypotheses = df$hyp_hypotheses[[i]] %||% list())
    } else NULL

    disc_result <- if ("disc_reengagement" %in% names(df)) {
      list(theory_reengagement = df$disc_reengagement[i] %||% NA_character_)
    } else NULL

    meth_result <- if ("meth_cv_alignment" %in% names(df)) {
      list(
        construct_validity_alignment = df$meth_cv_alignment[i] %||% NA_character_,
        mechanism_operationalisation = df$meth_mechanism_operationalised[i] %||% NA_character_
      )
    } else NULL

    w <- validate_cross_pass_consistency(
      theory_result, hyp_result, disc_result, meth_result, article_id = aid
    )

    if (length(w) > 0) {
      tibble::tibble(article_id = aid, warning = w)
    } else {
      NULL
    }
  })

  if (nrow(all_warnings) > 0) {
    cli::cli_warn(c(
      "!" = "{nrow(all_warnings)} cross-pass inconsistencies detected across ",
      "{length(unique(all_warnings$article_id))} articles.",
      "i" = "Review with: View(consistency_warnings)"
    ))
  } else {
    cli::cli_inform(c("v" = "No cross-pass inconsistencies detected."))
  }

  all_warnings
}
