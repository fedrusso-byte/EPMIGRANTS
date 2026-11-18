# Audit Plan — EPmigrants Pipeline Scripts (2026-11-18)

**Author:** Cline audit session for Federico Russo
**Scope (approved in plan mode):** Core pipeline + 05 Bayesian variants + pipeline-relevant utils.
**Mode:** Read-only audit. No pipeline re-runs, no model refits, no downloads; no code edits (fixes are proposed, not applied).

## Objectives

Audit all scripts composing the analysis pipeline for **correctness, cross-script consistency, robustness, reproducibility**, with priority on cross-script consistency after the **2026-11-17 DV promotion** (LLM-refined R2 DV promoted to primary; keyword DV demoted to Appendix B).

## In-scope files

| Tier | Files | Lines |
| :-- | :-- | :-- |
| Core | `run_pipeline.R`, `01_import_questions.R`, `02_df_setup.R`, `03_country_level_vars.R`, `04_download_problem_indicators.R`, `05_models.R`, `05_models_Bayesian.R`, `06_model_comparison.R`, `06_model_comparison_Bayesian.R`, `07_extract_all_coefficients.R`, `08_llm_screen.py` | ~2,880 |
| Variants (consistency-focused) | `05_models_Bayesian_{CMP, LIBE, TERM, FE, sens, sens_llm, sens_llm_R2, sens_keyword}.R` | ~2,957 |
| Pipeline utils | `make_table1_promotion.R`, `verify_promotion_drift.R`, `build_dv201_review_batches.R`, `update_dv201_decisions.R`, `run_dv201_phase2.sh`, `archive_pre_dv201_rerun.sh` | ~590 |

**Out of scope:** re-running models; manuscript-number checks; coding-workflow utils (dictionaries, minority-coding worksheets); applying fixes.

## Candidate risks to verify (from exploration)

1. DV-promotion consistency: §1b overlay in `05_models.R` vs frozen derivation `05_models_Bayesian_sens_llm_R2.R`; `rm()` housekeeping list; `sens_keyword.R` archive-restore logic; md5 manifests; whether current `output/bayesian_model_m*.rds` are refined-DV fits (`brm(file=)` cache-by-path hazard).
2. `04`: `FORCE_REDOWNLOAD <- TRUE` hardcoded → cache branch dead code; live Eurostat/WDI dependency each run.
3. No `renv.lock` / `.Rprofile` / `renv/`; `install.packages()` inside pipeline scripts → environment not pinned.
4. `07` §7: `interaction_summary` p.value-based interpretation likely mislabels Bayesian rows ("Null").
5. Window-constant drift: `08_llm_screen.py` (2009-07-01…2024-08-01 excl.) vs R term windows (2009-07-14…2024-07-15) vs 02 aggregation window (2024-06-08 corpus end).
6. `03`: hardcoded `country_features` (discrimination_mean, cmp_mean) — provenance concern.
7. Both `06` scripts' prediction grids: `gender = "M"`, party-family level, `libe = 0` — verify vs actual factor levels.
8. Duplicated code: `convergence_gate()` copies; country/name maps across 01–03.
9. Stale files: `scripts/main.R` (0 B), `scripts/#07_Exploratory analysis.r`, `scripts/test_system2.R`, root `test.R`, `Rplots.pdf`, `PROJECT_INDEX.md:Zone.Identifier`.
10. Style: mixed `|>`/`%>%`, `rm(list = ls())`, seeds (20260321) parity.

## Method

1. Parse/syntax checks on all in-scope `.R` (read-only) + `py_compile` on `08_llm_screen.py`.
2. Full close-read of every in-scope script with line numbers.
3. Read-only artifact checks: `md5` manifests of `output/archive_*/`, existence of promoted outputs, file contracts (writes vs reads downstream).
4. Cross-script consistency matrix: DV definitions, panel keys, term windows, formulas/priors parity, seeds, sample filters.
5. Confirm/dismiss each candidate risk with file:line evidence; severity 🔴/🟡/🟢.
6. Report → `quality_reports/2026-11-18_pipeline-scripts-audit.md` (`.clinerules` §10 structure + per-script sections + consistency matrix + prioritized remediation).
