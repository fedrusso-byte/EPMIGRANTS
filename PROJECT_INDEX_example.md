# EUQuest — Responsiveness Paper: Project Index

**Last updated:** 2026-04-22
**Paper:** "Whose Voice? Issue Responsiveness to National and European Publics in the European Parliament (2003 – 2024)"
**Authors:** Marcello Carammia, Stefano M. Iacus, Federico Russo
**Spinoff project:** "Questioning Migration" (single-author, Marcello only) – see Section 11.

---

## Quick Reference

| Status | Meaning |
|--------|---------|
| DONE | Complete, no action needed |
| CURRENT | Up to date, reflects latest results |
| OUTDATED | Exists but needs updating |
| NEEDS INPUT | Requires decision or input from authors |
| PENDING | Blocked on external data or decision |
| DRAFT | Work in progress |

---

## 1. Research Design

| Document | Location | Status | Action Needed |
|----------|----------|--------|---------------|
| Research specification | `quality_reports/research_spec_responsiveness_europeanisation.md` | CURRENT | Updated 2026-03-28 with empirical findings. Review with Federico. |
| **Paper outline** | `quality_reports/paper_outline.md` | DRAFT | Standalone outline with lit review integration. Depends on research spec (2026-03-28). |
| **Post-seminar feedback synthesis** | `quality_reports/2026-04-21_post-seminar-feedback.md` (+ `.pdf`) | CURRENT | Tokyo + EUI Q&A captured, themes triaged, paper-vs-book split. PDF ready to share with Federico. |
| Implementation plan | `quality_reports/plans/2026-03-27_responsiveness-implementation.md` | DONE | Executed. |
| Next steps plan | `quality_reports/plans/2026-03-29_responsiveness-next-steps.md` | CURRENT | Active roadmap (now superseded for paper-scope additions by the post-seminar feedback memo). |
| Responsiveness approach (design note) | `quality_reports/plans/2026-03-20_responsiveness-analysis-approach.md` | DONE | Superseded by implementation. |
| Spin-off ideas | `quality_reports/plans/2026-03-24_responsiveness-ideas-from-spinoff.md` | DONE | Reference for techniques. |
| Tokyo presentation plan | `quality_reports/plans/2026-04-19_tokyo-presentation.md` | DONE | Original 18-slide outline; deck delivered 2026-04-21. |
| Tokyo revisions plan | `quality_reports/plans/2026-04-20_tokyo-revisions.md` | DONE | 16-item revision list; merged via PR #34. |

## 2. Data Pipeline Scripts

| Script | Location | Status | Action Needed |
|--------|----------|--------|---------------|
| 01–05 (original pipeline) | `scripts/R/01_*.R` – `05_*.R` | DONE | Unchanged. |
| 06 Data preparation | `scripts/R/06_responsiveness_data.R` | CURRENT | Reviewed, all issues fixed. Electoral system stub awaits COMEPELDA. |
| 07 Descriptives | `scripts/R/07_responsiveness_descriptives.R` | CURRENT | Reviewed, all issues fixed. Link 1 models fitted but not yet in EDA. |
| 08 Models | `scripts/R/08_responsiveness_models.R` | CURRENT | Reviewed, restructured for memory. 5/6 models fitted (m4 awaits electoral data). |
| 09 Report script | `scripts/R/09_responsiveness_report.R` | OUTDATED | Generates figures from pre-fix data. Update or remove. |
| Pipeline orchestrator | `scripts/R/run_pipeline.R` | CURRENT | Steps 6-8 added. |
| Shared utilities | `scripts/R/utils/cap_issue_mapping.R` | CURRENT | `assign_issue_name()` and `add_committee_match()`. |
| Problem indicators | `scripts/R/download_problem_indicators.R` | DONE | Run once; output cached. |

## 3. Explorations

