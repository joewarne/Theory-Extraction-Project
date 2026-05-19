# sportTheoryAI — Comprehensive Project Review & Claude Optimisation Plan

**Date**: 2026-04-01
**Reviewer**: Claude (Opus 4.6)
**Scope**: Full architectural review, Claude API optimisation, future model recommendations

---

## 1. Executive Summary

The sportTheoryAI pipeline is a well-designed, philosophically grounded system for computationally auditing theory use in 269 sports science articles. The four-pass extraction architecture (theory → hypothesis → discussion → methods) is sound and the prompt templates are among the most sophisticated I have seen for structured academic content analysis.

However, the system was architected around the constraints of **small local models** (7–8B parameters). When targeting **Claude** as the primary backend, several architectural decisions become suboptimal. This review identifies **12 concrete changes** across prompts, code, and configuration that will substantially improve extraction quality when using Claude.

The 10-paper comparison revealed that Claude already outperforms Qwen 2.5 7B across every dimension — but the current implementation leaves significant Claude capability on the table.

---

## 2. Key Findings from the 10-Paper Comparison

| Dimension | Qwen 2.5 7B | Claude (Sonnet) | Gap |
|-----------|-------------|-----------------|-----|
| Theory hallucination rate | ~44% (4/9 theories fabricated) | 0% (0/8 theories) | Critical |
| Inference type calibration | 80% classified as "motivated" | Balanced distribution across derived/consistent/abductive | Severe |
| Mechanism specification | 0/10 detected | 3/10 detected with causal pathways | Total blindspot |
| Internal consistency | Frequent cross-pass contradictions | Coherent across all 4 passes | Structural |
| Reasoning transparency | No reasoning visible | Detailed `notes` fields explain every judgement | Qualitative |
| Atheoretical classification | Inconsistent | Correctly identified 2/2 descriptive studies | Reliable |
| Null result handling | Often `not_applicable` when nulls present | Distinguished `not_addressed` vs `auxiliary_hypothesis` | Nuanced |

**Bottom line**: Qwen 2.5 7B is not fit for purpose for this classification task. Claude is substantially more reliable, but the current implementation was designed to compensate for small-model weaknesses rather than exploit large-model strengths.

---

## 3. Architectural Changes for Claude Optimisation

### 3.1 System Prompt Separation (HIGH PRIORITY)

**Current state**: All prompts are single monolithic strings sent as `user` messages. This is correct for Ollama's `/api/generate` endpoint (which takes a `prompt` field), but suboptimal for the Claude Messages API.

**Problem**: Claude's architecture is designed to treat `system` prompts differently from `user` content. The system prompt sets the model's persona, expertise, and operating rules. The user message provides the specific content to analyse. Mixing these in one user message forces Claude to parse its own role from the content.

**Recommendation**: Split each prompt template into two parts:
- **System prompt**: The "You are an expert..." persona, all classification definitions, INCLUDE/EXCLUDE lists, schema definitions, calibration rules
- **User message**: The article text and any context (theory list, tested predictions)

**Impact**: Better adherence to classification rules, more consistent JSON formatting, reduced likelihood of the model "interpreting" its instructions as part of the article content.

**Implementation**: Modify `call_claude_api.R` to accept a `system` parameter:
```r
body <- list(
  model      = model,
  max_tokens = 4096L,
  temperature = 0,
  system     = system_prompt,
  messages   = list(list(role = "user", content = user_content))
)
```

### 3.2 Increase max_tokens (HIGH PRIORITY)

**Current state**: `call_claude_api.R` uses `max_tokens = 1024L`.

**Problem**: Claude's structured responses with `notes` fields, `alignment_rationale`, `mechanism_description`, and `theory_revision_detail` routinely require 800–1200 tokens for articles with multiple theories. A 1024 limit will cause JSON truncation for complex articles, producing parse failures that silently fall back to `.null_result()`.

**Recommendation**: Set `max_tokens = 4096L` (matching the Ollama `num_predict` setting). Cost impact is minimal — you only pay for tokens actually generated, not the maximum.

### 3.3 Add `notes` Field to All Pass Schemas (MEDIUM PRIORITY)

