# Human Validation Programme for the sportTheoryAI Extraction Pipeline

**Document type:** Research Proposal
**Project:** Theory Use in Applied Sports Science — Computational Audit
**Version:** 1.0
**Authors:** Joe Warne, Barry Gorman (TU Dublin, Sports Science Replication Centre)
**Date:** March 2026

---

## 1. Background and Rationale

The `sportTheoryAI` pipeline uses a locally hosted large language model (Qwen 2.5, 7B) to classify theoretical framework use across applied sports science articles. The pipeline produces classifications across 24 variables spanning four extraction passes: theory identification and classification (Pass 1), hypothesis-theory inference structure (Pass 2), discussion re-engagement and null result handling (Pass 3), and construct validity alignment (Pass 4).

The scientific validity of the study's conclusions depends entirely on whether those classifications are accurate. LLMs operating at zero temperature with structured prompts produce reproducible output, but reproducibility is not the same as validity. A model that consistently misclassifies "consistent" inference as "derived", or that systematically fails to detect implicit theories in empirically motivated studies, will produce precise but wrong results.

Three distinct validity questions must therefore be answered before strong conclusions can be drawn from the quantitative findings:

1. **Reliability**: Do two independent human coders, using the same coding criteria, agree sufficiently on the same article? If the task is too ambiguous for humans to agree, the LLM classifications cannot be interpreted.
2. **Criterion validity**: Does LLM output match the human gold standard at a level sufficient for the scientific claims being made?
3. **Construct validity of the coding scheme**: Do the categories, as operationally defined in the prompt templates, capture meaningful, distinct scientific constructs, and is the resulting classification system interpretable by domain experts?

This document proposes a four-study validation programme addressing these questions. The studies should be conducted sequentially, with each providing input to the next.

---

## 2. Overview of the Validation Programme

| Study | Design | N | Primary purpose |
|-------|--------|---|-----------------|
| 1 | Expert review panel | 5 experts | Content validity and codebook refinement |
| 2 | Pilot reliability | 20 articles × 2 coders | Identify ambiguous variables; calibrate coders |
| 3 | Primary validation | 60 articles × 2 coders + adjudication | IRR and LLM criterion validity |
| 4 | Known-groups validity | Archival subset analysis | Ecological validity of the classification system |

---

## 3. Variables Under Validation

The pipeline produces 24 classifiable variables. For validation planning purposes, these are grouped by difficulty and epistemological importance:

### Tier 1 — Conceptually clear; expected high reliability (target κ ≥ 0.80)

| Variable | Pass | Scale | Description |
|----------|------|-------|-------------|
| `theory_present` | 1 | Binary | Is any theoretical framework present? |
| `detection_type` | 1 | Nominal-2 | Explicit (named) vs implicit (inferred) |
| `rival_theories_acknowledged` | 1 | Binary | Is an alternative account addressed? |
| `hypothesis_present` | 2 | Binary | Is a directional prediction stated? |
| `mechanism_specified` | 2 | Binary | Is the causal pathway described? |
| `disc_overclaim` | 3 | Binary | Does discussion exceed what data supports? |
| `null_result_present` | 3 | Binary | Were null results observed? |

### Tier 2 — Conceptually distinct but require careful reading (target κ ≥ 0.70)

| Variable | Pass | Scale | Description |
|----------|------|-------|-------------|
| `role` | 1 | Nominal-2 | Operational (prediction-generating) vs contextual (framing) |
| `prediction_strength` | 1 | Ordinal-4 | Strong / moderate / weak / absent |
| `linkage_strength` | 2 | Ordinal-3 | Explicit / implicit / none |
| `disc_reengagement` | 3 | Ordinal-3 | Full / partial / absent |
| `null_result_handling` | 3 | Nominal-5 | Accepted / auxiliary hypothesis / methodological artefact / not addressed / not applicable |
| `disc_positioning` | 3 | Nominal-5 | Novel / replication / extension / boundary test / unclear |
| `hyp_alignment` | 2 | Ordinal-3 | Strong / partial / absent |
| `disc_quality` | 3 | Ordinal-3 | Strong / adequate / weak |
| `theoretical_basis_quality` | 1 | Ordinal-3 | Strong / weak / absent |

