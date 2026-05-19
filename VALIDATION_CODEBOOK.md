# Pass 1–4 Annotation Codebook
## Validation Development Record
**Project:** Theory Extraction Project — sportTheoryAI pipeline  
**Framework:** Pangakis & Wolken (2024) LLM annotation validation discipline  
**Use case:** (d) — full corpus, growing, periodic re-ingestion  
**Validation phase:** Phase 2 — Codebook elicitation  
**Initiated:** 2026-05-19  
**Researcher:** Joe Warne, TU Dublin

---

## Context and Purpose

This document records the development of the annotation codebook for validating the four-pass LLM extraction pipeline. It is structured as a question-and-answer elicitation between the researcher and the AI assistant, followed by formalised decision rules derived from those exchanges. The codebook will be used to hand-code a gold sample for inter-rater reliability testing (Phase 3 onward).

The pipeline extracts from sports science articles:
- **Pass 1**: Theory identification and classification (what theories does the paper invoke?)
- **Pass 2**: Hypothesis–theory linkage (what hypotheses are derived from each theory?)
- **Pass 3**: Discussion re-engagement (does the discussion revisit the theory in light of findings?)
- **Pass 4**: Construct validity assessment (do the measures operationalise the theoretical constructs?)

The **core research question** is whether theories cited in sports science papers are genuinely tested — not whether any individual study is a good test of its theory. Pass 1 is therefore about identifying what theories a paper invokes, not evaluating the quality of that invocation.

---

## Phase 2 Elicitation Record

### Q1 — Defining error types

**Question posed:**  
In your own words, what does it mean for a theory extraction to be wrong? Give me a concrete example of a false positive and a false negative you would actually expect to see in your corpus.

**Researcher response:**  
> A false positive would be someone's name being used as a reference to their own theory. A negative would be that the underlying text suggests a theoretical domain implicitly but the agent does not catch it — e.g., talk about training load management and the theory is actually periodisation theory.

**Codebook entries derived:**
- DR-2 (citation strings as FP source)
- DR-1 (implicit extraction threshold, FN source)

---

### Q2 — Implicit extraction threshold

**Question posed:**  
How deep should the inference go? Three cases:

1. *"We applied progressive overload principles across a 12-week block"* — extract Periodisation Theory?
2. *"Athletes perceived their effort as controllable and internally motivated"* — extract SDT or Attribution Theory?
3. *"The coach used sandwich feedback to maintain athlete self-esteem"* — extract anything?

**Researcher responses:**
1. **Yes** — correct extraction (other theories could be captured as crossover)
2. **No** — the context relates to results, not the primary area of focus of the study
3. **No** — nothing. Technique, not a theory.

**Additional note from researcher:**  
> We could consider a "field-wide" validation screen to check if terminology around a theory is consistent with the one extracted. Shelved for later consideration.

**Codebook entries derived:**
- DR-1 (primary focus criterion, results exclusion)
- DR-3 (techniques excluded)

---

### Q3 — Theory vs. non-theory (falsifiability gate)

**Question posed:**  
Named models and frameworks sit ambiguously between theory and tool. Three cases:

1. *"We used the Transtheoretical Model to stage participants' readiness to change"* — model as measurement tool. Extract?
2. *"The FITT principle guided prescription intensity"* — acronym framework. Extract?
3. *"We drew on the biopsychosocial framework to interpret recovery"* — broad integrative framework. Extract?

**Researcher responses:**
1. **Do not extract**
2. **Do not extract**
3. **Do not extract**

**Researcher ruling:**  
> None of these are falsifiable theories and this should be the core ruleset.

**Codebook entries derived:**
- DR-3 formalised as the primary gating criterion

---

### Q5 — Multi-theory and combined frameworks

**Question posed:**  
Papers often invoke two theories together, either as a combined framework or in competition. Three cases:

