# sportTheoryAI

An R-based pipeline for conducting computational audits of theory use in applied sports science research. The system uses a large language model to extract and classify theoretical frameworks from article introductions and discussions, assess the logical quality of hypothesis-theory connections, and evaluate how authors re-engage with theory in their conclusions.

The pipeline operationalises concepts from the philosophy of science — Meehl's prediction strength criteria, Lakatos's progressive/degenerative programme distinction, and FAIR theory principles — into automated, reproducible classifications across large paper samples.

**Two backends supported:**
- **Local (Ollama)**: Qwen 2.5 7B via Ollama — fully offline, no cloud APIs, deterministic
- **Cloud (Claude API)**: Anthropic Claude Sonnet via API — significantly higher extraction quality (see [10-paper comparison](#claude-vs-local-model-comparison))

**NOTE:** THIS IS A LLM PROJECT AND CANNOT REPLACE THE HUMAN FACTOR IN DECISION MAKING AND INFERRING THEORY IN SCIENCE. USERS SHOULD ALWAYS VALIDATE AND INTERPRET RESULTS WITH DOMAIN EXPERTISE. LLM MODELS ALLOW COMPUTATIONAL EXTRACTION BUT NOT INFERENCE OR JUDGMENT.

---

## How to use

There are three scripts, run in order:

| Script | Purpose | Run |
|--------|---------|-----|
| `01_setup.R` | Install packages, verify Ollama, smoke test | Once (first time only) |
| `02_pipeline.R` | Convert PDFs → XML → extract text → LLM extraction (**4 passes**) | Each new paper set |
| `03_report.qmd` | Generate the full HTML report | After pipeline completes |
| `04_pipeline_claude.R` | Same pipeline routed through Claude API | Alternative to 02 |
| `manuscript.qmd` | Generate the academic manuscript (Word format) | For publication |

### Quickstart (Local — Ollama)

```r
# 1. Install Ollama: https://ollama.com/download
# 2. In a terminal: ollama serve
# 3. In a second terminal: ollama pull qwen2.5:7b

# In R:
source("01_setup.R")     # first time only

# Edit PDF_DIR in 02_pipeline.R if using a different paper folder, then:
source("02_pipeline.R")  # runs extraction (~3-4 hrs for 269 papers on CPU)

# Render the report:
quarto::quarto_render("03_report.qmd")
```

### Quickstart (Cloud — Claude API)

```r
# 1. Set your Anthropic API key:
Sys.setenv(ANTHROPIC_API_KEY = "sk-ant-...")
# Or add to .Renviron: ANTHROPIC_API_KEY=sk-ant-...

# 2. Run the Claude pipeline (uses v5 optimised prompts):
source("04_pipeline_claude.R")  # ~18 min for 269 papers, ~$6 total

# 3. Render the report with Claude results:
quarto::quarto_render("03_report.qmd",
  execute_params = list(results_dir = "claude_results"))
```

The Claude backend uses v5 prompt templates with system/user prompt separation, richer cross-pass context threading, and `notes` fields for reasoning transparency. See [Claude vs Local Model Comparison](#claude-vs-local-model-comparison) below.

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
    │   ├── validate_consistency.R   cross-pass consistency checks (v4.2)
    │   ├── call_claude_api.R        Anthropic Claude API backend (v4.2)
    │   ├── evaluate_model.R         evaluate_extraction(), print_evaluation()
    │   └── utils.R                  internal helpers
    ├── inst/
    │   ├── config.yml               model parameters, Ollama + Claude settings
    │   └── prompt_templates/
    │       ├── theory_extraction_v1–v4.txt    Ollama prompt evolution (v4 = current default)
    │       ├── hypothesis_extraction_v1–v3.txt Ollama prompts (v3 = current default)
    │       ├── discussion_analysis_v1–v3.txt   Ollama prompts (v3 = current default)
    │       ├── methods_extraction_v1.txt        Pass 4 construct validity
    │       ├── theory_extraction_v5_claude.txt      Claude-optimised (system/user split, notes)
    │       ├── hypothesis_extraction_v5_claude.txt  Claude-optimised
    │       ├── discussion_analysis_v5_claude.txt    Claude-optimised
    │       └── methods_extraction_v5_claude.txt     Claude-optimised
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

### Local backend (Ollama)

- **Model:** `qwen2.5:7b` via Ollama (local, no internet required after pull)
- **Parameters:** `temperature = 0`, `top_p = 1`, `top_k = 1`, `seed = 42`
- **Prompt versions:** v4 (theory), v3 (hypothesis), v3 (discussion), v1 (methods)
- **Config:** `sportTheoryAI/inst/config.yml`

### Cloud backend (Claude API)

- **Model:** `claude-sonnet-4-6` via Anthropic Messages API
- **Parameters:** `temperature = 0`, `max_tokens = 4096`
- **Prompt versions:** v5 (all passes) — Claude-optimised with system/user separation
- **Results directory:** `claude_results/`
- **Estimated cost:** ~$6 for 269 articles × 4 passes

### Model selection rationale

`qwen2.5:7b` replaces the original `llama3:8b` from v1–v3. However, a 10-paper comparison revealed that 7B-parameter models are inadequate for this classification task (44% theory hallucination rate, 0% mechanism detection, systematic inference type miscalibration). **Claude Sonnet is the recommended backend** for production use — see comparison below.

To re-run on a new set of papers, edit `PDF_DIR` in `02_pipeline.R` and delete only the extraction `.Rds` files. Keep `theory_pipeline_articles.Rds` if re-using the same PDFs.

**Changing models invalidates cached extractions.** Delete all `*_full.Rds` files if switching model mid-project.

---

## Claude vs Local Model Comparison

A 10-paper head-to-head comparison was conducted using identical article text and classification criteria. Key findings:

| Dimension | Qwen 2.5 7B (local) | Claude Sonnet (API) |
|-----------|---------------------|---------------------|
| **Theory hallucination** | ~44% (fabricated theory names) | 0% |
| **Inference type calibration** | 80% classified as "motivated" | Balanced (derived/consistent/abductive) |
| **Mechanism specification** | 0/10 detected | 3/10 detected with causal pathways |
| **Cross-pass consistency** | Frequent contradictions | Coherent across all 4 passes |
| **Atheoretical classification** | Inconsistent | 2/2 descriptive studies correctly identified |
| **Null result handling** | Often "not_applicable" when nulls present | Distinguished "not_addressed" vs "auxiliary_hypothesis" |
| **Reasoning transparency** | No reasoning visible | Detailed `notes` fields for every judgement |

**Recommendation**: Use Claude Sonnet for production runs. Use local models only for development, testing, or offline-only requirements. The quality gap is not addressable through prompt engineering alone — it reflects a fundamental capability threshold around 14B+ parameters for philosophy-of-science-level classification.

Full comparison report: `06_report_10paper_comparison.qmd`
Detailed review: `PROJECT_REVIEW_CLAUDE_OPTIMISATION.md`

---

## Theoretical foundations

The extraction schema operationalises four bodies of literature:

- **Meehl (1978, 1990):** Prediction strength criteria; the crud factor argument against vague directional hypotheses
- **Lakatos (1978):** Progressive vs degenerative science; auxiliary hypothesis proliferation as a marker of degenerate programmes
- **Eronen & Bringmann (2021); Guest & Martin (2021):** The theory crisis in psychology; formalisation levels; FAIR theory principles
- **Tod, Hardy & Oliver (2011):** Documented paucity of genuine theory testing in sport psychology

See `manuscript.qmd` for a full academic treatment with citations.
