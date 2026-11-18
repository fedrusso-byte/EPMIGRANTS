# Session log — 2026-11-17 (evening): DV re-operationalization promoted to primary specification

Scope: execution of the approved plan (LLM-refined R2 DV → primary; keyword DV → Appendix B). Mode: act (approved).

## Timeline
1. **Archive (pre-promotion)** — `output/archive_spec_promotion_2026-11-17/`: `df_model_data.rds`, `bayesian_model_results.csv`, `bayesian_model_m1_total.rds`, `bayesian_model_m2_direct.rds` copied with `MANIFEST.md` incl. md5 (`24c05660…`, `315f631a…`, `7b0af060…`, `aaebad9a…`).
2. **Script restructure**
   - `scripts/05_models.R`: §1b R2 overlay (verbatim from `05_models_Bayesian_sens_llm_R2.R` §0–3; `lubridate::` namespaced) after the `mipex_center` mutate; keyword counts kept as `pqs_discrimination_keyword`; §2a promotion-equivalence asserts + surfacing audit + protocol-tail note after the panel write. Fixed one rename/select bug caught on review (`select(-pqs_discrimination_r2)` after simultaneous rename).
   - `scripts/05_models_Bayesian.R`: header rewrite (primary = refined DV; pointers), `pqs_discrimination_keyword` added to the column assert, M1 raised 2000/1000 → 4000/1500, M2-era note updated.
   - `scripts/05_models_Bayesian_sens_keyword.R` NEW (appendix restore-fit script); banners added to the three sens scripts.
3. **Run `05_models.R`** (log `output/runlog_05_models_promotion.log`): overlay asserts PASSED (1,319 → 784, Δ −535; VII/VIII/IX 378/301/105), panel N 10,955, equivalence asserts PASSED (739 refined / 1,244 keyword), surfacing audits 498/527 and 241/254, protocol tail 1. 4 frequentist ZINB refits on the refined DV; coefficient table regenerated (minority IRR ≈ 4.4–4.7, M4 interaction −0.007 ns).
4. **Background refits**: stale primary caches deleted (archived); `05_models_Bayesian.R` launched 00:14, M1+M2 completed 01:01–01:02 (log `output/runlog_bayes_promotion.log`). `05_models_Bayesian_sens_keyword.R` completed 00:25 (restores of archived fits; no refit; log `output/runlog_senskw_promotion.log`).
5. **Gates**: primary M1 Rhat 1.0029 / ESS 0.226 / 0 div; M2 1.003 / 0.237 / 0 div; keyword M1 1.0074 / 0.173 / 0; M2 1.0036 / 0.226 / 0 → gate ×4 PASSED.
6. **Drift gate**: `scripts/utils/verify_promotion_drift.R` — max |Δ| estimates 0.0096; endpoints ≤ 0.028 (MC noise); no sign/credibility flips. PASSED.
7. **Canonical tables**: `scripts/utils/make_table1_promotion.R` → `output/table1_canonical.md` (canonical refined) and `output/tableB1_keyword.md` (keyword = archived fits reproduced exactly). Manuscript Table 1 + all inline §5 numbers re-sourced from the canonical CSV.
8. **06 + 07 re-runs**: `07_extract_all_coefficients.R` OK (unified tables refreshed); `06_model_comparison_Bayesian.R` OK (figure regenerated on the new M1 fit).
9. **Manuscript** (`paper/MEPArticle_12_11_2026.md`): abstract; §4 DV definition + validation paragraph (784; 378/301/105; ≈0.6%; 143/129/54 MEPs; LLM-refined protocol narrative); model settings paragraph; H1/H2/H3/LIBE/RWN/gender/summary numbers; robustness restructure; conclusion (3 passages + limitation 1 + contribution 3); new Appendix B (text + Table B1 from archived fits).
10. **Bookkeeping**: TO_DO.txt dated entry; memo `quality_reports/2026-11-17_spec-promotion-refined-dv.md`; memory entry. No commit (none requested).

## Key runtime facts
- Frequentist stage ~26 min; primary Bayesian refits ~47 min total (M1 00:14→00:31, M2 00:31→01:01); keyword appendix restore-run ~12 min.
- Stale outputs left untouched: `bayesian_sensllm_r2_model_results.csv`, `bayesian_sensllm_r2_vs_primary.csv`, keyword-era `runlog_*.log` files, and all R1/R2 sens artifacts (frozen derivation record).

## Open items
- TERM/LIBE/CMP/FE sens scripts still keyword-DV (follow-ups, not blockers).
- No commit performed.
