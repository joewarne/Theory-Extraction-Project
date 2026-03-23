# sportTheoryAI — Setup Instructions

## 1. Install Ollama

Download and install from https://ollama.com/download

Verify installation:
```bash
ollama --version
```

## 2. Start the Ollama server

```bash
ollama serve
```

Leave this terminal open. The server listens on `http://localhost:11434`.

## 3. Pull a model

```bash
# Recommended: llama3 (~4 GB) — best quality
ollama pull llama3

# Alternative: mistral (~4 GB) — faster
ollama pull mistral
```

List available models:
```bash
ollama list
```

## 4. Install R package dependencies

```r
install.packages(c(
  "httr", "jsonlite", "dplyr", "purrr",
  "stringr", "tibble", "cli", "rlang",
  "yaml", "devtools", "testthat"
))
```

## 5. Install the sportTheoryAI package

From within the project directory in R/Positron:
```r
devtools::install("sportTheoryAI")
```

Or from the parent directory:
```r
devtools::install("path/to/sportTheoryAI")
```

## 6. Verify the connection

```r
library(sportTheoryAI)

# Should return a parsed list without error
result <- extract_theory(
  "Self-Determination Theory underpins our hypotheses about athlete motivation."
)
str(result)
```

## 7. Configure the model

Edit `sportTheoryAI/inst/config.yml` to change:
- `model.name` — switch between `llama3`, `mistral`, etc.
- `ollama.base_url` — if Ollama is on a remote machine
- `logging.enabled` — enable/disable JSONL logging

**Do not change `temperature`, `top_p`, `top_k`, or `seed`** — these ensure
reproducible outputs across runs and machines.

## Troubleshooting

| Problem | Fix |
|---------|-----|
| `Failed to reach Ollama` | Run `ollama serve` in a terminal |
| `HTTP 404` on model name | Run `ollama pull llama3` |
| Slow responses | Try `mistral` instead of `llama3` |
| JSON parse failures | Check raw response in `result$raw_response` |

## Reproducibility Checklist

Before submitting results:
- [ ] Record `ollama list` output (model name + version hash)
- [ ] Keep `config.yml` unchanged from the analysis run
- [ ] Archive `extraction_log.jsonl`
- [ ] Keep prompt template `theory_extraction_v1.txt` unchanged
- [ ] Save full results as `.Rds` (includes raw model responses)
