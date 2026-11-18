# 📑 ALTERNATIVE Model — Minority × CMP Interaction (CMP-coverage countries, 23) + LIBE-only Robustness

**Date**: 2026-11-12 · **Author**: Federico Russo (Univ. del Salento) with Cline
**Status**: executed and verified · **Scope**: ALTERNATIVE/additional model — does NOT replace the primary MIPEX-only specification
**Script**: `scripts/05_models_Bayesian_CMP.R` · **Log**: `quality_reports/session_logs/2026-11-12_cmp-interaction-alternative.log`

---

## 1. Motivation

The primary model (`05_models_Bayesian.R`, MIPEX-only 27-country sample) tests institutional moderation through `minority × mipex_center` (H3, null). The CMP-Claim Making Pressure moderator — the country-level hard-coded measure in `scripts/03_country_level_vars.R` / `data/claimmakingpressure.csv`, **not** the Comparative Manifesto Project — had been tested in a discarded Bayesian fit (archived in `output/archive_cmp_23cty_2026-11-12/`) whose RE structure predates the current conventions (`(1 | country)` only, no MEP RE). FR decided (2026-11-12) to restore the CMP idea as a **separate alternative model**:

- **M1 (main)**: `minority × cmp_center` interaction with `libe` kept as a control — same priors/sampler as the primary for comparability, upgraded RE structure `(1 | mep_id) + (1 | country)`.
- **M2 (robustness)**: same sample/controls with CMP removed entirely and **no interaction** (`gender + misery_index + party_family + minority + libe`). Per FR there is **no** `minority × libe` interaction anywhere (libe is a control in M1, a main effect in M2). M2 is nested in M1 → the nested-model question: *does adding the CMP moderator move the minority estimate?*

## 2. Sample rule (FR-approved) and verification

Structural, data-coverage-driven exclusion: countries without CMP values. Verified against `data/claimmakingpressure.csv`: HU and SK list `n.a.` for CMP; LU, MT, RO are absent from the file. The exclusion is computed programmatically (pct `cmp_mean` == 1 per country) and asserted against the pre-flight check.

**Fit-verified sample** (`output/df_model_data_cmp.rds`; script asserts exact equality):

| Quantity | Value |
|---|---|
| MEP-years | **9,850** — identical to the archived CMP fit |
| Countries | **23** (excl. HU LU MT RO SK) |
| Unique MEPs | **1,543** |
| Minority MEPs / MEP-years | **51 / 301** |
| DV sum (% rows > 0) | 1,038 (7.3%) |
| cmp_mean mean / sd (in-sample) | 8.8294 / **4.0073** |
| Rows by term | 7th = 3,445; 8th = 3,444; 9th = 2,961 |

The term filter (VII–IX) and the UK-9th exclusion safeguard are the same as all 2026-11-12 runs (UK-9th: verified no-op).

**Minority MEP-year concentration across the 23 countries** (mandatory caveat):

| Country | FR | UK | DE | SE | NL | BE | BG | IT | ES | FI | other 13 |
|---|---|---|---|---|---|---|---|---|---|---|---|
| minority MEP-years | 122 | 58 | 36 | 25 | 20 | 10 | 10 | 10 | 5 | 5 | **0** |

13 of 23 countries (AT CY CZ DK EE GR HR IE LT LV PL PT SI) have **zero** minority MEPs; minority rows sit at the **high** end of CMP (median cmp 13.03 vs 7.83 for non-minority; minority range 2.25–15.11).

## 3. Specification

Identical priors/sampler to the primary and LIBE-alternative fits:

- M1: `pqs_discrimination ~ gender + misery_index + party_family + libe + minority * cmp_center + offset(log(total_questions + 1)) + (1 | mep_id) + (1 | country)`
- M2: same with `minority * cmp_center` → `minority + libe` (CMP removed entirely)
- `zero_inflated_negbinomial()`; priors `student_t(3, 0, 2.5)` on `b` and `zi`; brms default on RE SDs; 4 chains × 2,000 iter (1,000 warmup), `adapt_delta = 0.95`, `seed = 20260321`
- `cmp_center` centered **within the estimation sample** (mean 8.8294) so 0 = sample mean; the archived fit centered globally on `df_merged_3` pre-filter — this shifts only the minority baseline, never the interaction (invariant to the centering constant)
- No MIPEX and no `discrimination_mean` anywhere (per FR: locked; all 23 CMP countries carry complete MIPEX/Discrimination, which is why N coincides with the archived 9,850)
- Pre-fit glmmTMB smoke tests (`nbinom2`, `ziformula = ~1`, same REs, 2026-11-12): M1 interaction **0.0854 (SE 0.0996)**; M2 minority **0.9483 (SE 0.2502)**; both conv. code 0, finite VCV. (Reference anchor: archived fit interaction 0.107 [−0.038, 0.275].)

