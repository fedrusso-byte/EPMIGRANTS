# LIBE Omission Robustness — Direct vs Total Effect of Minority Background

**Date:** 2026-11-12
**Status:** COMPLETE — analysis executed, verified, and memoed; presentation decisions pending
**Script:** `explorations/libe_robustness/libe_robustness.R`
**Outputs:** `output/libe_robustness/` (3 cached fits + 5 CSVs; primary fits in `output/` untouched)
**Related:** `scripts/05_models_Bayesian.R` (primary fits), `scripts/06_model_comparison_Bayesian.R` (grid conventions), `quality_reports/2026-11-06_CAP201-filter-implementation.md` (post-fix sample), manuscript §H2/H3

---

## 1. Why this analysis exists

The primary Bayesian ZINB models control for `libe` (MEP sits on the civil-liberties committee)
when estimating the effect of minority background on priority questions about discrimination.
The theoretical stance adopted with FR is that minority background plausibly **causes** committee
placement: minority MEPs self-select into LIBE (civil-rights agenda match) and/or parties channel
them there. Under that view `libe` is a **post-treatment** variable (a mediator of minority
background), so the primary control-for-`libe` models estimate a **direct effect** of biography,
while models that omit `libe` estimate its **total effect** (whatever operates directly plus
whatever operates through committee assignment). Neither estimand is "the" correct one a priori;
they answer different questions. This memo refits the models without `libe` (total effect) and
with an explicit `minority × libe` interaction, and compares them against the primary
(direct-effect) fits. Presentation decisions are deferred to FR.

## 2. What was run (design guarantees)

- **Estimation sample** `output/df_model_data.rds` — asserted identical to the primary models'
  in-script reconstruction (drop-NA on model variables, terms 7th–9th): **N = 9,850 MEP-years,
  1,543 MEPs, DV sum = 1,038** (`stopifnot` in the script).
- **Three fits**, same family `zero_inflated_negbinomial()`, same priors (`student_t(3, 0, 2.5)`
  on `b` and `zi`), chains = 4, iter = 2000 (warmup 1000), cores = 4, `adapt_delta = 0.95`,
  seed = 20260321:
  1. `bayesian_model_mipex_nolibe.rds` — primary MIPEX spec minus `libe` → **total effect**;
  2. `bayesian_model_cmp_nolibe.rds` — primary CMP spec minus `libe` → **total effect**;
  3. `bayesian_model_mipex_minoritylibe.rds` — MIPEX spec plus `minority * libe` and
     `minority * mipex_center` → **heterogeneous committee boost**.
- Primary fits (`output/bayesian_model_cmp.rds`, `output/bayesian_model_mipex.rds`) loaded
  read-only for side-by-side comparison; nothing outside `output/libe_robustness/` was written.