### Tier 3 — Philosophically demanding; require expert knowledge (target κ ≥ 0.65)

| Variable | Pass | Scale | Description |
|----------|------|-------|-------------|
| `theory_framework_type` | 1 | Nominal-4 | Causal / taxonomic / mathematical / paradigm |
| `boundary_conditions_met` | 1 | Nominal-3 | Within / outside / unclear |
| `multi_theory_coherence` | 1 | Nominal-4 | Complementary / redundant / contradictory / unassessed |
| `inference_type` | 2 | Nominal-5 | Derived / consistent / abductive / motivated / none |
| `theory_revision_signal` | 3 | Ordinal-4 | None / refined / partially disconfirming / new prediction |
| `construct_validity_alignment` | 4 | Nominal-4 | Aligned / partial / misaligned / unclear |
| `mechanism_operationalisation` | 4 | Nominal-3 | Mechanism measured / endpoints only / not applicable |
| `population_boundary_fit` | 4 | Nominal-3 | Within / outside / unclear |

---

## 4. Study 1: Content Validity and Expert Panel Review

### Purpose

To establish that the coding categories capture conceptually distinct and meaningful scientific constructs, and that the operational definitions in the prompt templates are interpretable by domain experts without ambiguity.

### Design

An expert panel review using the Content Validity Index (CVI) methodology (Lynn, 1986; Polit & Beck, 2006). Each expert independently rates every category definition on relevance, clarity, and distinctiveness.

### Participants

**N = 5 expert reviewers** with the following profile:
- At least 2 reviewers with expertise in philosophy of science, research methodology, or scientific epistemology (e.g., academics publishing in the Meehl/Lakatos tradition or on theory in psychology/sport science)
- At least 2 reviewers with domain expertise in applied sports and exercise science at senior academic level (e.g., professors with published meta-scientific or methods-focused work)
- At least 1 reviewer with expertise in computational text analysis or automated content coding

Reviewers should NOT be coders in Studies 2 and 3 (role separation to prevent bias).

### Materials

- A **Codebook Document** derived directly from the v4 prompt templates, reformatted for human readability. The codebook must include: (i) the definition of each variable, (ii) the complete set of categories with their definitions, (iii) at least 2 worked examples of each category drawn from real articles in the sample, and (iv) decision rules for common ambiguities.
- A **Content Validity Rating Form** for each variable, asking reviewers to rate:
  - *Relevance to the construct claimed* (1 = not relevant, 4 = highly relevant)
  - *Clarity of the operational definition* (1 = cannot be applied without subjective interpretation, 4 = can be applied consistently without ambiguity)
  - *Distinctiveness from other categories* (1 = overlaps substantially with another category, 4 = clearly distinct)
  - Open-text field for each variable: "What would you change about this definition or set of categories?"

### Analysis

- **Item-level Content Validity Index (I-CVI)**: proportion of experts rating an item as 3 or 4 on relevance. Acceptable threshold: I-CVI ≥ 0.78 (5 experts; Polit & Beck, 2006).
- **Scale-level CVI (S-CVI/Ave)**: mean I-CVI across all variables. Target: S-CVI ≥ 0.90.
- Qualitative synthesis of all open-text responses to identify definitional problems.

### Outcome and Action

Variables with I-CVI < 0.78 are candidates for revision. Specifically anticipated issues:
- `inference_type` (abductive vs consistent): the distinction between abductive inference and post-hoc theoretical framing is genuinely subtle and may require additional worked examples with "abductive" cases drawn from sports science practice
- `theory_framework_type` (taxonomic vs paradigm): Achievement Goal Theory is frequently cited in two ways — sometimes as a genuine causal account of motivation, sometimes as a purely taxonomic classification scheme; this ambiguity must be resolved in the codebook
- `construct_validity_alignment` (aligned vs unclear): many methods sections will have insufficient detail to distinguish "unclear" from "partial"

