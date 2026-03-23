test_that("build_prompt substitutes placeholder text", {
  text   <- "Self-Determination Theory underpins our study."
  prompt <- build_prompt(text)

  expect_true(grepl(text, prompt, fixed = TRUE))
  expect_false(grepl("{{INTRODUCTION_TEXT}}", prompt, fixed = TRUE))
})

test_that("build_prompt records template name as attribute", {
  prompt <- build_prompt("Some introduction text.")
  expect_true(!is.null(attr(prompt, "template_name")))
})

test_that("build_prompt errors on empty input", {
  expect_error(build_prompt(""),      class = "rlang_error")
  expect_error(build_prompt("   "),   class = "rlang_error")
  expect_error(build_prompt(NA_character_), class = "rlang_error")
})
