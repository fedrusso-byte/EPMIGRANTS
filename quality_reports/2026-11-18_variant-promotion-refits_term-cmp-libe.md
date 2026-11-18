# 2026-11-18 — Variant models promoted to the refined DV (TERM / CMP / LIBE refits)

**Remediation for**: `2026-11-18_pipeline-scripts-audit.md`, finding 1 (post-promotion
DV-generation debt). **Decision FR (2026-11-18): Option A** — promote the three variant
fits to the refined LLM (R2) DV (primary since 2026-11-17, `05_models.R` §1b), recompute
all invariants, archive keyword-vintage artifacts, refit. Status: **refits executed
2026-11-18**; results below.

## 1. Problem recap

After the 2026-11-17 spec promotion, the DV swap lived only in memory inside
`05_models.R`: the shipped `output/df_merged_3.csv` still carries the keyword DV. The
three variant scripts read that CSV:

- `05_models_Bayesian_TERM.R` reads the already-promoted `output/df_model_data.rds` (read
  only) but its asserts pinned the keyword-vintage minority events (17/24/9) → any rerun
  **hard-failed** (loud but blocking);
- `05_models_Bayesian_CMP.R` / `05_models_Bayesian_LIBE.R` read `df_merged_3.csv` directly
  and their asserts passed on the keyword column (CMP: DV sum 1,038; LIBE: **no DV-sum
  assert at all**) → a rerun would **silently refit on the keyword DV** and emit
  timestamp-fresh keyword-vintage artifacts next to refined-vintage primary outputs; the
  retired `run_dv201_phase2.sh` would have printed "PHASE2 COMPLETE" after a CMP/LIBE leg
  refit on the wrong estimand.

## 2. Estimand decision and consequences

Option A makes the three variants estimate the same estimand as the primary models
(refined LLM DV). The keyword-vintage fits are demoted to appendix references, exactly as
the primary keyword fits were (Appendix B). Two vintage subtleties surfaced during
recomputation and are now pinned as asserts:

1. **Keyword column itself moved vintage**: the 2026-11-13 `df_merged_3.csv` build
   includes the DV-201 force-keeps, so keyword sums on today's samples differ from the
   Nov-12 fit pins (CMP: 1,063 vs 1,038; +25 force-keep events). Any cached Nov-12 number
   was therefore doubly stale.
2. **CMP minority structure changed**: the minority.csv update of 2026-11-13 (MEP 28125,
   SE, VII term) touches a CMP-covered country → CMP minority MEPs 51→52, MEP-years
   301→306. Structural counters (N 9,850 / 23 countries / 1,543 MEPs / cmp sd 4.0073 /
   10 hosting countries) are unchanged.

## 3. Recomputed invariants (old pin → new pin)

| Script | Invariant | Old pin (keyword vintage) | New pin (refined; verified live 2026-11-18) |
|---|---|---|---|
| TERM | minority events VII/VIII/IX | 17 / 24 / 9 | **12 / 27 / 11** |
| TERM | refined DV sum / keyword DV sum | — | **739 / 1,244** (both pinned) |
| TERM | minority MEP-years / MEPs / spanning | 127/91/115, 28/21/23, 8+4 | unchanged (re-asserted) |
| CMP | refined DV sum | 1,038 (keyword) | **599** (4.2% of MEP-years positive) |
| CMP | keyword cross-check | 1,038 (Nov-12 sample) | **1,063** (Nov-13 sample) |
| CMP | minority MEPs / MEP-years | 51 / 301 | **52 / 306** |
| CMP | N / countries / MEPs / sd / rows by term | 9,850 / 23 / 1,543 / 4.0073 / 3445-3444-2961 | unchanged (re-asserted) |
| LIBE | refined DV sum | **(not pinned — hole)** | **753** (4.5% of MEP-years positive) |
| LIBE | keyword cross-check | — | **1,270** |
| LIBE | focal cell (m=1, libe=1) rows/MEPs | 56 / 11 | unchanged (re-asserted) |
| LIBE | focal-cell events | 23 (feasibility, keyword) | **21** (23.2% rows positive) |

Minority events by term follow the same 12/27/11 pattern in LIBE; CMP minority events by
term are 12/27/5 (the dropped CMP-less countries hold no VII/VIII refined minority events
and 5 IX-term events).

## 4. Code changes

- `scripts/05_models_Bayesian_TERM.R`: header provenance; asserts re-anchored + three new
  vintage tripwires (refined 739; keyword 1,244; keyword minority events 17/24/9).
- `scripts/05_models_Bayesian_CMP.R` + `scripts/05_models_Bayesian_LIBE.R`: §1b DV
  promotion overlay inserted ahead of the sample filters (question counts re-aggregated
  from `data_processed/epq.rds` over the promoted id lists, mirroring `05_models.R` §1b
  verbatim: id-list asserts, binary/in-window flag asserts, 1,319 → 784 (−535) window
  asserts, `total_questions` equality assert). Asserts re-anchored per §3. CMP §7 and
  smoke-test comments relabeled with vintage attribution.
- `scripts/utils/run_promotion_refits_2026-11-18.sh`: new dated runner (preflight guards
  on promotion markers + refined-vintage panel; archives before refitting; sequential
  TERM → CMP → LIBE with STEP OK/FAILED markers).
- `scripts/utils/run_dv201_phase2.sh`: RETIRED with an abort guard
  (`FORCE_DV201_PHASE2=1` to override).
- No changes to `run_pipeline.R`, primary scripts, or the sensitivity scripts
  (`05_models_Bayesian_sens_keyword.R` remains keyword-DV by design).

