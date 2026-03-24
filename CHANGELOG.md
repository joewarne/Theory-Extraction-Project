# Changelog

All notable changes to this project are documented here.

---

## [4.1.0] — 2026-03-24

### Changed

**Model migration: `llama3:8b` → `qwen2.5:7b`**
- Upgraded local LLM from LLaMA 3 8B to Qwen 2.5 7B across all extraction passes
- Motivation: v4 schema introduces nuanced philosophical distinctions (causal/taxonomic theory types, abductive inference, construct validity alignment) that require stronger instruction-following and reasoning ability than llama3 8B reliably provides
- `qwen2.5:14b` was evaluated first but exceeds VRAM limits on consumer GPUs (CUDA OOM error); `qwen2.5:7b` is the highest-capacity model that runs reliably on 6GB VRAM
- All cached extraction `.Rds` files must be deleted and re-generated when switching models — previous llama3 results are not directly comparable
- `config.yml` `model` field updated; README reproducibility section updated with model selection rationale
- Pull command: `ollama pull qwen2.5:7b`

### Fixed

- Report rendering error: `object 'theory_type' not found` — column aliasing added for pre-v4 cached data where detection type column name differs from v4 schema
- `manuscript.qmd` bibliography reference error: `references.bib` not found — bibliography stub file created; render path corrected
- Section 3a example sentences showing NA — defensive extraction added for intro text fallback
- Section 4 implicit theory justification column showing NA — `flatten_results()` updated to carry `justification` for implicit theories
- Discussion section table (`disc_overclaim_detail`) truncating text — column now uses `kableExtra::column_spec` word-wrap
- "corpus" terminology replaced with "sample" throughout report and manuscript for appropriate academic register
- Tables in report widened using `kableExtra` `full_width = TRUE` and horizontal scroll for wide column sets

---

## [4.0.0] — 2026-03-24

### Added

**Theory extraction v4 prompt** (`theory_extraction_v4.txt`)
- `theory_type` field: `causal` / `taxonomic` / `mathematical` / `paradigm` — epistemological classification that determines what kind of testing is even possible for this framework
- `boundary_conditions_met` field: `within` / `outside` / `unclear` — whether the study sample is within the theory's original specification
- `multi_theory_coherence` top-level field: `complementary` / `redundant` / `contradictory` / `unassessed` — assessed when 2+ theories are identified
- `intended_as_atheoretical` top-level field: `true` only for descriptive/normative studies where theoretical framing is not expected by the discipline
- Calibrated EXCLUDE list for `paradigm` type: Ecological Dynamics as a research orientation, biopsychosocial model as framing device

**Hypothesis extraction v3 prompt** (`hypothesis_extraction_v3.txt`)
- `abductive` added as fourth `inference_type` value: "hypothesis emerged from practical observation first, theory invoked post-hoc to provide mechanistic framing" — distinct from `consistent` (Steele, 2024; Peirce)
- Updated inference type definitions to clarify that `consistent` is the default for most sport science hypotheses

**Discussion analysis v3 prompt** (`discussion_analysis_v3.txt`)
- `theory_revision_signal` field: `none` / `refined` / `partially_disconfirming` / `new_prediction_generated` — the Lakatosian progressive/degenerative distinction at the article level
- `theory_revision_detail` field: what specifically changes or is generated for the theory
- `discussion_quality` = `strong` now requires a revision signal of `refined` or better (not just re-engagement)

**Pass 4 — Construct Validity (`methods_extraction_v1.txt` + `extract_methods.R`)**
- New fourth extraction pass on the methods section
- `meth_cv_alignment`: `aligned` / `partial` / `misaligned` / `unclear` / `not_applicable`
- `meth_mechanism_operationalised`: `mechanism_measured` / `endpoints_only` / `not_applicable`
- `meth_population_fit`: `within` / `outside` / `unclear`
- Addresses Borsboom et al. (2004) construct validity problem: a study that cites SDT but never measures need satisfaction is not a genuine test of SDT

**New report sections (03_report.qmd)**
- Section 2b: Theory framework type distribution (causal/taxonomic/mathematical/paradigm)
- Section 2c: Multi-theory coherence breakdown
- Section 6d: Theory revision signal distribution with detail table for non-none entries
- Section 6e: Construct validity — alignment, mechanism operationalisation, population fit
- TQI updated to 6 dimensions (adds construct validity as sixth criterion)

**Theory database schema**
- Four new columns: `theory_type`, `testability_ceiling`, `home_domain`, `cross_domain_application`
- `update_theory_database()` now auto-populates `theory_type` from v4 extraction results
- Schema migration: function adds new columns to any pre-v4 CSV

