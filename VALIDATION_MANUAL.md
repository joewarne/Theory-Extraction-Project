# Gold Sample Annotation Manual
## Inter-Rater Reliability Study — Theory Extraction Pipeline
**Project:** Theory Extraction Project, TU Dublin  
**Version:** 1.0 — 2026-05-19  
**For:** Both coders (primary researcher and second rater)

---

## 1. Purpose and Background

This project uses a large language model (LLM) pipeline to automatically extract theoretical frameworks from sports and exercise science research articles. The pipeline processes four aspects of each article in sequence:

- **Pass 1** — What theories does the introduction invoke?
- **Pass 2** — What hypotheses are stated, and how are they linked to those theories?
- **Pass 3** — Does the discussion re-engage with the theory in light of the findings?
- **Pass 4** — Do the study's measures actually correspond to the theoretical constructs?

Before the pipeline results can be reported in a manuscript, we must establish that the automated extractions are valid. We do this by hand-coding a sample of 30 articles using the same classification scheme and calculating inter-rater reliability (IRR) between two coders. The target is **Cohen's kappa ≥ 0.61** on each classification.

This manual provides all the instruction you need to complete the coding. Read it in full before opening the recording sheet. You do not need prior knowledge of the pipeline or the software.

---

## 2. What You Are Coding

You will code **30 articles** drawn from a corpus of sports and exercise science papers. For each article you will read the relevant section (introduction, discussion, or methods as appropriate) and record classifications in the **GOLD_SAMPLE_SHEET.csv** recording sheet.

You are coding independently. Do not discuss your classifications with the other coder until both have finished.

Each article has four sections to code. Work through all four passes for each article before moving to the next.

---

## 3. The Recording Sheet

Open **GOLD_SAMPLE_SHEET.csv** in Excel or Google Sheets. It contains the following worksheets:

| Sheet | Content |
|---|---|
| Pass1_Theories | One row per theory per article |
| Pass2_Hypotheses | One row per hypothesis per article |
| Pass3_Discussion | One row per article |
| Pass4_Methods | One row per article |

Each sheet has a `coder_id` column. Enter your name or initials in every row you code. Leave the other coder's rows blank.

When you are uncertain, use the `notes` column to record your reasoning. Do not leave uncertain cases unresolved — make a best judgement and note the uncertainty.

---

## 4. Pass 1 — Theory Identification

### What you are doing

Read the **introduction** of the article. Identify every theoretical framework the authors invoke to motivate their study.

### What counts as a theory

A theory must:
- Propose a mechanism (explain WHY variables relate, not just THAT they do)
- Make predictions about observable outcomes
- Be capable of being falsified by a study finding

**Include:**
- Named causal theories (e.g., Self-Determination Theory, Central Governor Model, Social Cognitive Theory)
- Named taxonomic frameworks with clear construct structure (e.g., Achievement Goal Theory)
- Implicit theories — where the theory is not named but the domain vocabulary clearly implies a recognised theoretical framework (see DR-1 below)

**Exclude — do not code these as theories:**
- Author-year citations used alone ("Deci & Ryan, 1985" with no theory name)
- Measurement or staging tools used as instruments (e.g., the Transtheoretical Model used only to stage readiness)
- Prescriptive acronym frameworks (FITT principle, RICE, SMART goals)
- Broad integrative orientations that cannot be falsified (biopsychosocial framework, ecological systems theory used as a lens)
- Statistical models, measurement instruments, training protocols, physiological facts cited as background

### Decision rules

**DR-1 — Implicit extraction:** You may infer a theory from domain vocabulary if:
1. The vocabulary appears in the primary theoretical framing of the introduction (not results or outcomes), AND
2. The implied theory is a recognised named construct whose identity is clear from the text itself

*Example:* "We applied progressive overload principles across a 12-week periodised block" → code as Periodisation Theory (implicit)  
*Counterexample:* "Athletes perceived their effort as controllable" (in results context) → do not code

**DR-2 — Citation strings:** A citation alone ("Deci & Ryan, 1985") is not a theory name. A valid extraction requires a named construct or sufficient domain vocabulary.

**DR-3 — Introduction scope:** Code only theories invoked in the introduction or stated aims. Do not extract from results, discussion, or conclusion sections. The quality of how the theory is tested is irrelevant — code what the paper claims to invoke.

**DR-4 — Multi-theory papers:** Extract ALL named theories as separate rows. If a combined/integrated framework is named, add it as an additional row and tick the `requires_review` flag.

### Classifications to record (per theory per article)

| Field | Options | Guidance |
|---|---|---|
| `theory_name` | Text | Use the canonical name (e.g., "Self-Determination Theory" not "SDT") |
| `detection_type` | explicit / implicit | Explicit = theory named in text. Implicit = inferred from vocabulary |
| `theory_framework_type` | causal / taxonomic / mathematical / paradigm | See definitions below |
| `role` | operational / contextual | Operational = generates the specific tested hypothesis. Contextual = background framing only |
| `requires_review` | yes / no | Yes if the entry is a combined framework, unnamed extension, or you are uncertain |