## 4. Results — M1 (minority × cmp, libe as control)

Population-level coefficients (brms summary; 95% CrI):

| term | estimate | l-95% | u-95% | note |
|---|---|---|---|---|
| minority | 0.544 | −0.383 | 1.362 | main effect at sample-mean CMP (draws median 0.563, P(+) = 0.890) |
| cmp_center | −0.033 | −0.080 | 0.014 | CMP gradient for non-minority MEPs (P(+) = 0.075) |
| **minority × cmp_center** | **0.109** | **−0.067** | **0.306** | **n.s.** (draws median 0.105, P(+) = 0.874) |
| libe | 0.500 | 0.207 | 0.781 | stable control (IRR ≈ 1.65) |
| RE SD country / MEP | 0.326 / 0.761 | — | — | [0.114, 0.560] / [0.639, 0.878] |
| Diagnostics | max R̂ 1.0055 | 0 divergences | min ESS bulk/tail 1,327 / 860 | clean |

**Marginal IRR contrasts** (posterior `epred` 4,000 draws, expected counts; profile: libe = 0, gender = M, party_family = CDU/conservatives, misery_index & total_questions at sample means, country RE integrated out; CMP steps per ±1 SD = 4.01 raw points):

| contrast | IRR median [95% CrI] | P(IRR > 1) |
|---|---|---|
| Minority IRR \| CMP mean − 1 SD (4.82) | 1.16 [0.21, 4.71] | 0.568 |
| Minority IRR \| CMP sample mean (8.83) | 1.76 [0.68, 3.90] | 0.890 |
| Minority IRR \| CMP mean + 1 SD (12.84) | **2.67 [1.66, 4.31]** | **1.000** |
| CMP +1 SD gradient \| minority MEPs | 1.34 [0.68, 2.99] | 0.780 |
| CMP +1 SD gradient \| non-minority MEPs | 0.88 [0.73, 1.06] | 0.076 |

Reading: the minority-vs-non-minority ratio widens monotonically with CMP — ns at low CMP, credible at the CMP top; minority MEPs gain ≈ +34% discrimination questions per +1 SD CMP while non-minority MEPs lose ≈ −12%. But the interaction *coefficient* itself is not conventionally credible (P(+) = 0.874) — the stratified IRRs are derived descriptors of a ns interaction, not independent evidence.

## 5. Results — M2 (minority + libe, CMP removed, no interaction)

| term | estimate | l-95% | u-95% |
|---|---|---|---|
| minority | **0.935** | **0.476** | **1.402** |
| libe | 0.485 | 0.188 | 0.772 |
| RE SD country / MEP | 0.324 / 0.769 | — | — |
| Diagnostics | max R̂ 1.0084 | 0 divergences | min ESS bulk/tail 941 / 415 (incl. `shape`) |

**Marginal IRR contrasts**: Minority IRR **2.55 [1.61, 4.06]**, P(>1) = 1.000 — identical on and off LIBE **by construction** (no interaction; the 4-row CSV shows the intended equality up to MCMC noise). LIBE boost 1.62 [1.21, 2.16] both among minority and non-minority MEPs.

Nested-model takeaway (M2 ⊂ M1): dropping the CMP moderator entirely **restores** the credible minority effect (0.935 [0.476, 1.402], IRR 2.55); adding CMP (and the ns interaction) pushes the minority main effect to 0.544 [−0.383, 1.362] (≈ −0.39 log points, wider CrI). The minority effect is therefore **confounded with country-level CMP** — minority MEPs sit in systematically higher-CMP countries — while the CMP interaction itself is not supported by the data.

## 6. Cross-model comparison

| Quantity | Archived CMP fit (discarded; 1\|country only, N = 9,850) | M1 CMP interaction (this run) | M2 LIBE-only robustness (this run) | Primary MIPEX-only (27 ctries) |
|---|---|---|---|---|
| minority (main) | 0.498 [−0.330, 1.197] | 0.544 [−0.383, 1.362] | **0.935 [0.476, 1.402]** | 0.835 [0.117, 1.486] |
| minority × moderator | 0.107 [−0.038, 0.275] | 0.109 [−0.067, 0.306] | — (no CMP) | 0.011 [−0.033, 0.058] |
| libe | 0.539 [0.298, 0.767] | 0.500 [0.207, 0.781] | 0.485 [0.188, 0.772] | 0.648 [0.385, 0.912] |
| RE SD country / MEP | 0.454 / — | 0.326 / 0.761 | 0.324 / 0.769 | 0.455 / 0.820 |
| Diagnostics | — | R̂ 1.0055; 0 div. | R̂ 1.0084; 0 div. | R̂ < 1.003; 0 div. |

