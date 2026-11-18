# Pipeline Scripts Audit — EPmigrants (2026-11-18)

**Auditor:** Cline session for Federico Russo · **Mode:** read-only audit (no fixes applied; fixes proposed only)
**Scope (approved):** core pipeline (`run_pipeline.R`, `01`–`07`, `08_llm_screen.py`) + 8 `05_models_*` variants + 6 pipeline-relevant utils, ≈ 6,400 lines.
**Out of scope:** model re-runs, manuscript-number checks, coding-workflow utils (dictionaries, minority-coding sheets), applying fixes.

## 0. Method & evidence base

1. Full close-read of every in-scope script (all middles read, none skipped).
2. Read-only validation: `parse()` on all 22 in-scope R files (all clean; note there is **no** `05_models_Bayesian_FE.R` — the FE variant is `05_models_FE.R`, frequentist), `python3 -m py_compile` on `08` (clean).
3. Artifact forensics: md5 of current vs archived (`archive_spec_promotion_2026-11-17`) Bayesian artifacts; readRDS inspection of `output/df_model_data.rds`; mtime ledger of `output/`.
4. Cross-script consistency matrix (DV generation, sample source, windows, priors, iter/warmup, seeds, `brm(file=)` caches).
5. Non-mutating empirical checks: DV column classes/sums; Table-1 term-string matching vs `bayesian_model_results.csv`; `select()` trailing-comma behavior.

**Established panel facts (validated):** `df_model_data.rds`: 10,955 rows; refined DV sum **739** (367 rows = 1 event; 485 rows > 0); keyword DV sum **1,244**; 27 countries; gender F|M; 9 party-family levels; `leg_year` levels `7th1…9th5`. These match the promotion header (`05_models_Bayesian.R:5-7`) and the §2a asserts (`05_models.R:263-271`).

## 1. Executive Summary

- **Overall Assessment: Good — strong promotion governance, but a post-promotion consistency debt has accumulated in 4 auxiliary scripts, plus 1 latent pipeline-config hazard.**
- **Strengths:** exemplary DV-promotion machinery (§1b overlay + §2a equivalence gate + `verify_promotion_drift.R`, all passing, artifacts dated 2026-11-17/18); archive discipline with md5 manifests **verified against the archive files**; uniform `set.seed(20260321)` in every fitting script; assert-laden utils that parse-extract the `01` pattern from source; robust, resume-safe `08_llm_screen.py`; all 22 R files parse cleanly.
- **Top Priorities:**
  1. 🔴 Decide the DV generation for the pre-promotion-frozen auxiliary studies (`TERM` hard-fails on rerun; `CMP`/`LIBE` silently keep the keyword DV), and fix the `05_models_FE.R` output-path collision before anyone selects `model_version="FE"`.
  2. 🔴 Fix `06_model_comparison.R`'s estimand labeling (link-space conditional mean presented as expected count) and regenerate its stale figure (Nov 12) against the promoted refit.
  3. 🟡 Close small reproducibility gaps: `brm(seed=)` regression in the promoted scripts, unseeded `posterior_predict` in `06_Bayesian`, `FORCE_REDOWNLOAD` dead cache, unpinned environment (no `renv.lock`) contradicting "project renv" comments.

## 2. Detailed Analysis

### 🟢 Correctness and Logic

The core estimation path is correct and unusually well guarded: the promoted DV is a question-level replacement overlay (`05M:88-220`: 529 refined retained-DV ids + 255 verified-INs, with id-existence, no-overlap, uniqueness, window and baseline-1,319 asserts), re-aggregated in a block commented to mirror `02` exactly, then gated by §2a equivalence asserts against **both** the R2 derivation panel (`output/df_model_data_sensllm_r2.rds`) and the archived keyword panel (key-set equality, DV equality, `total_questions` equality to both) — `05M:262-280`. The two-estimand Bayesian spec (M1_total no-LIBE / M2_direct +LIBE) at 4000/1500 is convergence-gated on both fits (`05B:171-190`). Appendix B (`SKW`) restores manifest-verified archived keyword fits with its own asserts. My independent readRDS inspection reproduces every declared number (739 / 1,244 / 10,955).

One real estimation-adjacent issue: `06:37-44,83-90` predicts with `type="link"` and exponentiates — the **conditional count-model mean** for a ZINB — labeled "Expected Mean Question Count"; the Bayesian twin uses `posterior_predict` (full ZINB mean incl. zero-inflation). Parallel figures, systematically different scales. The shipped frequentist figure (`output/figures/m4_interaction_magnitude_panel.png`, Nov 12 17:55) also predates the promoted refit of `zinb_model4.rds` (Nov 18 00:00): artifact ≠ model.

### 🎨 Style and Readability