| Document | Location | Status | Action Needed |
|----------|----------|--------|---------------|
| **EDA report (QMD)** | `explorations/responsiveness/responsiveness_eda.qmd` | CURRENT | Main analytical document. Share with Federico. |
| **EDA report (HTML)** | `explorations/responsiveness/responsiveness_eda.html` | CURRENT | Self-contained, 5 MB. Re-render after any QMD changes. |
| Year FE comparison | `explorations/responsiveness/year_fe_comparison.R` | DONE | Concluded: keep semester FE. |
| Economy puzzle + M5 slopes | `explorations/responsiveness/economy_puzzle_and_m5_slopes.R` | DONE | Results integrated into EDA. |
| Time series + scatter plots | `explorations/responsiveness/responsiveness_timeseries.R` | CURRENT | Re-run if panel data changes. |

## 4. Literature Reviews

| Review | Location | Status | Action Needed |
|--------|----------|--------|---------------|
| Agenda responsiveness | `quality_reports/lit_review_agenda_responsiveness.md` | DONE | 22 papers. Some BibTeX entries need VERIFY. |
| Political representation | `quality_reports/lit_review_political_representation.md` | DONE | 18 papers. Some BibTeX entries need VERIFY. |
| MEP representation | `quality_reports/lit_review_mep_representation.md` | DONE | 27+ papers. Some BibTeX entries need VERIFY. |
| EP parliamentary questions | `quality_reports/lit_review_ep_parliamentary_questions.md` | DONE | 17 papers. Some BibTeX entries need VERIFY. |
| Migration representation | `quality_reports/lit_review_migration_representation.md` | DONE | 22 papers. Some BibTeX entries need VERIFY. |

**Across all reviews:** ~89 new BibTeX entries to be verified and added to `ep.bib`.

## 5. R Code Reviews

| Review | Location | Status | Action Needed |
|--------|----------|--------|---------------|
| 06 review | `quality_reports/06_responsiveness_data_r_review.md` | DONE | All issues fixed (6 Critical, 4 High, 5 Medium, 3 Low). |
| 07 review | `quality_reports/07_responsiveness_descriptives_r_review.md` | DONE | All issues fixed (1 Critical, 3 High, 6 Medium, 3 Low). |
| 08 review | `quality_reports/08_responsiveness_models_r_review.md` | DONE | All issues fixed (2 Critical, 5 High, 7 Medium, 4 Low). |

## 6. Model Outputs

| Output | Location | Status | Notes |
|--------|----------|--------|-------|
| Responsiveness panel | `output/responsiveness_panel.rds` | CURRENT | 359K rows, 173K with MIP. |
| CAP-MIP crosswalk | `output/cap_mip_crosswalk.csv` / `.rds` | CURRENT | 19 MIP → 13 CAP. |
| MIP decomposed | `output/mip_decomposed.rds` | CURRENT | EU-mean + deviation. |
| Europeanisation CV | `output/europeanisation_cv.rds` | CURRENT | By issue-semester. |
| Congruence | `output/resp_congruence.rds` | CURRENT | Sigelman-Buell by country-semester. |
| Link 1 models | `output/resp_link1_models.rds` | CURRENT | Economy + migration. |
| Model m0 (baseline) | `output/resp_model_0_baseline.rds` | CURRENT | 173K rows. |
| Model m1 (+problems) | `output/resp_model_1_problems.rds` | CURRENT | 173K rows. |
| Model m2 (decomposition) | `output/resp_model_2_decomposition.rds` | CURRENT | Core H1/H2 test. |
| Model m3 (domain) | `output/resp_model_3_domain.rds` | CURRENT | H3 test. |
| Model m5 (full) | `output/resp_model_5_full.rds` | CURRENT | Random slopes + Mundlak. |
| Model comparison | `output/resp_model_comparison.rds` | CURRENT | AIC/BIC table. |
| Variance decomposition | `output/resp_vc_comparison.rds` | CURRENT | All models. |
| IRR tables | `output/resp_irr_tables.rds` | CURRENT | All models. |
| Domain trends | `output/resp_domain_trends.rds` | CURRENT | emtrends for m3. |
| M5 issue slopes | `output/resp_m5_issue_slopes.rds` | CURRENT | Random slopes by issue. |
| Economy puzzle | `output/resp_economy_puzzle.rds` | CURRENT | With/without committee. |
| Year FE comparison | `output/resp_year_vs_semester_fe.rds` | CURRENT | Robustness check. |
| Year FE domain trends | `output/resp_domain_trends_year_fe.rds` | CURRENT | Robustness check. |
| Time series data | `output/resp_timeseries_data.rds` | CURRENT | For circuit plots. |
| Scatter data | `output/resp_scatter_data.rds` | CURRENT | For scatter plots. |
| Temporal data | `output/resp_temporal_data.rds` | CURRENT | For temporal scatter. |
| Report summary | `output/report_summary.rds` | OUTDATED | From pre-fix 09 script. |

