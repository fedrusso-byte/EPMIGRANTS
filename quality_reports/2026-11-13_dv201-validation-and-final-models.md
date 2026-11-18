# DV-201 Validation & Final Two-Estimand Models — Readout Memo

**Date**: 2026-11-13 · **Author**: session with Cline (Federico Russo, Università del Salento) **Scope**: closure of the DV-201 validation disposition (Steps 3–5). Manuscript edits explicitly deferred (see §8). All model artifacts re-run on 2026-11-13; pre-change vintage archived.

------------------------------------------------------------------------

## 1. Executive summary

-   FR hand-coded the DV-201 review sheets on 2026-11-12/13 (batch A: 161 regex-excluded subtopic-201 rows, blank = OUT; batch B: 55 strong-marker FN candidates, explicit IN/OUT; precision sample: 120 kept rows, explicit `on_scope` token + notes; probe sample unchanged).
-   Disposition: **29 questions force-kept** (VII 11 / VIII 10 / IX 8), **187 OUT** — 216 explicit decision rows in `data/dv201_validation_decisions_FR.csv` (ids unique at 214 — E-002177/2014 and E-008266/2015 appear in both batches, coded OUT in both; no conflicts).
-   Primary pipeline re-run: kept in-window VII-IX (2009-07-14..2024-06-15) = **1,319** (608 / 482 / 229 per term; 1,291 within subtopic 201) — matches the locked projection exactly.
-   Two-estimand Bayesian re-structure: **M1_total** (Minority × MIPEX, no LIBE control) and **M2_direct** (Minority × MIPEX + LIBE), same priors/chains/offsets/random effects; M4 convergence gate (max R̂ ≤ 1.01, min ESS ratio ≥ 0.10, 0 divergences) on both fits.
-   Keyword-extension sensitivity: **183 extra-EU-anchored question rows removed** (VII 68 / VIII 64 / IX 51), covering **22/22** sheet extra-EU rows, with **zero** hits on the 29 force-keeps, 7 rescue rows and 63 precision-verified INs. Sens sample: 10,955 MEP-years (unchanged panel), **1,072** in-sample DV events (= 1,244 − 172; 11 of the 183 removed rows sat on out-of-sample MEP-years).
-   Precision readout: **63/120 = 0.525** (exact CI \[0.43, 0.62\]); per term 0.536 / 0.523 / 0.500. Category gradient of sampled OUT rows: extra-EU share 12.5% (VII) → 18.2% (VIII) → **35% (IX)**. Residual precision after the keyword extension: **63/98 = 0.643** (\[0.54, 0.74\]) — still below the 0.75 screening threshold, reported as a limitation.
-   Re-run outcome (full tables in §7): H1 slightly **stronger** after the patch (M1_total minority 0.896 \[0.201, 1.569\]; IRR 2.45×; pre-patch 0.835 \[0.117, 1.486\]); H3 still null (0.018 \[−0.028, 0.065\]). Keyword-extension sensitivity: minority **0.967 \[0.286, 1.605\]** (IRR 2.63×), interaction unchanged — robustness confirmed. All six production fits gate-passed (two documented ESS refits at 4000/1500; gate-failed attempts archived).

------------------------------------------------------------------------

## 2. Validation design and inputs

| Sheet | n | Coding convention | Coded by FR |
|------------------|------------------|------------------|------------------|
| `dv201_batchA_exclusions_tocode.csv` | 161 | blank = OUT; only explicit `IN` re-includes | 2026-11-12/13 |
| `dv201_batchB_fncandidates_tocode.csv` | 55 | explicit `IN` / `OUT` for every row | 2026-11-12/13 |
| `dv201_precision_sample_tocode.csv` | 120 | `on_scope` token (`IN`, `extra-EU OUT`, `non-discrimination OUT`, `non-ethnic discrimination OUT`) | 2026-11-12/13 |
| `dv201_probe_sample_tocode.csv` | 60 | unchanged (1/60 non-kept strong-lexicon row) | — |

Consolidation: `scripts/utils/update_dv201_decisions.R` → `data/dv201_validation_decisions_FR.csv` (216 rows; stopifnots 29 IN / 187 OUT / per-term 11-10-8 / no conflicting decisions). Cross-batch duplicates (E-002177/2014, E-008266/2015) are OUT in both sources. The provisional-reads sidecar (`dv201_provisional_reads.csv`) had flagged 5 batch-B blanks; FR resolved them as 4 OUT + 1 IN (E-003602/2016), consistent with the final record.