Mixed pipes (`%>%` in `01`,`04`,`05*`; `|>` in `02`,`03`), `rm(list=ls())` in model scripts, console debris (`01:25-28` unassigned `count/filter` chain), dead helpers (`check_na` defined `02:13-17`, never called), benign trailing comma in `select()` (`01:48`), and the M-numbering collision: frequentist ladder M1–M4 (M1 = baseline **without** minority) vs Bayesian M1_total/M2_direct (M1 = **with** minority, without LIBE). Both ladders are documented locally, but `07` merges them into one output table where "M1" means different models per engine.

### ⚡ Performance and Optimization

No consequential defects: vectorized throughout; the many-to-many committee-overlap join (`02:196`) is the heaviest step but bounded and intentional. The real bottleneck is `04`'s API download — repeated **every** run because `FORCE_REDOWNLOAD <- TRUE` (`04:32`) makes the cache branch dead (`04:35-37` untakeable) while the written `data_processed/covariates_cache.rds` (`04:202`) is never read.

### 🛡️ Robustness and Error Handling

Assert discipline is above average: readable `stopifnot` gates at every fragile join (rows, columns, event counts, per-term counts, sd checks — e.g. `CMP:139-155`, `TERM:106-128`, `update_dv201_decisions.R:35-63`). `brm(file=)` caching is understood, documented, and was followed correctly at the promotion (md5-verified: current fits/panel differ from archived keyword versions). Remaining debts: (a) unpinned environment — no `renv.lock`/`.Rprofile`/`renv/` exists while scripts say "under the project renv" (`LIBE:36-37`) and all `install.packages()` calls lack `repos=` (non-interactive failure); (b) the promotion-night scripts dropped `seed=` from `brm()` (older CMP/LIBE/TERM have it) so refits are not draw-reproducible; (c) both `06` scripts lack any seed.

**Line abbreviations used below:** `01`=`01_import_questions.R`, `02`=`02_df_setup.R`, `03`, `04`; `05M`=`05_models.R`, `05B`=`05_models_Bayesian.R`, `05FE`=`05_models_FE.R`; `CMP/LIBE/TERM/SENS/SLLM/R2/SKW`=`05_models_Bayesian_*`; `06`/`06B`=comparison; `07`=extractor; `08`=`08_llm_screen.py`; `T1T`/`DRFT`=utils.

---

## 3. Detailed Line-by-Line Feedback

