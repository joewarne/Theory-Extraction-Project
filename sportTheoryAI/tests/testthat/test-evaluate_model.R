test_that("evaluate_extraction returns correct metrics for perfect match", {
  human <- tibble::tibble(
    article_id  = c("A1", "A2"),
    theory_name = c("Self-Determination Theory", "Central Governor Model")
  )
  model <- tibble::tibble(
    article_id  = c("A1", "A2"),
    name        = c("Self-Determination Theory", "Central Governor Model"),
    theory_type = c("explicit", "explicit"),
    role        = c("primary", "primary"),
    confidence  = c(0.95, 0.90)
  )

  result <- evaluate_extraction(human, model,
                                id_column         = "article_id",
                                human_name_column = "theory_name")

  expect_equal(result$metrics$precision, 1)
  expect_equal(result$metrics$recall,    1)
  expect_equal(result$metrics$f1,        1)
})

test_that("evaluate_extraction handles no-theory articles", {
  human <- tibble::tibble(article_id = "A1", theory_name = "SDT")
  model <- tibble::tibble(
    article_id  = "A1",
    name        = NA_character_,
    theory_type = "explicit",
    role        = NA_character_,
    confidence  = NA_real_
  )

  result <- evaluate_extraction(human, model,
                                id_column         = "article_id",
                                human_name_column = "theory_name")

  expect_equal(result$metrics$fn_total, 1)
})

test_that(".normalise_name lowercases and strips punctuation", {
  expect_equal(sportTheoryAI:::.normalise_name("Self-Determination Theory"),
               "self determination theory")
})

test_that(".jaccard returns 1 for identical strings and 0 for disjoint", {
  expect_equal(sportTheoryAI:::.jaccard("sdt", "sdt"), 1)
  expect_equal(sportTheoryAI:::.jaccard("abc", "xyz"), 0)
})