The batch-build script now protects FR's codings: `scripts/utils/build_dv201_review_batches.R` routes its four `write_csv()` calls through `write_guarded()`, which refuses to overwrite an existing coded file unless `DV201_OVERWRITE=1` is set.

------------------------------------------------------------------------

## 3. Precision readout (120-row sample of kept rows)

**Overall: 63/120 kept rows are genuinely on-scope DV questions → 0.525 (exact 95% CI 0.43–0.62).**

Per term (sample denominators 56/44/20):

| Term   | IN  | OUT | Precision | sampled extra-EU OUT | extra-EU share   |
|--------|-----|-----|-----------|----------------------|------------------|
| VII    | 30  | 26  | 0.536     | 7                    | 12.5% (7/56)     |
| VIII   | 23  | 21  | 0.523     | 8                    | 18.2% (8/44)     |
| IX     | 10  | 10  | 0.500     | 7                    | **35.0% (7/20)** |
| pooled | 63  | 57  | 0.525     | 22                   | 18.3% (22/120)   |

OUT categories: extra-EU anchored 22; non-discrimination (unrelated issue areas — telecoms, assisted suicide, OLAF procedure, gambling, place-name disputes, death penalty in Hungary, etc.) 27; non-ethnic discrimination 8.

**Extra-EU gradient and the slope-bias argument.** The extra-EU OUT share rises monotonically across terms (12.5% → 18.2% → 35.0%). The paper's headline quantity — the minority × MIPEX interaction — is identified disproportionately from later-term variation (the 9th term supplies the strongest minority-cell contrasts; cf. the term-heterogeneity robustness script). Retaining keyword-invisible extra-EU noise therefore does not merely lower precision roughly uniformly: it injects *term-correlated* noise into the very cells that drive the interaction slope, biasing the moderation estimate toward a flatter pattern (extra-EU questions are largely country-agnostic "diaspora/dictatorship" claims whose MEP mix is closer to random with respect to MIPEX). The post-removal rates — extra-EU precision per term 30/37 = 0.811 (VII), 23/31 = 0.742 (VIII), 10/17 = 0.588 (IX) — leave residual extra-EU leakage mainly in the 9th term, which is why the keyword-extension sensitivity (§5) is the appropriate stress test.

**Diffuse-noise attenuation argument.** The remaining OUT mass (27 non-discrimination + 8 non-ethnic) is diffuse in MEP-author space: it is not concentrated among minority MEPs or in low/high-MIPEX countries, so it acts as background noise near the intercept rather than differentially loading onto the interaction cells. Removing it would raise precision without changing the estimand of interest; retaining it attenuates event counts roughly proportionally across design cells. This justifies restricting the sensitivity re-map to the extra-EU category (the only category with a clean operational signature) rather than attempting keyword surgery on the diffuse categories.

**Residual precision after extension.** Among sampled kept rows not already handled by the extension (i.e., excluding the 22 extra-EU rows), precision is 63/98 = **0.643** (exact CI \[0.54, 0.74\]) — still below the 0.75 screening threshold. Reported as a limitation: the CAP-201 minor-topic label identifies an imperfect but non-trivial slice of DV claim-making.

**Single-coder limitation.** All verdicts are FR's hand codings (single coder). No inter-coder reliability statistic is available for this round; the 120-row sample verdicts are treated as the validation criterion, not as an error-free gold standard.

Notable verdicts (row-level notes in the decisions CSV): CVM report E-002755/2015 and the Islamic-schools case are INs that only become visible when reading the full text (the title carries no minority keyword); the anti-Muslim-hatred funding position (P-002311/2023) and E-003602/2016 (bullying involving discrimination against minorities — resolved from the flagged sidecar blank to IN) round out the keyword-invisible INs. OUT: SWIFT agreement (Reg 437/2010 — data-protection frame), OLAF procedure rows, North-Macedonia rows (Bitola, Struga, FYROM Roma), and intra-EU free-movement frames without a discrimination anchor.

**Coding rules applied by FR (as far as reconstructable from the sheet notes):** 1. Discrimination / exclusion anchors (racial, ethnic, profiling, Roma, EU-MIDIS-type surveys, refugee/undocumented discrimination) → IN, even where CAP-201 labels are imperfect. 2. Intra-EU labour-migration discrimination with explicit exclusion/discrimination anchors (E-005644/2011, E-005645/2011) → IN; bare free-movement frames → OUT. 3. Historical / autochthonous-minority repatriation frames → OUT. 4. Titles anchored purely in non-EU jurisdictions → OUT (extra-EU category). 5. Religion-only frames without an EU anti-discrimination dimension → OUT; EU-institutional anti-discrimination policy → IN.

