# Next Steps Plan — Minority Attention Subproject

**Created:** 2026-09-09
**Status:** CURRENT — roadmap for the 7th-term extension + H3 theory revision cycle. Coding, merge, and the VII–IX refit executed 2026-11-05 (see `TO_DO.txt`); roadmap statuses below updated accordingly.
**Owners:** Zeynep Mentesoglu Tardivo (coding, H3 theory); Federico Russo (analyses); Cline (drafting, automation, reports)
**Related:** research specification (`quality_reports/research_spec_minority_attention.md`); implementation plan (`quality_reports/plans/2026-09-09_minority-attention-implementation.md`); SISP memo (`quality_reports/2026-09-09_sisp-feedback.md`)

---

## 1. Roadmap

| Priority | Step | Owner | Status |
|---|---|---|---|
| **Now** | Send the 7th-term worksheet (`data/minorities7th_tocode.xlsx` or `.csv`) to Zeynep | Federico | Done 2026-10-14 |
| **Now** | Record SISP 2026 discussant feedback in `quality_reports/2026-09-09_sisp-feedback.md` | Federico / Zeynep | Done 2026-09-09 |
| **Now** | Hand-code the 468 7th-term MEPs ‖ revise the H3 theory section (spec §7 menu) | Zeynep | Coding done 2026-10-14; theory in progress |
| **Now** | Decide: primary specification (Bayesian vs glmmTMB); random-intercept reconciliation (manuscript says per-MEP intercept, `05_models_Bayesian.R` has `(1 | country)` only); M1/M3 NaN handling in `05_models.R` | Federico (+ Cline) | Partially — Bayesian confirmed as refit spec (2026-11-05); M1/M4 NaN-SE still open (`TO_DO.txt` §2) |
| **Now** | Draft the paper outline (last PENDING research-design document) | Cline | To do |
| **Now** | Populate `ep.bib` with current + new (H3) references | Cline / Zeynep | To do |
| **Next** | Merge coding into `data_raw/minority.csv`; Latin-1 → UTF-8; add 3 missing MEPs (Orville 234344, Lavocat 251859, López Gil 197777); euquest sync | Cline prepares → Federico reviews | Merge done 2026-11-05; euquest sync still open |
| **Next** | Widen term filter in `scripts/05_models_Bayesian.R` (~line 51); archive cached `brms` fits; re-run pipeline (7th–9th) | Cline preps → Federico runs | Done 2026-11-05 (N = 9,850; fits archived in `output/archive_8th9th/`) |
| **Next** | Update results report + manuscript (numbers, sample, limitations, revised H3 section) | Cline drafts → authors review | Partially — results report (`.md` + `.html`) updated 2026-11-05; ms pending (numbers memo §1) |
| **Later** | 6th-term extension (749 MEPs; MIPEX starts 2007 → 2007+ restriction or exclusion; 218 overlapping MEPs reusable) | Both | Backlog |
| **Later** | Upstream fix: `national_parties` misalignment (~53 MEPs) in euquest `meps.csv` | Federico / Cline | Backlog |
| **Later** | Textual analysis of CAP 201 questions (protective vs oppositional framing) | Both | Backlog |
| **Later** | COMEPELDA electoral-systems integration (Harvard Dataverse doi:10.7910/DVN/GNRMTO) | Federico | Backlog |
| **Later** | Target-journal selection and submission package | Both | Backlog |

## 2. Definition of Done (this cycle)

- All 468 7th-term MEPs coded and merged into `data_raw/minority.csv`; anti-join verification clean.
- H3 theory section revised and integrated into `paper/MEPArticle_Updated.md`; SISP memo completed.
- Pipeline re-run on the 7th–9th terms with archived stale fits; results report and manuscript updated.
- `PROJECT_INDEX.md` and `TO_DO.txt` reflect the new state.

## 3. Standing Conventions

- R analyses run through `scripts/run_pipeline.R` (renv-activated environment when `renv.lock` present).
- Plans live in `quality_reports/plans/` (date-prefixed); session logs in `quality_reports/session_logs/`.
- Status vocabulary per `PROJECT_INDEX.md`: DONE / CURRENT / OUTDATED / NEEDS INPUT / PENDING / DRAFT.
- Decisions above are recorded in the research specification (§10) and implementation plan (§8).