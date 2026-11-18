# 📑 ALTERNATIVE Model — Minority × LIBE Interaction (MIPEX-free, all countries)

**Date**: 2026-11-12 · **Author**: Federico Russo (Univ. del Salento) with Cline
**Status**: executed and verified · **Scope**: ALTERNATIVE/additional model — does NOT replace the primary MIPEX-only specification

---

## 1. Motivation

The primary model (scripts/05_models_Bayesian.R, MIPEX-only 27-country sample) treats `libe` as a **plain control**, and tests institutional moderation through the `minority × mipex_center` interaction (H3). Two open questions motivated this alternative specification:

1. **Does committee assignment itself moderate the minority effect?** The LIBE-omission robustness memo (`quality_reports/2026-11-12_libe-omission-robustness.md`) showed descriptively that the minority "boost" in discrimination questions concentrates among minority MEPs on the civil-liberties committee (mean DV 0.451 vs 0.145 on/off LIBE). This model formalizes that into an explicit `minority × libe` interaction.
2. **Does the headline result survive without MIPEX at all?** MIPEX drops Malta and requires listwise deletion on coverage; removing MIPEX entirely changes both the sample (all 28 Member States) and the information set.

This is therefore a **separate, deliberately MIPEX-free** run: no `mipex_center` anywhere in the script, and no MIPEX coverage filter.

## 2. Sample rule (FR-approved) and verification

Built exactly like the primary sample in `05_models.R` (same joins, term filter VII–IX, listwise `drop_na()` on the 9 model variables), with two deviations:

- **No MIPEX coverage filter** → Malta (the only 100%-MIPEX-NA country) is retained.
- **UK excluded from the 9th term only** (`filter(!(country == "UK" & legislative_term == "9th"))`) — the Brexit-truncated 2019–2024 term. Verified during feasibility: **the upstream data contain no UK rows in the 9th term at all** (UK: 367 rows in the 7th, 374 in the 8th, 0 in the 9th), so this filter is an **explicit no-op safeguard** codifying the rule; both samples effectively already exclude UK in the 9th term.

**Fit-verified sample** (`output/df_model_data_libe.rds`; script asserts exact equality with the feasibility check):

| Quantity | Value |
|---|---|
| MEP-years | **11,042** (primary: 10,955 → difference +87, all Malta) |
| Countries | **28** (+Malta vs the primary 27) |
| Unique MEPs | **1,721** (primary: 1,707; +14, Malta) |
| Minority MEPs / MEP-years | **55 / 328** (unchanged — Malta has 0 minority MEPs) |
| DV sum | 1,241 |
| Rows by term | 7th = 3,855; 8th = 3,841; 9th = 3,346 |

**Minority × LIBE cell structure** (MEP-years / unique MEPs / events `Σ DV` / % rows with ≥1 discrimination question):

| minority | libe | MEP-years | MEPs | events | %>0 |
|---|---|---|---|---|---|
| 0 | 0 | 9,924 | 1,579 | 1,034 | 10.4% |
| 0 | 1 | 790 | 151 | 160 | 20.3% |
| 1 | 0 | 272 | 47 | 24 | 8.8% |
| 1 | 1 | **56** | **11** | 23 | 41.1% |

Raw rates already show the pattern: LIBE ≈ doubles the positive rate among non-minority MEPs (10.4% → 20.3%) and ≈ quadruples it among minority MEPs (8.8% → 41.1%).

Focal cell composition (11 MEPs): UK 1, HU 1, NL 2, FR 1, IT 1, SE 3, DE 1, BE 1.

## 3. Specification

Identical priors/sampler to the primary fit for comparability:

- `pqs_discrimination ~ gender + misery_index + party_family + minority * libe + offset(log(total_questions + 1)) + (1 | mep_id) + (1 | country)`
- `zero_inflated_negbinomial()`; priors `student_t(3, 0, 2.5)` on `b` and `zi` classes, brms default on RE SDs
- 4 chains × 2,000 iter (1,000 warmup), `adapt_delta = 0.95`, `seed = 20260321`
- Script: `scripts/05_models_Bayesian_LIBE.R`; cached fit: `output/bayesian_model_libe.rds`; runtime ≈ 17 min (+compile)
- **Not wired into `run_pipeline.R`** — standalone by design; primary pipeline untouched.