The 29 force-keeps: batch B supplies 28 FN candidates (majority outside subtopic 201 — EU-MIDIS Muslims surveys, Roma/anti-Gypsyism, migrant-worker discrimination, refugee profiling, minority decision compliance); batch A supplies 1 rescue: E-002519/2021, a subtopic-201 row whose title names the *Turkish research centre* drafting the EP-requested Islamophobia report, which the primary `turkey|turkish` key kills spuriously.

------------------------------------------------------------------------

## 4. Primary pipeline: import fix and re-run

-   `scripts/01_import_questions.R` now carries `cap201_force_keep_ids` (29). The keep rule is: `id %in% cap201_force_keep_ids | (subtopic == "201" & (id %in% cap201_rescue_ids |   !str_detect(subject, cap201_exclusion_pattern)))` — force-keeps bypass BOTH the subtopic gate and the exclusion regex. Validated counts: in-window kept 1,319 (608/482/229); subtopic-201 kept 1,291; 2019-07-01 edge case (5 rows) preserved.
-   Pre-change artifacts (bayesian_model_mipex.rds, zinb_model1–4.rds, df_model_data.rds, bayesian_model_results.csv) MOVED to `output/archive_dv201_2026-11-13/` with MD5 manifest.
-   Re-runs: 01 (14 s) → 02 → 03 → 05_models (glmmTMB ZINB 1–4, N = 10,955) → 05_models_Bayesian (M1_total + M2_direct, brms) → 06 (visualisation, now reads M1_total) → 07 (coefficient tables, now both Bayesian estimands).

**Upstream data note (independent of DV-201):** FR added Swedish MEP 28125 to `data_raw/minority.csv` on 2026-11-13 (10:33; backup saved at 10:30). MEP 28125 sits in the 7th term only, AFET (libe = 0), zero DV events. Effects on panel invariants: VII minority MEP-years 122 → 127, VII minority MEPs 27 → 28, total minority MEPs 55 → 56; no event changes. The term-heterogeneity script's assertions were updated accordingly (minority events additionally changed by the DV-201 force-keeps: +2 in VIII, +1 in IX → 17/24/9).

------------------------------------------------------------------------

## 5. Keyword-extension sensitivity (DV-201 disposition design)

Design: the "extra-EU OUT" category is operationalised as 90 keyword stems appended to the CAP-201 exclusion pattern and re-applied at QUESTION level; the (mep_id, leg_year) aggregation, the MIPEX-only estimation-sample construction, priors, chains, offsets and random effects are reproduced exactly from 01/02/03/05_models.R. Nothing in the primary namespace is overwritten (`*_sens` names throughout); removal audit in `data/dv201_sens_removed_ids.csv`.

**Derivation guards (each evaluated against the 29 force-keeps + 7 rescues + 63 verified INs):** three candidate stems were dropped at derivation because they collide with protected, EU-relevant verdicts: - bare `macedonia|macedonians?` → rescue E-0636/2000 (Macedonian minority in Greece); N-Macedonia coverage preserved via `fyrom`, `north macedonia`, `republic of macedonia` + city keys; - bare `ukrain` → IN P-000972/2022 (racial profiling at EU-Ukraine borders); replaced by refined phrases (`ukrainian citizens|in ukraine|from ukraine|to ukraine|of ukraine|over ukraine|for ukraine`); - `\bchechen` → a precision-verified IN row. A bare `russia|russian` stem is deliberately absent; refined Russia phrasings (`russian authorit|…|in russia|moscow|kremlin|putin|…`) catch the "Russian authorities promoting homophobia" row (E-006792/2013) without touching the protected "Russian-speaking minority in Latvia" IN.

**Locked outcome:** removal = **183** question rows in-window (VII 68 / VIII 64 / IX 51); question-level DV events 1,136 (540 / 418 / 178); sheet extra-EU coverage **22/22** (no residual); runtime re-verification of all guards inside the script; sample N = 10,955 (identical keys to the primary panel); in-sample DV events **1,072**.