1. *"We integrated SDT and Achievement Goal Theory into a combined motivational model"* — extract one, both, or neither?
2. *"Study 1 tests SDT; Study 2 tests AGT as a competing explanation"* — extract both?
3. *"We extend SDT by incorporating elements of stress-recovery theory"* — does the unnamed extension count as a separate extraction?

**Researcher responses:**
1. **Extract the combined motivational model** — the new combined construct is coded; flag for human review
2. **Extract both** — SDT and AGT are each extracted as separate entries
3. **Yes, separate extraction** — the stress-recovery theory element is extracted as its own entry

**Researcher ruling:**  
> These should be flagged for human review as well as coded.

**Codebook entries derived:**
- DR-5 (multi-theory and combined framework handling)
- OI-7 (human review flag mechanism — see Open Items)

---

### Q4 — Background citation vs. tested theory

**Question posed:**  
Papers often cite a theory to justify their topic without testing it. Three cases:

1. Introduction grounds the study in SDT; study measures adherence at 6 months with no control. Extract SDT?
2. Introduction notes that AGT has produced mixed results; study psychometrically validates a new measure. Extract AGT?
3. Introduction cites SDT, derives a directional hypothesis from it, tests it with an RCT, discusses results in relation to SDT predictions. Extract SDT?

**Researcher responses:**
1. **Yes — extract as explicit theory**
2. **Yes — extract as explicit theory**
3. **Yes — extract as explicit theory**

**Researcher ruling:**  
> All three are extracted as explicit theories. Specifically to case 3: we only consider the introduction etc., not how well the theory has been tested. This is the core question of the research project.

**Codebook entries derived:**
- DR-4 (extraction is introduction-scoped, test quality is not a criterion)

---

## Formalised Decision Rules — Pass 1

### DR-1: Implicit extraction threshold

A theory may be extracted from domain vocabulary (without the theory being explicitly named) **only if**:
- The vocabulary describes the study's **primary theoretical framing** (typically Introduction or stated aims), AND
- The implied theory is a recognised, named construct in the field, AND
- The inference is available from the text itself, not from background domain knowledge alone

A mention is **not** valid if:
- It appears in a results or outcomes context without prior theoretical framing
- The theoretical implication requires the reader to supply knowledge the text does not provide

**Positive example:** *"We applied progressive overload principles across a 12-week periodised block"* → extract Periodisation Theory  
**Negative example:** *"Athletes perceived their effort as controllable and internally motivated"* (results section) → do not extract

---

### DR-2: Citation strings excluded

Author-year citations (e.g., "Deci & Ryan, 1985") are **not** extractable as theory names. A valid extraction requires either:
- An explicitly named construct ("Self-Determination Theory"), OR
- Sufficient domain vocabulary to trigger DR-1

**Positive example:** *"Drawing on Self-Determination Theory (Deci & Ryan, 1985)..."* → extract "Self-Determination Theory"  
**Negative example:** *"As Deci and Ryan (1985) suggest..."* with no theory name → do not extract the citation string as a theory

---

### DR-3: Falsifiability gate (primary criterion)

A construct is extractable **only if** it:
- Proposes a mechanism,
- Predicts a direction of effect, and
- Is capable of being falsified by a study finding

**Excluded by this rule:**
- Measurement and staging tools (e.g., Transtheoretical Model used as a readiness instrument)
- Prescriptive frameworks and acronyms (e.g., FITT principle)
- Broad integrative or interpretive frameworks (e.g., biopsychosocial framework)
- Techniques and practices (e.g., sandwich feedback)

---

### DR-4: Introduction-scoped extraction; test quality not a criterion

Extraction is based on the **introduction and stated aims** of the paper. A theory is extracted if it is invoked to frame the study, regardless of:
- Whether the study design can actually test it
- Whether the study finds support for it
- Whether the theory is mentioned again in the discussion

The pipeline's purpose is to identify what theories the field *claims* to test — assessing whether those claims are warranted is the downstream analytic question, not a criterion for extraction.

