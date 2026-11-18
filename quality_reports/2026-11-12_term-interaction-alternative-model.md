# ALTERNATIVE MODEL: Legislature-Term Heterogeneity of the Minority Effect
**Date:** 2026-11-12 (evening, 3rd session) — **Status: ESEGUITO** — Author: Cline, per FR-approved design (plan mode, same day)
**Log:** `quality_reports/session_logs/2026-11-12_term-interaction-alternative.log` — **Script:** `scripts/05_models_Bayesian_TERM.R`

---

## 1. Purpose and design (approved in planning session, no deviations)

Minimal, elegant test of whether the **supported H1 minority effect** (primary MIPEX-only spec: minority 0.835 [0.117, 1.486], IRR 2.31×) differs across EP terms VII/VIII/IX. **Exactly two terms added to the otherwise unchanged primary specification**:

- `legislative_term` (factor; **7th = reference**; levels 7th/8th/9th, no other recoding);
- `minority:legislative_term` (interaction, conditional mean only).

Kept **identical to the primary** (`05_models_Bayesian.R`): controls (`gender`, `misery_index`, `party_family`, `libe`), **H3 interaction `minority × mipex_center` untouched**, offset `log(total_questions + 1)`, REs `(1 | mep_id) + (1 | country)`, ZINB family (intercept-only zero-inflation), priors student_t(3,0,2.5) on class b and zi, 4 chains × 2,000 (1,000 warmup), adapt_delta 0.95, seed 20260321.

**One fit yields** per-term minority IRRs, the pooled {8th,9th}-vs-7th **step contrast** (average minority log-effect change; exp = geometric-mean IRR — chosen because the 9th-term minority cell has only 8 events), pairwise contrasts (8v7, 9v7, 9v8), and term main effects as free context. It is informative under every possible outcome (monotone rise / 8th spike / flat). **Rejected alternatives** (planning): per-term stratified fits, continuous `year` interaction, external salience series (Eurobarometer MIP — future upgrade only).

**Sample: the PRIMARY sample, loaded READ-ONLY from `output/df_model_data.rds`.** No sample rebuild, no `df_model_data_term.rds`; MIPEX-coverage rule and every upstream choice are therefore inherited unchanged (by design — the term effect is tested within the approved sample, not beside a new one). Not wired into `run_pipeline.R`.

## 2. Feasibility (assertions passed before fitting; printed in the log)

| Term | Minority MEP-years | Minority MEPs | Minority events | Share>0 (min) | Share>0 (non-min) | Minority questions | Intensity /1k (min) | Intensity /1k (non-min) | Raw ratio |
|---|---|---|---|---|---|---|---|---|---|
| 7th | 122 | 27 | 17 | 13.9% | 15.0% (n=3,702) | 852 | 19.95 | 10.81 | 1.85× |
| 8th | 91 | 21 | 22 | 24.2% | 11.4% (n=3,719) | 434 | 50.69 | 9.98 | **5.08×** |
| 9th | 115 | 23 | 8 | 7.0% | 5.8% (n=3,206) | 494 | 16.19 | 8.82 | 1.84× |

Sample: **N = 10,955 MEP-years, 27 countries, 1,707 MEPs (55 minority), DV sum 1,215**; rows by term 3,824 / 3,810 / 3,321. Spanners: **8 two-term + 4 three-term minority MEPs** (=12 of 55; partial within-MEP variation — identification remains mostly between-MEP). Composition: FR 62/30/30; **UK 25/33/0 (Brexit — UK minority MEPs vanish in the 9th)**; DE 5/6/25; SE 0/5/20; NL 5/0/15. `total_questions` mean by term 13.7 → 11.3 → 6.5 (9th-term DV-completeness flag). Hard `stopifnot` invariants pinned the exact values above (script aborts if the upstream sample ever drifts).

## 3. Convergence — clean

max R̂ **1.0032**; min ESS bulk **1,505**, min ESS tail **1,110**; **0 divergent transitions** (4,000 post-warmup draws). RE SDs: country 0.528 [0.351, 0.773], MEP 0.817 [0.709, 0.931]; `shape` 1,118 with a huge CrI — the usual brms NB-dispersion behaviour. Runtime ≈ 20 min (cold).

## 4. Results

### 4.1 Focal coefficients (posterior median [95% CrI], P(draw>0), log-IRR scale; exp() = IRR)

