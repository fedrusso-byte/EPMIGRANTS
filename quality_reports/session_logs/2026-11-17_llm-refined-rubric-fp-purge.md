# Session log — §7d refined rubric: persist assets + gold-334 re-benchmark (HALT)

**Date:** 2026-11-17 · **Session:** Cline act mode (approved "Full package Steps 1–4") ·
**Status:** Steps 1–2 DONE; halt-guard → resolved as gold contamination (§6);
FR decision **A = refined operative** → **Steps 3–4 DONE** (§7). Gate now with FR:
code the 621-row candidate pool.

## 1. Step 1 — Persist refined-rubric assets (no LLM cost) ✅

- `scripts/08_llm_screen.py`: kept `RUBRIC_TEMPLATE` (original) untouched; added
  `RUBRIC_TEMPLATE_REFINED` (verbatim 3-hunk port from the validated /tmp copy:
  scope sentence, IN sentence, expanded `non_ethnic` OUT clause) + `RUBRICS` dict;
  `screen_one(..., rubric_template=...)` param; pool submit passes
  `RUBRICS[args.rubric]`; meta JSON now records `"rubric"`; screen subparser gained
  `--rubric {original,refined}` (**default `refined`**; use `--rubric original`
  to reproduce any pre-7d run).
- Validation: `py_compile` OK; template render OK (original 1,519 vs refined
  1,991 chars; 1,851-char displacement = exactly the 3 hunks); live smoke test
  (`--limit 2 --rubric refined`): 2/2 coded, err=0, `"rubric": "refined"` in meta.