All revisions to the codebook are documented and the revision rationale recorded before Study 2 begins.

---

## 5. Study 2: Pilot Reliability and Coder Training

### Purpose

To identify the most problematic variables before the primary validation, to train coders to criterion, and to estimate expected kappa values for sample size planning in Study 3.

### Design

Independent double-coding of a pilot sample, followed by structured calibration discussions.

### Sample

**N = 20 articles** drawn from the full sample using stratified random sampling:
- 7 articles where LLM identified explicit operational theories (highest stakes for Passes 1–4)
- 7 articles where LLM identified contextual or implicit theories
- 6 articles where LLM identified no theory

This stratification ensures all major subcategories are represented in the pilot. Articles should span at least 3 sub-disciplines (e.g., sport psychology, exercise physiology, performance analysis).

### Coders

**2 primary coders:**
- Both should be researchers familiar with theory in sports and exercise science, but not the authors of the study (to avoid confirmation bias in assessments of their own instrument)
- At minimum, postgraduate students supervised by someone familiar with philosophy of science
- Ideally: one researcher with methodology/philosophy background, one with sports science domain expertise

**Coder training protocol:**
1. Each coder independently reads the full Codebook Document from Study 1.
2. Each coder codes 5 training articles (not in the pilot sample) independently.
3. A joint calibration session reviews every disagreement on the training articles using the definitions. The goal is to reach explicit rules for ambiguous cases. These rules are documented as appendices to the Codebook.
4. Coders then code the 20 pilot articles independently with no further consultation.

### Data Collection Procedure

Each coder completes a structured **Coding Form** for each article. The form is designed to mirror the extraction order:
1. Read full introduction → code Pass 1 variables (theory presence, type, role, etc.)
2. Read full introduction again with Pass 1 results visible → code Pass 2 variables (hypotheses, inference type, mechanism)
3. Read full discussion → code Pass 3 variables (re-engagement, null handling, overclaiming)
4. Read full methods section → code Pass 4 variables (construct validity, mechanism operationalisation)

Coders record not only their classification but a **confidence rating (1–3)** and a **free-text justification** for each Tier 2 and Tier 3 variable.

### Analysis

For each variable:
- **Cohen's kappa** (nominal variables)
- **Weighted Cohen's kappa** (ordinal variables, using linear weights: adjacent disagreement penalised less than extreme disagreement)
- **Percent agreement** alongside kappa (because kappa is sensitive to base rate and can be misleadingly low for variables with extreme distributions)
- **Item-level error analysis**: For every disagreement, record which category each coder assigned and why. Disagreements that are consistent across multiple articles indicate definitional problems, not coder error.

Expected kappa benchmarks (Landis & Koch, 1977):
- κ < 0.40: poor, cannot be used
- κ 0.40–0.59: fair, interpret with extreme caution
- κ 0.60–0.74: good, acceptable for exploratory analysis
- κ ≥ 0.75: excellent, acceptable for primary conclusions

### Outcome and Action

Variables achieving κ < 0.60 in the pilot require:
1. Re-examination of the operational definition in the codebook
2. Addition of worked examples for the specific disagreement pattern observed
3. A second calibration round if necessary

Variables with consistent one-direction bias (one coder always higher) indicate a definitional asymmetry that must be resolved.

The pilot kappa estimates are used to calculate the sample size needed in Study 3 to achieve stable estimates.

---

## 6. Study 3: Primary Validation — LLM Criterion Validity

### Purpose

To establish the criterion validity of the LLM pipeline by comparing LLM classifications systematically against a human-coded gold standard across all 24 variables. This is the primary validity evidence for the published study.

### Sample Size Justification

Kappa reliability estimates require a minimum sample for stable estimation. Using Donner & Eliasziw (1987), for a two-rater design with the following assumptions:
- Expected kappa κ₁ = 0.70 (Tier 2 variables)
- Desired precision: 95% CI width ≤ ±0.15 (i.e., SE ≤ 0.075)
- Expected category distribution approximately equal across 3 categories