**Positive examples (all extract):**
- Theory cited in introduction, study has no control condition
- Theory mentioned as prior literature with mixed results
- Theory fully operationalised and tested with an RCT

---

### DR-5: Multi-theory and combined framework handling

When a paper invokes multiple theories:

**Case A — Named combined/integrated framework:**  
Extract the combined construct as a single entry. Also extract the constituent named theories if they are individually named. Flag the combined entry for human review.

*Example: "We integrated SDT and AGT into a combined motivational model" → extract "SDT", "AGT", and "combined motivational model [REVIEW]"*

**Case B — Competing or parallel theories:**  
Extract all named theories as separate entries. No review flag required.

*Example: "Study 1 tests SDT; Study 2 tests AGT" → extract "SDT" and "AGT" separately*

**Case C — Named theory extended by an unnamed construct:**  
Extract both the named base theory and the unnamed extension as separate entries.

*Example: "We extend SDT by incorporating elements of stress-recovery theory" → extract "SDT" and "stress-recovery theory" separately*

**Review flag:** Applies to combined/integrated frameworks where the emergent construct may not be independently falsifiable. Human review assesses whether the combined construct meets DR-3.

---

---

## Pass 2 — Hypothesis–Theory Linkage

### Phase 2 Elicitation Record

#### Q1 — Pass 2 error types

**Question posed:**  
What does a Pass 2 extraction error look like? Give me one false positive and one false negative you'd expect in your corpus.

**Researcher response:**  
> A false positive can occur when researchers suggest a prediction or direction with implied language but this is to support a contention in the text and does not refer to the hypothesis under question. Hypothesis should typically be at the end of the introduction, begin with specific language "we hypothesise / propose / suggest" and have context that relates directly to the preceding methods section (which would be a good way to confirm it is indeed the working hypothesis). A false negative would occur when researchers pose a hypothesis without confirmatory language and it is missed, e.g. just saying "there will be a difference".

**Codebook entries derived:**
- DR-P2-1 (hypothesis location and signal language)
- DR-P2-2 (non-standard hypothesis language — avoid false negatives)
- OI-8 (cross-pass confirmation: Pass 2 hypothesis should align with what Pass 4 finds being tested)

---

### Formalised Decision Rules — Pass 2

#### DR-P2-1: Hypothesis identification — location and signal language

A genuine hypothesis must satisfy at least ONE of the following:
1. Uses explicit signal language: "we hypothesise", "we propose", "we predict", "we suggest", "we expect", "it is hypothesised that", or close variants
2. Is a directional prediction positioned at or near the **end of the introduction**, with content that maps directly onto the study design described in the methods section

A directional statement is **not** a hypothesis if:
- It uses implied directional language to support a contention or argument within the body of the introduction (e.g., "higher motivation leads to better adherence, therefore...")
- It is a background claim about prior literature or theory, not a prospective prediction about this study's outcome
- It is a general aim or objective without a directional outcome prediction

**Cross-pass confirmation:** When in doubt, check whether the predicted outcome corresponds to a dependent variable in the methods section. If it does not, treat as a contention, not a hypothesis.

#### DR-P2-5: inference_type — abductive

`abductive` applies when the text reveals that **empirical observation or prior data preceded the theoretical framing**. The diagnostic is the order of reasoning in the text: observation/pilot data/practitioner knowledge first, theory invoked second to explain or frame it.

Signals in the text that indicate abductive reasoning:
- "Practitioners have long observed that..."
- "Pilot data from our lab showed..."
- "Prior studies consistently found X; drawing on [Theory], we hypothesise..."
- "It has been noted in applied settings that..."

**Both** of the following are `abductive`:
1. *"Practitioners have long observed that athletes who train in groups outperform those who train alone. Drawing on Social Facilitation Theory, we hypothesise that the presence of others will enhance cycling time trial performance."* — observation preceded theory
2. *"Pilot data from our lab showed that athletes who received autonomy-supportive coaching reported greater enjoyment. Grounded in SDT, we hypothesise that autonomy support will predict enjoyment in our full sample."* — pilot data preceded theory