| Script:line | Impact | Issue | Suggested improvement |
| :--- | :--- | :--- | :--- |
| `05B:118-135,149-164` | 🔴 High | Promotion-night `brm()` calls **lack `seed=`** — refits not draw-reproducible (`set.seed(20260321)` at `05B:52` does not control Stan chain seeds). Old variants have it (`LIBE:177`, `TERM:224`, `CMP:290,491`). Same omission in `SENS:358-387`, `SLLM`, `R2:264-290`, `SKW:75-107`. | Add `seed = 20260321` to every `brm()` call (one policy, all scripts). |
| `05FE:145,160,175` | 🔴 High | `saveRDS(zinb_model1/2/3, "output/zinb_model{1,2,3}.rds")` — **same paths as the primary frequentist ladder**. `run_pipeline:46-50` offers `model_version="FE"`; that run overwrites the primary fits (keyword-DV, country-FE) → mixed-generation `output/`. | Write `output/fe/zinb_model*.rds`; keep `model_coefficients_comparisonFE.csv` naming. |
| `05FE:111-120` | 🔴 High | FE variant rebuilds its own sample from `df_merged_3.csv` (**keyword DV**) with CMP-structural exclusion — silently stays on the demoted DV post-promotion while sharing the primary ladder's artifact namespace. | Re-run on the promoted DV, or pin as keyword-DV in the header; decouple from the path collision regardless. |
| `TERM:106-128` | 🔴 High | Invariants pinned to the **pre-promotion** DV (minority events 17/24/9 `:122-123`, 56 minority MEPs, N) asserted against the *primary* sample, which now carries the refined DV → **rerun fails the gate**; shipped `bayesian_term_*` artifacts (Nov 13 15:36) are keyword-vintage. `run_dv201_phase2.sh` depends on this script succeeding. | Recompute invariants for the promoted DV (and refit), or pin TERM to an archived sample copy. |
| `CMP:85-91,139-159` | 🔴 High | Built from `df_merged_3.csv`; asserts `sum(DV)==1038`, N=9,850, sd=4.0073 — **keyword-vintage, frozen 2026-11-12**. Asserts still pass (overlay never touches `df_merged_3.csv`): the study *silently* remains keyword-DV post-promotion. | FR decision: (a) re-run on the refined DV (re-derive every pinned number), or (b) document as keyword-DV appendix + header note. |
| `LIBE:97-140` | 🔴 High | Same class as CMP: sampled from `df_merged_3.csv` (keyword DV, all-country sample) — silent DV-generation mismatch. | Same as CMP. |
| `06:37-44,83-90` | 🔴 High | `predict(type="link")`+`exp()` = conditional count-model mean, labeled "Expected Mean Question Count"; Bayesian twin shows the full ZINB mean (`06B:52,102`) — different estimand, different scale. | Use response-scale expectation or simulate draws like `06B`; relabel the axis. |
| Output ledger | 🔴 High | `output/figures/m4_interaction_magnitude_panel.png` (Nov 12 17:55) **stale** vs refitted `zinb_model4.rds` (Nov 18 00:00); `bayesian_term_*` (Nov 13) keyword-vintage by freeze. | Re-run `06` (cheap, models cached); regenerate term artifacts after the TERM decision. |
| `07:220-244` | 🟡 Medium | §7 `interaction_summary` applies frequentist `p.value` semantics to Bayesian rows (`p.value`=NA → `"(ns)"` labels even when CrIs exclude 0); persists the mixed-engine label to `output/interaction_effects_summary.csv` (Nov 18 01:04, current). | Branch by engine (Bayesian → CrI-based labels); add an `engine` column to the CSV. |
| `04:32-37,202` | 🟡 Medium | `FORCE_REDOWNLOAD <- TRUE` → cache branch dead; every run hits Eurostat/WDI; cache written, never read. | `FALSE` default or env-var override; cache as fast path (current `problem_indicators.csv` is Nov 18-valid from Aug download). |
| `04:5-10`, `run_pipeline:21-26`, all fitting scripts | 🟡 Medium | Bare `install.packages()` (no `repos=`) + zero environment pinning (no `renv.lock`) despite "under the project renv" comments (`LIBE:36-37`, `TERM` header). | Adopt `renv` (`renv::init/snapshot`) or centralize installs with explicit `repos` in `run_pipeline.R`. |
| `08:74-75,131-147` | 🟡 Medium | Review window `2009-07-01..2024-08-01` ⊃ R derivation window `2009-07-14..2024-07-15` ⊃ aggregation cutoff `2024-06-08`; `term_from_date` month-grained sends `2019-07-01`→IX while `02:281-284` drops it. DV unaffected (id lists window-asserted); FR scope/docs inconsistent three ways. | Align the screen window to the derivation window; document supersets in the header. |
| `06B:52,102` | 🟡 Medium | `posterior_predict()` unseeded; no `set.seed` in either `06` — Bayesian figure not reproducible run-to-run (frequentist `06` is deterministic). | `set.seed(20260321)` at script top (and/or `seed=` in calls). |
| `03:55-76,~95-115,~120-140,~140-245` | 🟡 Medium | Four hardcoded provenance blocks: `country_features` (`cmp_mean` NA for HU & SK), `euro_entry_year`, `populist_in_gov` (hand-coded country-year history incl. debatable entries), `eu_budget_status`. No sources/as-of dates. | Add source + as-of comment per block; consider `data/` CSV + README. |
| `04:89-99` | 🟡 Medium | UK GDP growth 2005-2020 hardcoded (incl. −10.4 for 2020), injected over Eurostat. | Cite source + as-of date, or pull from WDI. |
| `SKW:34-40,89,107` | 🟡 Medium | `brm(file=here(archive_dir, "bayesian_model_m?.rds"))` uses the **promoted archive as live cache store** — a future spec edit silently refits *and overwrites archived keyword artifacts*. | Copy fits to a scratch cache dir, or restore via `readRDS` with `file=NULL`. |
| `LIBE:150-157`, `TERM:~245-250`, `CMP:262-264` | 🟡 Medium | Headers claim settings "IDENTICAL to 05_models_Bayesian.R … 2,000 iters" — now false (primary 4000/1500 since promotion); comparability comments drifted. | Update header notes (actual settings + promotion delta). |
| `run_pipeline:46-55,64-67` | 🟡 Medium | Config matrix not validated: `comparison_map` lacks "FE"; FE mode appends no `07`; FE+Bayesian combination would mix vintages. | Whitelist validated `(model, comparison)` pairs; `stopifnot` the config. |
| `run_pipeline:117-125` | 🟡 Medium | Error detection = exit status + regex sniffing; `Execution halted` w/o `Error:` passes. | Add `^Execution halted`, `^Error in` patterns (exit-status primacy retained). |
| `02:276-297` vs `05M:151-155` | 🟢 Low | Aggregation end 2024-06-08 (`02:278`) < DV-definition end 2024-07-15: corpus DV events 784 vs in-panel 739 — known, explicitly logged ("protocol-tail note", `05M:~266-268`). | None; keep the note in the manuscript operationalization paragraph. |
| `01:183-189` | 🟢 Low | `term_check` places 2019-07-01 in IX for the corpus assert while `02` drops it via `year_index<=5` — deliberate, assert-pinned (`01:197-208`; 5 edge rows). | None; maybe cross-reference in `02`. |
| `01:25-28`, `01:48` | 🟢 Low | Dead console fragment (unassigned `count/filter` chain); trailing comma (empty arg) in `select()` — parses and runs (verified), style only. | Remove both. |
| `02:13-17`, `02:100-135` | 🟢 Low | `check_na()` defined, never called; `group_abbr` maps "Group Union for Europe"→PPE while `party_family` maps it→Eurosceptic conservatives (unreachable in 2004-2024; latent only). | Delete dead helper; harmonize mappings or comment the divergence. |
| Stale files | 🟢 Low | `scripts/main.R` (0 B); `scripts/#07_Exploratory analysis.r` (references a gone `n_subtopic_201` column); `scripts/test_system2.R`; root `test.R` (12 B); `Rplots.pdf` (regenerated Nov 18); `scripts/.Rhistory` (0 B); `scripts/__pycache__/`; `PROJECT_INDEX.md:Zone.Identifier`; empty `output/tables/`. | Delete dead files; extend `.gitignore` (`Rplots.pdf`, `.Rhistory`, `__pycache__/`, `*.Zone.Identifier`). |

