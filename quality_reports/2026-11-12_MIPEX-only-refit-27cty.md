# MIPEX-only refit — 27 countries (2026-11-12)

**Type:** model re-specification + full refit + manuscript sync (.md)
**Supersedes:** the pending manuscript integration of `quality_reports/2026-11-06_CAP201-filter-implementation.md` §7 (its numbers refer to the 23-country CMP-era specification).
**Session log:** `quality_reports/session_logs/2026-11-12_mipex-only-refit-27cty.log`
**Archived old outputs:** `output/archive_cmp_23cty_2026-11-12/` (moved — *not copied* — so the brms `file=` cache could not silently reload the old fits)

---

## 1. What changed and why

**Decision (2026-11-12):** the estimation sample is now defined by **MIPEX coverage only**. CMP variables and the hardcoded time-invariant claim-making feature (`discrimination_mean`, from `scripts/03_country_level_vars.R`) are removed from sample construction and from all model formulas. This retains **all 27 EU countries covered by MIPEX** (Malta, not assessed by MIPEX, remains excluded). The only Bayesian model reported in the manuscript (Minority × MIPEX) now also carries a **per-MEP random intercept**, matching the manuscript text.

### New specification (single reported model)

```r
pqs_discrimination ~ gender + misery_index + party_family + libe +
  minority * mipex_center + offset(log(total_questions + 1)) +
  (1 | mep_id) + (1 | country)   # zero-inflated negbin, zi = ~1
```

Priors `student_t(3, 0, 2.5)` on `b` and `zi`; brms defaults for RE SDs; seed `20260321`; chains 4 / iter 2000 / warmup 1000 / `adapt_delta = 0.95` — unchanged for comparability.

### Code changes

| Script | Change |
| --- | --- |
| `scripts/05_models.R` | MIPEX-only: `discrimination_center`/`cmp_center` removed from centering, `stopifnot`, structural filter (`pct_na_cmp` branch deleted → only MT excluded), `drop_na()`, and M1–M4 formulas; M3/M4 labels updated |
| `scripts/05_models_Bayesian.R` | Reads the shared `output/df_model_data.rds` (prevents sample drift); CMP model + `res_cmp` deleted; MEP random intercept added; header documents the decision |
| `scripts/06_model_comparison_Bayesian.R` | `base_grid` drops both centered CMP terms; adds `mep_id = "Reference"` dummy (needed for `posterior_predict()` under `re.form = NA + allow_new_levels = TRUE`) |
| `scripts/06_model_comparison.R` | `base_grid` drops both centered CMP terms |
| `scripts/07_extract_all_coefficients.R` | `bayesian_model_cmp.rds` read removed; M3 label corrected; both Bayesian `bind_rows` calls reduced to mipex-only |
| `scripts/05_models_FE.R` | Header marked `[LEGACY — NOT IN PIPELINE]` (code untouched) |
| `scripts/run_pipeline.R` | `05_models.R` now always runs before the configured model script (it builds the shared sample); `07` appended for the Bayesian variant |

## 2. Sample validation

| Metric | Old (23-country) | New (27-country) |
| --- | --- | --- |
| N MEP-years | 9,850 | **10,955** |
| Countries | 23 | **27** (MT only excluded) |
| Unique MEPs | 1,543 | **1,707** |
| Unique minority MEPs | 51 | **55** |
| Minority MEP-years | 317 | 328 |
| Term split (7th/8th/9th) | — | 3,824 / 3,810 / 3,321 |
| Recovered countries | — | HU +331, RO +487, SK +195, LU +92 (as predicted by the pre-flight simulation) |
| Structural exclusions | HU, SK + (LU, RO, MT absent) | **MT only** |

## 3. Convergence diagnostics (`brms`, `output/bayesian_model_mipex.rds`)

- **Divergences: 0 of 4,000** post-warmup iterations.
- **R-hat:** all fixed effects **< 1.003** (max 1.0024, `mipex_center`).
- **Bulk ESS:** min 1,788 (Intercept); **Tail ESS:** min 2,377 — all well above thresholds.
- Random-effect SDs: `sd_country = 0.4605 [0.2887, 0.6955]`; `sd_mep_id = 0.8241 [0.7104, 0.9396]` — the MEP level dominates (expected with repeated MEP-years).
- Runtime: full chain (`05_models.R → 05_Bayesian → 06 ×2 → 07`) about **18 min** (fit about 15 min, slightly below the 15–30 min estimate).

## 4. Old → new posterior (key terms, beta with 95% CrI)

Old = manuscript Table 1 as of 2026-11-11 (matches the pre-CAP-201 VIII/IX fit; for reference the post-CAP-201 23-country fit gave an interaction of 0.0376 [-0.002, 0.080], never integrated in the .md).

