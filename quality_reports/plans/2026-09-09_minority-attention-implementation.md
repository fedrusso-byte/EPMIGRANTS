# Implementation Plan — 7th-Term Extension and H3 Theory Revision

**Created:** 2026-09-09
**Status:** ACTIVE — Phase A (hand-coding), Phase B (merge), and the VII–IX refit (Phase C) executed 2026-11-05 (see `TO_DO.txt` §1–3); H3 theory (Zeynep) and Phase D (manuscript, project docs) in progress.
**Owners:** Zeynep Mentesoglu Tardivo (coding, H3 theory); Federico Russo (analyses); Cline (drafting, automation, reports)
**Related:** research specification (`quality_reports/research_spec_minority_attention.md`); next steps plan (`quality_reports/plans/2026-09-09_minority-attention-next-steps.md`); SISP memo (`quality_reports/2026-09-09_sisp-feedback.md`)

---

## 1. Objective and Deliverables

1. Hand-coded minority background for all 468 7th-term MEPs, merged into the master file
   `data_raw/minority.csv`.
2. Strengthened H3 theoretical framework responding to SISP 2026 feedback.
3. Re-estimated models on the 7th–9th terms; updated manuscript, results report, and project docs.

## 2. Data Pipeline Map (reference)

```
01_import_questions.R → 02_df_setup.R → 03_country_level_vars.R → 04_download_problem_indicators.R
  → 05_models_Bayesian.R (Bayesian ZINB; `run_pipeline.R` default) → 06_model_comparison_Bayesian.R
Standalone: 07_extract_all_coefficients.R (reloads saved fits from output/);
           05_models.R (glmmTMB), 05_models_FE.R (robustness variants)
Orchestrator: scripts/run_pipeline.R — pipeline_config: model_version = "Bayesian", comparison_version = "Bayesian"
Key inputs: output/df_merged_3.csv, output/problem_indicators.csv; term filter at 05_models_Bayesian.R ~line 51
```

## 3. Phase A — Hand-Coding the 7th Term (owner: Zeynep)

**Input:** `data/minorities7th_tocode.xlsx` (identical `.csv` available) — 468 MEPs with
biographical info, national party, group, and committee; empty `minority`, `notes`, `link` columns
in the same format as `minorities8th9th.csv`. Worksheet generator:
`scripts/utils/minority_coding_worksheet_6th7th.R` (re-runnable if the roster changes).

**Operationalisation (identical to the 8th/9th-term coding):** `minority = 1` for a migratory or
racialised minority background — first- or second-generation migrant originating from a non-EU
country outside the Global North; Roma MEPs included; otherwise `0`. The European Parliament
collects no systematic ethnicity data and place of birth is an incomplete proxy, so coding rests on
biographical research across public sources.

**Acceptance criteria:**
- [x] All 468 rows carry a non-blank `minority` value (0 or 1).
- [ ] Every `minority = 1` row carries a `link` to an evidencing source (EP bio, reliable press,
      academic/NGO material) plus a `notes` entry.
- [ ] Rows whose national-party values were blanked (NA) in the worksheet because of suspect
      upstream data are not used as coding evidence.
- [x] The completed worksheet is returned as `.csv` (xlsx accepted; it will be exported to csv
      before merging — csv is the canonical merge format).

## 4. Parallel Workstream — H3 Theory Revision (owner: Zeynep)

**Inputs (in order):**
1. SISP 2026 feedback — complete `quality_reports/2026-09-09_sisp-feedback.md` first.
2. The current conditional-effects discussion in the theory section of `paper/MEPArticle_Updated.md`.
3. The candidate-directions menu in the research specification (§7).

**Deliverables:**
- [ ] Revised H3 theory section: explicit resource + interpretive mechanisms, a competing
      substitution expectation, and pre-stated observable implications (interaction sign; marginal
      effects of `minority` across the MIPEX range).
- [ ] New references collected for `ep.bib` (currently unpopulated).

## 5. Phase B — Merge and Data Reconciliation (owner: Federico, Cline-assisted)