**Current state**: The JSON schemas in the prompt templates do not include a `notes` field. When I classified papers directly in conversation, I naturally produced detailed reasoning notes for every judgement.

**Problem**: Without a `notes` field, Claude's reasoning is invisible. More importantly, asking Claude to produce reasoning *before* the classification improves classification accuracy (chain-of-thought effect within the JSON structure).

**Recommendation**: Add `"notes": "<reasoning for this classification>"` as the final field in every JSON schema. This serves dual purposes:
1. Forces the model to articulate its reasoning before committing to the classification
2. Provides an audit trail for human validation (Study 3 of the Human Validation protocol)

### 3.4 Remove Guardrails Designed for Small Models (LOW PRIORITY)

**Current state**: Prompts include extensive "do NOT" lists, confidence calibration anchors, and repeated warnings about fabrication.

**Assessment**: These are appropriate for Qwen 2.5 7B, which demonstrably fabricates theories and ignores classification boundaries. For Claude, the detailed INCLUDE/EXCLUDE lists and theory type definitions are sufficient. The confidence calibration anchors (0.85–1.0 for named theories, etc.) are well-calibrated and should be retained — they provide useful structure. The fabrication warnings can be simplified to a single line rather than an extensive list.

**Recommendation**: Create `_claude` variants of prompts (v5 series) that streamline the guardrails while preserving the philosophical definitions that are genuinely informative.

---

## 4. Prompt Template Optimisations (v5 Series for Claude)

### 4.1 Theory Extraction (v5)

**Keep** (these are excellent):
- Theory type classification (causal/taxonomic/mathematical/paradigm) — this is the intellectual heart of the system
- INCLUDE/EXCLUDE lists — well-calibrated for the domain
- Role classification (operational/contextual) with prediction strength
- Boundary conditions and multi-theory coherence

**Change**:
- Split into system prompt (persona + all definitions) and user message (article text)
- Add `"notes"` field to each theory object AND to the top-level response
- Add explicit instruction: "For each theory, first reason about whether it meets the inclusion criteria, then classify"
- Remove repeated "Return ONLY the JSON" warnings — Claude reliably produces clean JSON with a single instruction

### 4.2 Hypothesis Extraction (v5)

**Keep**:
- Inference type hierarchy (derived/consistent/abductive/motivated/none) — philosophically rigorous
- The abductive category with Steele/Peirce citations — this is a genuine contribution to the literature
- Mechanism specification requirement

**Change**:
- The current prompt passes `{{THEORY_LIST}}` and `{{TESTED_PREDICTIONS}}` as flat text. For Claude, pass these as a structured context block:
```
## Prior Pass Context (Theory Extraction Results)
Theories identified: [structured list with type and role]
Tested predictions: [with theory attribution]
```
- Add instruction to check cross-pass consistency: "Your classifications must be consistent with the theory types identified in Pass 1. A taxonomic theory cannot have inference_type = 'derived'."

### 4.3 Discussion Analysis (v5)

**Keep**:
- Theory revision signal (Lakatosian framework) — this is the strongest part of the pipeline
- Null result handling categories — well-discriminated
- Overclaiming detection

**Change**:
- Pass the full Pass 1 + Pass 2 context (theory type, role, hypothesis linkage, inference type) so Claude can assess consistency
- Add: "If no operational theory was identified in Pass 1, theory_reengagement should be scored relative to whichever framework (contextual, taxonomic) was identified, but disc_quality cannot exceed 'adequate' without an operational theory"

### 4.4 Methods/Construct Validity (v5)

**Keep**:
- The Borsboom construct validity framing — this is the most novel pass
- mechanism_measured vs endpoints_only distinction

**Change**:
- Pass the full mechanism_description from Pass 2 (if mechanism_specified = true). Currently the methods pass only receives theory names and tested predictions — it doesn't know *what* the proposed mechanism is, making it harder to assess whether the mechanism was operationalised
- Add: "When classifying mechanism_operationalisation, state the theoretical mechanism first, then assess whether the study design captures it"

---

## 5. R Package Code Changes

### 5.1 call_claude_api.R — Full Rewrite Recommended

