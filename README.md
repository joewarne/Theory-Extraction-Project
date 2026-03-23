# sportTheoryAI

An R-based pipeline for extracting explicit and implicit theoretical frameworks from sports science research article introductions using a locally hosted large language model (via Ollama). Produces structured, reproducible outputs suitable for systematic review, meta-analysis, and academic publication.

Sports science research rarely makes its theoretical commitments visible. This pipeline reads article introductions and asks a local LLM to identify:

- **Explicit theories** — named frameworks cited in the text (e.g., Self-Determination Theory, Central Governor Model)
- **Implicit theories** — conceptual frameworks inferred from the language used, even when not formally named

All model parameters are fixed (`temperature = 0`, `seed = 42`) so extraction is deterministic and reproducible across runs and machines. No cloud APIs are used.

---

## How to use

There are three scripts, run in order:

| Script | Purpose | Run |
|--------|---------|-----|
| `01_setup.R` | Install packages, verify Ollama, smoke test | Once (first time only) |
| `02_pipeline.R` | Convert PDFs → XML → extract introductions → LLM extraction | Each new paper set |
| `03_report.qmd` | Generate the full HTML report from saved results | After pipeline completes |

### Quickstart

```r
# 1. Install Ollama: https://ollama.com/download
# 2. In a terminal: ollama serve
# 3. In a second terminal: ollama pull llama3

# In R:
source("01_setup.R")     # first time only

# Edit PDF_DIR in 02_pipeline.R if using a different paper folder, then:
source("02_pipeline.R")  # runs extraction (~2-3 hrs for 269 papers on CPU)

# Render the report:
quarto::quarto_render("03_report.qmd")
```

---

## Project structure

```
Theory Extraction Project/
│
├── README.md                        this file
├── Theory_extraction.Rproj          R project file
│
├── 01_setup.R                       one-time setup and verification
├── 02_pipeline.R                    extraction pipeline (edit PDF_DIR for new paper sets)
├── 03_report.qmd                    comprehensive HTML report
│
├── Study_papers/                    source PDFs (269 articles)
│
├── files/xml_files_theory/          GROBID XML output (auto-created)
├── theory_pipeline_articles.Rds     parsed XML cache (auto-created)
├── theory_extraction_full.Rds       full results with raw model responses
├── theory_extraction_results.csv    tidy long-format results table
├── theory_extraction_log.jsonl      per-call model log
│
├── analysisMETACHECK.Rmd            metacheck/statcheck analysis
├── manuscript.qmd                   manuscript
│
└── sportTheoryAI/                   R package (loaded via source(), not install)
    ├── DESCRIPTION
    ├── NAMESPACE
    ├── R/
    │   ├── build_prompt.R           build_prompt(text)
    │   ├── call_model.R             call_model(prompt)
    │   ├── extract_theory.R         extract_theory(), batch_extract(), flatten_results()
    │   ├── evaluate_model.R         evaluate_extraction(), print_evaluation()
    │   └── utils.R                  internal helpers
    ├── inst/
    │   ├── config.yml               model parameters and Ollama settings
    │   └── prompt_templates/
    │       └── theory_extraction_v1.txt
    └── tests/testthat/
```

---

## Report sections

The HTML report (`03_report.qmd`) contains:

1. **Processing summary** — PDFs found, XMLs created, intro extraction success, short/missing introductions, LLM failure counts
2. **Extraction overview** — explicit vs implicit counts, confidence score distributions, articles with/without theories
3. **Theory frequency tables** — one table each for explicit and implicit theories, with counts, mean confidence, and an example sentence from the corpus
4. **Paper × theory mapping** — every theory extracted from every article in one searchable table
5. **Keyword-in-context** — every occurrence of the word *theory* in every introduction, with 10 words either side

---

## Core functions

| Function | Description |
|----------|-------------|
| `build_prompt(text)` | Assembles the versioned extraction prompt |
| `call_model(prompt)` | Posts to Ollama, returns raw response |
| `extract_theory(text)` | Single-article extraction |
| `batch_extract(df, text_column)` | Batch extraction with progress and retry |
| `flatten_results(df)` | Unnests results to tidy long format |
| `evaluate_extraction(human_df, model_df)` | Precision, recall, F1 vs human codes |

## Output schema

```json
{
  "explicit_theories": [
    { "name": "Self-Determination Theory", "role": "primary", "confidence": 0.97 }
  ],
  "implicit_theories": [
    {
      "inferred_name": "Progressive Overload Principle",
      "justification": "Authors frame adaptation as contingent on systematic increases in training load.",
      "confidence": 0.75
    }
  ],
  "no_theory_present": false
}
```

## Reproducibility

- Model: `llama3` via Ollama (local, no internet required after setup)
- Parameters: `temperature = 0`, `top_p = 1`, `top_k = 1`, `seed = 42`
- Prompt: versioned template at `sportTheoryAI/inst/prompt_templates/theory_extraction_v1.txt`
- All parameters stored in `sportTheoryAI/inst/config.yml`