## 4. Per-Script Audit Notes

**Upstream.** `01` (217 ln): CAP-201 filter is word-boundary-safe with documented regex history (`01:73-84`), force-keep/rescue allowlists (`01:162-176`), and a full assert block pinning the corpus totals (1,319 / 608-482-229 / 5 edge rows) — good. `02` (333 ln): committee→`committee_most_time` heuristic takes max-overlap per leg year with dplyr-stable tie-breaking (`02:213-218`); the 9th-term stub year is created then explicitly filtered in both expansions (`02:246`, `02:219`) — consistent. Boundary note: `assign_term` puts 2019-07-01 in the 8th → those 5 corpus questions drop from the panel (`02:284`). `03` (363 ln): joins by `country_name`+`leg_year`; re-declares `legislature_starts` (`03:299-305` = duplicate of `02:36-40`, values match); year-varying `euro_member` correctly overrides the static flag (`03:326,334-337`). `04` (207 ln): EL→GR harmonized throughout; `safe_interpolate` guards low-data series (`04:185-193`); `misery_index = unemp + bond − gdp_growth` (`04:200`); structural issue = dead cache flag (table).

**Model core.** `05M` (467 ln): §1 centering → §1b overlay (question-level `pq_r2`; asserts 784 / −535 / per-term 378-301-105) → §2 MIPEX-only structural exclusion (programmatic; Malta is the 100%-NA country) + listwise drop → §2a equivalence gate (10,955 rows; 739/1,244 events; keys == R2 panel; `total_questions` == both refs) → 4 glmmTMB ZINB models with `offset(log(total_questions+1))`, `(1|mep_id)+(1|country)`. Frequentist ladder: M1 baseline (no minority) → M2 +minority → M3 +MIPEX → M4 interaction. `05B` (219 ln): same sample by reference; priors `student_t(3,0,2.5)` on `b` and `zi`; convergence gate Rhat≤1.01 / ESSratio≥0.10 / 0 divergences on **both** fits (`05B:171-190`); documented M2 ESS-gate history + cache-deletion instruction (`05B:139-148`) — manual, not enforced, but executed correctly at the promotion (md5 evidence).

**Variants.** `SENS` (own keyword-extension DV from FR decisions), `SLLM` (R1: keyword+255 INs), `R2` (frozen refined derivation; §2a reference panel) and `SKW` (Appendix B; archives-based) are promotion-night-consistent and self-pinning. `CMP`, `LIBE`, `TERM` predate the promotion (🔴 rows). `05FE` (240 ln): country FE via `factor(country)` in-formula (`05FE:136-175`), 3 models, interaction `minority:cmp_center` with main effect absorbed by FE — coherent, but keyword-DV + path collision (🔴).

