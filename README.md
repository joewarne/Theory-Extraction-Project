# sportTheoryAI

An R-based pipeline for conducting computational audits of theory use in applied sports science research. The system uses a locally hosted large language model (via Ollama) to extract and classify theoretical frameworks from article introductions and discussions, assess the logical quality of hypothesis-theory connections, and evaluate how authors re-engage with theory in their conclusions.

The pipeline operationalises concepts from the philosophy of science — Meehl's prediction strength criteria, Lakatos's progressive/degenerative programme distinction, and FAIR theory principles — into automated, reproducible classifications across large paper corpora.

No cloud APIs are used at any stage. All outputs are deterministic and reproducible.

**NOTE:** THIS IS A LLM PROJECT AND CANNOT REPLACE THE HUMAN FACTOR IN DECISION MAKING AND INFERRING THEORY IN SCIENCE. USERS SHOULD ALWAYS VALIDATE AND INTERPRET RESULTS WITH DOMAIN EXPERTISE. LLM MODELS ALLOW COMPUTATIONAL EXTRACTION BUT NOT INFERENCE OR JUDGMENT.

---

## How to use

There are three scripts, run in order:

| Script | Purpose | Run |
|--------|---------|-----|
| `01_setup.R` | Install packages, verify Ollama, smoke test | Once (first time only) |
| `02_pipeline.R` | Convert PDFs → XML → extract text → LLM extraction (**4 passes**) | Each new paper set |
| `03_report.qmd` | Generate the full HTML report | After pipeline completes |
| `manuscript.qmd` | Generate the academic manuscript (Word format) | For publication |

### Quickstart

```r
# 1. Install Ollama: https://ollama.com/download
# 2. In a terminal: ollama serve
# 3. In a second terminal: ollama pull llama3

# In R:
source("01_setup.R")     # first time only

# Edit PDF_DIR in 02_pipeline.R if using a different paper folder, then:
source("02_pipeline.R")  # runs extraction (~3-4 hrs for 269 papers on CPU)

# Render the report:
quarto::quarto_render("03_report.qmd")

# Render the manuscript:
quarto::quarto_render("manuscript.qmd")
```

---

## Project structure

```
Theory Extraction Project/
│
├── README.md                        this file
├── CHANGELOG.md                     version history
├── SETUP.md                         full installation instructions
├── Theory_extraction.Rproj          R project file
│
├── 01_setup.R                       one-time setup and verification
├── 02_pipeline.R                    full extraction pipeline
├── 03_report.qmd                    comprehensive HTML analysis report
├── manuscript.qmd                   academic manuscript (Word output)
│
├── Study_papers/                    source PDFs
│
├── files/xml_files_theory/          GROBID XML output (auto-created)
├── theory_pipeline_articles.Rds     parsed XML cache — keep this, slow to regenerate
├── theory_extraction_full.Rds       theory extraction results (all articles)
├── hypothesis_extraction_full.Rds   hypothesis-theory alignment results
├── discussion_extraction_full.Rds   discussion re-engagement results
├── theory_extraction_results.csv    tidy long-format theory table
├── hypothesis_extraction_results.csv tidy long-format hypothesis table
├── discussion_extraction_results.csv tidy long-format discussion table
├── theory_database.csv              canonical theory definitions (grows over time)
├── theory_extraction_log.jsonl      per-call model log
│
└── sportTheoryAI/                   R package (loaded via source(), not install)
    ├── DESCRIPTION
    ├── NAMESPACE
    ├── R/
    │   ├── build_prompt.R           build_prompt(text)
    │   ├── call_model.R             call_model(prompt)
    │   ├── extract_theory.R         extract_theory(), batch_extract(), flatten_results()
    │   ├── extract_hypotheses.R     extract_hypotheses(), batch_extract_hypotheses(), flatten_hypotheses()
    │   ├── extract_discussion.R     extract_discussion(), batch_extract_discussion()
    │   ├── extract_methods.R        extract_methods_validity(), batch_extract_methods()  ← Pass 4
    │   ├── normalise_theories.R     normalise_flat(), normalise_theory_names()
    │   ├── theory_database.R        update_theory_database()
    │   ├── evaluate_model.R         evaluate_extraction(), print_evaluation()
    │   └── utils.R                  internal helpers
    ├── inst/
    │   ├── config.yml               model parameters and Ollama settings
    │   └── prompt_templates/
    │       ├── theory_extraction_v1.txt    original schema
    │       ├── theory_extraction_v2.txt    adds operational/contextual, tested_prediction
    │       ├── theory_extraction_v3.txt    adds prediction_strength, rival_theories_acknowledged,
    │       │                               calibrated confidence, stricter exclusion criteria
    │       ├── theory_extraction_v4.txt    adds theory_type (causal/taxonomic/mathematical/paradigm),
    │       │                               multi_theory_coherence, boundary_conditions_met,
    │       │                               intended_as_atheoretical  ← CURRENT DEFAULT
    │       ├── hypothesis_extraction_v1.txt  basic linkage strength classification
    │       ├── hypothesis_extraction_v2.txt  adds inference_type, mechanism_specified,
    │       │                                  tested_predictions context
    │       ├── hypothesis_extraction_v3.txt  adds abductive inference type  ← CURRENT DEFAULT
    │       ├── discussion_analysis_v1.txt    re-engagement and overclaiming
    │       ├── discussion_analysis_v2.txt    adds null_result_handling, study_positioning,
    │       │                                  tested_predictions context
    │       ├── discussion_analysis_v3.txt    adds theory_revision_signal, theory_revision_detail
    │       │                                  ← CURRENT DEFAULT
    │       └── methods_extraction_v1.txt     Pass 4 — construct validity analysis
    └── tests/testthat/
```