**Distinction from `consistent`:** If the text presents the theory first and the hypothesis follows from it, classify as `consistent` even if the researcher may have arrived at the idea empirically. `abductive` requires textual evidence that the empirical observation came first.

#### DR-P2-4: inference_type — derived

`derived` applies only when the theory specifies the **exact causal pathway** the hypothesis tests, with no inferential gaps between the theory's mechanism and the predicted outcome. The hypothesis must be a direct statement of what the theory's causal chain predicts will happen, such that denying the hypothesis while accepting the theory would be contradictory.

`derived` is **extremely rare** in sports science. Most sports science hypotheses, even those closely aligned with a named causal theory, are `consistent` because the theory's mechanism does not terminate precisely at the dependent variable without additional assumptions.

**Note:** Mathematical dose-response models that generate quantitative range predictions are excluded at Pass 1 (DR-3: prescriptive framework, not a falsifiable theory) and therefore cannot produce `derived` inferences in Pass 2.

**Worked example of genuine `derived`:** A theory specifies the exact causal chain "need frustration → controlled motivation → behavioural disengagement." Hypothesis: "participants in the need-frustrating condition will report lower autonomous motivation than controls." The theory names this pathway explicitly → `derived`.

#### DR-P2-3: inference_type — consistent vs motivated boundary

A hypothesis is `consistent` if the theory's named mechanism or construct domain **directly encompasses** the dependent variable in the hypothesis. The theory does not need to strictly entail the prediction — it must address the same construct.

A hypothesis is `motivated` if the dependent variable is one or more inferential steps removed from what the theory actually specifies. The theory may have inspired the research direction but bears no direct logical or causal relationship to the specific outcome being predicted.