**Pipeline updates (02_pipeline.R)**
- Step 7: Pass 4 methods extraction with retry logic and RDS/CSV caching
- Publication year extraction from article filename (`pub_year` column)
- Methods section extraction with fallback to `"method"` label
- Final summary extended to include theory_type breakdown and construct validity counts

### Changed

- **`extract_theory.R`**: `flatten_results()` column `theory_type` (explicit/implicit) renamed to `detection_type`; new `theory_framework_type` column carries causal/taxonomic/mathematical/paradigm classification; `batch_extract()` adds `theory_atheoretical` and `multi_theory_coherence` columns to output
- **`extract_discussion.R`**: `batch_extract_discussion()` adds `disc_revision_signal` and `disc_revision_detail` output columns; null-result stub factored into shared `.disc_null` list
- **`config.yml`**: defaults updated to v4 theory extraction, v3 hypothesis and discussion, v1 methods prompts; version bumped to 4.0.0
- **`README.md`**: updated to document four-pass pipeline, all v4 fields, new report sections

### Report backward compatibility
- Report setup chunk detects `detection_type` column and aliases it back to `theory_type` for existing pre-v4 CSV files
- All new sections gated with `eval = has_meth`, `eval = has_framework_type`, etc.

---

## [3.0.0] — 2026-03-24

### Added

**Theory extraction v3 prompt** (`theory_extraction_v3.txt`)
- `prediction_strength` field: `strong` / `moderate` / `weak` / `absent` — operationalises Meehl's (1978) prediction strength criteria
- `rival_theories_acknowledged` field: whether alternatives are explicitly reasoned against
- Calibrated confidence anchoring: named established theories anchored at ≥ 0.85; borderline cases 0.30–0.55
- Stricter exclusion criteria: physiological mechanisms (ATP resynthesis, calcium dynamics, oxygen kinetics), anatomical structures, named individuals, intervention protocols, and epidemiological prevalence statements are now explicitly excluded from the theory category

**Hypothesis extraction v2 prompt** (`hypothesis_extraction_v2.txt`)
- `inference_type` field: `derived` / `consistent` / `motivated` / `none` — the critical distinction between hypotheses that follow deductively from theory vs those merely compatible with it
- `mechanism_specified` field: whether the causal mechanism is stated
- `mechanism_description` field: the mechanism as described in text
- `{{TESTED_PREDICTIONS}}` context: the model now receives the actual predictions from theory extraction, not just theory names, improving discussion alignment assessment

**Discussion analysis v2 prompt** (`discussion_analysis_v2.txt`)
- `null_result_handling` field: `accepted_as_disconfirming` / `auxiliary_hypothesis` / `methodological_artefact` / `not_addressed` / `not_applicable` — operationalises Lakatosian degenerativity test
- `study_positioning` field: `novel_prediction` / `replication` / `extension` / `boundary_test` / `unclear`
- `{{TESTED_PREDICTIONS}}` context: discussion analysis now receives specific predictions from introduction, enabling more precise re-engagement assessment

**New report sections**
- Section 3d: Prediction strength distribution and rival theory acknowledgement
- Section 5b: Inference type distribution (derived / consistent / motivated)
- Section 5c: Mechanism specification rates
- Section 6b: Null result handling distribution
- Section 6c: Study positioning distribution
- Section 7b: Theory Quality Index — composite 5-dimension score per article

**Academic manuscript** (`manuscript.qmd`)
- Full Introduction with literature review: Meehl, Lakatos, FAIR theory, Tod et al., Open Science Collaboration, Eronen & Bringmann, Guest & Martin
- Complete Methods section: corpus description, GROBID extraction, LLM pipeline, three-pass extraction schema, reproducibility, validation plan
- Results section with dynamic R code chunks pulling from extracted data
- Discussion section addressing all four research questions in context of philosophy of science literature
- Reference list

**Code updates**
- `extract_theory.R`: `flatten_results()` now carries `role`, `tested_prediction`, `prediction_strength`, and `rival_theories_acknowledged` for both explicit and implicit theories (fixing `role = NA` for all implicit theories)
- `extract_hypotheses.R`: `flatten_hypotheses()` includes `inference_type`, `mechanism_specified`, `mechanism_description`; `batch_extract_hypotheses()` automatically extracts and passes `tested_predictions` from the theory list
- `extract_discussion.R`: `batch_extract_discussion()` stores `disc_null_handling`, `disc_positioning`, `disc_null_present`; automatically extracts and passes `tested_predictions` context
- `config.yml`: updated to v3 theory extraction, v2 hypothesis and discussion prompts as defaults; version bumped to 3.0.0
- `README.md`: complete rewrite documenting all three extraction passes, all output fields, all report sections, and theoretical foundations