```r
call_claude_api <- function(prompt,
                            system_prompt = NULL,
                            model    = "claude-sonnet-4-6",
                            max_tokens = 4096L,
                            log_file = NULL) {
  api_key <- Sys.getenv("ANTHROPIC_API_KEY")
  if (!nzchar(api_key)) stop("ANTHROPIC_API_KEY not set.")

  body <- list(
    model       = model,
    max_tokens  = max_tokens,
    temperature = 0
  )

  # System prompt separation (Claude-specific optimisation)
  if (!is.null(system_prompt) && nzchar(system_prompt)) {
    body$system <- system_prompt
  }

  # If system_prompt provided, `prompt` is just the user content
  body$messages <- list(list(role = "user", content = prompt))

  response <- httr::POST(
    url = "https://api.anthropic.com/v1/messages",
    httr::add_headers(
      "x-api-key"         = api_key,
      "anthropic-version" = "2023-06-01",
      "content-type"      = "application/json"
    ),
    body   = jsonlite::toJSON(body, auto_unbox = TRUE),
    encode = "raw",
    httr::timeout(180)  # Increased for complex articles
  )

  # ... error handling, logging as before
}
```

### 5.2 build_prompt.R — Add System Prompt Support

The current `build_prompt()` only handles `{{INTRODUCTION_TEXT}}` substitution. For Claude, templates should be split at a `---SYSTEM/USER---` delimiter:

```r
build_prompt_claude <- function(text, template_name = NULL, context = list()) {
  template <- load_template(template_name)

  # Split at delimiter
  parts <- strsplit(template, "---SYSTEM/USER---", fixed = TRUE)[[1]]
  system_prompt <- parts[1]
  user_template <- if (length(parts) > 1) parts[2] else template

  # Substitute all placeholders
  user_content <- user_template
  for (key in names(context)) {
    user_content <- str_replace(user_content,
      fixed(paste0("{{", key, "}}")), context[[key]])
  }

  list(system = trimws(system_prompt), user = trimws(user_content))
}
```

### 5.3 Extraction Functions — Pass Full Context Forward

Currently each pass only threads theory names and tested predictions forward. For Claude, the full prior pass results should be available:

- **Pass 2** receives: theory names, types, roles, tested predictions
- **Pass 3** receives: theory names, types, roles, tested predictions, hypothesis texts, inference types, mechanism descriptions
- **Pass 4** receives: theory names, types, roles, tested predictions, mechanism descriptions

This enables Claude's cross-pass consistency checking.

### 5.4 .safe_parse_json() — Simplification for Claude

The current implementation strips markdown fences and extracts content between first `{` and last `}`. This is a workaround for Qwen's tendency to produce "Here is the JSON output:" preambles and backtick-wrapped responses.

Claude with `temperature = 0` and a clear "Return ONLY valid JSON" instruction produces clean JSON >99% of the time. The safety parsing should be retained as a fallback but the aggressive regex stripping is unnecessary and could theoretically damage valid JSON containing literal braces in text fields.

### 5.5 .validate_schema() — Needs Updating

The current schema validator checks for v1 keys (`explicit_theories`, `implicit_theories`, `no_theory_present`). The v4 schema uses `theories[]` with a `type` field. This validator needs updating to match the current schema, regardless of backend.

---

## 6. Configuration Changes

### 6.1 Claude-Specific Config Block

Add to `config.yml`:
```yaml
claude:
  model: "claude-sonnet-4-6"
  max_tokens: 4096
  temperature: 0
  timeout_seconds: 180
  api_version: "2023-06-01"
  use_system_prompt: true
  prompt_series: "v5"  # Claude-optimised prompts

prompts:
  # ... existing Ollama defaults ...
  claude_theory_extraction: "theory_extraction_v5_claude.txt"
  claude_hypothesis_extraction: "hypothesis_extraction_v5_claude.txt"
  claude_discussion_analysis: "discussion_analysis_v5_claude.txt"
  claude_methods_extraction: "methods_extraction_v5_claude.txt"
```

### 6.2 Cost Estimation

For 269 articles × 4 passes:
- Average input: ~2,000 tokens per pass (article text + prompt)
- Average output: ~800 tokens per pass
- Total: 269 × 4 × 2,800 ≈ 3.0M tokens

