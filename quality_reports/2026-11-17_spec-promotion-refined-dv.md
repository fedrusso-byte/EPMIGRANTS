# DV Re-Operationalization Promoted to Primary Specification (2026-11-17, evening)

## 1. Decision and scope
- FR's locked disposition of 2026-11-17 afternoon: **"A: refined operativa"** — the LLM-refined operationalization becomes the **primary dependent variable**; the keyword-based measure is demoted to a robustness check (manuscript Appendix B).
- Pure **DV-definition promotion**: estimation panel untouched (10,955 MEP-year rows; keys and `total_questions` asserted identical to the pre-promotion panel). Sampling settings for both primary fits raised to `iter = 4000 / warmup = 1500`.

## 2. DV definition (primary)
- Question level: `pq_R2 = 1` iff id ∈ (refined retained-DV **529** = 524 refined-rubric kept-DV INs + 5 FR force-keeps ∪ FR verified-INs **255**) ⇒ **784** question-level events in-window (VII 378 / VIII 301 / IX 105) = 1,319 keyword kept-DV events − 535 refined/arbitrated-OUT + 255 verified-INs.
- Keywords: former counts retained as `pqs_discrimination_keyword` in `output/df_model_data.rds`; keyword measure = 1,319 events (1,244 in-sample; MEPs ≥1 221/214/113).
- Benchmarks on the arbitrated gold-334: precision ≈ .90 (refined) vs ≈ .74 (keyword); recall ≈ .80 vs .81.

## 3. Pipeline changes
| File | Change |
| :--- | :--- |
| `scripts/05_models.R` | §1b overlay inserted (lists, asserts, window asserts 1,319/784/Δ−535, MEP-year re-aggregation mirroring `02_df_setup.R`, keyword column renamed to `pqs_discrimination_keyword`); §2a promotion-equivalence asserts (row set ≡ `df_model_data_sensllm_r2.rds` ≡ archived keyword panel; DV/`total_questions` equality; 739/1,244 event asserts) + surfacing audit re-run (498/527 refined; 241/254 verified; 1 protocol-tail E-000739/2024). |
| `scripts/05_models_Bayesian.R` | Header rewritten (primary = refined DV); M1 raised to 4000/1500 (M2 unchanged); keyword column asserted present; pointers to Appendix-B script and archives. |
| `scripts/05_models_Bayesian_sens_keyword.R` | **New**: Appendix-B reference fits — reads the archived keyword panel and re-attaches the archived `brm(file=)` caches (restore, no refit); writes `output/bayesian_senskw_model_results.csv` with `M1_keyword`/`M2_keyword` labels. |
| `scripts/05_models_Bayesian_sens_llm_R2.R` / `_sens_llm.R` / `_sens.R` | Banners only (R2 = frozen derivation record of the promoted measure; R1 + keyword-extension = keyword-layer variants). |
| `scripts/utils/make_table1_promotion.R` | **New**: builds manuscript Table 1 (refined) and Table B1 (keyword) markdown from a two-estimand results CSV; used to source every ms table value from the canonical CSV. |
| `scripts/utils/verify_promotion_drift.R` | **New**: canonical-vs-R2-derivation drift gate. |
| `output/archive_spec_promotion_2026-11-17/` | Pre-promotion keyword-DV primary artifacts (panel + both fit caches + results CSV) with `MANIFEST.md` + md5. |
| `run_pipeline.R` | Unchanged (order 05_models → 05_Bayesian → 06 → 07 preserved). |

## 5. Numbers map (old keyword → new refined primary)
| Quantity | Keyword (old ms / Appendix B) | Refined (new primary) |
| :--- | :--- | :--- |
| Minority (M1 / M2) | 0.896 [0.201, 1.569] / 0.882 [0.204, 1.529]; 2.45× / 2.42× | **1.543 [0.760, 2.297] / 1.525 [0.756, 2.246]; 4.7× / 4.6×** |
| LIBE (M2) | 0.642 [0.389, 0.898] (~90%) | **0.704 [0.341, 1.056] (~102%)** |
| MIPEX (M1 / M2) | 0.006 / 0.005 (ns) | 0.012 [−0.001, 0.024] / 0.011 [−0.002, 0.023] (ns; borderline lo) |
| Minority × MIPEX | 0.018 / 0.009 (ns, both positive) | 0.005 / −0.003 (ns; **sign not stable across specifications**) |
| RWN | 0.398 [0.016, 0.774] / 0.414 [0.039, 0.786] (credible; ~49–51%) | 0.461 [−0.092, 1.002] / 0.492 [−0.066, 1.030] (positive but imprecise) |
| Gender | −0.103 / −0.066 (ns) | −0.160 [−0.422, 0.102] / −0.108 [−0.356, 0.151] (ns) |
| SD (country / MEP) | 0.458 / 0.841 | 0.441 [0.225, 0.709] / 1.122 [0.966, 1.289] |
| Party families | The Left 0.180 (ns) | The Left 0.880; broader credible set (Greens 0.818; NI 0.627; SocDem 0.756; Eurosceptics 0.990) |
| DV descriptives | 1,319 events (608/482/229), ≈1.1%; MEPs ≥1 (in-sample) 221/214/113 | 784 events (378/301/105), ≈0.6%; MEPs ≥1 143/129/54 |