---

## [2.0.0] — 2026-03-23

### Added

**Theory extraction v2 prompt** (`theory_extraction_v2.txt`)
- `role` field: `operational` / `contextual` — whether the theory generates a tested prediction
- `tested_prediction` field: the specific prediction the theory generates
- `theoretical_basis_quality` field: article-level assessment (`strong` / `weak` / `absent`)
- Unified `theories[]` schema replacing separate `explicit_theories` and `implicit_theories` arrays

**Hypothesis extraction** (`hypothesis_extraction_v1.txt`, `extract_hypotheses.R`)
- Three-level linkage strength classification: `explicit` / `implicit` / `none`
- Article-level `hypothesis_theory_alignment`: `strong` / `partial` / `absent`
- `batch_extract_hypotheses()` with retry logic and progress messages
- `flatten_hypotheses()` for tidy long-format output

**Discussion analysis** (`discussion_analysis_v1.txt`, `extract_discussion.R`)
- `theory_reengagement`: `full` / `partial` / `absent`
- `claims_beyond_hypothesis` overclaiming detection
- `discussion_quality`: `strong` / `adequate` / `weak`
- `batch_extract_discussion()` with fallback to `"conclusion"` section if `"discussion"` not found

**Theory database** (`theory_database.csv`, `theory_database.R`)
- Canonical theory definitions: name, aliases, domain, authors, year, definition, boundaries, example use
- `update_theory_database()` auto-updates from flat extraction results
- Pre-populated entries for high-frequency theories in the corpus

**Theory name normalisation** (`normalise_theories.R`)
- `normalise_theory_names()` standardises case variation, punctuation, common aliases
- `normalise_flat()` applies normalisation to the full flat results table

**JSON parsing robustness**
- `.safe_parse_json()` now extracts JSON from within free-text responses (handles model preamble like "Here is the JSON output:")

**New report sections** (added to `03_report.qmd`)
- Section 2: Operational vs contextual classification
- Section 3c: Operational vs contextual breakdown per theory
- Section 5: Hypothesis-theory alignment
- Section 6: Discussion re-engagement
- Section 7: Full theory chain per article
- Section 9: Theory database

### Fixed
- `group_by(file)` error: column renamed to `id` after GROBID update; pipeline now uses correct column name
- `libdeflate` package install corruption: resolved by sourcing R files directly rather than installing as compiled package
- `batch_extract()` cli progress bar scope error: replaced with `message()` calls compatible with `purrr::imap()`
- `last_updated` type mismatch in `update_theory_database()`: replaced `dplyr::if_else()` with base `ifelse()` to handle Date/character coercion

---

## [1.0.0] — 2026-03-22

### Added

**Core pipeline**
- GROBID-based PDF → XML conversion via `metacheck::pdf2grobid()`
- Introduction section extraction using GROBID section label `"intro"`
- LLM extraction via Ollama REST API (`http://localhost:11434/api/generate`)
- Fixed model parameters: `temperature = 0`, `top_p = 1`, `top_k = 1`, `seed = 42`

**Theory extraction v1** (`theory_extraction_v1.txt`)
- Explicit theories: named frameworks with `name`, `role` (`primary`/`secondary`), `confidence`
- Implicit theories: inferred frameworks with `inferred_name`, `justification`, `confidence`
- `no_theory_present` flag

**Core functions** (`sportTheoryAI/R/`)
- `build_prompt(text)`: assembles prompt from versioned template
- `call_model(prompt)`: POST to Ollama, returns raw response
- `extract_theory(text)`: single-article extraction
- `batch_extract(df, text_column)`: batch extraction with retry
- `flatten_results(df)`: tidy long-format output
- `evaluate_extraction()`: precision, recall, F1 vs human codes

**Initial report** (`03_report.qmd`)
- Processing summary
- Theory frequency tables
- Paper × theory mapping
- Keyword-in-context ("theory" ±10 words)

**Package structure**
- `sportTheoryAI/`: R package layout with DESCRIPTION, NAMESPACE, man/, tests/
- `sportTheoryAI/inst/config.yml`: centralised model and prompt configuration
- `01_setup.R`: dependency installation and Ollama verification
- `SETUP.md`: step-by-step installation guide
