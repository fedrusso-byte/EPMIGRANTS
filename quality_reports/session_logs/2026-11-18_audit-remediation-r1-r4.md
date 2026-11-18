# Session Log — Audit Remediation R1→R2→R3→R4 (2026-11-18, night)

Mode: **Act** — user-approved sequence (plan persisted at
`quality_reports/plans/2026-11-18_audit-remediation-r1-r4.md`).
Scope: audit §9 items 5, 8, 6, 7 + the SKW archive-as-cache hazard;
item 1 (ms editorial) deferred by FR. **No refits, no commits**; the only
pipeline execution was the md5-guarded `04` validation run.

## R1 — seeds + SKW cache decouple (audit item 5)

- `seed = 20260321` added to all **ten** `brm()` call sites: 05B M1/M2,
  SENS M1/M2, SLLM M1/M2, SLLM-R2 M1/M2, SKW M1/M2; `set.seed(20260321)` at
  the top of `06_model_comparison_Bayesian.R` (seeds `posterior_predict`
  resampling) and `06_model_comparison.R` (cosmetic).
- SKW cache decouple: `output/cache_skw_keyword/` populated with `cp -p`
  copies of the archived fits from `output/archive_spec_promotion_2026-11-17/`;
  md5 matched archive = cache = `MANIFEST.md`:
  - m1 `7b0af060487ea09be2389758c1fd9439`
  - m2 `aaebad9a9fedf8e452cf2fd7f0fcb51e`
- SKW header rewritten (scratch-cache rationale + manifest hashes recorded
  in-script); `brm(file=)` at SKW:104/123 → `cache_dir`; `stopifnot` guard on
  the cache dir; immutability addendum appended to `MANIFEST.md`.
- Verification: `parse()` OK ×7 scripts; grep: 2 seed args per fit script,
  `set.seed` at 06B:14/06:14; SKW's only remaining `archive_dir` reference is
  the intentional read-only `readRDS` of the panel.
- Note: SKW already had a top-level `set.seed(20260321)` — doesn't seed Stan
  chain RNGs; the per-call `seed=` was added as planned.

## R2 — hygiene (audit item 8)

- LIBE:290-/TERM:212-/CMP:395- "IDENTICAL 4×2,000" claims replaced with honest
  settings-provenance notes (variants genuinely run 2,000/1,000 — grep-verified
  first; primary moved to 4,000/1,500 at the 2026-11-17 promotion; variants
  refitted to the refined DV today under their own settings).
- Deleted: `scripts/main.R` (0 bytes), `scripts/test_system2.R`, `test.R`,
  `Rplots.pdf`, `PROJECT_INDEX.md:Zone.Identifier`.
- Archived: `scripts/#07_Exploratory analysis.r` →
  `scripts/archive/2026-11-18_07_Exploratory_analysis_legacy_scratch.r`
  (DO-NOT-RUN banner prepended).
- Dead code: `01`:24-28 (dangling `count()/filter()` print chain) removed;
  `02`:13-17 (`check_na`, sole definition, zero callers) removed via `sed`
  (trailing-whitespace-safe). `01`:34-38 duplicate-check was already
  commented out — left as-is (outside audit scope).
- `08_llm_screen.py`: window cross-reference block above `WINDOW_START`
  (doc-only; screen superset ⊃ `01` inclusion ⊃ no-cutoff aggregation;
  2019-07-01 → IX in both layers; constants unchanged). `py_compile` OK.
- `.gitignore`: `Rplots.pdf` + `*:Zone.Identifier` **already present** (the
  pre-execution check was mistaken) → no edit needed.
- Verification: `parse()` OK ×5 (01, 02, LIBE, TERM, CMP); ls confirms all
  deletions + archive move.

## R3 — 04 cache switch + provenance (audit item 6)

- `04:32` → `FORCE_REDOWNLOAD <- identical(Sys.getenv("EP_COVARIATES_FORCE"), "1")`
  (offline-stable default; `EP_COVARIATES_FORCE=1` re-downloads) + comment.
- `# TODO(FR)` provenance stubs: `04`:89ff (UK GDP 2005:2020 injection) and
  `03` ×4 — country_features/cmp_mean, euro_entry_year, populist_in_gov,
  eu_budget_status (data untouched; FR owns the citations).
- `scripts/run_pipeline.R`: `options(repos = c(CRAN = "https://cloud.r-project.org"))`
  inserted before the install fallback (exact-editor match failed on that
  file → `sed` insertion after the Usage anchor).
- **Guarded validation run**: `env -u EP_COVARIATES_FORCE Rscript scripts/04_download_problem_indicators.R`
  → exit 0, "Loading cached covariates", and `output/problem_indicators.csv`
  md5 **byte-identical** to the pre-run baseline `8640be4f5c9bb294b929114d91116e6d`.
- Verification: `parse()` OK ×3 (03, 04, run_pipeline); TODO counts 4 (03) / 1 (04).

## R4 — environment pinning (audit item 7)

- `renv` was not installed → bootstrapped from CRAN (renv 1.3.1, user library).
- `renv::init(bare = TRUE)` → `renv/` skeleton + `.Rprofile` + empty lockfile.
- **Gotcha (recorded)**: the generated `.Rprofile` auto-activates the EMPTY
  project library; a `renv::snapshot()` run inside such a session saw only
  `renv` (lockfile with 1 package + "Packages must first be installed" noise).
- **Fix**: snapshot executed with `Rscript --no-init-file -e 'library(renv);
  renv::snapshot(type="implicit", force=TRUE)'` against the REAL user library
  → **`renv.lock` = 207 packages, R 4.3.3** (brms/Stan stack, tidyverse 2.0.0,
  TMB 1.9.21, WDI 2.7.10, zoo 1.8-15, …).
- Empirical activation test (fresh process): `.libPaths()` = renv/library only,
  `brms` FALSE → full adoption would break every run. Within the approved
  scope ("pin versions, no library install") → `renv::deactivate()` removed
  the autoloader; post-test: user library restored, brms/glmmTMB/tidyverse
  TRUE, lock intact (207). Details in
  `quality_reports/2026-11-18_env-pinning-renv.md`.
- `xlsx` referenced outside `scripts/` but never installed → not locked;
  `zoo` installed and locked.

## End state

- Audit §9: items 5, 8, 6 (data-side closed; FR provenance TODOs open), 7
  (closed as "pinned, not isolated") + SKW cache hazard → **CLOSED**; closure
  notes appended as addendum §12 to
  `quality_reports/2026-11-18_pipeline-scripts-audit.md`.
- Still open: item 1 (ms editorial Appendix-B number refresh; FR defers),
  FR-owned provenance TODOs, git commit decision (parked).

## Operational notes

- `read_files` stale-cache issue persists in this repo → prefer shell
  `sed`/`grep` for verification after edits.
- Long/complex shell chains intermittently lose terminal output capture here;
  use short standalone commands for state checks.
- Terminal commands emit exit-code heuristics that can hide success — always
  verify effects by re-reading state (lockfile counts, md5s, `ls`), as done above.