This requires approximately **N = 50 articles** for stable kappa estimation. Given that some categories (e.g., `inference_type == "derived"`) may be rare, oversampling articles likely to contain these is necessary. A final sample of **N = 60 articles** is recommended.

For variables at the theory level (not article level), N = 60 articles with an average of 2.3 theories per article yields approximately N = 138 theory-level observations — sufficient for stable estimates of theory-level variables including `theory_framework_type` and `role`.

### Sampling Strategy

**Stratified random sample from the full corpus of N = 269 articles:**

| Stratum | N | Rationale |
|---------|---|-----------|
| LLM: explicit operational theory, ≥moderate prediction strength | 20 | High-quality theory use — tests the whole chain |
| LLM: explicit contextual theory only | 15 | Tests detection_type and role discrimination |
| LLM: implicit theory only | 10 | Tests hardest detection case |
| LLM: no theory detected | 10 | Tests sensitivity (false negatives) |
| LLM: multiple theories, multi_theory_coherence ≠ unassessed | 5 | Tests multi-theory variables |

This stratification intentionally over-represents edge cases and theoretically important subgroups to ensure all categories have adequate representation. It does NOT represent the prevalence of each type in the overall corpus; the corpus-level proportions are taken directly from the full automated run.

### Gold Standard Procedure

**Stage 1: Independent double coding**

Both coders from Study 2 (now fully trained and calibrated) independently code all 60 articles using the finalised Codebook. The procedure is identical to Study 2.

**Stage 2: Reconciliation**

For each article and each variable, if the two coders agree, their agreed code is the gold standard. If they disagree, the article is flagged for adjudication.

**Stage 3: Expert adjudication**