## 5. Safety

- 22 keyword-vintage artifacts moved to `output/archive_keyword_dv_2026-11-18/` before any
  refit (`MANIFEST.md`, `md5_manifest.txt`): 4 brm caches, 2 estimation samples, 16 CSVs.
- brm's `file=` path caching can no longer reload a stale keyword fit (archived), and the
  scripts' recomputed asserts fail loudly on any future vintage drift.
- The archive MANIFEST warns against restoring the `.rds` files to `output/`.

## 6. Refit results (2026-11-18, PROMOTION REFITS COMPLETE 10:29:34)

Runtime: TERM 09:11→09:33 (fit 21.3 min) → CMP 09:33→10:09 (M1 17 min, M2 17.8 min) →
LIBE 10:09→10:29 (fit 19.8 min).

### 6a. Diagnostic gate (per fit: max Rhat / min ESS bulk / divergences)

| Fit | max Rhat | min ESS bulk | divergences | Verdict |
|---|---|---|---|---|
| TERM (minority × term) | 1.0023 | 2,688 | 0 | PASS |
| CMP M1 (minority × cmp) | 1.0044 | 1,515 | 0 | PASS |
| CMP M2 (minority + libe) | 1.0014 | 2,907 | 0 | PASS |
| LIBE (minority × libe) | 1.0028 | 2,535 | 0 | PASS |

### 6b. Estimates — keyword vintage (archived) vs refined (new)

TERM (marginal minority IRRs, reference profile, `posterior_epred`):

| Contrast | Keyword (archived) | Refined (new) |
|---|---|---|
| Minority IRR, 7th term | 1.91 [0.83, 4.17] | 2.80 [1.03, 7.14] |
| Minority IRR, 8th term | 4.57 [1.90, 10.43] | 10.30 [3.72, 27.07] |
| Minority IRR, 9th term | 2.22 [0.85, 5.25] | 5.86 [1.90, 16.53] |
| Minority effect change 8th vs 7th | 2.41 [1.03, 5.50] | 3.72 [1.33, 10.18] |
| Minority effect change 9th vs 7th | 1.16 [0.40, 3.30] | 2.09 [0.63, 7.21] |
| STEP contrast {8th,9th} vs 7th | 1.67 [0.76, 3.68] (ns) | **2.76 [1.11, 7.31] (credible)** |

CMP M1 (minority × CMP pressure, 23 countries):

| Contrast | Keyword (archived) | Refined (new) |
|---|---|---|
| Minority IRR @ CMP mean | 1.76 [0.68, 3.90] | 2.82 [0.90, 7.35] |
| Minority IRR @ CMP −1 SD | 1.16 [0.21, 4.71] | 1.75 [0.22, 9.42] |
| Minority IRR @ CMP +1 SD | 2.67 [1.66, 4.31] | 4.53 [2.51, 8.03] |
| CMP +1SD gradient, minority MEPs | 1.34 [0.68, 2.99] (ns) | 1.56 [0.65, 4.19] (ns, P+=.847) |
| interaction b_minority:cmp_center (log) | — | 0.121 [-0.091, 0.369] |

CMP M2 (libe-only): b_minority 0.936 [0.476, 1.402] → **1.479 [0.885, 2.039]** (log;
IRR 2.55 → 4.39 [2.42, 7.68]).

LIBE (all countries, minority × libe):

| Parameter (log scale) | Keyword (archived) | Refined (new) |
|---|---|---|
| b_minority | 0.733 [0.137, 1.273] | **1.367 [0.705, 2.009]** |
| b_libe | 0.577 [0.318, 0.842] | 0.649 [0.265, 1.010] |
| b_minority:libe | 0.879 [-0.052, 1.801] (ns) | 0.584 [-0.593, 1.739] (ns) |
| Minority IRR ON LIBE | — | 7.06 [2.58, 19.03] |
| Minority IRR OFF LIBE | — | 3.92 [2.02, 7.46] |
| LIBE boost, minority MEPs | — | 3.39 [1.16, 10.55] |
| LIBE boost, non-minority MEPs | — | 1.91 [1.30, 2.74] |

### 6c. Interpretation

- **No reversal of substance**: the qualitative pattern is unchanged by the promotion —
  the minority effect is positive everywhere; the term-heterogeneity shape (VIII peak)
  is preserved and sharpened; the CMP interaction remains not credible (positive point,
  wider refined CrI); the minority × LIBE interaction remains not credible.
- The TERM **STEP contrast becomes credible** under the refined DV ([1.11, 7.31]).
- All refined point estimates are larger than keyword (thinner DV, 739/599/753 in-sample
  events vs 1,244/1,063/1,270 keyword) — same direction as the primary models' promotion
  (minority 0.896 → 1.543): consistent story across primary and variants.
- Keyword-vintage numbers below belong to Appendix B alongside the demoted primary
  keyword fits.


## 7. Follow-ups

- `05FE` variant (audit finding 2) receives the same treatment (decision already given;
  execution tracked in TO_DO).
- `explorations/libe_robustness/libe_robustness.R` reads `output/df_model_data_libe.rds`,
  which is now (post-refit) the refined-vintage sample; the exploration is a dated
  artifact — re-run it deliberately if a refined-vintage version is wanted.
- Manuscript numbers: the variant-model numbers in the ms (term heterogeneity, CMP
  interaction, LIBE interaction, and the RWN framing) must be updated to the refined
  fits; the keyword-vintage columns belong in Appendix B alongside the primary keyword
  fits.