**Claude Sonnet 4 pricing** (approximate):
- Input: $3/M tokens → $2.42
- Output: $15/M tokens → $3.23
- **Total estimated cost: ~$5.65 for the full 269-article pipeline**

This is remarkably affordable for the quality improvement demonstrated.

---

## 7. Future Model Recommendations

### 7.1 Cloud API Models (Recommended for Production)

| Model | Strengths for This Task | Weaknesses | Cost (269 articles) | Recommendation |
|-------|------------------------|------------|---------------------|----------------|
| **Claude Sonnet 4** | Best-in-class for structured reasoning, philosophy of science literacy, JSON reliability, cross-pass consistency | Requires API key; rate limits on free tier | ~$6 | **Primary recommendation** |
| **Claude Haiku 4.5** | Fast, cheap, good at structured extraction | Less nuanced on borderline cases (taxonomic vs paradigm) | ~$1.50 | Good for rapid iteration/testing |
| **GPT-4o** | Strong reasoning, good JSON | Less precise on philosophy of science distinctions; tends toward verbose explanations | ~$8 | Viable alternative |
| **GPT-4o-mini** | Fast, cheap | Quality concerns for nuanced classification | ~$1 | Testing only |
| **Gemini 1.5 Pro** | Large context window (1M tokens); could process full articles without GROBID sectioning | API stability concerns; less consistent JSON | ~$5 | Worth testing for GROBID bypass |

### 7.2 Local Models (For Offline/Privacy Use)

| Model | Parameters | VRAM Required | Quality Assessment | Recommendation |
|-------|-----------|---------------|-------------------|----------------|
| **Qwen 2.5 7B** | 7B | ~5 GB | Inadequate — 44% hallucination, no mechanism detection | **Do not use** |
| **Qwen 2.5 14B** | 14B | ~10 GB | Likely improved but untested; exceeds user's GPU | Requires GPU upgrade |
| **Qwen 2.5 32B** | 32B | ~20 GB (Q4) | Promising — the 32B class is where instruction-following becomes reliable | Requires 24GB GPU |
| **Llama 3.1 70B** | 70B | ~40 GB (Q4) | Strong reasoning, good philosophy of science capability | Requires A100/H100 |
| **Mistral Large** | 123B | Cloud only | Comparable to GPT-4o class | API only |
| **DeepSeek-V3** | 671B MoE | ~24 GB (reported) | Excellent reasoning, competitive with Claude on benchmarks | Worth testing via API |
| **Phi-4** | 14B | ~10 GB | Strong for size; Microsoft's reasoning focus | Untested for this domain |
| **Gemma 2 27B** | 27B | ~16 GB (Q4) | Google's best local model; strong instruction-following | Requires 24GB GPU |

**Key insight**: For this task, the quality threshold appears to be around **14B–32B parameters**. Below 14B, models cannot reliably distinguish between causal theories and physiological mechanisms, cannot detect abductive inference patterns, and hallucinate theory names. The 7B class is fundamentally inadequate for philosophy-of-science-level classification.

### 7.3 Recommended Strategy

1. **Production pipeline**: Claude Sonnet 4 via API (~$6 per full run)
2. **Rapid prototyping**: Claude Haiku 4.5 (~$1.50 per run, for testing prompt changes)
3. **Offline fallback**: Qwen 2.5 32B or Gemma 2 27B if GPU upgraded to 24GB
4. **Validation comparison**: Run GPT-4o alongside Claude for the Human Validation study (Study 3) to assess inter-model agreement as a complement to human-LLM agreement

---

## 8. Prompt Architecture: Proposed v5 Template Structure

Each v5 template follows this structure:

```
[SYSTEM PROMPT SECTION]
You are an expert research methodologist...
## Definitions
## Classification Rules
## JSON Schema
## Rules and Constraints
---SYSTEM/USER---
[USER MESSAGE SECTION]
## Context from Prior Passes (if applicable)
## Article Text to Analyse
```

The system prompt contains all stable instructions. The user message contains only the variable content (article text + prior pass context). This separation:
- Allows Claude to cache the system prompt across calls (reducing cost with prompt caching)
- Keeps the variable content clean and focused
- Enables future A/B testing of system prompts without changing the pipeline logic