**Takeaways**: (i) the CMP interaction stays null across RE structures (0.107 archived → 0.109 with MEP RE); (ii) the archived-CI ambiguity from session notes (`[−0.138, 0.254]`) is **resolved in favour of [−0.038, 0.275]** — verified from `output/archive_cmp_23cty_2026-11-12/bayesian_model_results.csv` at memo time; (iii) the CMP moderator is the *only* specification among these four in which the minority main effect loses credibility — evidence of confounding rather than moderation; (iv) `libe` and RE SDs are stable everywhere.

## 7. Caveats and interpretation

1. **Interaction null; IRR grid is descriptive.** `minority × cmp_center` is ns (P(+) = 0.874); the ±1 SD IRR contrast table must be read as a derived description of that null interaction, not as an independent test. No H3-style claim can be made from CMP.
2. **Time-invariant country moderator → between-country identification.** CMP is constant within country; the interaction is identified from cross-country contrasts, absorbed partly by the `(1 | country)` RE. With 13 of 23 countries hosting **zero** minority MEPs, identification leans on 10 countries (FR/UK/DE/SE/NL alone = 261 of 301 minority MEP-years).
3. **Minority–CMP overlap** (median cmp 13.03 vs 7.83; minority rows never below cmp 2.25): minority ≈ a high-CMP indicator in this sample, so M1's minority main effect (an extrapolation *at* the sample mean) and the interaction are jointly poorly identified — the M2-vs-M1 shift (0.935 → 0.544) is confounding, not evidence.
4. **Sample = 23 countries ≠ primary sample.** Comparisons with the primary MIPEX-only fit (27 countries, N = 10,955) mix sample and information-set changes; the LIBE-only comparison (same 23-country sample) is the clean nested reading.
5. **`discrimination_mean` not controlled** (locked with FR, 2026-11-12); same choice as primary, so internal comparisons are unaffected.
6. **libe mediator/`confounder` tension** (documented in `2026-11-12_libe-omission-robustness.md` §1/§8): conditioning on committee assignment along a post-treatment path applies equally to the `libe` control in M1 and main effect in M2 — read as descriptive, not causal.

## 8. What this model is NOT

- It does **not** replace the primary MIPEX-only model in the manuscript, pipeline, or headline narrative; it is an analytical memo + side outputs.
- `run_pipeline.R`, `05_models.R`, `05_models_Bayesian.R`, `05_models_Bayesian_LIBE.R`, `06/07_model_comparison*` and all primary outputs were **not modified** — verified by md5 diff of 20 primary files before/after the run (all match).
- No `minority × libe` interaction exists in either model (per FR).

## 9. Reproduction and outputs

```bash
cd /home/federusso/progetti/EPmigrants
Rscript scripts/05_models_Bayesian_CMP.R   # cold ≈ 30 min (fit ~12.7 + ~12.4 min; cache reload ≈ 2 min/fit when hot)
```

| Output | Content |
|---|---|
| `output/df_model_data_cmp.rds` | estimation sample (asserted N = 9,850; 23 ctries; 51 minority MEPs) |
| `output/bayesian_model_cmp.rds` / `..._libeonly.rds` | brms fit caches (M1 / M2) |
| `output/bayesian_cmp_model_results.csv` / `..._libeonly_model_results.csv` | coefficient tables (fixed + correctly labelled RE SDs + shape) |
| `output/bayesian_cmp_diagnostics.csv` / `..._libeonly_diagnostics.csv` | max R̂ / min ESS / divergences |
| `output/bayesian_cmp_focal_coefficients.csv` / `..._libeonly_focal_coefficients.csv` | draws-based median [CrI], P(+) |
| `output/bayesian_cmp_irr_contrasts.csv` / `..._libeonly_irr_contrasts.csv` | marginal IRR contrasts (§4 / §5) |

**In-session debugging record** (fixed in-script, kept for provenance): (1) first launch failed on glmmTMB `ziNegBin()` (not exported in glmmTMB 1.1.14 → `family = nbinom2, ziformula = ~1`); (2) first IRR step failed on brms `validate_data()` — the epred grid lacked the `libe` control column; (3) ratios were written inverted (den/num) in the first IRR pass — corrected to num/den and verified against `exp(b_minority)` anchors; (4) two mid-run restarts: brms cache (`brm(file = ...)`) made M1/M2 reload in minutes; ⚠ `Rscript` reads scripts progressively by byte offset — **never edit a script while a background `Rscript` run is in progress** (one attempt died on a parse error from exactly this).