## 4. Results

### 4.1 Focal coefficients (posterior median [95% CrI], P(draw > 0))

| Parameter | Estimate | CrI | P(+) |
|---|---|---|---|
| `minority` (main effect, OFF-LIBE reference) | **0.652** | [**0.043**, **1.221**] | 0.981 |
| `libe` (main effect, non-minority MEPs) | **0.572** | [**0.310**, **0.835**] | 1.000 |
| `minority × libe` (extra LIBE boost for minority MEPs) | **0.992** | [**0.033**, **1.945**] | 0.979 |

- The **interaction is credible at 95%** (`minority × libe` CrI just excludes zero; P(+) = 0.979) — in contrast, the primary's `minority × mipex_center` is null (0.011 [−0.033, 0.058]).
- The `minority` main effect here is **conditional on being OFF LIBE** (different estimand from the primary's pooled `minority`); it is also credible: 0.652 [0.043, 1.221].

### 4.2 Marginal IRR contrasts (expected counts; grid: gender M, reference party family, mean misery/offset, country averaged out)

| Contrast | IRR | 95% CrI | P(IRR > 1) |
|---|---|---|---|
| Minority IRR **ON** the LIBE committee | **5.22** | [2.31, 11.32] | 1.000 |
| Minority IRR **OFF** the LIBE committee | **1.92** | [1.04, 3.39] | 0.981 |
| LIBE boost, minority MEPs (0 → 1) | **4.79** | [1.88, 12.31] | 0.9998 |
| LIBE boost, non-minority MEPs (0 → 1) | **1.77** | [1.36, 2.31] | 1.000 |

Reading: minority MEPs on LIBE give ≈ **5.2×** the expected number of discrimination questions of non-minority MEPs on LIBE; OFF LIBE the gap is ≈ **1.9×** (CrI barely excludes 1). Conversely, committee membership boosts expected counts ≈ **2.7× more** for minority MEPs (4.79 vs 1.77). The pooled primary estimate (`exp(0.835) ≈ 2.31×`) sits between the two strata — consistent with the effect being concentrated ON the committee.

### 4.3 Other coefficients (means; see CSV for full detail)

`genderM` −0.05 [−0.24, 0.14]; `misery_index` −0.00 [−0.01, 0.01]; party-family dummies: Eurosceptics 0.47 [0.09, 0.85], Greens/DEFA 0.44 [0.09, 0.80], NI 0.51 [0.13, 0.88], right-wing nationalists 0.43 [0.07, 0.80] credible vs Christian-democrat reference; S&D and Communists ns. Zero-inflation intercept 0.07 [0.00, 0.16].

**Random-effect SDs** (extracted via `posterior_summary(..., variable = "sd_", regex = TRUE)`; note the broom `tidy()` rows labelled `sd__(Intercept)` in the CSV are the ambiguous duplicates flagged in the carry-over caveat — use the `sd_country__` / `sd_mep_id__` rows):
country **0.455** [0.298, 0.676]; MEP **0.820** [0.710, 0.934].

## 5. Diagnostics

| Metric | Value | Verdict |
|---|---|---|
| max R̂ | **1.0032** | clean |
| min bulk ESS | 1,077 (`shape`) | OK |
| min tail ESS | 535 (`shape`) | just above threshold; focal parameters bulk/tail ≥ 2,449 / 2,819 |
| divergent transitions | **0 / 4,000** | clean |

⚠️ The NB `shape` parameter is weakly identified (mean ≈ 2.8e6 with an absurd SD, CrI [3.09, 1,227.7]) — the usual behaviour of the NB dispersion in brms with this DV; it is the driver of the min-ESS rows above and does not propagate to the parameters of interest (focal ESS are comfortably high). Same family/data structure as the primary and the libe-robustness fits.

## 6. Side-by-side vs the primary MIPEX-only fit

| Quantity | Primary (`05_models_Bayesian.R`) | Alternative (this fit) |
|---|---|---|
| Sample | N = 10,955; 27 ctry (MIPEX coverage); 1,707 MEPs | N = 11,042; **28** ctry (+MT); 1,721 MEPs; UK dropped from 9th (no-op) |
| Moderator | MIPEX (`mipex_center`) | **LIBE membership (`libe`)** |
| minority | 0.835 [0.117, 1.486] — pooled avg effect | 0.652 [0.043, 1.221] — effect **off LIBE** |
| libe | 0.648 [0.385, 0.912] | 0.572 [0.310, 0.835] — effect for **non-minority** |
| Interaction | `minority × mipex` 0.011 [−0.033, 0.058] (ns) | **`minority × libe` 0.992 [0.033, 1.945] (P(+) 0.979)** |
| RE SD country / MEP | 0.460 / 0.824 | 0.455 / 0.820 |
| Diagnostics | max R̂ < 1.003; 0 divergences | max R̂ 1.0032; 0 divergences; min ESS 1,077/535 (`shape`) |

**Takeaway**: dropping MIPEX entirely and switching the moderator from `mipex_center` to `libe` (i) preserves a credible minority main effect, (ii) replaces the null institutional-moderation result (H3 vs MIPEX) with a marginally credible, substantively large committee-moderation interaction, and (iii) barely moves the RE structure or diagnostics.

## 7. Caveats and interpretation

1. **Thin focal cell.** `minority = 1 & libe = 1` has only **56 MEP-years / 11 MEPs** (23 events). The interaction estimate leans on those 11 MEPs; the wide CrI [0.03, 1.95] reflects this. The point estimate was independently corroborated pre-fit by a glmmTMB ZINB smoke test (1.004, SE 0.489, p = .040) — brms: 0.992, SE 0.488.
2. **Identification is mostly between-MEP.** `libe` varies within only **67 of 1,721 MEPs**; the interaction is therefore almost entirely a between-MEP (between-person selection + committee) comparison, not a within-MEP change.
3. **Moderator vs mediator tension** (per `2026-11-12_libe-omission-robustness.md` §1/§8): if minority background *causes* LIBE assignment (self-selection / party channelling), conditioning on `libe` (and interacting with it) describes association along the post-treatment path — this model should be read as **descriptive committee heterogeneity**, not a causal moderation claim, and its `minority` main effect is a *direct*-type effect (off-committee). The framing tension documented there applies to this model as well.
4. **"Just barely" credible.** The interaction CrI excludes zero by almost exactly zero mass (P(+) = 0.979): the honest reading is *indicative-to-weakly-credible*, robust enough to report as a robustness check, not as a headline.
5. **Sample differences vs primary are tiny**: +87 rows (Malta only; UK-9th rows do not exist upstream, so the safeguard is a rule codification, not a data effect). All other listwise deletions are identical.
6. **Generalization**: EU-28-era sample covers terms VII–IX (2009–2024); UK is present in VII/VIII only.

## 8. What this model is NOT

- It does **not** replace the primary MIPEX-only model in the manuscript or pipeline; it is an additional analytical memo + outputs.
- `run_pipeline.R`, `06_*` / `07_*` scripts, and the primary outputs (`bayesian_model_mipex.rds`, `bayesian_model_results.csv`, `df_model_data.rds`, zinb fits) were **not modified** — verified by before/after inventory diff of `output/`.

## 9. Reproduction

```bash
cd /home/federusso/progetti/EPmigrants
Rscript scripts/05_models_Bayesian_LIBE.R          # ≈ 18 min incl. compile (renv auto-activates)
```

Log: `quality_reports/session_logs/2026-11-12_libe-interaction-alternative.log`
Caching: `brm(file = ...)` reuses `output/bayesian_model_libe.rds` if present — **delete it before re-running with a changed formula/spec** (`seed = 20260321` fixed).

| Output | Content |
|---|---|
| `output/df_model_data_libe.rds` | estimation sample (asserted N = 11,042; 28 ctry; focal cell 56/11) |
| `output/bayesian_model_libe.rds` | brms fit object (cache) |
| `output/bayesian_libe_model_results.csv` | full coefficient table (fixed + correctly labelled RE SDs + shape; broom's ambiguous `sd__(Intercept)` duplicates retained from `tidy()`) |
| `output/bayesian_libe_diagnostics.csv` | max R̂ / min ESS bulk & tail / divergences |
| `output/bayesian_libe_focal_coefficients.csv` | median [CrI], P(+) for `minority`, `libe`, `minority × libe` |
| `output/bayesian_libe_irr_contrasts.csv` | the 4 marginal IRR contrasts of §4.2 |