Disagreements are referred to a **senior adjudicator** (the study's principal investigator or a named external expert in research methodology who has NOT seen the LLM output). The adjudicator reads the relevant text section and the two coders' justifications and makes a final determination. The adjudicator's determination is the gold standard for that variable for that article.

This three-stage design produces a gold standard that is:
- Systematically derived (not just one person's judgment)
- Documented (each determination has a recorded rationale)
- Blind to the LLM output at all stages

### Analysis Plan

#### Human Inter-Rater Reliability (prior to adjudication)

For each variable, compute:
- Cohen's kappa (pre-adjudication)
- Weighted kappa for ordinal variables
- Percent agreement
- Kappa confidence intervals (bootstrapped, 1000 iterations)

Report in a summary reliability table with flags for variables falling below threshold.

#### LLM Criterion Validity (LLM vs gold standard)

For **categorical agreement**:
- **Overall agreement**: proportion of articles where LLM classification equals gold standard
- **Cohen's kappa**: treating LLM as one "rater" and the human gold standard as the other
- **Sensitivity and specificity** for binary variables (e.g., theory_present, disc_overclaim)
- **Precision, recall, and F1** for multi-class variables, reported per category (macro- and micro-averaged)

For **ordinal variables** (prediction_strength, disc_reengagement, etc.):
- **Weighted kappa** (linear weights)
- **Mean absolute deviation** between LLM ordinal rank and gold standard ordinal rank
- **Directional bias analysis**: does the LLM systematically over- or under-classify (e.g., consistently rating prediction_strength one level higher than humans)?

For **theory identification** (which theory names were extracted):
- **Precision**: proportion of LLM-identified theories that are genuine theories per the gold standard
- **Recall**: proportion of gold-standard theories that the LLM detected
- **F1 score**: harmonic mean
- **Canonical name accuracy**: of correctly detected theories, what proportion received the canonical name?

#### Error Pattern Analysis

Beyond aggregate statistics, all LLM-human mismatches should be examined to identify systematic error patterns. Specifically:
1. Which theory types (causal/taxonomic/mathematical/paradigm) does the LLM most frequently misclassify?
2. Which inference types are most frequently confused (consistent vs abductive)?
3. Does the LLM over-classify theories as "operational" relative to humans?
4. Does the LLM under-detect implicit theories?
5. Does the LLM over- or under-detect overclaiming?

Systematic errors of this kind are scientifically important: they allow correction of the full corpus results using a calibration factor, and they indicate where future prompt engineering effort should be directed.

#### Reporting

All validation statistics should be reported in a supplementary materials table alongside the main paper. For the primary paper, a summary paragraph should report: human IRR (by variable tier), LLM-human kappa and F1 for the primary theoretical claims of the study, and any identified directional biases.

---

## 7. Study 4: Known-Groups Validity

### Purpose

To assess the construct validity of the entire coding system by testing a set of theoretically derived predictions about how classifications should differ across known subgroups. If the coding system is valid, it should discriminate in the predicted direction.

### Rationale

Even if the LLM reliably produces classifications that match human coders, it is possible that both the LLM and human coders are consistently miscoding the underlying construct. Known-groups validity provides an external check: if the coding system captures what it claims to capture, then certain external differences between article groups should be detectable.

### Predictions and Tests

**Prediction 4.1: Pre-registered vs non-pre-registered studies**

Pre-registered studies commit to their hypotheses and analysis plan before data collection. If `inference_type` validly distinguishes derived from post-hoc inference, pre-registered studies should show a higher rate of `derived` and lower rate of `abductive` inference type. They should also show lower rates of `disc_overclaim`.

*Test*: Compare inference_type distribution and disc_overclaim rate between pre-registered (n ≈ estimated from sample) and non-pre-registered articles using chi-square or Fisher's exact test.

**Prediction 4.2: Replication studies vs novel studies**

Studies framed as direct replications should show: (i) higher explicit theory use (they are replicating a prior theoretical test), (ii) lower `novel_prediction` and higher `replication` on `disc_positioning`, (iii) lower rates of `abductive` inference (replications are testing pre-existing hypotheses, not discovering new ones). Studies identified as replications in the sample can be cross-referenced against the Replication Centre's own database.

*Test*: Logistic regression of replication status (binary) on `inference_type` category, controlling for journal impact factor.

**Prediction 4.3: High-impact journals vs lower-impact journals**

If the coding system validly captures theory use quality, then journals with more rigorous review standards should show higher rates of `operational` theory use, higher `prediction_strength`, and more frequent `disc_reengagement`. This prediction is agnostic about the direction — it is conceivable that high-impact journals reward theory *rhetoric* rather than theory *use*, in which case the prediction may not hold and that itself is a finding.

*Test*: One-way ANOVA or Kruskal-Wallis on Theory Quality Index score by journal quartile.

**Prediction 4.4: Sport psychology vs exercise physiology**

Theory use patterns are expected to differ by sub-discipline. Sport psychology has a stronger tradition of named theory use (SDT, Achievement Goal Theory, Social Cognitive Theory), predicting higher explicit theory rates. Exercise physiology has a stronger tradition of mechanistic hypothesis testing predicting higher mechanism_specified rates and potentially higher `derived` inference. These are subgroup differences, not quality differences — neither pattern is better or worse.

*Test*: Chi-square tests on detection_type, role, and inference_type by domain category. Domain assignment is made by the research team based on journal and keyword.

**Prediction 4.5: Early-career vs senior-author studies**

Studies where the first author is demonstrably early-career (e.g., PhD dissertation-derived, first 3 years post-PhD) may show different theory use patterns compared to senior-author studies — either higher (if doctoral training emphasises theory) or lower (if junior researchers mimic the field's conventions). This is exploratory.

### Analysis

All predictions are tested at α = 0.05 with Bonferroni correction across the 5 tests (corrected α = 0.01). Effect sizes (Cohen's h for proportions, η² for ANOVA) should be reported alongside p-values. Pre-specify direction of prediction before analysis for Predictions 4.1–4.3.

---

## 8. Study 5: Adversarial and Edge Case Testing (Optional Extension)

### Purpose

To characterise the boundary conditions of the LLM pipeline by deliberately presenting it with articles designed to test known failure modes.

### Design

A set of 30 "edge case" articles are selected or constructed to stress-test specific aspects of the pipeline. Unlike Studies 2–4, the goal here is not to estimate average performance but to identify specific failure modes.

### Edge Case Categories

| Category | N | What is being tested |
|----------|---|---------------------|
| Articles with no theoretical content, well-written | 5 | False positive rate for theory detection |
| Articles that name a theory but only contextually, with no hypothesis | 5 | Role classification accuracy |
| Articles in which the theory named is misapplied (wrong domain) | 5 | boundary_conditions_met detection |
| Articles with explicit abductive reasoning language ("we observed X in practice and therefore...") | 5 | inference_type == "abductive" recall |
| Articles with explicit, unusually strong derived inference | 5 | inference_type == "derived" recall |
| Articles using taxonomic frameworks (AGT, ecological dynamics) as operational theories | 5 | theory_framework_type accuracy |

For each category, the "correct" answer is determined by expert consensus before testing.

### Analysis

For each edge case category, report: detection rate, error type (false positive vs false negative vs category substitution), and failure mode description.

---

## 9. Materials Required

The following materials must be produced before Study 2 can begin:

### 9.1 Codebook Document

A human-readable PDF/docx document containing:
- Conceptual background (what is a theory? why does the distinction between derived and consistent inference matter?)
- Complete definitions for all 24 variables with category descriptions identical to prompt templates
- **Worked examples**: For every category of every Tier 2 and Tier 3 variable, provide 2–3 verbatim passages from articles (anonymised) with the correct classification and a 2–3 sentence justification
- **Decision flowcharts** for the most difficult variables:
  - Theory presence decision tree (theory vs mechanism vs empirical finding)
  - Inference type decision tree (derived → consistent → abductive → motivated)
  - Discussion re-engagement decision tree (full → partial → absent)
  - Null result handling decision tree
- **Exclusion list** with examples: physiological mechanisms, named individuals, intervention protocols
- **Common errors section**: documented from the pilot, describing the most frequent misclassifications and how to avoid them

### 9.2 Coding Form

A structured form (Excel or REDCap) for each article containing:
- Article metadata fields (ID, journal, domain, year, first author career stage)
- Variable fields for all 24 variables with dropdown menus for category options
- Confidence rating fields (1–3) for all Tier 2 and Tier 3 variables
- Free-text justification fields for all Tier 2 and Tier 3 variables
- Automatic completion flagging (no empty required fields)

### 9.3 Training Articles

5 articles (not in pilot or primary sample) with pre-established gold standard codes and justifications, used for coder training and calibration. These should span the range of theory use quality.

### 9.4 Data Management Protocol

- All coding forms stored in a shared encrypted folder, inaccessible between coders until reconciliation
- Coder identities blinded in the reconciliation dataset (coder A and B, not named)
- LLM output stored separately and not accessible to coders at any stage
- Adjudication records maintained with reasons for every adjudicated decision

---

## 10. Statistical Analysis Plan Summary

The following statistics will be reported for each variable:

| Statistic | When used | Software |
|-----------|-----------|----------|
| Cohen's kappa (unweighted) | Nominal variables | R: `irr::kappa2()` |
| Weighted kappa (linear) | Ordinal variables | R: `irr::kappa2(weight = "linear")` |
| Krippendorff's alpha | Any variable, as cross-check | R: `irr::kripp.alpha()` |
| Bootstrapped 95% CI on kappa | All variables | R: `boot::boot()` with 1000 iterations |
| Percent agreement | All variables (reported alongside kappa) | Manual calculation |
| Sensitivity, specificity | Binary variables (LLM vs gold standard) | R: `caret::confusionMatrix()` |
| Precision, recall, F1 | Multi-class variables (LLM vs gold standard) | R: `caret::confusionMatrix(mode = "prec_recall")` |
| Weighted F1 (macro-average) | Multi-class variables | R: `MLmetrics::F1_Score()` |

**Minimum acceptable thresholds for use of a variable in primary conclusions:**
- Human IRR κ ≥ 0.60 AND LLM-human kappa ≥ 0.60

Variables not meeting both thresholds will be reported descriptively with an explicit caveat and excluded from inferential claims in the manuscript.

---

## 11. Reporting

Validation results will be reported in a dedicated **Supplementary Validation Report** released with the paper data, containing:
- Full reliability table (all 24 variables × all statistics)
- Confusion matrices for LLM vs human gold standard on all Tier 2 and Tier 3 variables
- Full error pattern analysis with examples
- Known-groups validity results
- Any prompt or codebook revisions made in response to the pilot

Within the main manuscript, a condensed validation section will report:
- Overall IRR (mean kappa across all Tier 1 and Tier 2 variables)
- LLM-human kappa for the six variables central to the paper's primary claims: `role`, `inference_type`, `disc_reengagement`, `prediction_strength`, `construct_validity_alignment`, `theory_revision_signal`
- Whether any systematic LLM bias was detected and in which direction
- Which specific variables should be interpreted cautiously

---

## 12. Ethical Considerations

- Human coders are compensated appropriately for their time (approximately 3–4 hours per 20 articles at Tier 2–3 depth)
- Coders are named in the acknowledgements of the main paper and offered co-authorship on the validation supplementary report
- All articles coded are published research and in the public domain; no individual participants are involved
- The codebook and training materials are published openly alongside the paper, enabling independent replication of the human validation process
- If the validation reveals that LLM performance is materially below threshold on variables used in primary conclusions, the main paper's conclusions are revised accordingly before publication

---

## 13. Timeline

| Phase | Activity | Duration |
|-------|----------|----------|
| Months 1–2 | Codebook development; recruit expert panel | 8 weeks |
| Month 2–3 | Study 1: Expert panel review; revise codebook | 4 weeks |
| Month 3–4 | Coder recruitment and training; Study 2 pilot | 5 weeks |
| Month 4–6 | Study 3: Primary validation (60 articles, double-coded) | 8 weeks |
| Month 6 | Reconciliation and adjudication | 2 weeks |
| Month 6–7 | Statistical analysis; Study 4 known-groups tests | 3 weeks |
| Month 7–8 | Validation report writing; revision of main manuscript | 4 weeks |

Total: approximately 8 months from project completion to validated manuscript submission.

---

## 14. References

Borsboom, D., Mellenbergh, G. J., & van Heerden, J. (2004). The concept of validity. *Psychological Review*, 111(4), 1061–1071.

Cronbach, L. J., & Meehl, P. E. (1955). Construct validity in psychological tests. *Psychological Bulletin*, 52(4), 281–302.

Donner, A., & Eliasziw, M. (1987). Sample size requirements for reliability studies. *Statistics in Medicine*, 6(4), 441–448.

Eronen, M. I., & Bringmann, L. F. (2021). The theory crisis in psychology: How to move forward. *Perspectives on Psychological Science*, 16(4), 779–788.

Krippendorff, K. (2004). *Content analysis: An introduction to its methodology* (2nd ed.). Sage.

Lakatos, I. (1978). *The methodology of scientific research programmes*. Cambridge University Press.

Landis, J. R., & Koch, G. G. (1977). The measurement of observer agreement for categorical data. *Biometrics*, 33(1), 159–174.

Lynn, M. R. (1986). Determination and quantification of content validity. *Nursing Research*, 35(6), 382–385.

Meehl, P. E. (1978). Theoretical risks and tabular asterisks: Sir Karl, Sir Ronald, and the slow progress of soft psychology. *Journal of Consulting and Clinical Psychology*, 46(4), 806–834.

Polit, D. F., & Beck, C. T. (2006). The content validity index: Are you sure you know what's being reported? Critique and recommendations. *Research in Nursing and Health*, 29(5), 489–497.

Steele, J. (2024). Foundations of scientific research in the sport and exercise sciences. In E. Dolan & J. Steele (Eds.), *Research methods in sport and exercise science: An open access primer*. Society for Transparency, Openness, and Replication in Kinesiology.

Van Lissa, C. J., et al. (2026). FAIR theory: A framework for findable, accessible, interoperable, and reusable theories. *Perspectives on Psychological Science*.