| Term | Old (manuscript) | New (MIPEX-only 27cty) | Credible? |
| --- | --- | --- | --- |
| Intercept | -4.804 [-5.218, -4.318] | **-5.175 [-5.531, -4.836]** | both yes |
| Gender: Male | 0.015 [-0.192, 0.219] | **-0.054 [-0.238, 0.140]** | both no |
| The Left | -0.029 [-0.400, 0.350] | **0.152 [-0.219, 0.519]** | both no |
| Eurosceptic Cons. | 0.205 [-0.219, 0.610] | **-0.032 [-0.405, 0.336]** | both no |
| Eurosceptics | 0.038 [-0.537, 0.575] | **0.461 [0.088, 0.832]** | **flips to credible** |
| Greens-EFA | 0.143 [-0.319, 0.581] | **0.446 [0.081, 0.805]** | **flips to credible** |
| Liberals | 0.037 [-0.332, 0.393] | **0.243 [-0.082, 0.546]** | both no |
| Non Inscripts | 0.163 [-0.354, 0.640] | **0.493 [0.129, 0.841]** | **flips to credible** |
| Right-wing nat. | 0.525 [0.158, 0.899] | **0.425 [0.044, 0.796]** | both yes |
| Social Democrats | 0.009 [-0.317, 0.334] | **0.070 [-0.197, 0.331]** | both no |
| LIBE committee | 0.429 [0.079, 0.751] | **0.648 [0.385, 0.912]** | both yes (stronger) |
| **Minority (H1)** | 0.327 [-0.596, 1.152] | **0.835 [0.117, 1.486]** | **flips to credible** |
| **Mipex (H2)** | -0.001 [-0.013, 0.011] | **0.005 [-0.006, 0.015]** | both no |
| **Minority x Mipex (H3)** | 0.066 [0.016, 0.117] | **0.011 [-0.033, 0.058]** | **flips to non-credible** |
| sd (country) | 0.471 [0.281, 0.719] | **0.461 [0.289, 0.696]** | (relabelled row in Table 1) |
| sd (MEP) — **new** | not in model | **0.824 [0.710, 0.940]** | — |

**IRR phrasing changes:** minority at reference = **2.31x** [1.12, 4.42]; LIBE = **+91.1%** (was +53.6%); right-wing nationalist = **+52.9%** (was +69.1%); interaction per MIPEX unit = **+1.1%** [-3.3%, +5.9%] (was +6.8% [1.6%, 12.5%]).

### Substantive reading

With the low-MIPEX CEE cases (HU, RO, SK, LU) back in the sample and MEP-level clustering absorbed by the new random intercept, **H1 became credible at the reference MIPEX value and H3 lost credible support**. The interaction's point estimate remains positive (+0.011) but its CrI includes zero. The manuscript narrative has been re-centred accordingly: minority background is associated with discrimination-related questioning (H1), the MIPEX main effect remains null (H2), and the conditional amplification story is now framed as suggestive at most (H3).

## 5. Frequentist side (`05_models.R`, M1–M4)

- M4 interaction `minority:mipex_center` = 0.010 (IRR 1.01), p = 0.680 — consistent with the Bayesian non-finding.
- `minority` in M2 = 0.976 (IRR 2.65), p < 0.001; drops to p = 0.012 (IRR 2.37) once the MIPEX interaction enters (M4).
- **The pre-existing M1/M3 NaN-SE issue (Hessian instability, TO_DO section 2) did NOT re-occur** with the larger sample; all four fits produced finite SEs and p-values.
- Tables regenerated: `model_coefficients_comparison.csv`, `model_coefficients_wide_comparison.csv`, `all_model_coefficients_comprehensive.csv`, `bayesian_coefficients_comparison.csv`, `bayesian_model_results.csv`, `interaction_effects_summary.csv`.

## 6. Figures

- `output/figures/bayesian_interaction_magnitude_panel.png` — regenerated (new sample/grid incl. `mep_id` dummy).
- `output/figures/m4_interaction_magnitude_panel.png` — regenerated.
- Old panels/CSVs preserved in `output/archive_cmp_23cty_2026-11-12/`.

## 7. Manuscript sync (`paper/MEPArticle_12_11_2026.md`) — completed edits

