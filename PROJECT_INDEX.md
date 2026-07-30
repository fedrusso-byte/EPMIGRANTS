# EPmigrants — Project Index

**Last updated:** 2026-07-30
**Project:** "Migration, Political Representation, and Policy Responsiveness in the European Parliament"
**Author:** Federico Russo, Università del Salento
**Repository:** https://github.com/fedrusso-byte/EPMIGRANTS.git

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
| Research specification | – | PENDING | To be created |
| Paper outline | – | PENDING | To be created |
| Implementation plan | – | PENDING | To be created |
| Next steps plan | – | PENDING | To be created |

## 2. Data Pipeline Scripts

| Script | Location | Status | Action Needed |
|--------|----------|--------|---------------|
| 01 Import questions | `scripts/01_import_questions.R` | CURRENT | Imports parliamentary questions data |
| 02 Dataframe setup | `scripts/02_df_setup.R` | CURRENT | Sets up analysis dataframe |
| 03 Country-level variables | `scripts/03_country_level_vars.R` | CURRENT | Downloads/creates country-level indicators |
| 04 Download problem indicators | `scripts/04_download_problem_indicators.R` | CURRENT | External data download |
| 05 Models (Bayesian) | `scripts/05_models_Bayesian.R` | CURRENT | Bayesian model specifications |
| 05 Models (FE) | `scripts/05_models_FE.r` | CURRENT | Fixed effects models |
| 05 Models | `scripts/05_models.R` | NEEDS INPUT | Zero-Inflated Binomial Negative Multilevel models — convergence issues with M1/M3 (NaN standard errors). See TO_DO.txt for resolution plan. |
| 06 Model comparison (Bayesian) | `scripts/06_model_comparison_Bayesian.R` | CURRENT | Bayesian model comparison |
| 06 Model comparison | `scripts/06_model_comparison.r` | CURRENT | Frequentist model comparison |
| Exploratory analysis | `scripts/#07_Exploratory analysis.r` | CURRENT | Exploratory data analysis |
| Main script | `scripts/main.R` | CURRENT | Pipeline orchestrator |
| Pipeline runner | `scripts/run_pipeline.R` | CURRENT | Executes full pipeline |

## 3. Utility Scripts

| Utility | Location | Status | Notes |
|---------|----------|--------|-------|
| CAP-MIP issue mapping | `scripts/utils/cap_issue_mapping.R` | CURRENT | Maps issues between CAP and MIP classifications |
| Babel files | `scripts/utils/babel_files.R` | CURRENT | Utility for file conversions |
| Converter | `scripts/utils/converter.R` | CURRENT | General conversion utilities |
| Dictionary: Geo-region IT | `scripts/utils/dictionary_georegion_it.R` | CURRENT | Italian geo-regional dictionary |
| Dictionary: MENA | `scripts/utils/dictionary_mena.R` | CURRENT | Middle East & North Africa dictionary |
| My dictionary | `scripts/utils/my_dict.R` | CURRENT | Custom dictionary |
| Check face validity | `scripts/utils/check_face_validity_problems.R` | CURRENT | Validity checks for problem indicators |
| Minor checkings / sample creation | `scripts/utils/minor-checkings_create-samples.R` | CURRENT | Data quality checks and sample creation |

## 4. Explorations

| Document | Location | Status | Action Needed |
|----------|----------|--------|---------------|
| Exploratory analyses | `explorations/` | EMPTY | Directory exists but empty. Ready for QMD/R scripts. |

## 5. Literature Reviews

| Review | Location | Status | Action Needed |
|--------|----------|--------|---------------|
| Literature reviews | `quality_reports/` | PENDING | Directory to be populated with review documents |

## 6. Model Outputs

| Output | Location | Status | Notes |
|--------|----------|--------|-------|
| Model outputs | `output/` | PENDING | Directory to be created/populated |

## 7. Figures

| Figure | Location | Status | In EDA? |
|--------|----------|--------|---------|
| Figures | `output/figures/` | PENDING | Directory to be created/populated |

## 8. External Data (Pending)

| Data | Source | Status | Action Needed |
|------|--------|--------|---------------|
| COMEPELDA electoral systems | Harvard Dataverse doi:10.7910/DVN/GNRMTO | PENDING | Download, extend to 2019/2024, integrate |
| Eurostat indicators | Eurostat | CURRENT | Various indicators downloaded via scripts |
| Additional indicators | Various | PENDING | To be identified based on research needs |

## 9. Session Logs

| Log | Location | Status |
|-----|----------|--------|
| Session logs | `quality_reports/session_logs/` | PENDING | Directory to be populated |

## 10. Bibliography

| File | Location | Status | Action Needed |
|------|----------|--------|---------------|
| Project bibliography | `ep.bib` | PENDING | To be created/populated |

## 11. Slides and Presentations

| Deliverable | Location | Status | Notes |
|-------------|----------|--------|-------|
| Slides | `slides/` | EMPTY | Directory exists but empty. Ready for QMD/SCSS files. |

## 12. Paper Manuscript

| Document | Location | Status | Notes |
|----------|----------|--------|-------|
| Draft manuscript | `paper/Draft_MEP Article.docx` | DRAFT | Word document draft |
| PDF | `paper/MentesogluTardivo_Russo_CAP2026.pdf` | CURRENT | CAP2026 conference paper |

## 13. Project Memory

| Document | Location | Status | Notes |
|----------|----------|--------|-------|
| Project memory | `memory/MEMORY.md` | CURRENT | Persistent project notes |
| User profile | `memory/user_profile.md` | CURRENT | User preferences and context |

---

## What Needs Input from Authors

1. **Model convergence issues (M1/M3)** — See TO_DO.txt for resolution options:
   - Option 1: Use `nlminb` optimizer with increased iterations on all models
   - Option 2: Simplify random effects structure
   - Option 3: Bayesian approach as primary specification

2. **Research design documentation** — Create formal research specification document

3. **Literature review** — Populate `quality_reports/` with systematic literature reviews

4. **Exploratory analyses** — Create QMD/R scripts in `explorations/` directory

5. **Output organization** — Establish output file naming conventions and structure

6. **Bibliography** — Create and populate `ep.bib` with project references

---

## Directory Structure Summary

```
EPmigrants/
├── scripts/
│   ├── 01_import_questions.R
│   ├── 02_df_setup.R
│   ├── 03_country_level_vars.R
│   ├── 04_download_problem_indicators.R
│   ├── 05_models*.R (3 variants)
│   ├── 06_model_comparison*.R (2 variants)
│   ├── #07_Exploratory analysis.r
│   ├── main.R
│   ├── run_pipeline.R
│   └── utils/ (8 utility scripts)
├── paper/
│   ├── Draft_MEP Article.docx
│   └── MentesogluTardivo_Russo_CAP2026.pdf
├── explorations/ (empty)
├── slides/ (empty)
├── quality_reports/ (empty)
├── output/ (to be created)
├── memory/
│   ├── MEMORY.md
│   └── user_profile.md
├── TO_DO.txt
├── PROJECT_INDEX.md
└── .clinerules