## 7. Figures

| Figure | Location | Status | In EDA? |
|--------|----------|--------|---------|
| CV over time by domain | `output/figures/resp_europeanisation_cv_time.pdf` | CURRENT | Yes |
| CV heatmap | `output/figures/resp_europeanisation_cv_heatmap.pdf` | CURRENT | Yes |
| Congruence over time | `output/figures/resp_congruence_time.pdf` | CURRENT | Yes |
| Circuit: economy | `output/figures/resp_circuit_economy.pdf` | CURRENT | Yes |
| Circuit: migration | `output/figures/resp_circuit_migration.pdf` | CURRENT | Yes |
| Scatter: raw | `output/figures/resp_scatter_responsiveness.pdf` | CURRENT | Yes |
| Scatter: normalised | `output/figures/resp_scatter_responsiveness_norm.pdf` | CURRENT | Yes |
| Scatter: combined | `output/figures/resp_scatter_combined.pdf` | CURRENT | No (alternative) |
| Temporal: economy | `output/figures/resp_temporal_economy.pdf` | CURRENT | Yes (combined) |
| Temporal: migration | `output/figures/resp_temporal_migration.pdf` | CURRENT | Yes (combined) |
| Temporal: combined | `output/figures/resp_temporal_combined.pdf` | CURRENT | Yes |
| Decomposition forest | `output/figures/resp_forest_decomposition.pdf` | CURRENT | Yes |
| M5 issue slopes | `output/figures/resp_m5_issue_slopes.pdf` | CURRENT | Yes |
| DHARMa m0–m3 | `output/figures/resp_dharma_m*.pdf` | CURRENT | No (diagnostics) |
| Report figures | `output/figures/report_*.pdf` | OUTDATED | No (from pre-fix 09) |

## 8. External Data (Pending)

| Data | Source | Status | Action Needed |
|------|--------|--------|---------------|
| COMEPELDA electoral systems | Harvard Dataverse doi:10.7910/DVN/GNRMTO | PENDING | Download, extend to 2019/2024, integrate. ON HOLD per user. |
| Federico's Misery Index | Federico (`scripts/R/08b`/`08c` on `federico-experiments` branch) | DONE | Numbers reported in Tokyo deck Robustness slide; full integration pending branch merge post-Tokyo. |
| Crime / homicide indicator | Eurostat `crim_hom_soff` or UNODC | PLANNED | Per post-seminar memo (2026-04-21): priority addition, two-to-three-day implementation, third domain coverage. |
| Terror events | GTD or RAND | OPTIONAL | Companion to homicide for the security domain; decision pending. |
| Consumer confidence | Eurostat / DG ECFIN | OPTIONAL | Perception-side economic indicator; methods-memo enrichment, not a need. |
| Migration indicator expansion | Eurostat `migr_imm*`, Frontex, UNHCR | OUT OF SCOPE | Reserved for the "Questioning Migration" spinoff (Section 11). |
| Environment indicators | EM-DAT, Eurostat air-quality, Copernicus | DEFERRED | To the book or a dedicated paper – CO2 slow-moving, salience event-driven. |