---

## 9. Quality Assurance Improvements

### 9.1 Cross-Pass Consistency Checks (NEW)

Add a post-processing step after all 4 passes complete for each article:

```r
validate_cross_pass_consistency <- function(theory_result, hyp_result, disc_result, meth_result) {
  warnings <- character(0)

  # 1. If no_theory_present = TRUE, hypothesis inference_type should be "none"
  if (isTRUE(theory_result$no_theory_present)) {
    for (h in hyp_result$hypotheses) {
      if (!identical(h$inference_type, "none") && !identical(h$inference_type, "abductive")) {
        warnings <- c(warnings, "Theory absent but hypothesis has non-none inference type")
      }
    }
  }

  # 2. If theory_type = "taxonomic", inference_type should not be "derived"
  # 3. If theory role = "contextual", disc_reengagement cannot be "full"
  # 4. If mechanism_specified = FALSE in Pass 2, mechanism_operationalisation should be "endpoints_only" or "not_applicable"
  # ... etc.

  warnings
}
```

### 9.2 Confidence-Based Flagging

For human validation, automatically flag articles where:
- Any theory confidence < 0.55 (borderline cases)
- theory_type classification differs between model runs
- Cross-pass consistency check produces warnings
- Multiple theories with `multi_theory_coherence = "contradictory"`

---

## 10. Implementation Priority

| Priority | Change | Effort | Impact |
|----------|--------|--------|--------|
| 1 | Increase max_tokens to 4096 | 1 line | Prevents silent truncation failures |
| 2 | Add system prompt separation | ~50 lines across 2 files | Significant quality improvement |
| 3 | Add `notes` field to all schemas | ~20 lines per template | Reasoning transparency + accuracy |
| 4 | Thread full context between passes | ~30 lines per extraction function | Cross-pass consistency |
| 5 | Create v5 Claude-optimised templates | ~4 hours of careful prompt work | Full Claude capability utilisation |
| 6 | Cross-pass consistency validator | ~80 lines new function | Automated quality assurance |
| 7 | Update .validate_schema() for v4 | ~20 lines | Prevents silent schema drift |
| 8 | Claude config block in config.yml | ~15 lines | Clean configuration |
| 9 | Prompt caching support | ~10 lines | ~50% cost reduction |
| 10 | Remove small-model guardrails | Template edits | Cleaner prompts |
| 11 | Cost logging and estimation | ~30 lines | Budget tracking |
| 12 | Multi-model comparison pipeline | ~100 lines | For Human Validation Study 3 |

---

## 11. Risks and Considerations

1. **API dependency**: Moving to Claude creates a dependency on Anthropic's API availability and pricing. Mitigate by maintaining the Ollama backend as a fallback.

2. **Reproducibility**: Claude model versions may change behaviour. Pin to specific model IDs (e.g., `claude-sonnet-4-6-20260301`) rather than aliases. Log the exact model ID returned in the response.

3. **Rate limits**: At 269 articles × 4 passes = 1,076 API calls. With standard rate limits (~60 requests/minute), the full pipeline takes ~18 minutes. Add retry logic with exponential backoff.

4. **Cost creep**: If prompts grow (e.g., adding full prior-pass context), input token costs increase. Monitor with the existing token logging.

5. **Prompt caching**: Anthropic offers prompt caching for system prompts. Since all 269 articles share the same system prompt per pass, this can reduce costs by ~50%. Implementation requires sending `cache_control` headers.

---

## 12. Summary Recommendations

### Must Do (before next full pipeline run)
1. Increase `max_tokens` from 1024 to 4096 in `call_claude_api.R`
2. Add system prompt separation to `call_claude_api.R`
3. Add retry logic with exponential backoff for rate limits

### Should Do (for publication-quality results)
4. Create v5 prompt templates optimised for Claude
5. Add `notes` field to all JSON schemas
6. Thread full prior-pass context between extraction functions
7. Implement cross-pass consistency validation

### Nice to Have (for the Human Validation study)
8. Multi-model comparison pipeline (Claude + GPT-4o + best local)
9. Prompt caching for cost reduction
10. Confidence-based flagging for human review prioritisation
