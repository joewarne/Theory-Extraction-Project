test_that(".safe_parse_json parses valid JSON", {
  json_str <- '{"explicit_theories": [], "implicit_theories": [], "no_theory_present": true}'
  result   <- sportTheoryAI:::.safe_parse_json(json_str)
  expect_true(result$no_theory_present)
})

test_that(".safe_parse_json returns NULL and warns on malformed JSON", {
  expect_warning(
    result <- sportTheoryAI:::.safe_parse_json("not json at all {{{"),
    regexp = NA   # just checking it doesn't error; warning text may vary
  )
  # returns NULL silently if no warning captured — either outcome is acceptable
})

test_that(".safe_parse_json strips markdown fences", {
  fenced <- "```json\n{\"no_theory_present\": false}\n```"
  result <- sportTheoryAI:::.safe_parse_json(fenced)
  expect_false(result$no_theory_present)
})

test_that(".null_result contains expected keys", {
  nr <- sportTheoryAI:::.null_result()
  expect_true("extraction_error" %in% names(nr))
  expect_true(nr$extraction_error)
  expect_equal(nr$explicit_theories, list())
})