## 9. Session Logs

| Log | Location | Status |
|-----|----------|--------|
| Planning + implementation | `quality_reports/session_logs/2026-03-27_responsiveness-paper-planning.md` | CURRENT |
| Tokyo presentation prep | `quality_reports/session_logs/2026-04-19_tokyo-presentation.md` | CURRENT |
| Tokyo deck revisions (rounds 2 – 4) | `quality_reports/session_logs/2026-04-21_tokyo-revisions.md` | CURRENT |
| Post-Tokyo follow-up | `quality_reports/session_logs/2026-04-22_post-seminar-followup.md` | CURRENT |

## 10. Bibliography

| File | Location | Status | Action Needed |
|------|----------|--------|---------------|
| Project bibliography | `ep.bib` | CURRENT | Tokyo-deck stubs added (Cotta 2012, Lord 2018, Borghetto-Seeberg, Baumgartner et al. 2009, Pitkin 1967); marked `% verify against Zotero after the trip`. ~89 lit-review entries still pending verification. |

---

## 11. Tokyo Presentation Deliverables (2026-04-21)

| Deliverable | Location | Status | Notes |
|-------------|----------|--------|-------|
| **Slide deck (QMD)** | `slides/whose_voice_tokyo.qmd` | CURRENT | RevealJS, embed-resources, 24 slides, speaker notes throughout. |
| **Slide deck (HTML)** | `slides/whose_voice_tokyo.html` | CURRENT | 4.6 MB self-contained, no `_files/`. Re-render after any QMD edit. |
| **Custom theme** | `slides/custom.scss` | CURRENT | `.po` class for Predictor/Outcome sublines. |
| **Methods memo** | `quality_reports/2026-04-19_methods-memo.md` (+ `.pdf`) | CURRENT | 14 sections including IRR primer (11b) and speaker glossary (14). PDF 97 KB. |
| **Speaker glossary handout** | `quality_reports/2026-04-21_speaker-glossary.md` (+ `.pdf`) | CURRENT | Two-column letter-paper printable, 35 KB PDF. |
| **Post-seminar feedback memo** | `quality_reports/2026-04-21_post-seminar-feedback.md` (+ `.pdf`) | CURRENT | Tokyo + EUI Q&A synthesis; ready to share with Federico. |

---

## 12. Spinoff – Questioning Migration (single-author, planned)

| Document | Location | Status | Notes |
|----------|----------|--------|-------|
| **Project brief** | `quality_reports/plans/2026-04-22_questioning-migration-paper.md` | PLANNED | Kickoff in the coming weeks. Marcello only; Federico not involved. |
| **Sandbox folder** | `explorations/questioning_migration/` (with README) | CREATED | Empty; for indicator pulls, classifier prototyping, exploratory notebooks. |
| **Working title** | – | – | "Questioning Migration: How MEPs Respond to the Multiple Faces of Migration in Europe (2003 – 2024)". |
| **Working RQs** | – | – | Q1 (within-migration heterogeneity in attention) + Q3 (within-migration heterogeneity in framing/stance), with 2015-16 as a quasi-experimental section. |

---

## What Needs Input from Authors

1. **Share post-seminar feedback memo PDF with Federico** — synthesis of Tokyo + EUI comments, ready in `quality_reports/2026-04-21_post-seminar-feedback.pdf`.
2. **Crime indicator scope** — homicide rate alone, or homicide + terror events?
3. **Consumer confidence** — include as perception-side economic indicator, or skip?
4. **Term-interacted robustness model** — main text or appendix?
5. **COMEPELDA timing** — still on hold; revisit after the next paper round.
6. **BibTeX verification** — ~89 lit-review entries plus the six Tokyo-deck stubs.
7. **MEP descriptive appendix** — keep in this paper or promise as a companion piece?
8. **Branch merge timing** — when to merge `federico-experiments` (Misery Index pipeline) into `main`.