---

## What the pipeline extracts

### Pass 1 — Theory Extraction (introduction)

| Field | Description |
|-------|-------------|
| `type` | `explicit` (named) or `implicit` (inferred from language) |
| `theory_type` | `causal` / `taxonomic` / `mathematical` / `paradigm` — epistemological classification |
| `role` | `operational` (generates tested prediction) or `contextual` (background/framing) |
| `tested_prediction` | The specific prediction the theory generates, if operational |
| `prediction_strength` | `strong` / `moderate` / `weak` / `absent` |
| `boundary_conditions_met` | `within` / `outside` / `unclear` — whether sample is within theory's domain |
| `rival_theories_acknowledged` | Whether alternatives are reasoned against |
| `confidence` | Certainty the framework qualifies as a theory (0–1, anchored by type) |
| `theoretical_basis_quality` | Article-level: `strong` / `weak` / `absent` |
| `multi_theory_coherence` | Article-level: `complementary` / `redundant` / `contradictory` / `unassessed` |
| `intended_as_atheoretical` | Whether the study is a descriptive/normative study not expected to have theory |

### Pass 2 — Hypothesis Extraction (introduction)

| Field | Description |
|-------|-------------|
| `hypothesis_text` | The specific directional prediction |
| `linked_theory` | Theory this hypothesis derives from |
| `linkage_strength` | `explicit` / `implicit` / `none` |
| `inference_type` | `derived` / `consistent` / `abductive` / `motivated` / `none` |
| `mechanism_specified` | Whether the causal mechanism is explained |
| `mechanism_description` | The mechanism as stated in the text |
| `hyp_alignment` | Article-level: `strong` / `partial` / `absent` |

### Pass 3 — Discussion Analysis (discussion section)

| Field | Description |
|-------|-------------|
| `disc_reengagement` | `full` / `partial` / `absent` |
| `disc_revision_signal` | `none` / `refined` / `partially_disconfirming` / `new_prediction_generated` |
| `disc_revision_detail` | What specifically changes or is generated for the theory |
| `disc_overclaim` | Whether claims exceed what the hypothesis test supports |
| `disc_null_handling` | How null results are handled (see below) |
| `disc_positioning` | `novel_prediction` / `replication` / `extension` / `boundary_test` / `unclear` |
| `disc_quality` | Article-level: `strong` / `adequate` / `weak` |

**Null result handling options:**

| Code | Meaning |
|------|---------|
| `accepted_as_disconfirming` | Null acknowledged as potential disconfirmation — scientifically strongest |
| `auxiliary_hypothesis` | Null explained by new untested assumption — Lakatosian protective belt |
| `methodological_artefact` | Null attributed to design limitations without theoretical consideration |
| `not_addressed` | Null results present but ignored |
| `not_applicable` | All predictions supported |

### Pass 4 — Construct Validity (methods section)