Fits: `M1_sens` (no LIBE) and `M2_sens` (+ LIBE), same priors/chains as primary; convergence gate applied to both; caches `output/bayesian_model_m1_sens.rds` / `_m2_sens.rds`; results in `output/bayesian_sens_model_results.csv` — readout in §7.2 (production fits at iter 4000/1500 after a documented ESS-gate refit).

------------------------------------------------------------------------

## 6. Two-estimand structure (M1_total / M2_direct)

-   M1_total: `pqs_discrimination ~ gender + misery_index + party_family + minority * mipex_center +   offset(log(total_questions+1)) + (1|mep_id) + (1|country)` — total effect (LIBE omitted).
-   M2_direct: identical plus `libe` — direct effect net of committee assignment.
-   Same student_t(3,0,2.5) priors (b and zi), 4 chains × (1000 warmup + 1000 sampling), cores = 4, adapt_delta = 0.95.
-   Visualisation (06) loads **M1_total** (the total-effect spec is the headline estimand); M2_direct is tabulated in 07. The `libe` column kept in the prediction grids is unused by the M1_total formula.
-   Convergence gate (M4 gate) applied to BOTH fits inside `05_models_Bayesian.R` (max R̂ ≤ 1.01, min ESS ratio ≥ 0.10, zero divergences; the pipeline halts otherwise).

------------------------------------------------------------------------

## 7. Results (2026-11-13 re-run — all fits gate-checked)

### 7.1 Primary two-estimand fits

| Model | max R̂ | min ESS ratio | divergences | minority (log) | IRR\* | minority × mipex_center |
|-----------|-----------|-----------|-----------|-----------|-----------|-----------|
| M1_total (iter 2000/1000) | 1.0074 | 0.173 | 0 | 0.896 \[0.201, 1.569\] | 2.45× | 0.018 \[−0.028, 0.065\] |
| M2_direct (iter 4000/1500)\* | 1.0036 | 0.226 | 0 | 0.882 \[0.204, 1.529\] | 2.41× | 0.009 \[−0.036, 0.055\] |

*population-level, re.form = NA conventions as in the pre-disposition run.* M2_direct deviation:\* the first fit at the nominal settings FAILED the ESS gate (min neff ratio 0.066 — the NB `shape` dispersion parameter, the classic slow-mixing ZINB geometry; every scientific parameter well mixed: b_Intercept 0.38, zi 0.39; max R̂ 1.0066; 0 divergences). Refit at 2.5× sampling draws (iter 4000 / warmup 1500) → gate-passed. The gate-failed fit is archived (`output/archive_dv201_2026-11-13/bayesian_model_m2_direct.rds`). M1_total passed at nominal settings and its cached fit is reused.

Interpretation vs the 2026-11-12 pre-patch fit: minority 0.835 \[0.117, 1.486\] → **0.896 \[0.201, 1.569\]** in M1_total — the DV-201 force-keeps slightly STRENGTHEN the H1 effect (3 of the 29 INs are authored by minority MEP-years: 2 in VIII, 1 in IX). H3 remains null: 0.011 \[−0.033, 0.058\] → 0.018 \[−0.028, 0.065\] (M1_total) / 0.009 \[−0.036, 0.055\] (M2_direct).

### 7.2 Keyword-extension sensitivity

Both sens fits also required the documented ESS remedy — the first attempt (iter 2000/1000) failed on M1_sens itself (min neff ratio 0.094; archived in `output/archive_dv201_2026-11-13/sens_first_attempt/`); the production sens fits use iter 4000 / warmup 1500:

| Model | max R̂ | min ESS ratio | divergences | minority | minority × mipex_center |
|------------|------------|------------|------------|------------|------------|
| M1_sens | 1.0028 | 0.201 | 0 | 0.967 \[0.286, 1.605\] | 0.018 \[−0.026, 0.063\] |
| M2_sens | 1.0026 | 0.270 | 0 | 0.949 \[0.294, 1.574\] | 0.009 \[−0.036, 0.053\] |

Removing the 183 extra-EU-anchored rows leaves every conclusion intact and makes the minority effect slightly stronger (IRR 2.45× → 2.63× at reference values in the total-effect spec); the interaction is unchanged to the third decimal. The DV-201 correction therefore does not drive the paper's findings — it modestly sharpens them.

### 7.3 Term heterogeneity (re-run on the patched data; R̂ 1.0041, ESS 1,563/1,237, 0 div)