**Worked examples:**
- SDT → intrinsic motivation hypothesis: `consistent` (SDT's mechanism addresses motivation directly)
- SDT → 5km time trial performance: `motivated` (SDT addresses motivation regulation, not performance outcomes; performance is outside the theory's construct domain)
- Periodisation Theory → VO2max gains: `consistent` (the theory predicts superior physiological adaptations from structured load variation; VO2max is such an adaptation)

**Decision rule:** Ask — does the theory's mechanism terminate at or near the hypothesis's dependent variable? If yes, `consistent`. If the DV requires additional inferential steps the theory does not specify, `motivated`.

#### DR-P2-2: Non-standard hypothesis language — avoid false negatives

Do not require explicit signal verbs. A statement qualifies as a hypothesis if:
- It is phrased as a future-tense or conditional directional prediction ("there will be a difference", "X will be greater than Y", "we expect X to increase")
- AND it appears at the end of the introduction in the position typical for hypotheses
- AND it predicts a specific outcome rather than making a general claim

---

## Pass 3 — Discussion Re-engagement

### Phase 2 Elicitation Record

#### Q1 — Pass 3 error types

**Question posed:**  
What does a Pass 3 false positive and false negative look like in your corpus?

**Researcher response:**  
> False positive — naming a theory or even saying "the result aligns with theory" without explicit connection between claim and theory and a body of words that identify the claim in light of the theory in some capacity. False negative — authors making a good effort at discussing the implication of the claim in light of elements of the theory, without any naming.

**Codebook entries derived:**
- DR-P3-1 (full reengagement threshold — requires substantive connection, not name-dropping)
- DR-P3-2 (implicit reengagement — theory name not required if construct vocabulary is present)

---

### Formalised Decision Rules — Pass 3

#### DR-P3-1: theory_reengagement = "full" threshold

`full` requires ALL of the following:
1. The specific finding is connected to the theory's mechanism, construct, or predictions — not just labelled as "consistent with" or "aligned with"
2. There is a substantive body of text that situates the finding within the theory's framework — i.e., the authors explain what the result means FOR the theory, not just THAT it agrees with it

`partial` applies when:
- The theory is named in the discussion but results are only discussed at the hypothesis level ("our hypothesis was supported")
- "Aligns with [theory]" type statements without elaboration

`absent` applies when:
- The theory is not named AND the theory's construct vocabulary is absent from the discussion

#### DR-P3-2: implicit reengagement — theory name not required

A theory name need not appear in the discussion to qualify as reengagement. If the authors discuss the finding using the theory's specific construct vocabulary, causal language, or mechanistic elements (established in Pass 1), this constitutes reengagement even without explicit naming.

**False negative guard:** Before scoring `absent`, check whether the discussion uses conceptual vocabulary associated with the theory identified in Pass 1. If the vocabulary is present and the discussion substantively interprets the finding through it, score `partial` or `full` accordingly.

#### Q2 — theory_revision_signal and new_prediction_generated

**Question posed:**  
Three cases — score theory_revision_signal for each:
1. *"...consistent with SDT's basic psychological needs model and adds to the growing body of evidence..."* 
2. *"Contrary to SDT predictions... ceiling effect... need satisfaction pathway may operate differently at elite level"*
3. *"...raises the question of whether SDT's basic needs operate independently at different developmental stages — a prediction that remains untested"*

**Researcher responses:** 1. refined, 2. partially_disconfirming, 3. new_prediction_generated

**Researcher clarification:**  
> In the last question, Case 3 was refined AND generated new prediction, as a prediction is not a theory. So we can refine or update a theory, and then lead to a new confirmatory prediction to further examine.

**Schema change derived:** `new_prediction_generated` split out as a separate boolean field; `theory_revision_signal` values reduced to `none | refined | partially_disconfirming`.

---

#### DR-P3-3: theory_revision_signal decision rules

**`none`**: The discussion confirms or fails to confirm the hypothesis with no claim about what this means for the theory beyond this study. The theory is treated as a static backdrop — present at the start, unchanged at the end.

**`refined`**: The discussion uses the finding to add ANY degree of contextual specificity to the theory — population scope, conditions under which it holds, accumulating support in a domain, boundary conditions, or moderating factors. Adding a result to "a growing body of evidence in athletic populations" qualifies as `refined`.

**`partially_disconfirming`**: A null or contrary result is acknowledged AND the authors propose an explanation that implicates the theory's mechanism or scope (e.g., ceiling effects, population limits, pathway differences). The result is difficult to reconcile with the theory as stated.

**`new_prediction_generated`**: The finding prompts the authors to derive a new, untested prediction from the theory for future investigation. The theory moves forward rather than simply being confirmed or qualified.

**`theory_revision_signal` and `new_prediction_generated` are independent fields.** A discussion can score `refined` AND `new_prediction_generated = true` simultaneously. Score both when both are present.

**Worked examples:**
- *"...consistent with SDT's basic psychological needs model and adds to the growing body of evidence supporting the theory in athletic populations"* → `refined`
- *"Contrary to SDT predictions... may reflect a ceiling effect... suggesting the need satisfaction pathway may operate differently at elite level"* → `partially_disconfirming`
- *"...raises the question of whether SDT's basic needs operate independently at different developmental stages — a prediction that remains untested"* → `new_prediction_generated`

#### Q3 — null result handling

**Question posed:**  
1. *"The absence of an effect may be due to our small sample size and consequent lack of statistical power."*
2. *"The absence of an effect may reflect the fact that our athletes were already highly motivated at baseline, leaving little room for the intervention to operate."*

**Researcher responses:** 1. methodological_artefact, 2. auxiliary_hypothesis

**Codebook entries derived:** DR-P3-4

---

#### DR-P3-4: null_result_handling — methodological_artefact vs auxiliary_hypothesis

`methodological_artefact`: The null is attributed to **design or measurement limitations** — sample size, statistical power, instrumentation, procedure. No claim is made about the theory's conditions or scope. The explanation is entirely outside the theoretical framework.

`auxiliary_hypothesis`: The null is explained by a **substantive assumption about the study's context** that modifies or restricts the theory's conditions — ceiling effects, population characteristics, baseline state, timing. This is the Lakatosian protective belt: a new subsidiary assumption is introduced to insulate the theory from the disconfirming result.

**Worked examples:**
- *"Small sample size and lack of statistical power"* → `methodological_artefact`
- *"Athletes already highly motivated at baseline, leaving little room for the intervention"* → `auxiliary_hypothesis` (introduces a ceiling assumption not in the original rationale)

**Decision rule:** Ask — does the explanation invoke a property of the study's *design or measurement*, or a property of the *theoretical conditions or population*? If the former, `methodological_artefact`. If the latter, `auxiliary_hypothesis`.

#### DR-P2-6: no_hypothesis_present

The corpus contains only papers with a confirmed hypothesis. `no_hypothesis_present = true` is therefore always an extraction error, not a valid outcome. Flag any such result for manual review.

---

---

## Pass 4 — Construct Validity

### Phase 2 Elicitation Record

#### Q1 — construct_validity_alignment cases

**Question posed:**  
Three SDT cases — score construct_validity_alignment:
1. SDT → intrinsic motivation. Measures: Basic Psychological Needs Scale + Intrinsic Motivation Inventory
2. SDT → intrinsic motivation. Measures: coach behaviour checklist (IV) + 5km time trial performance (DV)
3. SDT → intrinsic motivation. Measures: Basic Psychological Needs Scale only; performance as outcome

**Researcher responses:** 1. aligned, 2. partial, 3. partial

**Codebook entries derived:** DR-P4-1

---

### Formalised Decision Rules — Pass 4

#### DR-P4-1: construct_validity_alignment decision rules

`aligned`: The primary outcome measures **directly operationalise** the theoretical constructs specified by the theory. Validated instruments targeting the theory's named constructs qualify.

`partial`: **At least one** relevant theoretical construct is measured, but others are absent. Applies when:
- The IV is operationalised correctly but the DV is a non-theoretical outcome (e.g., performance instead of motivation)
- The mediating construct is measured but the terminal outcome is not
- Some constructs in the theoretical chain are measured, others are not

`misaligned`: The measured constructs are **categorically unrelated** to any construct in the theory's framework. Neither the IV nor the DV corresponds to what the theory specifies.

`not_applicable`: No operational theory was identified in Pass 1.

**Worked examples:**
- SDT + BPNS + IMI → `aligned`
- SDT + coach behaviour checklist + 5km performance → `partial` (IV measured correctly; DV non-theoretical)
- SDT + BPNS only; performance as outcome → `partial` (mediating construct measured; terminal construct absent)
- SDT + heart rate variability + cortisol → `misaligned` (physiological stress markers categorically unrelated to SDT's psychological constructs; nothing in the study corresponds to the theory's construct domain)

#### Q2 — misaligned confirmation

**Question posed:**  
SDT hypothesis about intrinsic motivation. Study measures only heart rate variability and cortisol. — misaligned or partial?

**Researcher response:** misaligned

---

#### Q3 — mechanism_operationalisation

**Question posed:**  
Central Governor Model (heat stress → RPE → performance). Two cases:
1. Heat stress (IV) + time trial performance (DV). RPE not measured.
2. Heat stress (IV) + RPE continuously measured + time trial performance (DV).

**Researcher responses:** 1. endpoints_only, 2. mechanism_measured

**Codebook entries derived:** DR-P4-2

---

#### DR-P4-2: mechanism_operationalisation decision rules

`mechanism_measured`: The study measures the **intermediate construct(s)** the theory specifies as the causal mechanism between IV and DV. The theoretical chain is captured, not just its endpoints.

`endpoints_only`: The study measures the IV and DV but does not measure the theoretical mechanism between them. The causal pathway is assumed but not tested.

`not_applicable`: The theory is contextual (not operational in Pass 1), or is taxonomic/paradigm type — no measurable mechanism is specified.

**Worked examples (Central Governor Model — heat stress → RPE → performance):**
- Heat stress + time trial performance, no RPE → `endpoints_only`
- Heat stress + continuous RPE + time trial performance → `mechanism_measured`

---

---

## Phase 3 — Gold Sample Design

### Decisions

| Parameter | Decision |
|---|---|
| Sample size | 30 articles |
| Coders | 2 (researcher + second rater) |
| Sampling strategy | Purposive + random: edge cases identified by system from pipeline output, remainder random |
| Passes coded | All four (Pass 1–4), in order |
| Benchmark role | Fixed sample — reused for future pipeline runs as a stability benchmark |

### Edge case selection criteria (system-identified after pipeline run)

The following output signals flag candidates for purposive inclusion:

| Signal | Field | Rationale |
|---|---|---|
| Combined/integrated framework | `requires_review = TRUE` | DR-5 Case A — hardest Pass 1 case |
| Implicit theory | `detection_type = "implicit"` | DR-1 boundary — FN risk |
| Low confidence | `confidence < 0.55` | Borderline extractions |
| Multi-theory coherence issues | `multi_theory_coherence = "redundant" or "contradictory"` | Complex Pass 1 cases |
| Abductive inference | `inference_type = "abductive"` | Pass 2 boundary case |
| Motivated linkage | `inference_type = "motivated"` | Theory decorative — Pass 2 FP risk |
| New prediction generated | `disc_new_prediction = TRUE` | Pass 3 highest revision signal |
| Partial/misaligned construct validity | `meth_cv_alignment = "partial" or "misaligned"` | Pass 4 boundary cases |
| Null result present | `disc_null_present = TRUE` | Null handling — Pass 3 edge case |

### Sampling procedure (post-pipeline)

1. Run full pipeline on 269 articles
2. Flag articles matching ≥1 edge case criterion above
3. Select up to 15 purposive articles covering the range of edge case types
4. Fill remaining slots (minimum 15) with random selection from non-flagged articles
5. Ensure total = 30

### Pending

- Second rater background and domain expertise (needed to assess whether full codebook briefing is required)
- IRR threshold (minimum acceptable kappa before results can be reported)
- Annotation sheet format (how gold sample coding will be recorded)

---

## Open Items

| ID | Item | Status |
|----|------|--------|
| OI-1 | Field-wide validation screen: check if extracted theory terminology is consistent across corpus | Shelved — Phase 6+ |
| OI-2 | Codebook elicitation for Pass 2 (hypothesis–theory linkage) | Pending |
| OI-3 | Codebook elicitation for Pass 3 (discussion re-engagement) | Pending |
| OI-4 | Codebook elicitation for Pass 4 (construct validity) | Pending |
| OI-5 | Gold sample size determination | Pending |
| OI-6 | Second rater identification | Pending |
| OI-7 | Human review flag mechanism: pipeline output field — `requires_review` added to per-theory JSON schema and `flatten_results()` output | Resolved 2026-05-19 |
| OI-8 | Cross-pass confirmation: Pass 2 hypothesis should align with what Pass 4 identifies as being tested — consider adding a cross-pass consistency check | Pending |
| OI-9 | Second rater: same sports science background as primary researcher. Full codebook manual required. | Resolved 2026-05-19 |
| OI-10 | IRR threshold: κ ≥ 0.61 (substantial agreement, Landis & Koch) before results can be reported | Resolved 2026-05-19 |
| OI-11 | Annotation system: VALIDATION_MANUAL.md (coder instruction manual) + GOLD_SAMPLE_SHEET.csv (recording sheet) | Resolved 2026-05-19 |

---

*Document updated: 2026-05-19. All Q&A entries are verbatim or lightly paraphrased from elicitation session.*