- **Comparison grid** mirror of `06`: `gender = "M"`, reference party family ("Christian
  democrats and conservatives"), offset at mean `total_questions`, `misery_index` at mean,
  country averaged out (`re.form = NA`, `allow_new_levels = TRUE`), MIPEX at observed
  min / median / max.
- Rerun note: `brm(file = ...)` caches by path — if a spec changes, delete the cached `.rds`
  first or the stale fit loads silently.

## 3. Convergence (all clean)

| Fit | max R-hat | min bulk ESS | min tail ESS | divergent transitions |
|---|---|---|---|---|
| MIPEX no libe | 1.003 | 1,639 | 2,258 | 0 |
| CMP no libe | 1.004 | 1,578 | 2,174 | 0 |
| MIPEX minority × libe | 1.002 | 1,887 | 2,020 | 0 |

## 4. Focal coefficients — median [95% CrI], P(draw > 0)

| Parameter | MIPEX primary (w/ libe) | MIPEX no libe (**total**) | MIPEX minority × libe | CMP primary (w/ libe) | CMP no libe (**total**) |
|---|---|---|---|---|---|
| minority (main) | 0.448 [−0.256, 1.063] (P = .90) | 0.470 [−0.223, 1.066] (P = .92) | 0.169 [−0.549, 0.840] (P = .68) | 0.517 [−0.330, 1.197] (P = .91) | 0.616 [−0.237, 1.287] (P = .92) |
| libe (main) | 0.509 [0.270, 0.743] (P = 1.00) | — | 0.383 [0.128, 0.632] (P = 1.00) | 0.540 [0.298, 0.767] (P = 1.00) | — |
| mipex_center | 0.002 [−0.009, 0.013] (P = .62) | 0.003 [−0.008, 0.013] (P = .70) | 0.002 [−0.009, 0.013] (P = .65) | — | — |
| **H3** minority × mipex | 0.037 [−0.002, 0.080] (P = .97) | **0.044 [0.005, 0.085] (P = .99)** | 0.022 [−0.020, 0.064] (P = .85) | — | — |
| cmp_center | — | — | — | −0.040 [−0.094, 0.013] (P = .07) | −0.034 [−0.086, 0.018] (P = .10) |
| **H2** minority × cmp | — | — | — | 0.104 [−0.038, 0.275] (P = .92) | 0.105 [−0.034, 0.284] (P = .91) |
| **minority × libe** | — | — | **1.378 [0.554, 2.220] (P = 1.00)** | — | — |

In the `minority × libe` model, coefficients on the count scale imply: the LIBE boost among
**non-minority** MEPs is `exp(0.383) ≈ 1.5×`, among **minority** MEPs `exp(0.383 + 1.378) ≈ 5.8×`;
the ratio of boosts is `exp(1.378) ≈ 4.0×`. The interaction is comfortably positive
(P(draw > 0) = .999).

## 5. Expected counts (posterior median [95% CrI]) — MIPEX models

Male (`gender = "M"` grid convention), Christian-democrat, mean misery index, mean
`total_questions` offset, country averaged out.

**Median MIPEX**

| Model | non-minority | minority | minority IRR [95% CrI], P(>1) |
|---|---|---|---|
| Primary, libe = 0 (direct) | 0.072 [0.055, 0.094] | 0.124 [0.059, 0.222] | 1.65 [0.85, 2.93] (P = .94) |
| Primary, libe = 1 (direct) | 0.121 [0.084, 0.168] | 0.208 [0.094, 0.384] | 1.65 [0.85, 2.93] (P = .94) |
| No libe (total) | 0.075 [0.057, 0.098] | 0.133 [0.065, 0.240] | 1.71 [0.90, 2.95] (P = .95) |
| Minority × libe, libe = 0 | 0.073 [0.055, 0.094] | 0.094 [0.043, 0.178] | 1.22 [0.62, 2.31] (P = .72) |
| Minority × libe, libe = 1 | 0.108 [0.075, 0.151] | 0.564 [0.209, 1.239] | 4.81 [1.94, 11.55] (P = 1.00) |

In the primary model the marginal minority IRR is identical at `libe = 0` and `libe = 1` because
that model contains no `minority × libe` term — the fixed committee value cancels in the ratio.

**Full grid (minority vs non-minority IRR)**

| MIPEX | Primary (direct) | No libe (total) | Minority × libe: off LIBE | Minority × libe: on LIBE |
|---|---|---|---|---|
| min (−28.5) | 0.55 [0.09, 2.88] (P = .25) | 0.46 [0.07, 2.27] (P = .17) | 0.62 [0.10, 3.46] (P = .31) | 2.48 [0.32, 18.47] (P = .82) |
| median (+1.5) | 1.65 [0.85, 2.93] (P = .94) | 1.71 [0.90, 2.95] (P = .95) | 1.22 [0.62, 2.31] (P = .72) | 4.81 [1.94, 11.55] (P = 1.00) |
| max (+23.5) | 3.76 [2.10, 6.69] (P = 1.00) | 4.50 [2.52, 7.80] (P = 1.00) | 1.96 [0.93, 3.98] (P = .96) | 7.80 [3.77, 16.04] (P = 1.00) |

Below the MIPEX minimum the minority gap turns **negative** (IRR < 1): in the least-liberal
contexts minority MEPs are expected to ask fewer discrimination questions than comparable
non-minority MEPs — the same low-end reversal that the H3 interaction implies, here visible
in both the direct and the total framing.

## 6. Verified descriptives (estimation sample)

| Cell (minority, libe) | MEP-years | MEPs | mean DV | P(DV > 0) |
|---|---|---|---|---|
| (0, 0) | 8,899 | 1,421 | — | — |
| (0, 1) | 650 | 126 | 0.138 | 10.3% |
| (1, 0) | 250 | 43 | 0.080 | 4.8% |
| (1, 1) | 51 | 10 | 0.451 | 27.5% |

Note: earlier working notes for this check recorded "mean DV 0.145" and "9 MEPs" for the
minority-off-LIBE contrast; the verified in-sample figures are **0.080** and **10 MEPs**
(51 MEP-years). The committee boost for minority MEPs is therefore roughly **5.6x**
(0.451 vs 0.080), even larger than the "~3x" used as planning motivation.

## 7. Reading of results

1. **H3 strengthens under the total-effect framing.** Omitting `libe` — consistent with treating
   committee placement as a channel through which minority background works — moves the
   minority x MIPEX interaction from 0.037 [-0.002, 0.080] to **0.044 [0.005, 0.085]**, i.e. the
   95% CrI now **excludes zero**. In the fully saturated model (minority x libe + minority x
   mipex), the residual *direct* H3 is 0.022 [-0.020, 0.064], P(+) = .85: part of the MIPEX
   amplification for minority MEPs travels through their higher-propensity LIBE placement, and
   the remainder is direct.
2. **The committee boost itself is strongly heterogeneous.** `minority x libe` = 1.378
   [0.554, 2.220] on the count scale: LIBE membership multiplies expected discrimination
   questions by ~4x more for minority than non-minority MEPs (marginal on-committee IRR
   4.81 [1.94, 11.55] vs 1.22 [0.62, 2.31] off-committee). This is consistent with a civil-rights
   agenda match: minority MEPs on the civil-liberties committee ask discrimination questions at
   very high rates.
3. **The minority main effect shifts upward, modestly.** MIPEX: 0.448 -> 0.470; CMP: 0.517 ->
   0.616. Direction is as expected if part of the effect runs through committee placement, but
   CrIs remain wide and include zero in all four specifications. The marginal minority IRR moves
   little at median MIPEX (1.65 -> 1.71) and more at high MIPEX (3.76 -> 4.50).
4. **H2 is essentially untouched** (0.104 [−0.038, 0.275] -> 0.105 [−0.034, 0.284]), as expected:
   the CMP party-position moderation is a country- and party-level mechanism, not one that
   committee placement should mediate. The two hypotheses respond differently exactly as theory
   predicts, which supports the mediator reading of `libe` for H3 specifically.

## 8. Caveats

- The mediator stance (minority background -> LIBE) is theoretically motivated and assumed, not
  estimated: no instrument for committee placement is used. The labels "direct/total" are correct
  only under that causal ordering; if LIBE placement were instead exogenous to biography, the
  primary control-for-`libe` specification would be the right one. The safest manuscript framing
  is two estimands with an explicit interpretation, not a single headline number.
- Thin cell: the minority x LIBE stratum has **51 MEP-years / 10 MEPs**, so on-committee IRRs and
  the interaction are estimated with wide uncertainty (see CrIs above).
- Tiny shifts between primary-fit numbers across documents (e.g. libe median 0.509 here vs 0.507
  elsewhere) are posterior MCSE noise from different seeds, not substantive disagreement.
- Downstream artifacts **not** updated in this run (deferred by decision): `06` grids fix
  `libe = 0` — comparison figures/tables condition on off-committee MEPs; manuscript
  (~line 619) and `GemmaReport` §9.2 thin-cell note describe the direct-effect framing only.

## 9. Outputs and how to rerun

`output/libe_robustness/`:

- `bayesian_model_mipex_nolibe.rds`, `bayesian_model_cmp_nolibe.rds`,
  `bayesian_model_mipex_minoritylibe.rds` — brms caches (fits; reload via `brm(file = ...)`)
- `libe_robustness_results.csv` — full coefficient table, 5 models (tidy/broom.mixed)
- `libe_robustness_focal_coefficients.csv` — focal parameters, draws-based medians/CrIs/P(+)
- `libe_robustness_diagnostics.csv` — R-hat / ESS / divergence summary
- `libe_robustness_expected_counts.csv` — grid expected counts (posterior median + 95% CrI)
- `libe_robustness_minority_contrasts.csv` — minority IRRs by MIPEX level and libe state

Rerun: `Rscript explorations/libe_robustness/libe_robustness.R` under the project `renv`
(~35 min total: ~12 min per brms fit plus fast post-processing; cached fits make reruns load in
seconds). The run log is preserved at `/tmp/epmigrants_libe_robustness.log`.

## 10. Deferred to FR (presentation decisions)

- Whether the manuscript reports total vs direct effect (or both) for H3, and how `libe` is
  framed (mediator discussion vs robustness footnote).
- Whether `06`-style grids should add a minority-x-LIBE stratum or average over committee instead
  of fixing `libe = 0`.
- Any figure/table updates (manuscript ~line 619, GemmaReport §9.2, coefficient tables).

No primary fits (`output/bayesian_model_*.rds`), analysis scripts (`scripts/05*`, `scripts/06*`),
or paper artifacts were modified.