Minority IRR: VII **1.91 \[0.83, 4.17\]** (ref) → VIII **4.57 \[1.90, 10.43\]** (P = 1.000) → IX 2.22 \[0.85, 5.25\]; 8-vs-7 change **2.41 \[1.03, 5.50\] (P = .979 — now credible, was marginal pre-patch)**; 9-vs-8 0.49 \[0.16, 1.38\]; pooled {8th, 9th}-vs-7th step 1.67 \[0.76, 3.68\] (ns, P = .902); non-minority baselines 0.70× (VIII) / 0.50× (IX). The "8th-term spike, not a crisis-era step" reading survives, with the spike modestly reinforced by the two force-kept VIII INs.

### 7.4 LIBE alternative model (re-run on the patched data; R̂ 1.0020, ESS 1,634/1,429, 0 div)

Minority IRR **ON LIBE 4.91 \[2.24, 10.66\]** vs **OFF 2.08 \[1.15, 3.57\]**; LIBE boost 4.29× for minority MEPs vs 1.78× for non-minority MEPs — qualitatively identical to the 2026-11-12 fit (5.22 / 1.92; boosts 4.79 / 1.77). All four contrasts P ≥ 0.99 in the direction shown.

### 7.5 Gate ledger (final production fits)

| Fit | Setting | Final gate |
|------------------------|------------------------|------------------------|
| M1_total | 2000/1000 | R̂ 1.0074 · ESS 0.173 · 0 div — PASS |
| M2_direct | 2000/1000 → archived; 4000/1500 | R̂ 1.0036 · ESS 0.226 · 0 div — PASS |
| M1_sens | 2000/1000 → archived; 4000/1500 | R̂ 1.0028 · ESS 0.201 · 0 div — PASS |
| M2_sens | 4000/1500 | R̂ 1.0026 · ESS 0.270 · 0 div — PASS |
| Term interaction | per TERM script (2000/1000) | R̂ 1.0041 · ESS 1,563/1,237 · 0 div — PASS |
| LIBE interaction | per LIBE script (2000/1000) | R̂ 1.0020 · ESS 1,634/1,429 · 0 div — PASS |

------------------------------------------------------------------------

## 8. Deferred manuscript edits (NOT applied in this session)

The manuscript (`paper/MEPArticle_12_11_2026.md`) is untouched. Deferred (in line order): - L419–420 — sampling-frame description (CAP-201 label + keyword filter + DV-201 validation note). - L500–510 — precision/validation paragraph (replace the previous validation sketch with the 63/120 readout and the residual-precision limitation). - L512–675 — results section: re-point figures/tables to M1_total / M2_direct and the updated `07` coefficient tables; add the DV-201 sensitivity readout. - L612–623 — robustness subsection: replace the LIBE-omission narrative with the two-estimand design and the keyword-extension sensitivity.

------------------------------------------------------------------------

## 9. Artifacts and provenance

| Artifact | Location |
|------------------------------------|------------------------------------|
| Decisions CSV (audit trail) | `data/dv201_validation_decisions_FR.csv` |
| Removal audit (sensitivity) | `data/dv201_sens_removed_ids.csv` |
| Sensitivity script | `scripts/05_models_Bayesian_sens.R` |
| Two-estimand script | `scripts/05_models_Bayesian.R` (restructured) |
| Retargeted visualisation / tables | `scripts/06_model_comparison_Bayesian.R`, `scripts/07_extract_all_coefficients.R` |
| Batch-build output guard | `scripts/utils/build_dv201_review_batches.R` (`write_guarded()`) |
| Decisions consolidator | `scripts/utils/update_dv201_decisions.R` |
| Archiver (primary) | `scripts/utils/archive_pre_dv201_rerun.sh` → `output/archive_dv201_2026-11-13/` |
| Archiver (phase 2, TERM/LIBE) | `scripts/utils/run_dv201_phase2.sh` → `output/archive_dv201_2026-11-13/term_libe/` |
| Session logs | `quality_reports/session_logs/2026-11-13_primary_rerun.log`, `2026-11-13_dv201_phase2.log` |

Robustness scripts re-run on the patched data (2026-11-13): TERM (term heterogeneity; asserts updated: minority cells 127/91/115, 28/21/23 MEPs, events 17/24/9) and LIBE (alternative all-country sample; N = 11,042 unchanged; focal cell 56 MEP-years / 11 MEPs unchanged — MEP 28125 is AFET, libe = 0). Stale `brm(file=)` caches for both were archived before refit — `brm` caches by path, and with unchanged formulas it would silently reload the pre-DV-201 fits otherwise.