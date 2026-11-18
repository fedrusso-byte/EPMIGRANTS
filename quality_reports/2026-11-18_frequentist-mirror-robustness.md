# Frequentist Mirror Rebuild — Robustness Memo (2026-11-18, evening)

**Directive (FR):** rebuild the frequentist engine as an *exact* robustness
mirror of the Bayesian primary (`M1_total` / `M2_direct` on the promoted
refined DV, same sample/spec) and quarantine all outdated frequentist /
keyword-era assets. Resolves audit item 2
(`quality_reports/2026-11-18_pipeline-scripts-audit.md`).

## 1. What the frequentist engine is now

`scripts/05_models.R` §3 fits exactly the two promoted Bayesian estimands by
maximum likelihood (glmmTMB) on the identical promoted MIPEX-only panel
(`df_model_data.rds`: 10,955 MEP-years, 739 refined-DV in-sample events,
equivalence asserted by §2a against the archived promotion panel):

- `zinb_model_m1_total` — `M1_total`: `gender + misery_index + party_family +
  minority * mipex_center + offset(log(total_questions + 1)) + (1|mep_id) +
  (1|country)`, `nbinom2`, `ziformula = ~1`. **No LIBE.**
- `zinb_model_m2_direct` — `M2_direct`: `M1_total` **+ libe**.

Same optimizer discipline as the NaN-SE mitigation vintage (nlminb,
iter/eval.max = 3000; the finite-SE hazard did not materialize this run).

Pipeline gates (halt on failure):

1. **Spec parity**: `minority:mipex_center` present in M1_total; `libe`
   present only in M2_direct; M1_total nested in M2_direct (terms + libe).
2. **Finite SEs**: all conditional fixed-effect SEs finite on both fits.
3. **Drift gate vs the archived ladder M4** (pre-existing exact `M2_direct`
   twin): PASS with **max |Δcoef| = 0.00e+00** — the refreshed fit is
   numerically identical to the archived benchmark (the §2a asserts pin the
   panel, so any future drift trips the gate instead of passing silently).

The retired 4-step ladder (`zinb_model1`–`4`) matched no manuscript estimand:
its M1–M3 all carried `libe` (so old-M1 was not `M1_total`), only its M4
coincided with `M2_direct`, and nothing downstream consumed the ladder (the
manuscript cites zero frequentist numbers).

## 2. Quarantine ledger

| asset | destination |
|---|---|
| `zinb_model{1..4}.rds`, `model_coefficients_comparison.csv`, `figures/m4_interaction_magnitude_panel.png` (stale link-scale panel), orphan `figures/bayesian_term_irr_small_multiples.png` | `output/archive_freq_mirror_2026-11-18/` (+ `MANIFEST.md`, `md5_manifest.txt`) |
| `scripts/05_models_FE.R` (keyword-DV, country-FE variant) | `scripts/archive/2026-11-18_05_models_FE_legacy_keyword-dv_country-FE.R` (banner) |
| `output/libe_robustness/` (8 keyword-vintage outputs) | `output/archive_keyword_dv_2026-11-18/libe_robustness/` (+ md5); exploration `libe_robustness.R` bannered |
| `GemmaReport_2026-07-22.{html,md}`, `bayesian_analysis_report.{html,md}`, `COEFFICIENT_TABLES_README.md` | `output/archive_keyword_dv_2026-11-18/stale_docs/` |
| `scripts/utils/archive_pre_dv201_rerun.sh` | retired-banner (superseded by the 2026-11-18 promotion runner) |

`scripts/run_pipeline.R`: `"FE"` removed from `model_map`; matched-engine
guard added (`stopifnot` on `model_version == comparison_version` ∈
{Standard, Bayesian}). `zinb_model4.rds` is deliberately retained in the
archive: it is the live drift-check benchmark read by `05_models.R` §3.

## 3. Consumers rewired