- `explorations/llm_screen/triage_fp.py` ← /tmp/triage_fp.py (verbatim; rule
  families calibrated on FR's 180-row adjudication).
- /tmp assets archived → `output/llm_screen/`: `refined_180.csv` →
  `refined_glm_body_sample180.csv` · `refined_180.log` → `runlog_refined_180.log`
  · `refined_cand.log` → `runlog_refined_candidates.log` · `confusion180.out` →
  `refined_180_confusion_report.txt` · `crosscheck.out` →
  `refined_crosscheck_report.txt`.
- New helpers: `explorations/llm_screen/build_keptdv_ids.py` (ready, not yet run),
  `explorations/llm_screen/step2_gold_report.py` (used below; rerunnable).

## 2. Step 2 — gold-334 re-benchmark, refined rubric ✅ (halt triggered)

Command (literal gold flags, per memo §8 lesson):

```
python3 scripts/08_llm_screen.py screen --corpus data_raw/epq_3.0.csv \
  --ids data/dv201_llm_gold_ids.csv \
  --gold data/dv201_validation_decisions_FR.csv \
  --gold data/dv201_precision_sample_tocode.csv \
  --mode body --model glm-5.3-flash:cloud --workers 12 --rubric refined \
  --out output/llm_screen/refined_glm_body_gold.csv \
  --meta output/llm_screen/refined_glm_body_gold_meta.json --fresh
```

Execution: 334 queued 10:10:02 → finished 10:11:48 (106 s); **err=0**; gold
merged 334 (OUT 242 / IN 92; in-script `read_gold`, no post-hoc join needed);
224,125 prompt / 9,291 eval tokens; latency mean 3.78 s / p90 6.2 s.

## 2a. Replication check of the original benchmark (same 334, post-hoc join)

`step2_gold_report.py` recovering the phase-0 labels from `full_glm_body.csv`
reproduces the ms figures **exactly**: TP 76 / FN 16 / FP 14 / TN 228 →
recall .826 [.736, .890], precision .844 [.756, .905] (Wilson 95%). The join is
sound; the comparison below is apples-to-apples.

## 2b. Refined results on the same gold-334

| Metric | Original | Refined | Δ |
|---|---|---|---|
| TP | 76 | 65 | −11 |
| FN | 16 | 27 | +11 |
| FP | 14 | **8** | **−6** |
| TN | 228 | 234 | +6 |
| Recall | .826 [.736, .890] | **.707 [.607, .790]** | −.119 |
| Precision | .844 [.756, .905] | **.890 [.798, .943]** | +.046 |

## 2c. FN dissection (16 → 27): the staleness signature, quantified

- **14 shared FNs** (missed by both rubrics — the hard core); 2 original FNs now
  caught; **13 refined-only new FNs**.
- Family census of the 13 refined-only FNs (rule tags on subject only): 
  `language_rights` 3 (Linguistic diversity in Europe; Language discrimination in
  Spain; linguistic-discrimination Spain P-005521); national-minority cluster 5 by
  subject (national-minority protection decision; Russian-speaking minority Latvia;
  Minority Safepack; Beneš decrees; Sami); religion-as-such/generic 2; residual 3
  (migrant workers; migrants inadmissible discrimination; Roma projects).
- Body-text check on the 6 non-language concerning cases:
  - `E-001045/2021` → **by-design** (autochthonous-national family hit in body).
  - `E-001218/2022`, `E-005645/2011` → refugee/discrimination framing; borderline.
  - `E-012873/2015` (Roma projects) → body is subsidy-fraud procedure ("waste,
    misuse and fraud in this field"); LLM's `other` is defensible.
  - `E-003602/2016` → body is anti-bullying programme; gold IN questionable.
  - `P-005607/2021` (Sami mine) → body carries `racism_racial` nexus, gold IN
    defensible → **strongest genuine refined miss** within the 13.
- FP side: 6 of the original 14 FPs purged (E-004083, E-004408, E-1003/2009,
  E-1836/2010, E-6386/2009, P-003699); `P-000962/2024` also fixed; **one new FP**
  `E-002765/2023` (eyeball before any ms use).
- Interpretation: gold labels were coded under the BROADER scope (precision sample
  2026-11-12/13, pre-purge). The recall drop is dominated by the designed narrowing
  out of language-rights / national-minority items; id-level proof: gold IN
  "Language discrimination in Spain" vs FR's 17-Nov adjudication ruling the
  language family OUT. True rubric cost beyond the design ≈ 3 gold-INs (~.03
  recall), inside the overlapping Wilson interval — but non-zero (Sami clearest).

## 2d. Pre-registered halt

Guardrail (approved plan): *stop and report if refined gold recall < .826*.
Refined recall = .707 → **HALTED before Steps 3–4** (kept-DV 1,319 re-screen;
candidate 2-run re-screen + majority vote). Nothing further was run; no ms edits.

## 3. Decision options (FR)

**A.** Proceed 3–4 with **refined operative** on kept-DV/candidates; report gold
     result as a scope consequence (validation-layer framing; original .826/.844
     stays in the ms).
**B.** Proceed 3–4 with **original rubric operative**; refined = sensitivity only
     (both runs kept).
**C.** **Refresh gold labels first**: FR arbitrates the 13 refined-only FNs + the
     refined FPs (8) against full text (~30 min), update gold files, re-benchmark,
     then choose A/B with a clean instrument.
**D.** Stop here; §7d closes with refined validated on the 180-sample only.

## 4. Files

- Edited: `scripts/08_llm_screen.py` (rubric block + `--rubric` threading, 5 edits),
  `TO_DO.txt` (§7d status bullet, line 176).
- Created: `explorations/llm_screen/{triage_fp.py, build_keptdv_ids.py,
  step2_gold_report.py}`; `output/llm_screen/{refined_glm_body_gold.csv,
  refined_glm_body_gold_meta.json, refined_glm_body_sample180.csv,
  runlog_refined_180.log, runlog_refined_candidates.log,
  refined_180_confusion_report.txt, refined_crosscheck_report.txt}`; this log.
- Pending after coding: `data/dv201_llm_keptdv_ids.csv` (builder ready), memo §11
  addendum, Steps 3–4 outputs.

## 5. Decision C executed (2026-11-17, cont.) — arbitration sheet + rebench tooling

FR chose **C** (refresh gold labels first). Delivered, zero LLM cost:
- `data/dv201_arbitration_tocode.csv` — 21 rows = 13 refined-only FNs + 8 refined
  FPs. Columns: type / id / date / term / subject / url / gold_origin (source
  file + batch + decision token + FR notes) / gold_label / orig_llm_label+reason /
  refined_llm_label+reason / rule_tag (triage_fp, subject-level) / prior_triage
  (session-log §2c wording for the 6 body-checked cases) / adjud180_ruling (FR's
  11-17 sampled verdict where the id overlaps the 180-sample) / body_excerpt
  (~700 chars of corpus text) / **FR_decision** (IN / OUT / DROP; blank = keep
  current gold label; DROP = remove from benchmark) / FR_notes.
- Composition verified from the run outputs: FN side = 3 language_rights
  (E-007527/2011, E-011283/2015, P-005521/2021), the national-minority cluster
  (E-011004/2013 Safepack, E-002788/2018 Latvia, P-000746/2022 Beneš,
  E-001703/2018 protection decision, P-005607/2021 Sami, E-001045/2021), residual
  (E-005645/2011, E-001218/2022, E-012873/2015, E-003602/2016). FP side = 7
  carried original FPs + new E-002765/2023; subject census: immigrant-
  discrimination 3, antisemitism/Palestine-related 3 (incl. the new E-002765/2023),
  no-signal 2 (P-001292 free movement, P-000962-fixed family excluded).
- Builder `explorations/llm_screen/build_arbitration_sheet.py`: recomputes the
  FN/FP sets from the run outputs (asserts ORIGINAL 76/16/14/228 and REFINED
  65/27/8/234 pass), empirically resolves the duplicate-id gold merge order
  against the refined run's gold_label column (last-row-wins, mismatches 0),
  joins the corpus text (all 21 ids found).
- Rebench `explorations/llm_screen/step2b_rebench_arbitrated.py`: applies
  FR_decision to the gold dict and reprints both confusion matrices (Wilson CIs)
  on the already-computed labels; dry-run with a blank sheet reproduced the halt
  numbers EXACTLY (ORIGINAL .826 [.736,.890] / .844 [.756,.905]; REFINED .707
  [.607,.790] / .890 [.798,.943]); writes `data/dv201_gold_arbitration_overrides.csv`
  only when decisions are applied.
- Blocked on: FR coding of the sheet → rerun rebench → reopen A/B choice with
  the clean instrument.

## 6. Rebench actuals (2026-11-17, cont.) — arbitrated gold, both rubrics re-scored

FR coded the sheet: **11 changes, 0 DROPs** → gold 83 IN / 251 OUT (n=334).
- 10 gold IN → OUT: E-007527/2011, E-011004/2013, E-011283/2015, E-003602/2016,
  E-001703/2018, E-002788/2018, E-001045/2021, P-005521/2021, P-005607/2021,
  P-000746/2022 (language rights, Minority Safepack, indigenous minorities,
  anti-bullying). FR notes: "Indigenous minorities are outside the scope of this
  project, with the exception of the Roma minority which is highly racialised";
  Sami "borderline because object of racism".
- 1 gold OUT → IN: P-001292/2014 (free movement for EU citizens).
- 3 FNs deliberately kept IN (genuine refined misses): E-005645/2011
  ("discrimination of migrants, including non European migrants"),
  E-001218/2022 ("discrimination against refugees coming from non european
  countries"), E-012873/2015 ("Roma projects are about integration of a
  racialised minority").
- 7 FPs confirmed gold OUT (antisemitism OUT by design; intra-EU migrant
  discrimination outside scope): E-8775/2010, E-000608/2011, E-002878/2011,
  E-010052/2014, E-002807/2021, E-002765/2023, E-000243/2024.

Benchmark on the arbitrated gold (computed labels unchanged; tool
`step2b_rebench_arbitrated.py`, zero LLM cost; the blank-sheet dry run had
reproduced the halt numbers exactly before application):

| rubric | TP | FN | FP | TN | recall | precision | F1 |
|---|---|---|---|---|---|---|---|
| ORIGINAL | 67 | 16 | 23 | 228 | .807 [.710,.878] | .744 [.646,.823] | .775 |
| REFINED | 66 | 17 | 7 | 244 | .795 [.696,.868] | .904 [.815,.953] | .846 |

- The morning HALT (rec .826 → .707 on the old gold) is resolved as **gold
  contamination**: 9 of the 13 refined-only FNs were by-design family items FR
  now codes OUT. On the clean gold the inter-rubric recall gap is −1.2pp
  (2 questions) while refined holds +16pp precision and +7pp F1.
- The ORIGINAL rubric's own precision degrades to .744 on the clean gold (its
  9 extra FPs are exactly the flipped items): the refined narrowing was drifting
  toward FR's typology, not away from it.
- Overrides recorded in `data/dv201_gold_arbitration_overrides.csv` (input for
  the memo §11 addendum). Gold source files untouched by design.
- **Decision A recorded (FR, evening of 11-17)** → Steps 3–4 executed below.

## 7. Decision A → Steps 3–4 executed (2026-11-17, evening)

FR picked **A — refined rubric operative** on the clean gold (+16pp precision,
+7pp F1, −1.2pp recall, overlapping CIs). Both runs `--rubric refined`
(body, glm-5.3-flash:cloud, 12 workers), meta records `"rubric": "refined"`.

### Step 3 — arbitration-aware kept-DV universe + refined re-screen ✅

- Builder `build_keptdv_ids.py` updated to apply
  `data/dv201_gold_arbitration_overrides.csv` as FR's most recent decision
  (asserts 10 OUT / 1 IN parsed; leakage assert `union ∩ arb_out = ∅`) →
  `data/dv201_llm_keptdv_ids.csv` **1,309** =
  kept-201 **1,284** (7 arbitrated-OUT members removed) ∪ force-keeps **27**
  (29 − 3 arbitrated-OUT; P-001292/2014 is added by arbitration but was already a
  kept-201 member). Accounting: 10/11 changes remove from the 1,319 universe; the
  11th (P-001292) was already inside → net −10 exactly.
- Run: `screen --ids data/dv201_llm_keptdv_ids.csv` 11:42→11:49, **err=0**;
  866,549 prompt + 38,344 eval tokens; mean 3.78 s.
- Results: refined-IN **524/1,309 = 40.0%** (original-rubric reference
  642/1,319 = 48.7%, memo §10c) → **operative kept-DV = 529** =
  524 + **5 FR force-keeps held IN over refined-OUT** (E-000782/2013,
  E-001218/2022, E-002519/2021, E-007949/2017, E-016119/2015; P-001292/2014 is
  itself refined-IN) — per term VII 263 / VIII 197 / IX 69.
- Files: `refined_glm_body_keptdv.csv|.json`, `runlog_refined_keptdv.log`.

### Step 4 — candidate 2-run majority + FR pool export ✅

- run #2: 11:49→11:58, **err=0**; 937,677 prompt + 60,055 eval tokens;
  IN 536/1,421 (run #1, 09:31 pre-halt, err=0: 546).
- Majority over the 1,421 original candidates: **agree_IN 461 / split 160 /
  agree_OUT 800** → FR arbitration pool **621 (43.7%)**
  (VII 277 / VIII 238 / IX 106), sorted split-first then by date; columns per
  row: both runs' label/reason/conf, rule-triage `category`, `known_fr_from_sample`,
  body excerpt (~700 chars) + url, blank `FR_decision`/`FR_notes`.
- File: `data/dv201_llm_candidates_majority_tocode.csv` (621 × 18);
  script `explorations/llm_screen/step4_majority_candidates.py` (no LLM calls;
  run-time asserts: identical id sets, pool = ≥1 IN).
- Session LLM cost: ~1.80M prompt + 98k eval tokens, 0 errors across both runs
  (plus the zero-cost arbitration re-benchmark of §6).

**Open:** FR codes the 621 pool → robustness refit DV ∪ verified-LLM-INs;
§7d then closes on the ms-side integration (validation paragraph, memo already
carries §11).

## 8. §7c-b executed — FR sheet adjudication + R1/R2 LLM-verified-IN refits (2026-11-17, evening)

FR coded the 621 pool: **258 IN / 363 OUT** (double-run agreement 220/461 ≈
48%, split-IN 38/160 = 24%, pool 258/621 ≈ 42%); the 3 earlier-sample IN→OUT
flips treated as deliberate (sheet-authoritative; audit of sheet-OUT ids vs
the 29 decisions-CSV force-keeps = 0).

- Consolidator `explorations/llm_screen/step5_consolidate_fr.py`: canon
  zero-strip join (suffix-preserving) — 258/258 sheet-INs in epq, 0 canon
  collisions, 0 kept-DV overlap; window filter keeps **255** (VII 115 /
  VIII 102 / IX 38), excludes the 3 pre-window keyword-DV1 rows
  (E-3845/2009, E-3675/2009, E-4252/2009); writes
  `data/dv201_llm_verified_in_ids.csv` (255) and
  `data/dv201_llm_refined_keptdv_ids.csv` (529 = refined-IN 524 ∪ 5 FR
  force-keeps held over refined-OUT), both in epq-id format.
- Refits (clones of 05_Bayesian_sens, iter 4000 / warmup 1500, fresh
  `*_sensllm*` cache names, M4 gate — all four fits PASS, 0 divergences):
  - **R1** `scripts/05_models_Bayesian_sens_llm.R` (additive; DV 1,574 =
    1,319 + 255; VII 723 / VIII 589 / IX 262): gates Rhat 1.0026 / ESS
    0.243–0.257. minority 0.900 [0.256, 1.529] / 0.880 [0.227, 1.510] vs
    primary 0.896 [0.201, 1.569] / 0.882 [0.204, 1.529]; libe 0.617
    [0.362, 0.866]; interaction ns → H1/H2/H3 unchanged.
  - **R2** `scripts/05_models_Bayesian_sens_llm_R2.R` (replacement DV 784
    = 529 + 255; date-based VII 378 / VIII 301 / IX 105): gates Rhat
    1.0026/1.0028 / ESS 0.247–0.256. minority 1.549 [0.756, 2.301] /
    1.532 [0.760, 2.273] → H1 robust, if anything strengthened; libe
    0.709 [0.345, 1.057]; interaction ns.
  - Panel N = 10,955 in both variants; `total_questions` asserted
    identical to the primary aggregation.
  - Surfacing (pre-registered caveat, reported at run time): R1 241/255
    verified-INs on panel keys (13 authors outside the MIPEX/ESS panel;
    1 protocol tail E-000739/2024); R2 refined 498/529 (2 ids on the
    2019-07-01 edge = year-index 6 under the primary protocol) + 241/255.
- Outputs: `bayesian_sensllm[_r2]_model_results.csv`,
  `bayesian_sensllm[_r2]_vs_primary.csv`; logs
  `runlog_sensllm_r{1,2}.log`.
- Bookkeeping: TO_DO §7c gate closed; §7c-b results bullet added; memo
  §12 addendum written; ms DV paragraph + Section-5 robustness paragraph
  updated with the third LLM check. Primary pipeline (01/03/04) and
  primary outputs untouched.

