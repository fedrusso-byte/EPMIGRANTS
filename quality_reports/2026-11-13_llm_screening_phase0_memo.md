# LLM screening of EP questions — Phase 0 memo (gold benchmark + corpus pilot)

**Date:** 2026-11-13 · **Status:** Phase 0 complete, awaiting go/no-go for full-corpus run
**Scripts:** `scripts/08_llm_screen.py` (stdlib-only, checkpointed/resumable, token logging), `explorations/llm_screen/analyze_phase0.py`
**Outputs:** `output/llm_screen/` (bench/pilot CSVs, run meta JSON, runlogs, cache); **Pilot draw:** `data/dv201_llm_pilot_ids.csv` (seed 42); **Gold ids:** `data/dv201_llm_gold_ids.csv`

## 1. Purpose and framing

Open-LLM classification screen of the 2009–2024 EP question corpus as a **recall
validation/robustness layer for the DV** (CAP-201 retained measure), not a DV
swap. The screen answers: (a) what recall does an independent, transparent
classifier reach against the hand-coded scope definition; (b) how many
within-scope discrimination questions the CAP-201 + keyword pipeline plausibly
misses (candidates for an optional DV ∪ verified-LLM-INs robustness refit).

## 2. Setup (pinned)

- **Endpoint:** Ollama daemon `http://localhost:11434/api/chat` (paid Ollama cloud). **Models:** `glm-5.3-flash:cloud` (GLM-5.3 Flash, 1M ctx) and `gemma4:31b-cloud`.
- **Decoding:** `temperature=0`, `num_predict=160`, `think=false` (auto-fallback); rigid 3-line answer (LABEL/REASON/CONFIDENCE); ≤3 attempts with format-repair retry; API retries 2/5/10 s. **Observed: 0 parse and 0 API errors in ~2,500 calls** (10 rows resolved on 2nd attempt).
- **Input:** `data_raw/epq_3.0.csv`, in-window `2009-07-01 ≤ date < 2024-08-01`: **125,081 unique questions** (VII 54,922 / VIII 45,892 / IX 24,267). Delta vs the manuscript's 124,337 (`data/epq.csv`, 2009-07-14..2024-07-15) = window definition + unique-id dedupe of revision variants.
- **Modes:** body = title + first **260 words** after header-line strip (audit §6.3 convention); subject = title only. Language residue (~4%) handled natively by GLM.
- **Gold (334 unique):** 216 batch decisions (29 IN / 187 OUT) + 120 precision-sample rows (63 IN; 22 extra-EU / 27 non-discrimination / 8 non-ethnic OUT). Two ids conflicting across files dropped (kept-first).

**System prompt (verbatim):**
```
You are a research assistant coding European Parliament written questions for a political science study. You will receive the formal title and, in some modes, the opening text of one question. Decide whether the question falls within the scope of the study's discrimination measure. Answer with EXACTLY three lines and nothing else:
LABEL: IN or OUT
REASON: <code>
CONFIDENCE: high or low
When LABEL is IN use REASON code in_scope. When LABEL is OUT use exactly one of: extra_EU | non_discrimination | non_ethnic | other
```

**User prompt (verbatim template; opening text appended in body mode):**
```
Study scope: discrimination against ethnic, racial, national, linguistic, or racialised religious minorities -- including Roma and Sinti, Jews, Muslims in Europe, migrants targeted as an ethnic group, and autochthonous national minorities -- located in the European Union.

Label the question IN (in_scope) when EU-located minority discrimination is a central theme: unequal treatment, exclusion, racism or xenophobia, hate crime or hate speech, police or institutional profiling, segregation, minority-rights violations.

Label the question OUT with exactly one reason code otherwise:
- extra_EU: the minority or discrimination issue lies outside the EU -- e.g. Turkey, Ukraine, the Western Balkans, Russia, the Middle East, China, or any other non-EU country -- including EU statements about discrimination elsewhere, and non-EU countries' treatment of their own minorities, even when the minority also lives in the EU if the question is anchored to the non-EU state.
- non_discrimination: the question deals with migration, asylum, integration, security, or another policy area without any discrimination or minority-rights framing.
- non_ethnic: discrimination on grounds other than ethnic, racial, or national origin -- gender, sexual orientation, disability, age, or religion as such (including discrimination against Christians, even within the EU); also death penalty, children's rights, or general human-rights issues.
- other: purely procedural or unrelated to the study.

Formal title: {subject}
Date: {date}
```