- `06_model_comparison.R` now reads `zinb_model_m1_total` (frequentist twin
  of `M1_total`, mirroring `06_model_comparison_Bayesian.R`) and computes the
  **response-scale ZINB mean** `E[Y] = μ·(1 − P(excess zero))`; CIs via
  delta method combining the conditional and zero-inflation prediction
  components: `SE(log E[Y]) = sqrt(SE_μ² + p₀²·SE_zlink²)`. The former
  `exp(predict(type = "link"))` band — a conditional log-mean mislabeled as
  an "Expected Mean Question Count" — is gone (audit honesty fix). New
  figure: `output/figures/freq_interaction_magnitude_panel.png`.
- `07_extract_all_coefficients.R` — 2 frequentist twins + 2 Bayesian
  estimands; 2-column wide table; **engine-aware interaction summary**
  (audit item 4): Wald-p labels for glmmTMB rows, 95%-CrI-coverage labels for
  brms rows, new `engine` column. Bayesian rows no longer default to "Null"
  (`p.value` was `NA` for every brms row under the old logic). Tables
  rewritten: `all_model_coefficients_comprehensive.csv`,
  `model_coefficients_wide_comparison.csv`,
  `interaction_effects_summary.csv`.

## 4. Verdict: frequentist mirror vs Bayesian primary

| quantity | M1_total mirror (glmmTMB) | M1_total primary (brms) | M2_direct mirror (glmmTMB) | M2_direct primary (brms) |
|---|---|---|---|---|
| minority | **1.589** (SE .417), IRR 4.90 [2.16, 11.11] | 1.543 [0.760, 2.297], IRR 4.68 | **1.546** (SE .410), IRR 4.69 [2.10, 10.49] | 1.525 [0.756, 2.246], IRR 4.60 |
| libe | — | — | **0.680** (SE .192), IRR 1.97 [1.35, 2.87] | 0.704 [0.341, 1.056], IRR 2.02 |
| mipex_center | 0.013 (p .007) | 0.012 (ns) | 0.012 (p .010) | 0.011 (ns) |
| minority × mipex | −0.0004 (p .99), CI [−0.061, 0.060] | +0.005 (CrI −0.051, 0.060), ns | −0.0068 (p .82), CI [−0.066, 0.053] | −0.003 (CrI −0.058, 0.051), ns |
| gender | −0.137 (ns) | −0.160 (ns) | −0.090 (ns) | −0.108 (ns) |

Model level: RMSE 0.331 on both; AIC 3700.9 (M2_direct) < 3710.6 (M1_total);
**LR test on libe: χ²(1) = 11.76, p = 0.0006** — the frequentist analogue of
the Bayesian credible interval excluding zero.

**Reading.** The two estimation paradigms agree on everything substantive:
the minority effect (≈ 4.7–4.9×) is large and credible in both engines and
both specifications; LIBE raises the rate ≈ 2× in both; the MIPEX
interaction is null with tiny sign-unstable estimates in both. The only
nominal divergence is the MIPEX *main* effect — magnitude-trivial everywhere
(IRR ≈ 1.01); the frequentist p < .05 for point estimates the Bayesian CrI
leaves open, while the tested H3 interaction is null under both engines.
**No manuscript number changes.**

## 5. Manuscript paragraph (applied to paper/MEPArticle_12_11_2026.md §5)

"Robustness" now reads "Three further checks…" and gains the third
(estimation-paradigm) check with the numbers above; the closing sentence
covers both operationalizations *and both estimation engines*.

## 6. Artifacts produced by this rebuild

`output/zinb_model_m1_total.rds`, `output/zinb_model_m2_direct.rds`,
`output/model_coefficients_comparison.csv` (2-col estimand table),
`output/figures/freq_interaction_magnitude_panel.png`, plus the three 07
tables. Runtime logs: `quality_reports/session_logs/2026-11-18_freq-mirror-rebuild.log`
(`05_models.R`: fits + gates) and `2026-11-18_freq-consumers-rerun.log`
(06 + 07). Session note: `2026-11-18_freq-mirror-rebuild.md`.

## 7. Residual open items (audit §9, non-blocking)

Seeds in the 5 promoted `brm()` call sites; 06B figure seed; renv pinning;
`04` `FORCE_REDOWNLOAD` flip + provenance comments; hygiene batch; ms
Appendix B numbers refresh for the TERM/CMP/LIBE variants (promotion done
in the morning, ms edit pending).

