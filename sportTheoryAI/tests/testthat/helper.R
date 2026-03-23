# Tests that call call_model() or extract_theory() require Ollama running.
# Skip those with:  skip_if_no_ollama()

skip_if_no_ollama <- function() {
  response <- tryCatch(
    httr::GET("http://localhost:11434", httr::timeout(3)),
    error = function(e) NULL
  )
  if (is.null(response) || httr::http_error(response)) {
    testthat::skip("Ollama not available — skipping live model tests.")
  }
}