| Parameter | Estimate | P(+) |
|---|---|---|
| minority (main effect; 7th term, mean MIPEX) | 0.667 [−0.177, 1.497] | 0.941 |
| mipex_center (main effect) | 0.007 [−0.004, 0.017] | 0.882 |
| **H3 re-check: minority × mipex_center** | **0.007 [−0.039, 0.056]** | 0.624 |
| term main effect: 8th vs 7th (non-minority baseline) | −0.357 [−0.545, −0.164] | 0.000 |
| term main effect: 9th vs 7th (non-minority baseline) | −0.715 [−0.980, −0.449] | 0.000 |
| **minority × 8th term (change vs 7th)** | **0.770 [−0.093, 1.596]** | **0.959** |
| minority × 9th term (change vs 7th) | 0.073 [−1.060, 1.094] | 0.547 |
| **STEP contrast {8th,9th} vs 7th** | **0.417 [−0.398, 1.186]** | 0.840 |
| Pairwise: minority log-effect, 9th vs 8th | −0.698 [−1.849, 0.408] | 0.101 |

Full coefficient table: `output/bayesian_term_model_results.csv` (broom `tidy()` means; the focal table above uses poster medians — hence e.g. 0.770 vs 0.760).

### 4.2 Marginal IRR contrasts (median [95% CrI], P(IRR>1))

| Contrast | IRR | P(>1) |
|---|---|---|
| Minority IRR — 7th term (reference) | 1.95× [0.84, 4.47] | 0.941 |
| Minority IRR — **8th term** | **4.19× [1.60, 9.78]** | **0.998** |
| Minority IRR — 9th term | 2.08× [0.73, 5.37] | 0.911 |
| Minority-effect change — 8th vs 7th | 2.16× [0.91, 4.93] | 0.959 |
| Minority-effect change — 9th vs 7th | 1.08× [0.35, 2.98] | 0.547 |
| Minority-effect change — 9th vs 8th | 0.50× [0.16, 1.50] | 0.101 |
| **STEP contrast — average {8th,9th} vs 7th** | **1.52× [0.67, 3.27]** | 0.840 |
| Term main effect (non-minority) — 8th vs 7th | 0.70× [0.58, 0.85] | 0.000 |
| Term main effect (non-minority) — 9th vs 7th | 0.49× [0.38, 0.64] | 0.000 |

Internal consistency: IRR levels × change contrasts agree (1.95 × 2.16 ≈ 4.19; 1.95 × 1.08 ≈ 2.08); epred-based and coefficient-based rows are algebraically equivalent here (intercept-only zi, common offset, re.form = NA) — the duplication is a deliberate cross-check, not a discrepancy. Figure: `output/figures/bayesian_term_irr_small_multiples.png`.


## 5. Interpretation — spike, not step; and the adjustment cuts the raw preview badly

