# Session log — 2026-11-18: Option-A promotion refits (TERM / CMP / LIBE)

**Scope**: audit remediation item 1 (`quality_reports/2026-11-18_pipeline-scripts-audit.md`,
finding 1 — post-promotion DV-generation debt: TERM hard-fails on rerun; CMP/LIBE silently
refit on the keyword DV). FR decision 2026-11-18: **Option A** — promote all three variant
fits to the refined LLM (R2) DV promoted primary on 2026-11-17, recompute every invariant,
archive the keyword-vintage artifacts, refit.

## Actions (chronological)
1. One-off read-only preflight (`/tmp/preflight_promotion_invariants.R`): exact replica of
   the `05_models.R` §1b overlay + each variant script's filters. Outcome (all asserts
   passed): refined minority events by term **12/27/11**; refined DV sums **739 / 599 (CMP)
   / 753 (LIBE)**; CMP minority structure **52 MEPs / 306 MEP-years** (= 51/301 +
   MEP 28125, minority.csv update of 2026-11-13); keyword-vintage cross-checks on the
   same samples: CMP 1,063 (+25 DV-201 force-keep events vs the 2026-11-12 fit's 1,038),
   LIBE 1,270; LIBE focal cell 56 MEP-years / 11 MEPs with **21 refined events**
   (keyword feasibility check: 23).
2. Script edits (every pin recomputed, none invented):
   - `scripts/05_models_Bayesian_TERM.R` — header provenance addendum; events assert
     re-anchored to the refined DV; NEW vintage pins (refined DV sum 739; keyword column
     1,244; keyword-vintage minority events 17/24/9).
   - `scripts/05_models_Bayesian_CMP.R` — §1b DV-promotion overlay (verbatim logic from
     `05_models.R`); asserts re-anchored (52/306 minority; refined DV 599; keyword
     cross-check 1,063); header sample facts recomputed; §7 / smoke-test anchors relabeled
     with vintage attributions.
   - `scripts/05_models_Bayesian_LIBE.R` — §1b overlay; header addendum; NEW asserts
     (refined DV 753; focal-cell events 21; keyword cross-check 1,270) — closes the missing
     DV-sum tripwire.
   - `scripts/utils/run_promotion_refits_2026-11-18.sh` — new guarded dated runner.
   - `scripts/utils/run_dv201_phase2.sh` — RETIRED with a guard (`FORCE_DV201_PHASE2=1`
     override; documents the 2026-11-13 history and why rerun is dangerous).
3. Keyword-vintage artifacts (22 files: 4 brm caches + 2 estimation samples + 16 CSVs)
   archived BEFORE refitting into `output/archive_keyword_dv_2026-11-18/`
   (`MANIFEST.md` + `md5_manifest.txt`). Runner preflight guards re-verify promotion
   markers and the refined-vintage panel on every invocation.
4. Refits launched via `scripts/utils/run_promotion_refits_2026-11-18.sh`
   (09:11:42), sequential TERM → CMP (M1 interaction + M2 libe-only) → LIBE; runtime log:
   `quality_reports/session_logs/2026-11-18_promotion_refits.log`.

## Fit-time invariant verification (from `2026-11-18_promotion_refits.log`)

- **TERM** (start 09:11:44): refined panel loaded read-only; asserts passed — N 10,955 /
  27 countries / 1,707 MEPs / minority events **12/27/11**; new vintage pins passed
  (refined DV sum 739; keyword column 1,244; keyword minority events 17/24/9). Step OK
  09:33:27 (fit 21.3 min). Gate: 1.0023 / 2,688 / 0 div.
- **CMP** (start 09:33:27): §1b overlay assertions passed (529/255 ids, 1,319 → 784 (−535)
  window, `total_questions` equality); recomputed sample pins passed — N 9,850 / 23
  countries / 1,543 MEPs / minority **52/306** / refined DV **599** / keyword cross-check
  **1,063**. Both fits OK 10:09:15 (M1 17 min, M2 17.8 min). Gate: M1 1.0044 / 1,515 /
  0 div; M2 1.0014 / 2,907 / 0 div.
- **LIBE** (start 10:09:15): overlay + new DV pins passed — N 11,042 / 28 countries /
  focal cell 56×11 / refined DV **753** / focal events **21** / keyword cross-check
  **1,270**. Step OK 10:29:34 (fit 19.8 min). Gate: 1.0028 / 2,535 / 0 div.
- **PROMOTION REFITS COMPLETE 10:29:34.** Fresh refined-vintage artifacts written:
  `bayesian_model_{term,cmp,cmp_libeonly,libe}.rds`, `df_model_data_libe.rds` (refined
  sample), and the sixteen `bayesian_{term,cmp,cmp_libeonly,libe}_*.csv` result tables.
  Keyword vintages live in `output/archive_keyword_dv_2026-11-18/` (22 files + MANIFEST +
  md5). New estimates recorded in `quality_reports/2026-11-18_variant-promotion-refits_term-cmp-libe.md` §6.