| Field | Description |
|-------|-------------|
| `meth_cv_alignment` | `aligned` / `partial` / `misaligned` / `unclear` / `not_applicable` |
| `meth_cv_rationale` | Which measures are present and which theoretical constructs are absent |
| `meth_mechanism_operationalised` | `mechanism_measured` / `endpoints_only` / `not_applicable` |
| `meth_mechanism_detail` | What intermediate measure or missing mechanism is identified |
| `meth_population_fit` | `within` / `outside` / `unclear` — sample vs theory's original domain |
| `meth_population_rationale` | Sentence describing the population-theory boundary assessment |

---

## Report sections

The HTML report (`03_report.qmd`) contains fourteen sections:

| Section | Contents |
|---------|----------|
| 1 | Processing summary — PDF/XML counts, intro lengths, LLM failures |
| 2 | Theory extraction overview — explicit/implicit/operational/contextual counts |
| 2b | **Theory framework type** — causal/taxonomic/mathematical/paradigm distribution |
| 2c | **Multi-theory coherence** — complementary/redundant/contradictory breakdown |
| 3a | Explicit theory frequency table with context and operational breakdown |
| 3b | Implicit theory frequency table with justification |
| 3c | Operational vs contextual breakdown per theory |
| 3d | Prediction strength distribution and rival theory acknowledgement |
| 4 | Paper × theory mapping — every theory in every article |
| 5a | Hypothesis-theory alignment overview and quality distribution |
| 5b | Inference type (derived / consistent / **abductive** / motivated) distribution |
| 5c | Mechanism specification rates |
| 6a | Discussion re-engagement quality |
| 6b | Null result handling distribution |
| 6c | Study positioning distribution |
| 6d | **Theory revision signal** — none/refined/partially_disconfirming/new_prediction_generated |
| 6e | **Construct validity** (Pass 4) — measures aligned to theoretical constructs? |
| 7 | Full theory chain per article (Introduction → Hypothesis → Discussion) |
| 7b | Theory Quality Index — composite **6-dimension** score per article |
| 8 | Keyword-in-context — every occurrence of "theory" ±10 words |
| 9 | Theory database — canonical definitions, framework type, boundaries, example uses |

---

## Core functions

| Function | Description |
|----------|-------------|
| `build_prompt(text)` | Assembles the versioned extraction prompt |
| `call_model(prompt)` | Posts to Ollama, returns raw response |
| `extract_theory(text)` | Single-article theory extraction |
| `batch_extract(df, text_column)` | Batch theory extraction with retry |
| `flatten_results(df)` | Unnests theory results to tidy long format |
| `extract_hypotheses(text, theories, tested_predictions)` | Single-article hypothesis extraction |
| `batch_extract_hypotheses(df, ...)` | Batch hypothesis extraction |
| `flatten_hypotheses(df)` | Unnests hypothesis results to tidy long format |
| `extract_discussion(text, theories, tested_predictions)` | Single-article discussion analysis |
| `batch_extract_discussion(df, ...)` | Batch discussion analysis |
| `extract_methods_validity(text, theories, tested_predictions)` | Single-article construct validity analysis |
| `batch_extract_methods(df, ...)` | Batch methods/construct validity extraction |
| `normalise_flat(flat)` | Standardise theory names |
| `update_theory_database(flat)` | Add/update canonical theory database |
| `evaluate_extraction(human_df, model_df)` | Precision, recall, F1 vs human codes |

---

## Reproducibility

- **Model:** `llama3` via Ollama (local, no internet required after pull)
- **Parameters:** `temperature = 0`, `top_p = 1`, `top_k = 1`, `seed = 42`
- **Prompt versions:** v3 (theory), v2 (hypothesis), v2 (discussion) — all in `sportTheoryAI/inst/prompt_templates/`
- **Config:** `sportTheoryAI/inst/config.yml`

To re-run on a new set of papers, edit `PDF_DIR` in `02_pipeline.R` and delete only the extraction `.Rds` files. Keep `theory_pipeline_articles.Rds` if re-using the same PDFs.

---

## Theoretical foundations

The extraction schema operationalises four bodies of literature:

- **Meehl (1978, 1990):** Prediction strength criteria; the crud factor argument against vague directional hypotheses
- **Lakatos (1978):** Progressive vs degenerative science; auxiliary hypothesis proliferation as a marker of degenerate programmes
- **Eronen & Bringmann (2021); Guest & Martin (2021):** The theory crisis in psychology; formalisation levels; FAIR theory principles
- **Tod, Hardy & Oliver (2011):** Documented paucity of genuine theory testing in sport psychology

See `manuscript.qmd` for a full academic treatment with citations.