**Theory framework type definitions:**
- **causal** — specifies a mechanism: A causes B causes C. Can be tested in the hypothetico-deductive sense.
- **taxonomic** — organises or classifies constructs without specifying the causal mechanism (e.g., Achievement Goal Theory classifying goal orientations)
- **mathematical** — specifies relationships in formal quantitative terms with precise predictions
- **paradigm** — broad worldview or research orientation that frames questions but does not generate specific testable predictions

---

## 5. Pass 2 — Hypothesis–Theory Linkage

### What you are doing

Read the **introduction** again, focusing on the end. Identify every hypothesis (directional prediction about this study's outcome) and classify how it relates to the theories identified in Pass 1.

### What counts as a hypothesis

**Include:**
- Statements with explicit signal language: "we hypothesise", "we propose", "we predict", "we expect", "we suggest", "it is hypothesised that"
- Future-tense directional predictions without signal language: "there will be a difference", "X will be greater than Y" — if these appear at the end of the introduction in the position typical for hypotheses

**Exclude:**
- Directional statements that support a contention or argument within the body of the introduction (these predict nothing about this study's outcome)
- General aims ("this study aims to investigate...")
- Research questions without a directional prediction
- Background claims about prior literature

**Locating the hypothesis:** It almost always appears at the **end of the introduction**, immediately before the methods. If a directional statement appears mid-introduction supporting an argument, it is a contention, not a hypothesis.

### Decision rules

**DR-P2-1 — Location and signal language:** A statement positioned at the end of the introduction with a directional outcome prediction is a hypothesis, even without explicit signal language. A directional statement mid-introduction supporting an argument is not.

### Classifications to record (per hypothesis per article)

| Field | Options | Guidance |
|---|---|---|
| `hypothesis_text` | Text | Quote or close paraphrase of the prediction |
| `linked_theory` | Text or "none" | Canonical theory name from Pass 1, or "none" |
| `linkage_strength` | explicit / implicit / none | Explicit = theory named in the same sentence or directly adjacent. Implicit = theory established earlier, connection is clear but not stated. None = no apparent link |
| `inference_type` | derived / consistent / abductive / motivated / none | See definitions below |
| `mechanism_specified` | yes / no | Yes only if the text explains HOW/WHY the effect will occur through a causal pathway — not just THAT it will |

**Inference type definitions:**

- **derived** — the hypothesis follows logically from the theory's core causal claims; denying the hypothesis while accepting the theory would be a contradiction. *Extremely rare in sports science.*
- **consistent** — the hypothesis is compatible with the theory and the theory's mechanism addresses the same construct domain as the predicted outcome. This is the default for most sports science hypotheses.
- **abductive** — the text reveals that empirical observation or prior data came first, and theory was invoked retrospectively to frame it. Look for: "practitioners have long observed...", "pilot data showed...", "prior studies consistently found X; drawing on [theory]..."
- **motivated** — the theory is cited in the introduction but its construct domain does not reach the hypothesis's dependent variable. The theory is decorative rather than functional.
- **none** — no theoretical connection at all

**Consistent vs motivated rule:** Ask — does the theory's mechanism address the same construct as the DV in the hypothesis? If yes → consistent. If the DV is one or more inferential steps beyond what the theory specifies → motivated.

*Example:* SDT → intrinsic motivation hypothesis: consistent (SDT addresses motivation directly)  
*Example:* SDT → 5km time trial performance: motivated (SDT addresses motivation, not performance outcomes)

---

## 6. Pass 3 — Discussion Re-engagement

### What you are doing

Read the **discussion section** of the article. Assess how well the authors reconnect their findings to the theoretical frameworks from the introduction.

### Classifications to record (per article)

| Field | Options | Guidance |
|---|---|---|
| `theory_reengagement` | full / partial / absent | See below |
| `theory_revision_signal` | none / refined / partially_disconfirming | See below |
| `new_prediction_generated` | yes / no | Yes only if authors explicitly derive a specific untested prediction for future research |
| `null_result_present` | yes / no | Were any predictions not supported? |
| `null_result_handling` | accepted_as_disconfirming / auxiliary_hypothesis / methodological_artefact / not_addressed / not_applicable | See below |
| `claims_beyond_hypothesis` | yes / no | Did authors generalise beyond what the hypothesis test supports? |
| `discussion_quality` | strong / adequate / weak | See below |

**Theory reengagement definitions:**

- **full** — the finding is connected to the theory's mechanism, construct, or predictions with a substantive body of text. Authors explain what the result means FOR the theory, not just THAT it agrees with it. "Aligns with theory" alone is insufficient.
- **partial** — theory named but discussion stays at hypothesis level only ("our hypothesis was supported"). Broader theoretical implications not addressed.
- **absent** — theory not mentioned AND theory's construct vocabulary absent from the discussion. Before scoring absent: check whether the discussion uses the theory's conceptual vocabulary without naming it — if so, score partial or full.

**Theory revision signal definitions:**

- **none** — theory is treated as a static backdrop; the theoretical position is identical before and after the study
- **refined** — finding adds any contextual specificity: population scope, conditions, accumulating evidence, boundary conditions. "Adds to the growing body of evidence in athletic populations" qualifies.
- **partially_disconfirming** — null or contrary result acknowledged AND authors propose an explanation that implicates the theory's mechanism or scope (ceiling effects, population limits)

Note: `theory_revision_signal` and `new_prediction_generated` are independent. Score both when present.

**Null result handling definitions:**

- **accepted_as_disconfirming** — authors treat null as evidence against the hypothesis or theory
- **auxiliary_hypothesis** — null explained by a substantive assumption about the study's context (ceiling effects, population characteristics, baseline state) — a new subsidiary assumption introduced to protect the theory
- **methodological_artefact** — null attributed to design/measurement limitations (sample size, power, instrumentation) with no theoretical implication
- **not_addressed** — null results present but not discussed
- **not_applicable** — all predictions were supported

*Distinguishing auxiliary_hypothesis vs methodological_artefact:* Does the explanation invoke a property of the design/measurement, or a property of the theoretical conditions/population? Former → methodological_artefact. Latter → auxiliary_hypothesis.

**Discussion quality:**

- **strong** — theory fully re-engaged, results interpreted at theoretical level, null results handled honestly, claims proportionate, revision signal present
- **adequate** — some theoretical interpretation, minor overclaiming or partial null avoidance, revision signal may be absent
- **weak** — no theoretical re-engagement, substantial overclaiming, or systematic avoidance of null result implications

---

## 7. Pass 4 — Construct Validity

### What you are doing

Read the **methods section**. Assess whether the study's measures actually correspond to the constructs specified by the theory identified in Pass 1.

### Core question

If the theory says "variable A causes variable B", does the study actually measure A and B? Or does it measure something else entirely?

### Classifications to record (per article)

| Field | Options | Guidance |
|---|---|---|
| `construct_validity_alignment` | aligned / partial / misaligned / unclear / not_applicable | See below |
| `mechanism_operationalisation` | mechanism_measured / endpoints_only / not_applicable | See below |
| `population_boundary_fit` | within / outside / unclear | Does the sample match the population the theory was developed for? |

**Alignment definitions:**

- **aligned** — primary outcome measures directly operationalise the theory's named constructs. Validated instruments targeting the theory's constructs qualify.
- **partial** — at least one theoretical construct is measured, but others are absent. If the IV is correctly operationalised but the DV is a non-theoretical outcome (e.g., performance instead of motivation), score partial.
- **misaligned** — nothing in the study's measures corresponds to the theory's construct domain. Neither IV nor DV corresponds to what the theory specifies.
- **unclear** — insufficient information, or theory too vague to assess
- **not_applicable** — no operational theory was identified in Pass 1

**Decision rule:** `misaligned` requires that nothing corresponds to the theory at all. If at least one theoretical construct is measured → partial.

**Mechanism operationalisation definitions:**

- **mechanism_measured** — the study measures the intermediate construct the theory specifies as the causal mechanism between IV and DV
- **endpoints_only** — IV and DV measured but the theoretical mechanism between them is not
- **not_applicable** — theory is contextual, taxonomic, or paradigm type — no measurable mechanism specified

*Example (Central Governor Model — heat stress → RPE → performance):*  
- Heat stress + performance only → `endpoints_only`  
- Heat stress + continuous RPE + performance → `mechanism_measured`

---

## 8. Handling Uncertainty

- Always make a best-judgement classification — do not leave fields blank
- Use the `notes` column to record your reasoning when uncertain
- If you are genuinely unable to classify a case, record "UNCERTAIN" in the field and explain in notes
- Do not discuss your classifications with the other coder until both have finished all 30 articles

Common uncertain cases and guidance:

| Situation | Guidance |
|---|---|
| Theory is implicit — not named but vocabulary is present | Code as implicit. Note the vocabulary that led to your inference. |
| Two theories seem equally applicable | Code both as separate rows in Pass 1 |
| Hypothesis has no signal language | Check position (end of introduction) and directionality. If both are present, code as a hypothesis. |
| Discussion mentions theory once in passing | Score partial reengagement, not full |
| Can't tell if null explanation is auxiliary or methodological | Ask: does the explanation invoke a property of the study design, or a property of the theoretical conditions? |

---

## 9. IRR and Disagreement Resolution

After both coders have independently coded all 30 articles, classifications will be compared and Cohen's kappa calculated for each field. The target is **κ ≥ 0.61** on all primary fields.

Fields below threshold will be reviewed jointly to identify the source of disagreement — usually an ambiguous decision rule that needs sharpening. Disagreements on individual items will be resolved through discussion to a consensus code.

Do not attempt to reconcile or discuss individual items before the independent coding is complete.

---

*Version 1.0 — 2026-05-19. Contact the primary researcher with any questions about specific cases before coding.*