**Consumers.** `06`/`06B`: mirrored grids (gender="M", party_family reference, offset at mean); `06B:15-19` documents that it visualizes M1_total (its grids' `libe` unused there) — correct; estimand mislabel + missing seed remain. `07` (248 ln): fits from both engines; wide + Bayesian tables (refined-consistent, Nov 18 01:04); §7 mislabels (table).

**Pipeline & utils.** `run_pipeline`: order 01→04→05M→(05B)→(06B)→07 with per-step `system2` capture — sound; config-validation + FE hazards as in table. `T1T` (63 ln): term strings match brms/broom output verbatim (verified: CSV literally holds `party_familyRightMwingnationalists`, `party_familyGreensDEFA`; the 3 em-dash cells in `table1_canonical.md` are exactly the M1-`libe` cells — correct by design). `DRFT` (41 ln): drift gate est ≤0.02 / bounds ≤0.03 — **passed** (artifact Nov 17 20:01). `build_dv201_review_batches.R` (207 ln): parse-extracts `cap201_exclusion_pattern`/rescue ids **from `01` as single source** (`:43-56`) + write-guard on FR-coded files (`:184-196`) — exemplary. `update_dv201_decisions.R` (91 ln): full numeric audit trail (216/29/187; 11/10/8 per term; 2 documented cross-batch id collisions). `archive_pre_dv201_rerun.sh`: moves artifacts, idempotence guard, md5 manifest. `run_dv201_phase2.sh` (2026-11-13): waits on primary-rerun log, archives stale TERM/LIBE caches, re-runs sens→TERM→LIBE (the TERM step will now fail; see 🔴).

`08` (≈470 ln, stdlib-only): resume-safe append skipping coded/PENDING ids (`:377-386`), threaded workers with per-row error capture and token accounting (`:420-460`), meta JSON with latency percentiles; clean `py_compile`; window/term semantics in table.

## 5. Cross-Script Consistency Matrix

| Script | DV used | Sample source | Iter (warmup) | `seed=` in brm | Cache (`file=`) | Post-promotion status |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| `05M` freq | refined (built in-script) | builds `df_model_data.rds` | glmmTMB (n/a) | n/a | n/a | ✅ current (Nov 17 23:59) |
| `05B` | refined (from `05M` panel) | `df_model_data.rds` read | 4000 (1500) | **missing** ⚠️ | both fits | ✅ refit Nov 18 00:32/01:00 |
| `SENS` | own keyword-extension DV | rebuilds from `epq.rds`+decisions | 4000 (1500) | **missing** ⚠️ | own paths | ✅ keyword-era **by design** (header) |
| `SLLM` | keyword+255 INs (R1) | derived panel | 4000 (1500) | **missing** ⚠️ | own paths | ✅ (Nov 17 20:04) |
| `R2` | refined R2 (frozen derivation) | derived panel | 4000 (1500) | **missing** ⚠️ | own paths | ✅ (Nov 17 20:01); §2a reference |
| `SKW` | keyword (Appendix B) | **archived panel** (asserted vs shipped) | 4000 (1500) | **missing** ⚠️ | **archive dir** ⚠️ | ✅ (Nov 18 00:02) |
| `CMP` | **keyword** ⚠️ | `df_merged_3.csv` (23 CMP cty) | 2000 (1000) | ✅ `:290,491` | own paths | 🔴 silent old-DV study (Nov 12) |
| `LIBE` | **keyword** ⚠️ | `df_merged_3.csv` (28 cty) | 2000 (1000) | ✅ `:177` | own paths | 🔴 silent old-DV study (Nov 13) |
| `TERM` | refined *by reference* ⚠️ | `df_model_data.rds` read-only | 2000 (1000) | ✅ `:224` | own paths | 🔴 asserts → rerun halt |
| `05FE` | **keyword** ⚠️ | `df_merged_3.csv` rebuild | glmmTMB FE | n/a | **primary paths** ⚠️ | 🔴 latent collision |
| `06`/`06B`/`07` | refined (consumers) | read current fits | n/a | — | n/a | ✅ current outputs except stale `06` figure |

**Window map.** DV-derivation `2009-07-14..2024-07-15` (`01` asserts, `05M` overlay) · corpus-kept total `..2024-06-15` (`01:187-189`) · MEP-year aggregation `2004-07-20..2024-06-08` + `year_index≤5` (`02`, `05M` overlay) · `08` screen `2009-07-01..2024-08-01`. The three DV-end values reconcile via the protocol-tail note; `2019-07-01` has three treatments (IX in `01` assert; VIII-then-dropped in `02`; IX in `08`) — documented in `01:178-186`, worth a cross-note in `02`/`08`.

**Priors parity:** `student_t(3,0,2.5)` on `b`+`zi`, brms-default RE SDs — identical across `05B/SENS/SLLM/R2/SKW/CMP/LIBE/TERM` (grep-verified). **Seed parity:** `set.seed(20260321)` in all 11 fitting scripts ✓; per-chain `seed=` present only in CMP/LIBE/TERM.

## 6. Promotion-Night Artifact Ledger (mtime forensics)

**Post-promotion (current):** dv201 id CSVs (Nov 17 18:35) → `SENSLLM/R2` panels (18:38) → their results (20:01-20:04) → `05M`/`df_model_data.rds`/zinb1-4 (23:59-00:00) → SKW results (00:02) → `05B` M1/M2 (00:32/01:00) → 06B figure (01:04) → 07 tables (01:04) → Table-1 mds (00:25/00:05/01:03) → promotion runlogs (`runlog_*_promotion.log`, 5 files). **Frozen pre-promotion (by design):** `SENSLLM/SKW` reference archive; `bayesian_sens_model_results.csv` (Nov 13 16:39). **Frozen pre-preparation (needs decision):** `bayesian_term_*` (Nov 13 15:36), `df_model_data_cmp.rds` (Nov 12 21:33), `df_model_data_libe.rds` (Nov 13 15:36). **Stale vs current model:** `m4_interaction_magnitude_panel.png` (Nov 12 17:55). **Unrelated staleness:** `problem_indicators.csv` (Aug 11) — covariates, DV-independent, fine. `output/tables/` empty since Jul 8.

**MD5 verification (mine vs manifest):** archive `df_model_data.rds` 24c05…, `bayesian_model_results.csv` 315f…, m1 7b0a…, m2 aaeb… — all match `MANIFEST.md` ✓; current fits/panel (3077…, 2d40…, 6495…, c979…) all differ from archive ✓ → the `brm(file=)` cache hazard did **not** materialize at the promotion.

## 7. Refactored Code (proposals — not applied)

### 🔴 `07:220-231` — engine-aware interaction summary
```r
interaction_summary <- all_coefficients %>%
  filter(str_detect(term, "minority.*:|minority.*\\*")) %>%
  mutate(engine = if_else(is.na(p.value), "Bayesian", "Frequentist")) %>%
  mutate(
    interpretation = case_when(
      is.na(p.value) & estimate > 0 & conf.high > 0 & conf.low > 0 ~
        "Positive (CrI excludes 0)",
      is.na(p.value) & estimate < 0 & conf.high < 0 & conf.low < 0 ~
        "Negative (CrI excludes 0)",
      is.na(p.value) & estimate > 0 ~ "Positive (CrI incl. 0)",
      is.na(p.value) & estimate < 0 ~ "Negative (CrI incl. 0)",
      estimate > 0 & p.value < 0.05 ~ "Positive & Significant",
      estimate < 0 & p.value < 0.05 ~ "Negative & Significant",
      estimate > 0 ~ "Positive (ns)",
      estimate < 0 ~ "Negative (ns)",
      TRUE ~ "Null"
    )
  )
```
The `engine` column is tagged in the preceding `mutate(engine = if_else(is.na(p.value), "Bayesian", "Frequentist"))`, so the mixed-engine CSV keeps one interpretation column with unambiguous semantics.

### 🟡 `04:32` — revive the cache
```r
FORCE_REDOWNLOAD <- identical(Sys.getenv("EP_COVARIATES_FORCE"), "1")
# if (!FORCE_REDOWNLOAD && file.exists(cache_path)) readRDS(cache_path) else { …download… }
```

### 🟢 `run_pipeline` — validated config pairs
```r
valid_combos <- list(
  "Bayesian" = c("Bayesian", "Standard"),
  "Standard" = "Standard",
  "FE"       = "Standard")
stopifnot(
  "Unsupported model version" = pipeline_config$model_version %in% names(valid_combos),
  "Unsupported comparison for this model" =
    pipeline_config$comparison_version %in% valid_combos[[pipeline_config$model_version]])
```

### 🟢 `06:41-43` — honest frequentist CI/estimand
Replace `type="link"`+`exp()` with `type="response"` prediction (glmmTMB then applies the zi component for the expected count) and compute CIs by simulating (`predict(., newdata, type="response"`, or `simulate()`), or relabel the panel explicitly.

## 8. Reproducibility Assessment

- **Environment:** unpinned. No `renv.lock`/`.Rprofile`; every script installs on demand with no `repos=`. Session logs + runlogs + md5 manifests partially compensate. → adopt `renv` or a documented package-version table.
- **Seeds:** uniform `set.seed(20260321)` ✓; per-chain `seed=` regression in the 5 promoted scripts (older variants seed correctly) — the §2a/drift gates make *numerical* drift detectable at promotion time, which is why the current outputs are trustworthy; still, add `seed=` for clean reruns.
- **`brm(file=)` discipline:** documented in every variant header; promotion executed correctly (md5-verified). Residual risks: manual cache-deletion requirement (`05B:143-145`) and SKW's archive-as-cache (table).
- **`06` figure reproducibility:** Bayesian figure unseeded; frequentist figure stale — regenerate both after fixes.
- **Pipeline determinism:** `01-04` are deterministic given raw inputs (with `04` re-downloading live data — set the flag to `FALSE` to make reruns offline-stable).

## 9. Prioritized Remediation Plan (proposals, in order)

1. **FR decision + fix (🔴):** DV generation for `TERM` (recompute invariants → refit on refined DV, or pin to archived sample), `CMP`, `LIBE` (re-run on refined DV vs. explicit keyword-DV labeling). Update `run_dv201_phase2.sh` expectations accordingly.
2. **Decouple `05FE` (🔴):** rename output paths (`output/fe/…`), add a keyword-DV header note (or promote to refined DV later); whitelist pipeline config pairs.
3. **Fix `06` estimand + regenerate both figures (🔴/🟡):** response-scale frequentist predictions, seed for `06B`.
4. **`07` §7 engine-aware summaries (🟡):** CrI-based interpretation for Bayesian rows + `engine` column.
5. **Seeds (🟡):** `seed = 20260321` in all five promoted `brm()` call sites.
6. **`04` cache + provenance comments (🟡):** flip `FORCE_REDOWNLOAD`, cite the UK GDP source, annotate `03`'s four hardcoded blocks.
7. **Env pinning (🟡):** `renv::snapshot()` (and fix "project renv" comments or make them true).
8. **Hygiene (🟢):** delete stale files, extend `.gitignore`, remove dead code (`01:25-28`, `02:13-17`), align `08` window constants, refresh LIBE/TERM/CMP header notes.

## 10. Validation of Audit Findings

- Parse: 22/22 R files clean; `08` compiles. (One earlier "PARSE-FAIL" was an auditor filename slip — no `05_models_Bayesian_FE.R` exists; the real file `05_models_FE.R` parses clean.)
- Panel facts reproduced independently by readRDS: 10,955 / 739 / 1,244 / 27 countries / F|M / 9 party families.
- Table-1 mappings verified against the live CSV; the 3 em-dash cells correspond to the M1-`libe` row (structurally correct).
- Promotion integrity verified via md5s (current ≠ archived keyword) and mtimes.
- No files were modified; no models were refit; no downloads were triggered.

*End of audit report.*

## 11. Addendum — Remediation Executed (2026-11-18, evening; FR directive)

Closure status of the §9 items touched by the frequentist-mirror rebuild
(`quality_reports/2026-11-18_frequentist-mirror-robustness.md`; session note
`2026-11-18_freq-mirror-rebuild.md`, runtime logs of the same date):

- **Finding 2 / §9-item 2 (05FE decouple) — CLOSED, stricter than proposed.**
  The legacy country-FE script (keyword-DV vintage) is not retuned but
  quarantined: `scripts/archive/2026-11-18_05_models_FE_legacy_keyword-dv_country-FE.R`
  (banner), removed from `run_pipeline.R`'s model_map with a matched-engine
  combination guard; its artifact was already in `output/archive_8th9th/`.
  `05_models.R` §3 now shares no artifact with the FE vintage. The keyword-era
  `libe_robustness/` outputs and July/August stale reports are archived under
  `output/archive_keyword_dv_2026-11-18/` — the pending "re-run or retire"
  decision is resolved by retirement (recoverable, manifest md5).
- **§9-item 3 (06 estimand + figures) — CLOSED for the frequentist figure.**
  `06_model_comparison.R` reads the frequentist M1_total twin and reports the
  response-scale ZINB mean `E[Y] = μ·(1 − P(excess zero))` with delta-method
  CIs (link + zlink components), relabelled; new
  `output/figures/freq_interaction_magnitude_panel.png` replaces the stale
  link-scale panel (archived). The Bayesian figure (06B) is unchanged — its
  reseed remains open under item 5.
- **§9-item 4 (07 engine-aware summaries) — CLOSED.** Interaction summary
  derives uncertainty per engine (Wald p for glmmTMB; 95% CrI coverage of 0
  for brms) with an `engine` column; Bayesian rows no longer default to
  "Null" (their `p.value` is NA). Wide/comprehensive tables rebuilt on the
  two estimand mirrors (2 frequentist + 2 Bayesian).
- **Frequentist engine replaced as a mirror (§7/§10 context).** `05_models.R`
  §3 fits exactly the two Bayesian estimands (M1_total / M2_direct, refined
  DV) via glmmTMB, with spec-parity, finite-SE and drift gates; drift vs the
  archived ladder M4 = 0.00e+00. Retired ladder fits/table + both stale
  figures in `output/archive_freq_mirror_2026-11-18/` (md5 manifest);
  `zinb_model4.rds` retained there as the live drift benchmark.
- Frequentist-vs-Bayesian verdict (memo §4): mirrors the primary on all
  substantive quantities; no manuscript number changes — ms §5 Robustness
  adds the third (estimation-paradigm) check.

Still open from §9 (unchanged): item 1 ms-side Appendix-B number refresh for
the promoted variants; items 5 (seeds incl. 06B), 6 (04/03 provenance),
7 (renv), 8 (hygiene).

## 12. Addendum 2 — Remediation R1–R4 Executed (2026-11-18, night; FR-approved sequence)

Closure status of the remaining §9 items. Executed per the persisted plan
(`quality_reports/plans/2026-11-18_audit-remediation-r1-r4.md`); full record
in `quality_reports/session_logs/2026-11-18_audit-remediation-r1-r4.md`.
No refits, no commits; the only pipeline execution was the md5-guarded `04`
validation run.

- **§9-item 5 (seeds) — CLOSED.** `seed = 20260321` added to all ten `brm()`
  call sites (05B M1/M2; SENS M1/M2; SLLM M1/M2; SLLM-R2 M1/M2; SKW M1/M2)
  and `set.seed(20260321)` at the top of `06_model_comparison_Bayesian.R`
  (seeds `posterior_predict` resampling) and `06_model_comparison.R`
  (cosmetic). Parses verified; no reruns needed — `brm(file=)` cache
  semantics untouched, existing fits reload exactly as before.
- **SKW archive-as-cache hazard — CLOSED (stricter than the table proposal).**
  md5-verified copies of the two archived keyword fits now live in the
  writable scratch cache `output/cache_skw_keyword/` (m1 `7b0af060…`, m2
  `aaebad9a…` — equal to the `MANIFEST.md` hashes); `brm(file =)` in SKW
  points at the scratch cache with a `stopifnot` existence guard. The archive
  is no longer a brm write target; `MANIFEST.md` carries an immutability
  addendum.
- **§9-item 8 (hygiene) — CLOSED.** The LIBE/TERM/CMP "IDENTICAL 4×2,000"
  header claims were replaced with honest settings-provenance notes (the
  variants genuinely run 2,000/1,000; the primary moved to 4,000/1,500 at the
  2026-11-17 promotion; the variants were refitted to the refined DV under
  their own settings in remediation 1, 'Option A'). Deleted: `scripts/main.R`,
  `scripts/test_system2.R`, `test.R`, `Rplots.pdf`,
  `PROJECT_INDEX.md:Zone.Identifier`. Archived: `scripts/#07_Exploratory
  analysis.r` → `scripts/archive/2026-11-18_07_Exploratory_analysis_legacy_scratch.r`
  (DO-NOT-RUN banner). Dead code removed: the `01`:24-28 dangling
  `count()/filter()` chain and `02`'s uncalled `check_na()` (the `01` epq
  duplicate check was already commented out and left). A window
  cross-reference was added in `08_llm_screen.py` (doc-only: screen superset ⊃
  `01` inclusion window ⊃ no-cutoff aggregation; 2019-07-01 → IX in both 01
  and 08; constants unchanged). `.gitignore` already contained `Rplots.pdf`
  and `*:Zone.Identifier` (earlier check mistaken; no edit needed).