1. **Raw preview vs adjusted results.** Raw intensity ratios were 1.85 / **5.08** / 1.84 (7/8/9). After full adjustment the 8th-term spike survives in direction and order of magnitude (minority IRR 4.19× in the 8th) but the *change* is marginal: **2.16× [0.91, 4.93], P = .96** — CrI touches 1. The pooled **step contrast is 1.52× [0.67, 3.27], P = .84 — same direction, not credible**. The apparent 8th-term amplification is therefore *suggestive*, concentrated in one term, and shrinks under controls (the non-minority baseline falls faster than the minority across terms, which flatters the raw 8th-term ratio).
2. **The pattern is an 8th-term spike, not a crisis-era step.** 8-vs-7 is +0.77 (marginal), 9-vs-7 is ≈ 0 (1.08×), 9-vs-8 reverses (−0.70, ns). The {8th,9th}-pooled step dilutes the spike with the reversion — as designed, it is reported next to the per-term IRRs, not instead of them.
3. **Aggregate context, not a salience effect by itself.** Non-minority discrimination attention falls decisively across terms (0.70×, then 0.49×). The term dummies net topic composition *and* the falling DV volume (mean questions/MEP-year 13.7 → 11.3 → 6.5), so they are a **context index, not a salience measure**. The informative quantity is the within-term minority contrast (difference-in-differences across topic-volume regimes) — the interaction.
4. **The primary specification's quantities are stable under the extension.** H3 re-check 0.007 [−0.039, 0.056] vs primary 0.011 [−0.033, 0.058]; mipex main ≈ 0.007 vs 0.005; minority main at the 7th-term reference 1.95× (P = .94) — a little below the primary's 2.31× because H1's effect now sits explicitly on the 7th-term baseline; same ballpark, no overturning. The term extension adds context; it does not move the H1/H3 verdicts.
5. **Best reading to carry forward (for FR's judgment):** "the minority amplification is consistent with the salience account in the direction of an 8th-term (Brexit + peak-migration-salience era) concentration, with the 9th term inconclusive" — **"consistent with", never a test**; the 9th cell is too thin to adjudicate and the design is a period proxy, not a causal salience manipulation.

## 6. Caveats (ranked)

- **9th-term cell is thin and composition-shifted**: 8 events; UK minority MEPs disappear (0 MEP-years vs 25/33 in 7th/8th); DV completeness declines (6.5 questions/MEP-year). The 9th-term reversion could be noise + composition; the step contrast only partially buys this back (and pools a spike with a reversion).
- **Identification mostly between-MEP**: only 12/55 minority MEPs span ≥ 2 terms (8 two-term, 4 three-term). Term contrasts are cross-sectional to a large extent; no within-MEP causal claim.
- **Period ≠ salience**: no manipulation of MIP salience; Brexit-shock, budget-cycle and migration-MIP timing all co-move with the 8th term. A Eurobarometer MIP-series interaction is the principled upgrade (out of scope here).
- **9th term DV completeness** interacts with everything above; the model's offset conditions on asked questions, so the flag concerns *selection into question-asking volume*, not DV coding.

## 7. Decision points reserved for FR (none taken unilaterally)

1. **Manuscript treatment**: keep out of the main spec (recommended — the primary fit is unchanged); whether to add a robustness paragraph + the small-multiples figure, or keep this in quality_reports only.
2. **H4 framing**: if reported, frame as above ("consistent with salience-era amplification in the 8th term; 9th inconclusive"). Do NOT claim H4-style evidence without FR's sign-off.
3. **Eurobarometer MIP upgrade** remains a listed future direction only.

## 8. Outputs and files

- `scripts/05_models_Bayesian_TERM.R` (new, self-contained; sample loaded read-only; **NOT in `run_pipeline.R`**)
- `output/bayesian_model_term.rds` (brms cache, 135 MB; delete before re-spec)
- `output/bayesian_term_model_results.csv` — full coefficient table (mean/CrI)
- `output/bayesian_term_focal_coefficients.csv` — focal draws-based table (9 rows, incl. step + pairwise)
- `output/bayesian_term_irr_contrasts.csv` — 9 marginal IRR contrasts (epred + coefficient-derived)
- `output/bayesian_term_diagnostics.csv` — R̂ / ESS / divergences
- `output/figures/bayesian_term_irr_small_multiples.png` — per-term IRR forest (panel A) + change contrasts (panel B)
- **Intactness check**: md5 diff of all 40 pre-existing `output/*.csv` + `*.rds` files vs pre-run snapshot `– all match; nothing overwritten (the new files carry distinct `_term` names).

**Ops notes** (for the next session): (i) `tidy.brmsfit` warning "parameter names contain underscores" is the routine broom.mixed caveat — parameters were matched by exact name; (ii) R stdout is buffered when running detached: the log shows "Iteration 1/2000" for most of the run and flushes at completion — harmless; (iii) the script text was assembled via heredoc chunks (editor tool's 6 KB payload cap); parse-checked (94 top-level expressions) before launch.

## 9. Figure regeneration (appendix)

The figure is deterministic from the saved CSV (no refit needed). Recipe: read `output/bayesian_term_irr_contrasts.csv`; map the 3 `Minority IRR | …` rows to panel A (levels) and the 4 change rows (8v7, 9v7, 9v8, STEP) to panel B; `ggplot` `geom_pointrange` with `scale_x_log10`, dashed vline at 1, 8th-term rows highlighted (#B13B24), facet per panel (free scales), 9.2 × 4.6 in @200 dpi. Generation code recorded verbatim in the session log of this run.

---
*Carried-over manuscript items unchanged: .docx regeneration (find&replace list in `2026-11-12_MIPEX-only-refit-27cty.md` §8), ms placeholders ~L419, reference cleanup, duplicated sentence ~L697, Figures 1–2, H3 framing update, optional git commit; also still formally open: LIBE-hardening (leave-one-out, triple interaction) if ever wanted.