## 3. Benchmark results (n = 334; GLM = glm-5.3-flash:cloud)

| Config | acc | precision | recall | F1 | TP/FP/FN/TN |
|---|---|---|---|---|---|
| GLM body | 0.910 | 0.844 | 0.826 | 0.835 | 76/14/16/228 |
| GLM subject | 0.925 | 0.894 | 0.826 | 0.859 | 76/9/16/233 |
| gemma4:31b body | 0.901 | 0.798 | 0.859 | 0.827 | 79/20/13/222 |

Wilson 95% CIs (GLM body): recall 0.826 **[0.74, 0.90]**; precision 0.844 **[0.77, 0.91]**.

Per-source recall on gold INs:

| Gold IN source | GLM body | GLM subject | gemma body |
|---|---|---|---|
| batch A rescue (n=1) | 0/1 | 1/1 | 0/1 |
| batch B force-keeps (n=28) | 25/28 (0.89) | 28/28 (1.00) | 26/28 (0.93) |
| precision sample (n=63) | 51/63 (0.81) | 47/63 (0.75) | 53/63 (0.84) |

OUT-side specificity (GLM body): batch A 0.96, batch B 0.81, extra-EU 0.95,
non-discrimination 0.96, non-ethnic 0.88. LLM OUT-reason codes track the hand
taxonomy (batch A OUTs → `extra_EU` 139/158).