## 6. Manuscript regions changed (`paper/MEPArticle_12_11_2026.md`)
1. Abstract — interaction-sign claim corrected (not robust in sign); RWN reframed (positive, imprecise; credible under conservative measure).
2. §3 — unchanged in substance (data description pre-dates the DV change; no stale numbers found by sweep).
3. §4 DV definition — 784 (378/301/105), ≈0.6%, 143/129/54 MEPs; validation paragraph fully rewritten (LLM-refined protocol, adjudication, gold-334 benchmarks, composition 529 + 255; keyword → Appendix B).
4. §4 model paragraph — explicit priors (Student-t(3, 0, 2.5) on b and zi; brms defaults for SDs) and sampling settings (4 chains × 4,000, warm-up 1,500).
5. §5 — H1 (1.543/1.525; 4.7×/4.6×), H2 (borderline ns), H3 (sign-inconsistent → no support), LIBE (0.704; ~2×), RWN (reframed honestly + Appendix B citation), gender, summary row.
6. Table 1 — regenerated from the canonical CSV (`bayesian_model_results.csv`); note updated (identical settings in both fits).
7. Robustness — restructured: LIBE check (canonical numbers) + keyword-DV check (0.896/0.882, Appendix B Table B1) + two keyword-layer variants (183 extra-EU removals: 0.967/0.949; R1 additive verified-INs: 0.900/0.880).
8. Conclusion — clearest-result + policy-feedback paragraphs updated (no sign-stable interaction); RWN paragraph reframed; limitation 1 re-anchored to the verified measure; contribution 3 mentions the DV validation strategy.
9. **Appendix B (new)** — keyword measure construction, benchmarks, Table B1 (= archived fits reproduced exactly), notes and interpretation (RWN credible under keyword; interaction positive there but ns).

## 7. Honest-reporting notes
- "Measurement precision" (≈.90 vs .74) must not be conflated with estimate precision: with 739 in-sample events the intervals are wider than under the keyword measure, and the minority IRR point estimate is ~4.7× with a wide CrI.
- H2 remains marginal: point estimate 0.012 with lower bound −0.001/−0.002 — described as "not credibly different from zero", no upgrade to "supported".
- RWN: positive-but-imprecise in the refined model; credibility only under the conservative keyword measure (Appendix B). No strengthened claim in the main text.
- The keyword interaction was positive-ns in both specifications; the refined one flips sign (ns) — flagged in Appendix B to avoid over-claiming stability.

## 8. Follow-ups (non-blocking)
- TERM / LIBE / CMP / FE alternative-model scripts still key off the keyword DV: update or re-run if sensitivity to the refined DV is wanted for those specifications.
- Optional: regenerate `bayesian_sensllm_r2_vs_primary.csv` against the new canonical CSV for the record.
- No git commit made (none requested).

## 4. Verification
- **Equivalence asserts (05_models.R)**: PASSED — panel `10,955` rows; in-sample events 739 (refined) / 1,244 (keyword); refined DV, `total_questions`, and keyword DV equal the R2-derivation / archived keyword panels term-by-term.
- **Convergence gate (M4 gate on all four fits)**: PASSED ×4 — primary M1_total: max Rhat 1.0029, min ESS ratio 0.226, 0 divergences; primary M2_direct: 1.003 / 0.237 / 0; keyword restore M1_keyword: 1.0074 / 0.173 / 0; M2_keyword: 1.0036 / 0.226 / 0.
- **Drift gate (canonical vs R2-derived fits)**: PASSED — max |Δ| estimate 0.0096, interval endpoints ≤ 0.028 (Monte-Carlo wobble between independent chains; no sign or credibility flips). Canonical CSV: `output/bayesian_model_results.csv` (regenerated 2026-11-18 01:01).
- 06 (`06_model_comparison_Bayesian.R`) re-run on the new M1 fit (figure regenerated); 07 re-run (unified coefficient tables refreshed on the refined fits + keyword appendix CSV in place).