1. Abstract: "26 EU Member States" → "27 EU Member States (all covered by MIPEX; Malta, not assessed by MIPEX, is not included)".
2. Abstract claim sentence rewritten: minority now credible at reference; interaction positive in sign but not credible.
3. Contribution section: "26" → "27 … (all covered by MIPEX)".
4. Data section: appended "— that is, 27 of the 28 EU Member States; Malta, which MIPEX does not assess, is therefore excluded."
5. Modelling strategy: "random intercept for each MEP" → "random intercepts for each MEP and for each country" (now accurate).
6. H1 paragraph rewritten — supported at reference: beta = 0.835 [0.117, 1.486]; 2.31x [1.12, 4.42].
7. H2 paragraph: beta updated to 0.005 [-0.006, 0.015].
8. H3 paragraph rewritten — not supported: beta = 0.011 [-0.033, 0.058]; +1.1% per unit [-3.3%, +5.9%].
9. Post-H3 paragraph: "moderate evidence" replaced by weak-evidence framing.
10. **Table 1 fully replaced** (clean pipe table; new rows "*Random-intercept SD (Country)*" and "*Random-intercept SD (MEP)*"; `{.underline}` on cells whose CrI excludes zero, incl. the Intercept; Notes extended to cover the SD rows).
11. LIBE sentence: beta = 0.648 [0.385, 0.912], +91.1%; **fixed the duplicated `.\]).` typo**.
12. Right-wing nationalist: beta = 0.425 [0.044, 0.796], +52.9 per cent.
13. Gender paragraph: beta = -0.054 [-0.238, 0.140].
14. Findings-summary paragraph rewritten (the "credibly conditional" claim removed).
15. Conclusion: "26 EU" → "27 EU (all covered by MIPEX)".
16. Conclusion "clearest empirical result" paragraph rewritten.
17. Policy-feedback paragraph downgraded to "suggestive support"; observational + non-credible-interaction caution added; "future research" closing.
18. Closing wrap-up softened: variation "may … although the present model cannot identify this variation precisely".

## 8. Word/docx find-&-replace memo (when the .docx is regenerated)

Apply the same changes to the Word manuscript. Key search strings (old → new):
1. `across 26 EU Member States` → `across 27 EU Member States (all covered by MIPEX; Malta, not assessed by MIPEX, is not included)` — 2 occurrences (abstract, contribution).
2. `indicators across 26 EU Member States.` → `indicators across 27 EU Member States (all covered by MIPEX).` (conclusion).
3. Data section: `Migrant Integration Policy Index (MIPEX).` → `Migrant Integration Policy Index (MIPEX) — that is, 27 of the 28 EU Member States; Malta, which MIPEX does not assess, is therefore excluded.`
4. Abstract/conclusion claim sentences + H1, H3, post-H3, findings-summary, policy-feedback and closing paragraphs: replace whole sentences (copy from the .md — they were rewritten, not merely renumbered).
5. H2: `(β = −0.0007, 95% CrI [−0.013, 0.011])` → `(β = 0.005, 95% CrI [−0.006, 0.015])`.
6. LIBE: `(β = 0.429, 95% CrI [0.079, 0.751]).]).` → `(β = 0.648, 95% CrI [0.385, 0.912]).` (also deletes the duplicated `]).`); `53.6% more` → `91.1% more`.
7. Right-wing: `(β = 0.525, 95% CrI [0.158, 0.899])` → `(β = 0.425, 95% CrI [0.044, 0.796])`; `69.1 per cent` → `52.9 per cent`.
8. Gender: `(β = 0.015, 95% CrI [−0.191, 0.219])` → `(β = −0.054, 95% CrI [−0.238, 0.140])`.
9. Model description: `a random intercept for each MEP to account for repeated observations and unobserved individual differences` → `random intercepts for each MEP and for each country to account for repeated observations, unobserved individual differences, and unobserved country-level heterogeneity`.
10. H1: `β = 0.327, 95% CrI [−0.595, 1.151]` → `β = 0.835, 95% CrI [0.117, 1.486]` (+ paragraph rewrite).
11. H3: `β = 0.0658, 95% CrI [0.016, 0.117]` → `β = 0.011, 95% CrI [−0.033, 0.058]`; `6.8% more discrimination-related questions (95% CI [1.6%, 12.5%])` → `about 1.1% more discrimination-related questions (95% CrI [−3.3%, +5.9%])`.
12. Table 1: delete and paste the new table (the .md version is the source of truth); keep the underline convention for cells whose CrI excludes zero.

## 9. Flags & carry-overs

- `paper/MEPArticle_12_11_2026.md` line ~419 placeholders (`[updated percentage]`, `[X] MEPs in the seventh legislature`) still open — should now be computed on the 27-country sample.
- Duplicated sentence (`The article makes three main contributions.` twice, ~line 697) — pre-existing, flagged for the next editorial pass.
- Descriptive Figures 1–2 regeneration still pending (outside the model pipeline).
- `run_pipeline.R` order fix means a full pipeline rerun rebuilds the shared sample + fits both engines; earlier archives (`archive_8th9th/`, `archive_cap201_prefilter_2026-11-06/`) untouched.
- If Zeynep's H3 theory revision (TO_DO section 5) is still planned, it should be reframed for the new pattern (H1 positive/credible, H3 null) before inclusion.
- broom.mixed output note: for the two-group model, `tidy()`/`bayesian_model_results.csv` labels BOTH random-effect rows `sd__(Intercept)` — the Table 1 SD rows were built from `posterior_summary(fit, variable = "sd_", regex = TRUE)` (unambiguous naming) instead.
