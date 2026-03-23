#' Normalise theory names to canonical forms
#'
#' Applies a two-stage normalisation to theory names extracted by the LLM:
#' 1. String cleaning (case, whitespace, punctuation)
#' 2. Alias lookup against a known canonical name table
#'
#' This resolves fragmentation such as "Self Determination Theory",
#' "Self-determination theory", and "SDT" all mapping to
#' "Self-Determination Theory".
#'
#' @param names Character vector of raw theory names from LLM output.
#'
#' @return Character vector of normalised names, same length as `names`.
#'
#' @export
normalise_theory_names <- function(names) {
  cleaned <- names |>
    stringr::str_squish() |>
    stringr::str_to_title()

  purrr::map_chr(cleaned, function(nm) {
    hit <- .theory_aliases[
      stringr::str_detect(nm, stringr::regex(.theory_aliases$pattern, ignore_case = TRUE)),
    ]
    if (nrow(hit) > 0) hit$canonical[1] else nm
  })
}


#' Apply normalisation to the flat results table
#'
#' Convenience wrapper that normalises the `name` column of the data frame
#' returned by [flatten_results()].
#'
#' @param flat Data frame with a `name` column (output of [flatten_results()]).
#'
#' @return `flat` with `name` replaced by normalised values and a new
#'   `name_raw` column preserving the original.
#'
#' @export
normalise_flat <- function(flat) {
  if (nrow(flat) == 0 || !"name" %in% names(flat)) return(flat)
  flat |>
    dplyr::mutate(
      name_raw = name,
      name     = normalise_theory_names(name)
    )
}


# ── Internal alias table ──────────────────────────────────────────────────────
# pattern: regex to match raw names; canonical: standardised display name

.theory_aliases <- tibble::tribble(
  ~pattern,                                                        ~canonical,

  # Self-Determination Theory
  "self.?determin",                                                "Self-Determination Theory",
  "\\bSDT\\b",                                                     "Self-Determination Theory",
  "basic.?psycholog",                                              "Self-Determination Theory",

  # Achievement Goal Theory
  "achievement.?goal",                                             "Achievement Goal Theory",
  "\\bAGT\\b",                                                     "Achievement Goal Theory",
  "mastery.?goal|performance.?goal",                               "Achievement Goal Theory",

  # Social Cognitive Theory
  "social.?cogni",                                                 "Social Cognitive Theory",
  "\\bSCT\\b",                                                     "Social Cognitive Theory",
  "bandura",                                                       "Social Cognitive Theory",
  "self.?efficac",                                                 "Social Cognitive Theory",

  # Constraint-Led Approach
  "constraint.?led",                                               "Constraint-Led Approach",
  "constraints.?based",                                            "Constraint-Led Approach",
  "newell.*constraint",                                            "Constraint-Led Approach",

  # Central Governor Model
  "central.?governor",                                             "Central Governor Model",
  "\\bCGM\\b",                                                     "Central Governor Model",

  # Dual-Process Model
  "dual.?process",                                                 "Dual-Process Model",
  "system 1.*system 2|type 1.*type 2",                            "Dual-Process Model",

  # Inverted-U Hypothesis
  "inverted.?u",                                                   "Inverted-U Hypothesis",
  "yerkes.?dodson",                                                "Inverted-U Hypothesis",

  # Progressive Overload
  "progressive.?overload",                                         "Progressive Overload Principle",
  "overload.?principle",                                           "Progressive Overload Principle",

  # Transtheoretical Model
  "transtheoretical",                                              "Transtheoretical Model",
  "stages? of change",                                             "Transtheoretical Model",
  "\\bTTM\\b",                                                     "Transtheoretical Model",

  # Theory of Planned Behaviour
  "planned.?behav",                                                "Theory of Planned Behaviour",
  "\\bTPB\\b",                                                     "Theory of Planned Behaviour",

  # Ecological Dynamics
  "ecological.?dynam",                                             "Ecological Dynamics",
  "affordance",                                                    "Ecological Dynamics",

  # Overreaching / Overtraining
  "overreach",                                                     "Overreaching Model",
  "overtraining.?syndrome",                                        "Overtraining Syndrome Model",

  # General Stress-Recovery
  "stress.?recover",                                               "Stress-Recovery Model",
  "recovery.?stress",                                              "Stress-Recovery Model",

  # Attention Control Theory
  "attention.?control",                                            "Attention Control Theory",
  "\\bACT\\b.*anxi|anxi.*\\bACT\\b",                              "Attention Control Theory",

  # Relative Age Effect
  "relative.?age",                                                 "Relative Age Effect",
  "\\bRAE\\b",                                                     "Relative Age Effect"
)