- **§9-item 6 (04 cache + provenance) — CLOSED on the code side; FR
  provenance TODOs remain.** `04:32` now reads
  `FORCE_REDOWNLOAD <- identical(Sys.getenv("EP_COVARIATES_FORCE"), "1")`
  (offline-stable default; `EP_COVARIATES_FORCE=1` re-downloads from the
  Eurostat/WDI APIs). Guarded validation: the `04` rerun through the cache
  exited 0 and left `output/problem_indicators.csv` byte-identical (md5
  `8640be4f5c9bb294b929114d91116e6d` before = after). `# TODO(FR)`
  provenance stubs were added in `04` (UK GDP injection) and in all four
  hardcoded blocks of `03` (country_features/cmp_mean, euro_entry_year,
  populist_in_gov, eu_budget_status) — data values untouched.
- **§9-item 7 (env pinning) — CLOSED as "pinned, not isolated".** renv 1.3.1
  bootstrapped from CRAN; `renv::init(bare = TRUE)`; snapshot taken from the
  live user library → **`renv.lock` with 207 packages pinned under R 4.3.3**.
  Full renv activation was empirically tested (fresh-session `.libPaths()`
  = empty project library; `brms` unavailable) and deliberately deactivated
  after the lockfile write, because the approved scope was "pin versions, no
  library install" and the workspace must keep running as-is. Adoption path
  (`renv::activate()` + `renv::hydrate()`) documented in
  `quality_reports/2026-11-18_env-pinning-renv.md`.
  `scripts/run_pipeline.R` pins
  `options(repos = c(CRAN = "https://cloud.r-project.org"))` before its
  install fallback. Note: `xlsx` is referenced outside `scripts/` but not
  installed → not in the lock; `zoo` (1.8-15) is installed and locked.

Still open from §9 after this addendum: **item 1 only** (ms editorial
Appendix-B number refresh for the promoted variants; FR defers) plus the
FR-owned provenance TODOs of item 6 and the parked git-commit decision.