Cline prepares the merge script and verification checks; Federico reviews and applies.

> Executed 2026-11-05: master 1,299 → 1,770 rows; zero VII-overlap verified (10 repeat MEPs inherit their VIII/IX coding — see `TO_DO.txt` §1).

- [x] Convert `minorities8th9th.csv` from Latin-1/Windows encoding to UTF-8.
- [x] Append Zeynep's 468 codings to `data_raw/minority.csv` (master), keyed by `mep_id`, with
      `minority` / `notes` / `link` matching the master format.
- [x] Add the 3 hand-coded MEPs missing from the master despite being coded in
      `minorities8th9th.csv` (`minority = 1`): Max ORVILLE (234344, FRA), Guy LAVOCAT (251859, FRA),
      Leopoldo LÓPEZ GIL (197777, SPA).
- [x] Verification: anti-join check that no 7th-term MEP in the panel lacks a minority coding;
      report row counts before/after.
- [ ] Upstream sync: fix mis-aligned `national_parties` for ~53 MEPs (6th term) in the `euquest`
      repository's `data_raw/meps.csv`.

## 6. Phase C — Analysis Widening (owner: Federico; Cline preps)

- [x] Cline: widen the term filter at `scripts/05_models_Bayesian.R` (~line 51) from
      `c("8th", "9th")` to `c("7th", "8th", "9th")`.
- [x] Cline/Federico: archive the cached fits (`output/bayesian_model_cmp.*`,
      `output/bayesian_model_mipex.*`). `brms` silently reloads existing `file =` fits, so stale
      8th/9th-term results would otherwise be reused.
- [x] Federico: run `Rscript scripts/run_pipeline.R` (config: Bayesian); check convergence
      (R-hat ≈ 1.00, effective sample sizes) and posterior predictive behaviour.
- [x] Federico: re-run `scripts/07_extract_all_coefficients.R` to regenerate the unified
      coefficient tables.
- [ ] Federico + Cline: interpret — H1–H3 with the enlarged sample; marginal effects of `minority`
      across the observed MIPEX range; sensitivity checks (DV variants; §8 decisions).

## 7. Phase D — Reporting (Cline drafts; both authors review)

- [x] Update `quality_reports/bayesian_model_results_report.md` with the new estimates.
- [ ] Manuscript (`paper/MEPArticle_Updated.md`): data/sample section (add the 7th term), findings
      and Table 1, limitations (drop the "only 8th/9th legislatures" caveat), and integrate Zeynep's
      revised H3 theory section.
- [ ] Update `PROJECT_INDEX.md` statuses and `TO_DO.txt` after each phase.

## 8. Open Technical Decisions (gating)

| # | Decision | Owner | Blocks |
|---|---|---|---|
| 1 | Primary specification: Bayesian `brms` vs frequentist `glmmTMB` | Federico | Phase C interpretation |
| 2 | Random-intercept reconciliation: manuscript states a per-MEP intercept; `05_models_Bayesian.R` has `(1 | country)` only | Federico (+ Cline) | Phase C |
| 3 | M1/M3 NaN SEs in `05_models.R`: `nlminb` / simplify random effects / Bayesian-primary | Federico | Robustness suite |
| 4 | 6th-term scope: MIPEX starts 2007 (2007+ restriction or exclusion) | Both | Optional extension |

## 9. Risks and Mitigations

| Risk | Mitigation |
|---|---|
| Coder drift between the 8th/9th and 7th codings | Same operational rules (§3); Cline runs a consistency spot-check on a random sample plus the 218 MEPs overlapping the 6th/7th worksheets |
| Stale `brms` cached fits silently reused | Archive fits before re-running (Phase C) |
| Longer runtimes with the larger sample | Run via `run_pipeline.R` in stages; fits cached to `output/` |
| Few new `minority = 1` MEPs in the 7th term → limited power gain | Document; the extension mainly improves precision and temporal coverage |
| SISP feedback recall fading | Fill `quality_reports/2026-09-09_sisp-feedback.md` as the first theory-revision step |