**FN pattern (16, GLM body):** (i) INs visible only beyond the 260-word window (FR's own notes mark several as kept after full-text reading: "Funds for the national Operational Programme", "Violation of fundamental rights in Bulgaria", "DARE project"); (ii) EU-scope boundary subtleties (Chechen exiles *in the EU* = IN, Turkey-anchored items lean OUT); (iii) religion-as-such boundary (Imam expulsions, Islamophobia report).
**FP pattern (14):** Turkey-anchored minority items; antisemitism *incident* questions (FR draws a report-vs-incident line); historical minorities; batch-B rows whose OUT depended on full text.

## 4. Pilot (n = 1,498 stratified, GLM body) and corpus yield

| Term | n | LLM-IN | IN rate |
|---|---|---|---|
| VII | 658 | 15 | 2.28% |
| VIII | 549 | 8 | 1.46% |
| IX | 291 | 7 | 2.41% |
| **All** | **1,498** | **30** | **2.00%** |

Crossing pilot INs with LLaMA CAP codes (`data/epq.csv`): **7 of 30 inside the
CAP-201 net**, **23 outside CAP-201** (candidate misses). Of pilot LLM-OUT rows, 6
carry upstream subtopic-201 flags (pre-keyword-screen; not directly comparable
with the retained-set precision).

**Full-corpus extrapolation (×125,081):** LLM-IN ≈ **2,500**; candidates outside
CAP-201 ≈ **1,900** (95% ≈ 1,760–2,080) — the full-adjudication volume if all
candidates go to FR's batch format (§7 gives cheaper designs).

## 5. Token burn and throughput (measured from API usage fields)

| Run | rows | prompt tok | eval tok | prompt/call | latency mean (p90) |
|---|---|---|---|---|---|
| GLM body (gold + pilot) | 1,832 | 1,043,952 | 40,848 | 570 | 2.34 s (2.87 s) |
| GLM subject (gold) | 334 | 152,152 | 8,888 | 456 | ~1.1 s |
| gemma4:31b body (gold) | 334 | 204,048 | 5,320 | 611 | ~2.5 s |

Throughput 0.428 question/worker-s (GLM body). **Full-run projections
(n = 125,081):** body ≈ **71.3M prompt + 2.8M eval ≈ 74M tokens**, wall ≈ **6.8 h at
12 workers** (~10.2 h at 8); subject ≈ **57M prompt (+3.3M eval)**. The planning
estimate (~12M) was low — exact counts are now measured.

## 6. Dual-model arbitration simulation (on the 334 gold rows)

| Rule | acc | precision | recall |
|---|---|---|---|
| GLM body alone | 0.910 | 0.844 | 0.826 |
| gemma body alone | 0.901 | 0.798 | 0.859 |
| union (IN if either) | 0.901 | 0.792 | 0.870 |
| intersection (IN if both) | 0.910 | 0.852 | 0.815 |
| gemma arbitrates GLM disagreements | 0.901 | 0.798 | 0.859 |

Pairwise agreement GLM↔gemma = **0.961** (GLM body↔subject 0.937). Full dual
screening doubles cost (~148M tokens) for +4 recall points at −5 precision
points. **Cheap alternative:** screen `gemma4:31b-cloud` only on GLM-IN flagged
rows (~2,500 × 611 ≈ 1.5M tokens) and keep the intersection → precision 0.852
at +1.5M tokens.

## 7. Decision points for the full run

**Gate decision (2026-11-13 night): FR approved Option 1 — full GLM-flash body run, 12 workers, with the LLaMA-201 rescreen.**

### 7a. LLaMA-201 rescreen (EXECUTED 2026-11-13, `output/llm_screen/rescreen_kept201.csv`)

PASS/FAIL pass over the **1,291 kept subtopic-201 rows** (exact paper window
2009-07-14..2024-07-15; reproduced from `data_processed/epq.csv` +
`pq_discrimination` — 1,319 kept / 1,291 subtopic-201 confirmed):

| Term | LLM PASS rate |
|---|---|
| VII | 308/597 (0.52) |
| VIII | 240/472 (0.51) |
| IX | 81/222 (0.36) |
| **All** | **629/1,291 (48.7%)** |

This is an independent second precision estimator of the retained DV: 48.7% vs
the hand-coded precision sample's 52.5% [0.43–0.62] — within ~4 points, and the
term pattern (IX ≪) matches the extra-EU gradient documented in the manuscript.
Cut reasons on the 662 cuts: `extra_EU` 260, `non_discrimination` 161, `other`
158, `non_ethnic` 80. Consistency check: predicted PASS under the benchmark
(recall .826, FP rate .156, true-IN share .525) ≈ 50.7% ≈ observed 48.7%.
Burn: 748,598 prompt + 40,200 eval tokens; latency mean 3.64 s (p90 4.96 s).

### 7b. Options considered

1. **Full corpus (CHOSEN):** GLM-flash, **body**, 12 workers — ~74M tokens, ~7–8 h. Launched as `full_glm_body.csv` (seeded with the 1,832 phase-0 rows = valid resume).
2. Dual union: 148M tokens, +4 recall points, −5 precision — rejected.
3. Subject mode: ~60M tokens — rejected (untested candidate yield on neutral-subject rows).

### 7c. Adjudication design after the full run

- **(a) *Sampled:** adjudicate the 30 pilot INs + a random ~150 pilot OUT rows → unbiased pilot-level recall of the LLM screen; scaled, publishable recall statement without touching 1,900 candidates.
- **(b) *Full candidates:* export the LLM-IN-outside-CAP-201 rows in the batch format (`dv201_llm_candidates_tocode.csv`, now with text columns; §10e) → FR adjudication, supports DV ∪ verified-LLM-INs refit (05_Bayesian_sens precedent, ~30 min).

### 7d. Optional prompt iteration

Targeting the 16 FNs (one more rubric sentence on full-text-dependent INs) — re-runs gold-only (≈0.2M tokens); report both iterations to avoid over-fitting to gold.

## 8. Known issues

- A bash quoting bug (`$G` expanded by the outer shell) stripped the `--gold` flags in Phase-0 launches → gold columns are empty in the emitted CSVs; all metrics above were computed by post-hoc join in `analyze_phase0.py`. Use literal flags in future launches.
- In-window count 125,081 (this screen, epq_3.0 unique ids, month-level window) vs 124,337 (paper, epq.csv, day-level window): reconcile before the manuscript sentence.
- 2 gold ids with conflicting codes across the two gold files were dropped from the benchmark (334 evaluated).

## 9. Reproduction

```bash
python3 scripts/08_llm_screen.py draw-pilot --n 1500 --seed 42 --out data/dv201_llm_pilot_ids.csv
python3 scripts/08_llm_screen.py screen --corpus data_raw/epq_3.0.csv \
    --gold data/dv201_validation_decisions_FR.csv --gold data/dv201_precision_sample_tocode.csv \
    --mode body --model glm-5.3-flash:cloud --workers 12 \
    --out output/llm_screen/full_glm_body.csv --meta output/llm_screen/full_glm_body_meta.json   # full run
python3 explorations/llm_screen/analyze_phase0.py
```

## 10. Full-run results (2026-11-14, post-429 cleanup)

### 10a. Execution record

Run 1 (12 workers, ~23:45 → 07:45): 125,081 attempted; 122,763 valid; **2,316 API_ERROR = HTTP 429** (overnight cloud throttling ~02:00–07:45, scattered across the queue) + 2 PARSE_ERROR — no silent losses. Meta run 1: 68,696,261 prompt / 2,466,180 eval tokens; latency mean 2.34 s.

Cleanup (Act-approved 2026-11-14): backup `full_glm_body_run1.bak.csv` + `full_glm_body_meta_run1.json`; rewrote the CSV dropping the 2,318 error rows; re-ran the identical `screen` command (no `--fresh`) → the resume coded exactly those 2,318 rows: **IN 37 / OUT 2,281 / err 0** (1,314,604 prompt / 48,017 eval tokens; latency 3.35 s; ~40 min; rate limit had reset). Resume quirk confirmed: error rows must be dropped from the CSV to be retried (`scripts/08_llm_screen.py` treats any non-`PENDING` label as already coded).

**Final `full_glm_body.csv`: 125,081 clean rows — IN 2,063 (1.65%) / OUT 123,018.**

### 10b. Metrics vs the 334 gold — exact replication of the phase-0 benchmark

Same confusion table (TP 76 / FP 14 / FN 16 / TN 228):

- accuracy .910 [.875, .936]; **precision .844 [.756, .905]; recall .826 [.736, .890]; F1 .835**
- per-source: batchB recall 25/28 = .89 (spec .81); prec recall 51/63 = .81; batchA 0/1
- the 16 FNs are unchanged → the §7d prompt-iteration target stands (no new FN classes)
- the 2 PARSE_ERROR rows resolved on retry (no effect on the gold join)

Re-running ~2,900 of the pilot/gold rows under identical params reproduced every gold prediction — the screen is stable, not a one-off.

### 10c. Kept-DV replication (third independent check, full-run params)

- kept-DV 1,319: LLM PASS 642/1,319 = 48.7% [.460, .514]
- subtopic-201 (1,291): **PASS 617/1,291 = 47.8% [.451, .505]** vs the separate rescreen's 629 (48.7%) → 98.1% agreement (temperature wobble); by term VII .503 / VIII .498 / IX .369

The hand-coded precision estimate 52.5% [0.43–0.62] now has **two independent LLM confirmations** (48.7% rescreen; 47.8% full rerun) → the manuscript precision statement is safe.

### 10d. Full-corpus patterns

- IN rate by term: VII 1.80% (n 54,922) / VIII 1.58% (45,892) / IX 1.44% (24,267) — same declining gradient as the hand-coded DV (extra-EU attrition in later terms).
- OUT reasons: other 61.0% / non_discrimination 18.8% / extra_EU 13.0% / non_ethnic 7.2%; residual MALFORMED_* labeled OUT: 37 rows (0.03%) — negligible, leave as-is.
- Token total (runs 1+2): **70.01M prompt + 2.51M eval** — inside the 74M projection.

### 10e. Exports (FR decision on §7c pending)

- `data/dv201_llm_candidates_tocode.csv` (7c-b): **1,421 LLM-INs outside the kept-DV net**, existing batch format, 0 ids missing metadata. By term VII 677 / VIII 483 / IX 261; **only 9 are subtopic-201** (audited dictionary exclusions the LLM re-includes: 6 VII, 3 IX); remaining by code family: 2xx 874, 9xx 220, 1xx 146, 6xx 84, 5xx 67, rest 30. (Far below the ~1,900 pilot projection because the realized LLM-IN total, 2,063, is below the 2,400+ projected from the pilot's 2.00% rate.)
- `data/dv201_llm_adjudication_sample_tocode.csv` (7c-a): 30 pilot INs + 150 random pilot OUTs, seed 42, same format.
- Text columns (2026-11-14, FR request — verifying the coding needs the text, not only the title): both files extended with `lang`, `llm_reason` (verbatim screen reason) and two text columns — `text_llm_input` = verbatim LLM input after "Question text (opening):" (83/1,578 truncated at the 260-word cap, `[...]` marker) and `text_full` = complete corpus text, whitespace-collapsed. The 7 original batch columns are unchanged (verified 0 field diffs, same row order); regenerated deterministically by re-running `analyze_full.py` (seed-42 sample identical; 1,578 unique ids = 1,421 ∪ 180 with 23 overlap; 0 texts missing from the corpus).
- ⚠ Incidental finding (2026-11-14): `normalize_body()` drops everything before the first newline "as the document header", but corpus line 1 is usually real opening text (a regex scan finds masthead-like first lines in only ~7.5k of ~180k multiline corpus rows) → the LLM never saw the opening paragraph of most questions (1,504/1,578 = 95.3% of export texts are multiline). Implications: (i) the recall .826 [.74–.90] was achieved *without* paragraph 1 — a robustness point for the ms; (ii) §7d levers now include "keep line 1" alongside the 260-word cap; (iii) the manuscript description of the LLM input must say "title + date + body text excluding the first line, capped at 260 words", not "opening text".
- Analysis: `explorations/llm_screen/analyze_full.py` → `output/llm_screen/analyze_full_output.txt` + `fullrun_analysis_cache.json`; retry log `output/llm_screen/runlog_phase1_retry.txt`.

## 11. §7d addendum — arbitration-guided gold refresh + refined operative (2026-11-17)

**Path C (FR):** FR arbitrated the discrepancy sheet `dv201_arbitration_tocode.csv`
(13 refined-only FNs + 8 refined FPs with both LLM labels, rule tags, body
excerpt): **11 changes, 0 DROPs** — 10 IN→OUT (language-rights trio, Minority
Safepack, indigenous-minority cluster, anti-bullying), 1 OUT→IN
(P-001292/2014, free movement) — recorded in
`data/dv201_gold_arbitration_overrides.csv`; gold = 83 IN / 251 OUT (n 334),
source files untouched. Re-benchmark on the clean gold (no LLM cost):

| rubric | TP | FN | FP | TN | recall | precision | F1 |
|---|---|---|---|---|---|---|---|
| ORIGINAL | 67 | 16 | 23 | 228 | .807 [.710,.878] | .744 [.646,.823] | .775 |
| REFINED | 66 | 17 | 7 | 244 | .795 [.696,.868] | **.904** [.815,.953] | **.846** |

The §2d halt (rec .826→.707 on the old gold) resolves as **gold contamination**:
9 of the 13 refined-only FNs were by-design family items FR now codes OUT. On the
clean gold the recall gap is −1.2pp (2 questions) against +16pp precision; the
ORIGINAL rubric's own precision degrades (.844→.744) — its 9 extra FPs are
exactly the flipped items. Scope note (FR): indigenous minorities OUT except the
Roma ("highly racialised").

**FR decision A — refined rubric operative.** Kept-DV universe arbitration-aware
(`data/dv201_llm_keptdv_ids.csv`, **1,309** = kept-201 1,284 after the 7
arbitrated-OUT removals ∪ 27 FR force-keeps after 3 arbitrated-OUT removals;
P-001292/2014 was already inside the kept-201 net) → refined re-screen, err 0
(866,549 prompt tokens): refined-IN 524/1,309 = 40.0% (original-rubric reference
642/1,319 = 48.7%, §10c) + 5 FR force-keeps held IN over refined-OUT
(E-000782/2013, E-001218/2022, E-002519/2021, E-007949/2017, E-016119/2015) →
**operative kept-DV 529** (VII 263 / VIII 197 / IX 69).

Candidates (1,421 LLM-INs outside kept-DV, §10e): refined run #2 err 0 (937,677
prompt tokens; run #1 09:31 err 0, 546 IN) → majority over the two independent
runs: agree_IN 461 / split 160 / agree_OUT 800 → **FR pool 621 (43.7%** of the
original candidates; VII 277 / VIII 238 / IX 106) exported to
`data/dv201_llm_candidates_majority_tocode.csv` (both runs' label/reason/conf,
rule-triage category, FR-known flag, excerpt + url, blank `FR_decision`/
`FR_notes`). Session LLM cost: ~1.80M prompt + 98k eval tokens.

Next: FR codes the 621 pool → robustness refit DV ∪ verified-LLM-INs (this adds
to the two LLM confirmations of §10b–10c); the .826 [.74–.90] / .844 original
figures remain the manuscript text.

## 12. §7c-b closure — FR sheet adjudication + LLM-verified-IN refits R1/R2 (2026-11-17)

**FR codes the 621 pool** (`data/dv201_llm_candidates_majority_tocode.csv`):
**621 decided = 258 IN / 363 OUT**, 0 blanks. Coding-validation stats:
double-run agreement 220/461 ≈ 48%, split-IN 38/160 = 24%, pool share
258/621 ≈ 42%. Three IN→OUT flips against earlier intermediate sheet
states are deliberate (sheet-authoritative policy); the audit of sheet-OUT
ids against the 29 decisions-CSV force-keeps returns 0 — no protected row
is touched.

**Consolidator** `explorations/llm_screen/step5_consolidate_fr.py` (no LLM
calls, runtime asserts): suffix-preserving canon zero-strip join verified —
258/258 sheet-INs match `data_processed/epq.csv`, 0 canon collisions,
0 kept-DV overlap; window filter (02_df_setup boundaries) keeps **255**
(VII 115 / VIII 102 / IX 38) and excludes the 3 pre-window keyword-DV1 rows
(E-3845/2009, E-3675/2009, E-4252/2009); all 255 kept ids are DV=0
pre-overlay. Outputs (epq-format ids, so the R scripts match `epq$id`
literally): `data/dv201_llm_verified_in_ids.csv` (255) and
`data/dv201_llm_refined_keptdv_ids.csv` (529 = refined keptdv run 524 IN ∪
5 FR force-keeps held IN over refined-OUT).

**R1 — additive refit** `scripts/05_models_Bayesian_sens_llm.R` (clone of
05_Bayesian_sens; iter 4000 / warmup 1500): DV 1,319 → **1,574** question
events in-window (723/589/262); N = 10,955 unchanged; `total_questions`
asserted identical to primary; in-sample DV events 1,485; surfacing audit
**241/255** verified-INs on estimation-sample (mep_id, leg_year) keys —
13 verified-IN authors sit outside the MIPEX/ESS panel and 1 (E-000739/2024)
falls beyond the 2024-06-08 aggregation window end (primary-protocol tail).
M4 gates PASS (M1 Rhat 1.0026 / ESS 0.243 / 0 div; M2 Rhat 1.0026 / ESS
0.257 / 0 div). Focal coefficients (R1 vs primary): minority **0.900
[0.256, 1.529]** (M1) / **0.880 [0.227, 1.510]** (M2) vs 0.896 [0.201,
1.569] / 0.882 [0.204, 1.529]; libe 0.617 [0.362, 0.866] vs 0.642 [0.389,
0.898]; minority×mipex unchanged and ns → **H1/H2/H3 verdicts unchanged**.

**R2 — refined-operative replacement DV** `scripts/05_models_Bayesian_sens_llm_R2.R`:
DV = 1 iff id ∈ (529 retained ∪ 255 verified) = **784** in-window question
events (date-based VII 378 / VIII 301 / IX 105; the 529 retained split
263/199/67 by epq date vs 263/197/69 by corpus `term` label — the known
2019-07-01 boundary nuance, cancels in the delta); −535 vs primary
(refined-OUT and arbitrated-OUT keyword rows leave the DV). N = 10,955
unchanged; in-sample DV events 739; surfacing: refined **498/529**
(29 authors outside the panel; 2 ids fall on the 2019-07-01 edge =
year-index 6 under the primary aggregation protocol) plus verified 241/255.
M4 gates PASS (M1 Rhat 1.0026 / ESS 0.247 / 0 div; M2 Rhat 1.0028 / ESS
0.256 / 0 div). Focal: minority **1.549 [0.756, 2.301]** (M1) /
**1.532 [0.760, 2.273]** (M2) — **H1 robust, if anything strengthened**
(the cleaner refined measure sheds attenuating noise); libe 0.709 [0.345,
1.057] vs 0.642 [0.389, 0.898]; interaction ns → H3 unchanged.

**Artifacts**: fresh caches `output/bayesian_model_m[12]_sensllm[_r2].rds`
(the `dv201_sensllm_*` namespace avoids the `brm(file =)` stale-cache trap),
tables `output/bayesian_sensllm[_r2]_model_results.csv` and
`bayesian_sensllm[_r2]_vs_primary.csv`, runlogs
`output/llm_screen/runlog_sensllm_r{1,2}.log`. Primary pipeline untouched
(01/03/04 and primary outputs intact). ms updated: DV-measurement paragraph
(third triangulation pointer) + Section-5 robustness paragraph.

